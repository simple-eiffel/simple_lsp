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
import { workspace, ExtensionContext, window, OutputChannel, commands, tasks, Task, TaskDefinition, ShellExecution, TaskScope, TaskRevealKind, TaskPanelKind, WebviewPanel, ViewColumn, Uri } from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;
let outputChannel: OutputChannel;
let compileChannel: OutputChannel;
let heatmapPanel: WebviewPanel | undefined;
let cachedHeatmapData: any = null;  // Cache LSP response for drill-down

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
        commands.registerCommand('eiffel.clean', () => cleanEifgens()),
        commands.registerCommand('eiffel.showHeatmap', () => showHeatmap(context))
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

/**
 * Show the DbC Heatmap in a webview panel
 */
async function showHeatmap(context: ExtensionContext) {
    // If panel already exists, reveal it
    if (heatmapPanel) {
        heatmapPanel.reveal(ViewColumn.One);
        return;
    }

    // Create webview panel
    heatmapPanel = window.createWebviewPanel(
        'eiffelDbcHeatmap',
        'DbC Heatmap',
        ViewColumn.One,
        {
            enableScripts: true,
            retainContextWhenHidden: true
        }
    );

    // Handle panel disposal
    heatmapPanel.onDidDispose(() => {
        heatmapPanel = undefined;
    }, null, context.subscriptions);

    // Handle messages from the webview
    heatmapPanel.webview.onDidReceiveMessage(
        async (message) => {
            switch (message.command) {
                case 'openFile':
                    // Open file at specific line
                    const filePath = message.filePath;
                    const line = message.line || 1;
                    try {
                        const doc = await workspace.openTextDocument(Uri.file(filePath));
                        const editor = await window.showTextDocument(doc, ViewColumn.One);
                        const position = editor.selection.active.with(line - 1, 0);
                        editor.selection = new (await import('vscode')).Selection(position, position);
                        editor.revealRange(new (await import('vscode')).Range(position, position));
                    } catch (error) {
                        window.showErrorMessage(`Could not open file: ${filePath}`);
                    }
                    break;
                case 'requestData':
                    // Request heatmap data from LSP server or oracle-cli
                    const data = await getHeatmapData();
                    heatmapPanel?.webview.postMessage({ command: 'updateData', data });
                    break;
                case 'drillDown':
                    // Handle drill-down request
                    const libraryData = await getLibraryDetails(message.libraryName);
                    heatmapPanel?.webview.postMessage({ command: 'showLibrary', data: libraryData });
                    break;
            }
        },
        undefined,
        context.subscriptions
    );

    // Set initial HTML content
    heatmapPanel.webview.html = getHeatmapHtml();

    // Load initial data
    const initialData = await getHeatmapData();
    heatmapPanel.webview.postMessage({ command: 'updateData', data: initialData });
}

/**
 * Get heatmap data from LSP server's eiffel/dbcMetrics endpoint
 */
async function getHeatmapData(): Promise<any> {
    // Try to get real DbC metrics from LSP server
    if (client && client.isRunning()) {
        try {
            outputChannel.appendLine('[Heatmap] Requesting DbC metrics from LSP server...');
            const lspResult = await client.sendRequest('eiffel/dbcMetrics');
            outputChannel.appendLine('[Heatmap] Got response from LSP server');

            if (lspResult && typeof lspResult === 'object') {
                const result = lspResult as any;
                outputChannel.appendLine(`[Heatmap] Libraries: ${result.libraries?.length || 0}, Overall score: ${result.overall_score || 0}%`);

                // Transform LSP response to heatmap format and cache it
                const transformed = transformLspResponse(result);
                cachedHeatmapData = transformed;  // Cache for drill-down
                return transformed;
            }
        } catch (error) {
            outputChannel.appendLine(`[Heatmap] LSP request failed: ${error}`);
        }
    } else {
        outputChannel.appendLine('[Heatmap] LSP client not available, falling back to local scan');
    }

    // Fall back to local environment scan if LSP not available
    const envData = scanEnvironmentForLibraries();
    if (envData.libraries && envData.libraries.length > 0) {
        cachedHeatmapData = envData;  // Cache for drill-down
        return envData;
    }

    // Last resort - sample data
    const sampleData = getSampleHeatmapData();
    cachedHeatmapData = sampleData;
    return sampleData;
}

