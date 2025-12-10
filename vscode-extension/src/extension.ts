/**
 * Eiffel Language Support Extension
 *
 * Connects VS Code to simple_lsp for Eiffel language features:
 * - Go to Definition
 * - Hover documentation
 * - Code completion
 * - Diagnostics
 * - Compile commands (Melt, Freeze, Finalize)
 */

import * as path from 'path';
import * as fs from 'fs';
import * as cp from 'child_process';
import { workspace, ExtensionContext, window, OutputChannel, commands, tasks, Task, TaskDefinition, ShellExecution, TaskScope, TaskRevealKind, TaskPanelKind } from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;
let outputChannel: OutputChannel;
let compileChannel: OutputChannel;

export function activate(context: ExtensionContext) {
    outputChannel = window.createOutputChannel('Eiffel LSP');
    compileChannel = window.createOutputChannel('Eiffel Compile');
    outputChannel.appendLine('Eiffel LSP extension activating...');

    // Register compile commands
    context.subscriptions.push(
        commands.registerCommand('eiffel.melt', () => runCompile('melt')),
        commands.registerCommand('eiffel.freeze', () => runCompile('freeze')),
        commands.registerCommand('eiffel.finalize', () => runCompile('finalize')),
        commands.registerCommand('eiffel.compileTests', () => runCompile('compile-tests')),
        commands.registerCommand('eiffel.runTests', () => runCompile('run-tests')),
        commands.registerCommand('eiffel.clean', () => cleanEifgens())
    );

    const serverPath = findServerPath(context);

    if (!serverPath) {
        window.showErrorMessage(
            'Could not find simple_lsp.exe. Please set eiffel.lsp.serverPath in settings.'
        );
        outputChannel.appendLine('ERROR: simple_lsp.exe not found');
        return;
    }

    outputChannel.appendLine(`Using LSP server: ${serverPath}`);

    // Server options - run the Eiffel LSP server
    const serverOptions: ServerOptions = {
        run: {
            command: serverPath,
            transport: TransportKind.stdio
        },
        debug: {
            command: serverPath,
            transport: TransportKind.stdio
        }
    };

    // Client options - activate for Eiffel files
    const clientOptions: LanguageClientOptions = {
        documentSelector: [
            { scheme: 'file', language: 'eiffel' }
        ],
        synchronize: {
            // Watch .e and .ecf files for changes
            fileEvents: workspace.createFileSystemWatcher('**/*.{e,ecf}')
        },
        outputChannel: outputChannel,
        traceOutputChannel: outputChannel
    };

    // Create the language client
    client = new LanguageClient(
        'eiffelLsp',
        'Eiffel Language Server',
        serverOptions,
        clientOptions
    );

    // Start the client (also starts the server)
    client.start().then(() => {
        // Get server info from initialize result
        const serverInfo = (client as any)._initializeResult?.serverInfo;
        const serverVersion = serverInfo?.version || 'unknown';
        const serverName = serverInfo?.name || 'simple_lsp';
        outputChannel.appendLine(`${serverName} v${serverVersion} connected`);
        window.showInformationMessage(`Eiffel LSP v${serverVersion} connected`);
    }).catch((error) => {
        outputChannel.appendLine(`ERROR starting LSP client: ${error}`);
        window.showErrorMessage(`Failed to start Eiffel LSP: ${error}`);
    });

    context.subscriptions.push({
        dispose: () => {
            if (client) {
                client.stop();
            }
        }
    });
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        return undefined;
    }
    return client.stop();
}

/**
 * Run Eiffel compile command with streaming output
 */
