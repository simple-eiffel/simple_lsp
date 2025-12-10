/**
 * Eiffel Language Support Extension
 *
 * Connects VS Code to simple_lsp for Eiffel language features:
 * - Go to Definition
 * - Hover documentation
 * - Code completion
 * - Diagnostics
 */

import * as path from 'path';
import * as fs from 'fs';
import { workspace, ExtensionContext, window, OutputChannel } from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;
let outputChannel: OutputChannel;

export function activate(context: ExtensionContext) {
    outputChannel = window.createOutputChannel('Eiffel LSP');
    outputChannel.appendLine('Eiffel LSP extension activating...');

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
        outputChannel.appendLine('Eiffel LSP client started successfully');
        window.showInformationMessage('Eiffel LSP connected');
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