/**
 * Transform LSP eiffel/dbcMetrics response to heatmap format
 */
function transformLspResponse(lspResult: any): any {
    const libraries = (lspResult.libraries || []).map((lib: any) => ({
        name: lib.name,
        path: lib.path,
        dbc_score: lib.score,
        feature_count: lib.feature_count,
        require_count: lib.require_count,
        ensure_count: lib.ensure_count,
        invariant_count: lib.class_count, // classes with invariants
        classes: (lib.classes || []).map((cls: any) => ({
            name: cls.name,
            path: cls.path || '',  // Use path from LSP response
            dbc_score: cls.score,
            feature_count: cls.features,
            require_count: cls.requires,
            ensure_count: cls.ensures,
            has_invariant: cls.has_invariant
        }))
    }));

    return {
        name: 'Simple Eiffel Universe',
        dbc_score: lspResult.overall_score || 0,
        library_count: libraries.length,
        class_count: lspResult.total_classes || 0,
        feature_count: lspResult.total_features || 0,
        require_count: lspResult.total_with_require || 0,
        ensure_count: lspResult.total_with_ensure || 0,
        invariant_count: lspResult.total_with_invariant || 0,
        libraries
    };
}

/**
 * Scan SIMPLE_* environment variables to find libraries
 */
function scanEnvironmentForLibraries(): any {
    const libraries: any[] = [];

    for (const [key, value] of Object.entries(process.env)) {
        if (key.startsWith('SIMPLE_') && value && fs.existsSync(value)) {
            const libName = key.toLowerCase();
            const libPath = value;

            // Count .e files and estimate metrics
            const eFiles = scanForEiffelFiles(libPath);
            const classCount = eFiles.length;

            libraries.push({
                name: libName,
                path: libPath,
                dbc_score: 50, // Default - would need real analysis
                feature_count: classCount * 5, // Estimate
                require_count: classCount * 2,
                ensure_count: classCount * 2,
                invariant_count: Math.floor(classCount * 0.7),
                classes: eFiles.slice(0, 10).map(f => ({
                    name: path.basename(f, '.e').toUpperCase(),
                    path: f,
                    dbc_score: 50,
                    feature_count: 5,
                    require_count: 2,
                    ensure_count: 2,
                    has_invariant: true
                }))
            });
        }
    }

    return {
        name: 'Simple Eiffel Universe',
        dbc_score: libraries.length > 0 ?
            Math.round(libraries.reduce((sum, l) => sum + l.dbc_score, 0) / libraries.length) : 0,
        library_count: libraries.length,
        class_count: libraries.reduce((sum, l) => sum + (l.classes?.length || 0), 0),
        feature_count: libraries.reduce((sum, l) => sum + l.feature_count, 0),
        require_count: libraries.reduce((sum, l) => sum + l.require_count, 0),
        ensure_count: libraries.reduce((sum, l) => sum + l.ensure_count, 0),
        invariant_count: libraries.reduce((sum, l) => sum + l.invariant_count, 0),
        libraries
    };
}

/**
 * Scan a directory for .e files
 */
function scanForEiffelFiles(dir: string): string[] {
    const results: string[] = [];
    try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory() && entry.name !== 'EIFGENs' && !entry.name.startsWith('.')) {
                results.push(...scanForEiffelFiles(fullPath));
            } else if (entry.isFile() && entry.name.endsWith('.e')) {
                results.push(fullPath);
            }
        }
    } catch {
        // Ignore permission errors
    }
    return results;
}

/**
 * Get detailed data for a specific library
 */