async function runCompile(compileType: 'melt' | 'freeze' | 'finalize' | 'compile-tests' | 'run-tests') {
    const workspaceFolders = workspace.workspaceFolders;
    if (!workspaceFolders || workspaceFolders.length === 0) {
        window.showErrorMessage('No workspace folder open');
        return;
    }

    const wsRoot = workspaceFolders[0].uri.fsPath;
    const ecfFile = await findEcfFile(wsRoot);

    if (!ecfFile) {
        window.showErrorMessage('No .ecf file found in workspace');
        return;
    }

    const compilerPath = findCompilerPath();
    if (!compilerPath) {
        window.showErrorMessage('EiffelStudio compiler (ec.exe) not found. Set eiffel.compilerPath or ISE_EIFFEL environment variable.');
        return;
    }

    // Determine the target based on compile type
    let target = '';
    const ecfBaseName = path.basename(ecfFile, '.ecf');

    if (compileType === 'compile-tests' || compileType === 'run-tests') {
        // Look for a _tests target
        target = ecfBaseName + '_tests';
    }

    // Build the command arguments
    const args: string[] = ['-batch', '-config', ecfFile];

    if (target) {
        args.push('-target', target);
    }

    // Add compile type flag
    switch (compileType) {
        case 'melt':
            // Default - no extra flag
            break;
        case 'freeze':
            args.push('-freeze');
            break;
        case 'finalize':
            args.push('-finalize');
            break;
        case 'compile-tests':
        case 'run-tests':
            // Just compile to W_code
            break;
    }

    // Add C compile flag
    args.push('-c_compile');

    compileChannel.clear();
    compileChannel.show(true);
    compileChannel.appendLine(`=== Eiffel ${compileType.toUpperCase()} ===`);
    compileChannel.appendLine(`Compiler: ${compilerPath}`);
    compileChannel.appendLine(`ECF: ${ecfFile}`);
    compileChannel.appendLine(`Target: ${target || '(default)'}`);
    compileChannel.appendLine(`Command: ${compilerPath} ${args.join(' ')}`);
    compileChannel.appendLine('');
    compileChannel.appendLine('--- Output ---');

    // Run the compiler with streaming output
    const startTime = Date.now();

    try {
        const exitCode = await runCommandWithStream(compilerPath, args, wsRoot, compileChannel);
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

        compileChannel.appendLine('');
        compileChannel.appendLine('--- Result ---');

        if (exitCode === 0) {
            compileChannel.appendLine(`SUCCESS (${elapsed}s)`);
            window.showInformationMessage(`Eiffel ${compileType} completed successfully`);

            // If run-tests, execute the test runner
            if (compileType === 'run-tests') {
                await runTests(wsRoot, ecfBaseName, target);
            }
        } else {
            compileChannel.appendLine(`FAILED with exit code ${exitCode} (${elapsed}s)`);
            window.showErrorMessage(`Eiffel ${compileType} failed`);
        }
    } catch (error) {
        compileChannel.appendLine(`ERROR: ${error}`);
        window.showErrorMessage(`Eiffel compile error: ${error}`);
    }
}

/**
 * Run a command with streaming output to the output channel
 */
function runCommandWithStream(command: string, args: string[], cwd: string, channel: OutputChannel): Promise<number> {
    return new Promise((resolve, reject) => {
        // On Windows, spawn with shell:true needs quoted paths for spaces
        // Use shell: false and quote the command ourselves for reliability
        const proc = cp.spawn(command, args, {
            cwd,
            shell: false,
            windowsVerbatimArguments: false
        });

        proc.stdout.on('data', (data: Buffer) => {
            channel.append(data.toString());
        });

        proc.stderr.on('data', (data: Buffer) => {
            channel.append(data.toString());
        });

        proc.on('error', (err) => {
            reject(err);
        });

        proc.on('close', (code) => {
            resolve(code ?? 1);
        });
    });
}

/**
 * Run the test executable
 */
async function runTests(wsRoot: string, ecfBaseName: string, target: string) {
    const targetName = target || ecfBaseName + '_tests';
    const exePath = path.join(wsRoot, 'EIFGENs', targetName, 'W_code', ecfBaseName + '.exe');

    if (!fs.existsSync(exePath)) {
        compileChannel.appendLine(`Test executable not found: ${exePath}`);
        return;
    }

    compileChannel.appendLine('');
    compileChannel.appendLine('--- Running Tests ---');
    compileChannel.appendLine(`Executable: ${exePath}`);
    compileChannel.appendLine('');

    try {
        const exitCode = await runCommandWithStream(exePath, [], wsRoot, compileChannel);
        compileChannel.appendLine('');
        if (exitCode === 0) {
            compileChannel.appendLine('Tests completed successfully');
        } else {
            compileChannel.appendLine(`Tests exited with code ${exitCode}`);
        }
    } catch (error) {
        compileChannel.appendLine(`Error running tests: ${error}`);
    }
}

/**
 * Clean (delete) the EIFGENs folder
 */
async function cleanEifgens() {
    const workspaceFolders = workspace.workspaceFolders;
    if (!workspaceFolders || workspaceFolders.length === 0) {
        window.showErrorMessage('No workspace folder open');
        return;
    }

    const wsRoot = workspaceFolders[0].uri.fsPath;
    const eifgensPath = path.join(wsRoot, 'EIFGENs');

    if (!fs.existsSync(eifgensPath)) {
        window.showInformationMessage('EIFGENs folder does not exist - nothing to clean');
        return;
    }

    const answer = await window.showWarningMessage(
        'Delete the EIFGENs folder? This will remove all compiled code.',
        { modal: true },
        'Delete'
    );

    if (answer === 'Delete') {
        compileChannel.clear();
        compileChannel.show(true);
        compileChannel.appendLine('=== Eiffel CLEAN ===');
        compileChannel.appendLine(`Deleting: ${eifgensPath}`);

        try {
            // Use rimraf-style recursive delete
            fs.rmSync(eifgensPath, { recursive: true, force: true });
            compileChannel.appendLine('EIFGENs folder deleted successfully');
            window.showInformationMessage('EIFGENs folder deleted');
        } catch (error) {
            compileChannel.appendLine(`Error: ${error}`);
            window.showErrorMessage(`Failed to delete EIFGENs: ${error}`);
        }
    }
}

/**
 * Find an .ecf file in the workspace
 */
async function findEcfFile(wsRoot: string): Promise<string | undefined> {
    const files = fs.readdirSync(wsRoot);
    const ecfFiles = files.filter(f => f.endsWith('.ecf'));

    if (ecfFiles.length === 0) {
        return undefined;
    }

    if (ecfFiles.length === 1) {
        return path.join(wsRoot, ecfFiles[0]);
    }

    // Multiple ECF files - let user choose
    const selected = await window.showQuickPick(ecfFiles, {
        placeHolder: 'Select ECF file to compile'
    });

    return selected ? path.join(wsRoot, selected) : undefined;
}

/**
 * Find the EiffelStudio compiler (ec.exe)
 */
function findCompilerPath(): string | undefined {
    const config = workspace.getConfiguration('eiffel');
    const exeName = process.platform === 'win32' ? 'ec.exe' : 'ec';

    // 1. User-configured path
    const configuredPath = config.get<string>('compilerPath');
    if (configuredPath && configuredPath.trim() !== '') {
        const expandedPath = expandEnvVars(configuredPath);
        if (fs.existsSync(expandedPath)) {
            return expandedPath;
        }
    }

    // 2. ISE_EIFFEL environment variable
    const iseEiffel = process.env.ISE_EIFFEL;
    if (iseEiffel) {
        const isePath = path.join(iseEiffel, 'studio', 'spec', process.platform === 'win32' ? 'win64' : 'linux-x86-64', 'bin', exeName);
        if (fs.existsSync(isePath)) {
            return isePath;
        }
    }

    // 3. Common installation paths (Windows)
    if (process.platform === 'win32') {
        const programFiles = process.env['ProgramFiles'] || 'C:\\Program Files';

        // Search for EiffelStudio installations
        const eiffelDir = path.join(programFiles, 'Eiffel Software');
        if (fs.existsSync(eiffelDir)) {
            const versions = fs.readdirSync(eiffelDir);
            // Sort descending to get latest version first
            versions.sort().reverse();
            for (const ver of versions) {
                const ecPath = path.join(eiffelDir, ver, 'studio', 'spec', 'win64', 'bin', 'ec.exe');
                if (fs.existsSync(ecPath)) {
                    return ecPath;
                }
            }
        }
    }

    return undefined;
}

/**
 * Find the simple_lsp.exe server executable
 *
 * Search order:
 * 1. User-configured path in settings (eiffel.lsp.serverPath)
 * 2. SIMPLE_LSP environment variable
 * 3. Bundled with extension (for distributed .vsix)
 * 4. Relative to workspace (for project-local install)
 * 5. In system PATH
 * 6. Common installation locations
 */