async function getLibraryDetails(libraryName: string): Promise<any> {
    outputChannel.appendLine(`[Heatmap] Drill-down requested for library: ${libraryName}`);

    // First, try to find in cached data from LSP
    if (cachedHeatmapData && cachedHeatmapData.libraries) {
        const cachedLib = cachedHeatmapData.libraries.find(
            (lib: any) => lib.name === libraryName || lib.name.toLowerCase() === libraryName.toLowerCase()
        );
        if (cachedLib) {
            outputChannel.appendLine(`[Heatmap] Found ${libraryName} in cache with ${cachedLib.classes?.length || 0} classes`);
            return {
                name: cachedLib.name,
                path: cachedLib.path,
                dbc_score: cachedLib.dbc_score,
                classes: cachedLib.classes || []
            };
        }
    }

    outputChannel.appendLine(`[Heatmap] Library ${libraryName} not in cache, falling back to local scan`);

    // Fall back to local environment scan
    const envVar = libraryName.toUpperCase().replace(/-/g, '_');
    const libPath = process.env[envVar];

    if (!libPath || !fs.existsSync(libPath)) {
        return null;
    }

    const eFiles = scanForEiffelFiles(libPath);
    const classes = eFiles.map(f => ({
        name: path.basename(f, '.e').toUpperCase(),
        path: f,
        dbc_score: 50, // Fallback - no real analysis available
        feature_count: 5,
        require_count: 2,
        ensure_count: 2,
        has_invariant: true,
        line: 1
    }));

    return {
        name: libraryName,
        path: libPath,
        classes
    };
}

/**
 * Find oracle-cli executable
 */
function findOracleCli(): string | undefined {
    const oracleEnv = process.env.SIMPLE_ORACLE;
    if (oracleEnv) {
        const paths = [
            path.join(oracleEnv, 'oracle-cli.exe'),
            path.join(oracleEnv, 'EIFGENs', 'simple_oracle_cli', 'F_code', 'simple_oracle.exe'),
            path.join(oracleEnv, 'EIFGENs', 'simple_oracle_cli', 'W_code', 'simple_oracle.exe')
        ];
        for (const p of paths) {
            if (fs.existsSync(p)) {
                return p;
            }
        }
    }
    return undefined;
}

/**
 * Sample heatmap data for testing
 */
function getSampleHeatmapData(): any {
    return {
        name: 'Simple Eiffel Universe',
        dbc_score: 34,
        library_count: 5,
        class_count: 25,
        feature_count: 150,
        require_count: 45,
        ensure_count: 38,
        invariant_count: 18,
        libraries: [
            { name: 'simple_json', dbc_score: 65, classes: [] },
            { name: 'simple_sql', dbc_score: 45, classes: [] },
            { name: 'simple_file', dbc_score: 55, classes: [] },
            { name: 'simple_oracle', dbc_score: 40, classes: [] },
            { name: 'simple_lsp', dbc_score: 30, classes: [] }
        ]
    };
}

/**
 * Generate the heatmap webview HTML
 */
function getHeatmapHtml(): string {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DbC Heatmap</title>
    <script src="https://d3js.org/d3.v7.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: #1e1e1e;
            color: #d4d4d4;
            overflow: hidden;
        }
        #header {
            padding: 12px 20px;
            background: #252526;
            border-bottom: 1px solid #3c3c3c;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        #header h1 {
            font-size: 16px;
            font-weight: 500;
            color: #ff4500;
        }
        #breadcrumb {
            display: flex;
            gap: 8px;
            align-items: center;
            font-size: 13px;
        }
        #breadcrumb span {
            cursor: pointer;
            color: #569cd6;
        }
        #breadcrumb span:hover {
            text-decoration: underline;
        }
        #breadcrumb .separator {
            color: #6e6e6e;
            cursor: default;
        }
        #stats {
            padding: 8px 20px;
            background: #2d2d2d;
            font-size: 12px;
            display: flex;
            gap: 20px;
        }
        .stat { color: #9cdcfe; }
        .stat-value { color: #ce9178; font-weight: 500; }
        #visualization {
            width: 100%;
            height: calc(100vh - 90px);
        }
        .node { cursor: pointer; }
        .node:hover { filter: brightness(1.2); }
        .link { stroke: #4a4a4a; stroke-opacity: 0.6; }
        .label {
            font-size: 11px;
            fill: #d4d4d4;
            pointer-events: none;
            text-anchor: middle;
        }
        .tooltip {
            position: absolute;
            background: #3c3c3c;
            border: 1px solid #555;
            border-radius: 4px;
            padding: 10px;
            font-size: 12px;
            pointer-events: none;
            z-index: 1000;
            max-width: 300px;
        }
        .tooltip h4 {
            color: #ff4500;
            margin-bottom: 6px;
        }
        .tooltip-row {
            display: flex;
            justify-content: space-between;
            margin: 2px 0;
        }
        .tooltip-label { color: #9cdcfe; }
        .tooltip-value { color: #ce9178; }
        #loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 14px;
            color: #6e6e6e;
        }
        .score-bar {
            height: 4px;
            background: #3c3c3c;
            border-radius: 2px;
            margin-top: 6px;
            overflow: hidden;
        }
        .score-fill {
            height: 100%;
            border-radius: 2px;
        }
    </style>
</head>
<body>
    <div id="header">
        <h1>DbC Heatmap</h1>
        <div id="breadcrumb">
            <span onclick="showUniverse()">Universe</span>
        </div>
    </div>
    <div id="stats">
        <span class="stat">Score: <span class="stat-value" id="score">--</span>%</span>
        <span class="stat">Libraries: <span class="stat-value" id="libCount">--</span></span>
        <span class="stat">Classes: <span class="stat-value" id="classCount">--</span></span>
        <span class="stat">Features: <span class="stat-value" id="featureCount">--</span></span>
        <span class="stat">Requires: <span class="stat-value" id="requireCount">--</span></span>
        <span class="stat">Ensures: <span class="stat-value" id="ensureCount">--</span></span>
    </div>
    <div id="visualization">
        <div id="loading">Loading heatmap data...</div>
    </div>
    <div class="tooltip" style="display: none;"></div>

    <script>
        const vscode = acquireVsCodeApi();
        let currentData = null;
        let currentView = 'universe';
        let currentLibrary = null;

        // Color scale: heat = good (red/orange), cold = bad (black/purple)
        function getColor(score) {
            if (score >= 90) return '#ff4500';      // Red-orange - excellent
            if (score >= 75) return '#ff6b35';      // Orange - good
            if (score >= 50) return '#cc5500';      // Burnt orange - moderate
            if (score >= 25) return '#8b4570';      // Muted magenta - needs work
            if (score >= 1)  return '#4a3060';      // Dark purple - poor
            return '#1a1a2e';                        // Near-black - no contracts
        }

        // Handle messages from extension
        window.addEventListener('message', event => {
            const message = event.data;
            switch (message.command) {
                case 'updateData':
                    currentData = message.data;
                    renderUniverse(currentData);
                    break;
                case 'showLibrary':
                    if (message.data) {
                        renderLibrary(message.data);
                    }
                    break;
            }
        });

        // Request initial data
        vscode.postMessage({ command: 'requestData' });

        function renderUniverse(data) {
            currentView = 'universe';
            const loadingEl = document.getElementById('loading');
            if (loadingEl) loadingEl.style.display = 'none';

            // Update stats
            document.getElementById('score').textContent = data.dbc_score || 0;
            document.getElementById('libCount').textContent = data.library_count || 0;
            document.getElementById('classCount').textContent = data.class_count || 0;
            document.getElementById('featureCount').textContent = data.feature_count || 0;
            document.getElementById('requireCount').textContent = data.require_count || 0;
            document.getElementById('ensureCount').textContent = data.ensure_count || 0;

            // Update breadcrumb
            document.getElementById('breadcrumb').innerHTML = '<span onclick="showUniverse()">Universe</span>';

            // Clear previous
            const container = document.getElementById('visualization');
            container.innerHTML = '';

            const width = container.clientWidth;
            const height = container.clientHeight;

            const svg = d3.select(container)
                .append('svg')
                .attr('width', width)
                .attr('height', height);

            // Build nodes and links
            const nodes = [];
            const links = [];

            // Universe center node
            nodes.push({
                id: 'universe',
                name: data.name || 'Universe',
                score: data.dbc_score || 0,
                radius: 50,
                type: 'universe',
                x: width / 2,
                y: height / 2
            });

            // Library nodes arranged in a circle
            const libraries = data.libraries || [];
            const libCount = libraries.length;
            libraries.forEach((lib, i) => {
                const angle = (2 * Math.PI * i) / libCount;
                const dist = Math.min(width, height) * 0.35;
                nodes.push({
                    id: 'lib_' + lib.name,
                    name: lib.name,
                    score: lib.dbc_score || 0,
                    radius: 25,
                    type: 'library',
                    data: lib,
                    x: width / 2 + Math.cos(angle) * dist,
                    y: height / 2 + Math.sin(angle) * dist
                });
                links.push({
                    source: 'universe',
                    target: 'lib_' + lib.name
                });
            });

            // Create simulation
            const simulation = d3.forceSimulation(nodes)
                .force('charge', d3.forceManyBody().strength(d => d.radius > 30 ? -800 : -300))
                .force('center', d3.forceCenter(width / 2, height / 2))
                .force('collision', d3.forceCollide().radius(d => d.radius + 20))
                .force('link', d3.forceLink(links).id(d => d.id).distance(150).strength(0.3));

            // Draw links
            const link = svg.append('g')
                .selectAll('line')
                .data(links)
                .enter().append('line')
                .attr('class', 'link');

            // Draw nodes
            const node = svg.append('g')
                .selectAll('circle')
                .data(nodes)
                .enter().append('circle')
                .attr('class', 'node')
                .attr('r', d => d.radius)
                .attr('fill', d => getColor(d.score))
                .on('click', (event, d) => {
                    if (d.type === 'library') {
                        drillDown(d.data);
                    }
                })
                .on('mouseover', showTooltip)
                .on('mouseout', hideTooltip)
                .call(d3.drag()
                    .on('start', dragStarted)
                    .on('drag', dragged)
                    .on('end', dragEnded));

            // Draw labels
            const label = svg.append('g')
                .selectAll('text')
                .data(nodes)
                .enter().append('text')
                .attr('class', 'label')
                .attr('dy', d => d.radius + 15)
                .text(d => d.name.replace('simple_', ''));

            simulation.on('tick', () => {
                link
                    .attr('x1', d => d.source.x)
                    .attr('y1', d => d.source.y)
                    .attr('x2', d => d.target.x)
                    .attr('y2', d => d.target.y);
                node
                    .attr('cx', d => d.x)
                    .attr('cy', d => d.y);
                label
                    .attr('x', d => d.x)
                    .attr('y', d => d.y);
            });

            function dragStarted(event, d) {
                if (!event.active) simulation.alphaTarget(0.3).restart();
                d.fx = d.x;
                d.fy = d.y;
            }

            function dragged(event, d) {
                d.fx = event.x;
                d.fy = event.y;
            }

            function dragEnded(event, d) {
                if (!event.active) simulation.alphaTarget(0);
                d.fx = null;
                d.fy = null;
            }
        }

        function renderLibrary(data) {
            currentView = 'library';
            currentLibrary = data;

            // Update breadcrumb
            document.getElementById('breadcrumb').innerHTML =
                '<span onclick="showUniverse()">Universe</span>' +
                '<span class="separator">›</span>' +
                '<span>' + data.name + '</span>';

            const container = document.getElementById('visualization');
            container.innerHTML = '';

            const width = container.clientWidth;
            const height = container.clientHeight;

            const svg = d3.select(container)
                .append('svg')
                .attr('width', width)
                .attr('height', height);

            const nodes = [];
            const links = [];

            // Library center node
            nodes.push({
                id: 'library',
                name: data.name,
                score: 50,
                radius: 40,
                type: 'library',
                x: width / 2,
                y: height / 2
            });

            // Class nodes
            const classes = data.classes || [];
            const classCount = classes.length;
            classes.forEach((cls, i) => {
                const angle = (2 * Math.PI * i) / classCount;
                const dist = Math.min(width, height) * 0.3;
                nodes.push({
                    id: 'class_' + cls.name,
                    name: cls.name,
                    score: cls.dbc_score || 50,
                    radius: 15,
                    type: 'class',
                    data: cls,
                    x: width / 2 + Math.cos(angle) * dist,
                    y: height / 2 + Math.sin(angle) * dist
                });
                links.push({
                    source: 'library',
                    target: 'class_' + cls.name
                });
            });

            const simulation = d3.forceSimulation(nodes)
                .force('charge', d3.forceManyBody().strength(-200))
                .force('center', d3.forceCenter(width / 2, height / 2))
                .force('collision', d3.forceCollide().radius(d => d.radius + 15))
                .force('link', d3.forceLink(links).id(d => d.id).distance(100).strength(0.4));

            const link = svg.append('g')
                .selectAll('line')
                .data(links)
                .enter().append('line')
                .attr('class', 'link');

            const node = svg.append('g')
                .selectAll('circle')
                .data(nodes)
                .enter().append('circle')
                .attr('class', 'node')
                .attr('r', d => d.radius)
                .attr('fill', d => getColor(d.score))
                .on('click', (event, d) => {
                    if (d.type === 'class' && d.data && d.data.path) {
                        openFile(d.data.path, d.data.line || 1);
                    }
                })
                .on('mouseover', showTooltip)
                .on('mouseout', hideTooltip)
                .call(d3.drag()
                    .on('start', dragStarted)
                    .on('drag', dragged)
                    .on('end', dragEnded));

            const label = svg.append('g')
                .selectAll('text')
                .data(nodes)
                .enter().append('text')
                .attr('class', 'label')
                .attr('dy', d => d.radius + 12)
                .text(d => d.name);

            simulation.on('tick', () => {
                link
                    .attr('x1', d => d.source.x)
                    .attr('y1', d => d.source.y)
                    .attr('x2', d => d.target.x)
                    .attr('y2', d => d.target.y);
                node
                    .attr('cx', d => d.x)
                    .attr('cy', d => d.y);
                label
                    .attr('x', d => d.x)
                    .attr('y', d => d.y);
            });

            function dragStarted(event, d) {
                if (!event.active) simulation.alphaTarget(0.3).restart();
                d.fx = d.x;
                d.fy = d.y;
            }

            function dragged(event, d) {
                d.fx = event.x;
                d.fy = event.y;
            }

            function dragEnded(event, d) {
                if (!event.active) simulation.alphaTarget(0);
                d.fx = null;
                d.fy = null;
            }
        }

        function showUniverse() {
            console.log('[Heatmap] showUniverse called');
            console.log('[Heatmap] currentData exists:', currentData ? 'yes' : 'no');
            console.log('[Heatmap] currentData.libraries:', currentData?.libraries?.length || 0);
            console.log('[Heatmap] currentView was:', currentView);

            if (currentData && currentData.libraries) {
                console.log('[Heatmap] Calling renderUniverse...');
                renderUniverse(currentData);
                console.log('[Heatmap] renderUniverse completed');
            } else {
                console.log('[Heatmap] No currentData or no libraries, requesting fresh data');
                vscode.postMessage({ command: 'requestData' });
            }
        }

        function drillDown(library) {
            vscode.postMessage({
                command: 'drillDown',
                libraryName: library.name
            });
        }

        function openFile(filePath, line) {
            vscode.postMessage({
                command: 'openFile',
                filePath: filePath,
                line: line
            });
        }

        function showTooltip(event, d) {
            const tooltip = document.querySelector('.tooltip');
            let html = '<h4>' + d.name + '</h4>';
            html += '<div class="tooltip-row"><span class="tooltip-label">DbC Score:</span><span class="tooltip-value">' + d.score + '%</span></div>';

            if (d.data) {
                if (d.data.feature_count !== undefined) {
                    html += '<div class="tooltip-row"><span class="tooltip-label">Features:</span><span class="tooltip-value">' + d.data.feature_count + '</span></div>';
                }
                if (d.data.require_count !== undefined) {
                    html += '<div class="tooltip-row"><span class="tooltip-label">Requires:</span><span class="tooltip-value">' + d.data.require_count + '</span></div>';
                }
                if (d.data.ensure_count !== undefined) {
                    html += '<div class="tooltip-row"><span class="tooltip-label">Ensures:</span><span class="tooltip-value">' + d.data.ensure_count + '</span></div>';
                }
            }

            html += '<div class="score-bar"><div class="score-fill" style="width: ' + d.score + '%; background: ' + getColor(d.score) + '"></div></div>';

            if (d.type === 'library') {
                html += '<div style="margin-top: 8px; font-size: 11px; color: #6e6e6e;">Click to drill down</div>';
            } else if (d.type === 'class') {
                html += '<div style="margin-top: 8px; font-size: 11px; color: #6e6e6e;">Click to open file</div>';
            }

            tooltip.innerHTML = html;
            tooltip.style.display = 'block';
            tooltip.style.left = (event.pageX + 15) + 'px';
            tooltip.style.top = (event.pageY + 15) + 'px';
        }

        function hideTooltip() {
            document.querySelector('.tooltip').style.display = 'none';
        }
    </script>
</body>
</html>`;
}