function findServerPath(context: ExtensionContext): string | undefined {
    const config = workspace.getConfiguration('eiffel.lsp');
    const exeName = process.platform === 'win32' ? 'simple_lsp.exe' : 'simple_lsp';

    // 1. User-configured path in settings
    const configuredPath = config.get<string>('serverPath');
    if (configuredPath && configuredPath.trim() !== '') {
        const expandedPath = expandEnvVars(configuredPath);
        if (fs.existsSync(expandedPath)) {
            outputChannel.appendLine(`Using configured server path: ${expandedPath}`);
            return expandedPath;
        }
        outputChannel.appendLine(`Configured server path not found: ${configuredPath}`);
    }

    // 2. SIMPLE_LSP environment variable (points to library root)
    const simpleLspEnv = process.env.SIMPLE_LSP;
    if (simpleLspEnv) {
        const envPaths = [
            path.join(simpleLspEnv, 'EIFGENs', 'simple_lsp_exe', 'F_code', exeName),
            path.join(simpleLspEnv, 'EIFGENs', 'simple_lsp_exe', 'W_code', exeName),
            path.join(simpleLspEnv, exeName)
        ];
        for (const p of envPaths) {
            if (fs.existsSync(p)) {
                outputChannel.appendLine(`Found server via SIMPLE_LSP env: ${p}`);
                return p;
            }
        }
    }

    // 3. Bundled with extension (for marketplace distribution)
    const bundledPaths = [
        path.join(context.extensionPath, 'server', exeName),
        path.join(context.extensionPath, 'bin', exeName),
        path.join(context.extensionPath, exeName)
    ];
    for (const bundledPath of bundledPaths) {
        if (fs.existsSync(bundledPath)) {
            outputChannel.appendLine(`Using bundled server: ${bundledPath}`);
            return bundledPath;
        }
    }

    // 4. Relative to workspace root (project-local install)
    const workspaceFolders = workspace.workspaceFolders;
    if (workspaceFolders && workspaceFolders.length > 0) {
        const wsRoot = workspaceFolders[0].uri.fsPath;
        const workspacePaths = [
            path.join(wsRoot, '.eiffel_lsp', exeName),
            path.join(wsRoot, 'tools', exeName),
            path.join(wsRoot, 'bin', exeName)
        ];
        for (const wsPath of workspacePaths) {
            if (fs.existsSync(wsPath)) {
                outputChannel.appendLine(`Found server in workspace: ${wsPath}`);
                return wsPath;
            }
        }
    }

    // 5. Check system PATH
    const pathDirs = (process.env.PATH || '').split(path.delimiter);
    for (const dir of pathDirs) {
        const exePath = path.join(dir, exeName);
        if (fs.existsSync(exePath)) {
            outputChannel.appendLine(`Found server in PATH: ${exePath}`);
            return exePath;
        }
    }

    // 6. Common installation locations (platform-specific)
    const commonPaths = getCommonInstallPaths(exeName);
    for (const commonPath of commonPaths) {
        if (fs.existsSync(commonPath)) {
            outputChannel.appendLine(`Found server at common location: ${commonPath}`);
            return commonPath;
        }
    }

    return undefined;
}

/**
 * Get common installation paths based on platform
 */
function getCommonInstallPaths(exeName: string): string[] {
    if (process.platform === 'win32') {
        // Windows common locations
        const programFiles = process.env.ProgramFiles || 'C:\\Program Files';
        const programFilesX86 = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
        const localAppData = process.env.LOCALAPPDATA || '';
        const userProfile = process.env.USERPROFILE || '';

        return [
            path.join(programFiles, 'simple_lsp', exeName),
            path.join(programFilesX86, 'simple_lsp', exeName),
            path.join(localAppData, 'simple_lsp', exeName),
            path.join(userProfile, '.simple_lsp', exeName),
            path.join(userProfile, 'simple_lsp', exeName)
        ];
    } else if (process.platform === 'darwin') {
        // macOS common locations
        const home = process.env.HOME || '';
        return [
            '/usr/local/bin/simple_lsp',
            '/opt/homebrew/bin/simple_lsp',
            path.join(home, '.local', 'bin', 'simple_lsp'),
            path.join(home, '.simple_lsp', 'simple_lsp')
        ];
    } else {
        // Linux common locations
        const home = process.env.HOME || '';
        return [
            '/usr/local/bin/simple_lsp',
            '/usr/bin/simple_lsp',
            path.join(home, '.local', 'bin', 'simple_lsp'),
            path.join(home, '.simple_lsp', 'simple_lsp')
        ];
    }
}

/**
 * Expand environment variables in a path string
 * Supports $VAR, ${VAR}, and %VAR% syntax
 */
function expandEnvVars(p: string): string {
    // Handle ${VAR} and $VAR syntax (Unix-style)
    let result = p.replace(/\$\{([^}]+)\}/g, (_, varName) => process.env[varName] || '');
    result = result.replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_, varName) => process.env[varName] || '');
    // Handle %VAR% syntax (Windows-style)
    result = result.replace(/%([^%]+)%/g, (_, varName) => process.env[varName] || '');
    return result;
}
