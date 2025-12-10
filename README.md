<p align="center">
  <img src="https://raw.githubusercontent.com/simple-eiffel/claude_eiffel_op_docs/main/artwork/LOGO.png" alt="simple_ library logo" width="400">
</p>

# simple_lsp

**[Documentation](https://simple-eiffel.github.io/simple_lsp/)** | **[GitHub](https://github.com/simple-eiffel/simple_lsp)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![VS Code](https://img.shields.io/badge/VS%20Code-1.75+-007ACC.svg)](https://code.visualstudio.com/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()

Eiffel Language Server Protocol (LSP) implementation for VS Code and other editors.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

**Developed using AI-assisted methodology:** Built interactively with Claude Opus 4.5 following rigorous Design by Contract principles.

## Overview

simple_lsp brings modern IDE features to Eiffel development in VS Code:

- **Go to Definition** (Ctrl+Click) - Jump to class or feature definitions
- **Hover Documentation** - See feature signatures and comments on hover
- **Code Completion** (Ctrl+Space) - Autocomplete classes and features as you type
- **Document Symbols** (Ctrl+Shift+O) - Outline view of current file
- **Workspace Symbols** (Ctrl+T) - Search all symbols across workspace
- **Find All References** (Shift+F12) - Find all definitions of a symbol

## Quick Start

### Windows Installer (Recommended)

1. Download `simple_lsp_setup_0.1.0.exe` from [Releases](https://github.com/simple-eiffel/simple_lsp/releases)
2. Run the installer
3. Open VS Code with any folder containing `.e` files
4. Start coding!

The installer will:
- Install `simple_lsp.exe` to your chosen location
- Optionally add to PATH and set SIMPLE_LSP environment variable
- Install the VS Code extension

### Manual Installation

Download the release archive and extract:

```
simple_lsp/
├── simple_lsp.exe          # LSP server
├── eiffel-lsp-0.1.0.vsix   # VS Code extension
├── install.bat             # Optional install script
└── README.md
```

**Option A: Run install.bat**
```cmd
cd simple_lsp
install.bat
```

**Option B: Manual setup**
1. Copy `simple_lsp.exe` to a permanent location (e.g., `C:\tools\simple_lsp\`)
2. Set environment variable:
   ```cmd
   setx SIMPLE_LSP "C:\tools\simple_lsp"
   ```
3. Install VS Code extension:
   - Open VS Code
   - Press `Ctrl+Shift+P` > "Extensions: Install from VSIX..."
   - Select `eiffel-lsp-0.1.0.vsix`

## Distribution Files

The `dist/` folder contains distribution infrastructure:

```
dist/
├── simple_lsp_setup.iss    # Inno Setup installer script
├── readme_before.txt       # Pre-install information
├── output/                 # Generated installers go here
└── windows/
    └── install.bat         # Manual install script
```

To build the installer yourself:
```cmd
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" dist\simple_lsp_setup.iss
```

## VS Code Configuration

The extension automatically finds `simple_lsp.exe` by searching:

1. `eiffel.lsp.serverPath` setting (if configured)
2. `SIMPLE_LSP` environment variable
3. Bundled with extension
4. Workspace `.eiffel_lsp/` folder
5. System PATH
6. Common install locations (`C:\Program Files\simple_lsp\`, etc.)

To manually configure, add to VS Code `settings.json`:
```json
{
    "eiffel.lsp.serverPath": "C:/path/to/simple_lsp.exe"
}
```

## Requirements

- **Windows 10/11** (64-bit)
- **VS Code 1.75+**
- No additional runtime dependencies (statically linked)

## How It Works

1. VS Code launches `simple_lsp.exe` when you open an Eiffel file
2. The server parses and indexes all `.e` files in your workspace
3. Symbol information is stored in `.eiffel_lsp/symbols.db` (SQLite)
4. The server responds to LSP requests (hover, definition, completion, etc.)
5. Debug logs are written to `.eiffel_lsp/lsp.log`

## Building from Source

### Prerequisites

- EiffelStudio 25.02+
- Visual Studio 2022 (for C compilation)
- Node.js 18+ (for VS Code extension)

### Environment Variables

Set these to point to your simple_* library clones:
```bash
export SIMPLE_LSP=/path/to/simple_lsp
export SIMPLE_JSON=/path/to/simple_json
export SIMPLE_SQL=/path/to/simple_sql
export SIMPLE_FILE=/path/to/simple_file
export SIMPLE_PROCESS=/path/to/simple_process
export SIMPLE_EIFFEL_PARSER=/path/to/simple_eiffel_parser
export SIMPLE_REGEX=/path/to/simple_regex
```

### Build Commands

```bash
# Compile LSP server (finalized with contracts)
cd /path/to/simple_lsp
ec.exe -batch -config simple_lsp.ecf -target simple_lsp_exe -finalize -keep -c_compile

# Build VS Code extension
cd vscode-extension
npm install
npm run compile
npx vsce package
```

### Build Outputs

- `EIFGENs/simple_lsp_exe/F_code/simple_lsp.exe` - Optimized with contracts (13MB)
- `vscode-extension/eiffel-lsp-0.1.0.vsix` - VS Code extension

## Project Structure

```
simple_lsp/
├── src/                           # Eiffel source code
│   ├── lsp_server.e               # Main LSP server
│   ├── lsp_message.e              # JSON-RPC message handling
│   ├── lsp_symbol_database.e      # SQLite symbol storage
│   └── lsp_logger.e               # Debug logging
├── vscode-extension/              # VS Code extension
│   ├── src/extension.ts           # Extension entry point
│   ├── syntaxes/                  # Syntax highlighting
│   └── package.json               # Extension manifest
├── dist/                          # Distribution files
│   ├── simple_lsp_setup.iss       # Inno Setup script
│   └── windows/install.bat        # Manual installer
├── docs/                          # Documentation
├── simple_lsp.ecf                 # Eiffel project config
├── LICENSE                        # MIT License
└── README.md                      # This file
```

## Dependencies

This project depends on other simple_* libraries (only needed for building from source):

- [simple_json](https://github.com/simple-eiffel/simple_json) - JSON parsing
- [simple_sql](https://github.com/simple-eiffel/simple_sql) - SQLite database
- [simple_file](https://github.com/simple-eiffel/simple_file) - File operations
- [simple_process](https://github.com/simple-eiffel/simple_process) - Process handling
- [simple_eiffel_parser](https://github.com/simple-eiffel/simple_eiffel_parser) - Eiffel source parsing
- [simple_regex](https://github.com/simple-eiffel/simple_regex) - Regular expressions

**Note:** End users don't need these - the distributed binary is self-contained.

## Troubleshooting

### Server not starting

1. Check the Output panel in VS Code (View > Output > "Eiffel LSP")
2. Verify `simple_lsp.exe` exists at the configured path
3. Try setting the path explicitly in settings
4. Check `.eiffel_lsp/lsp.log` for errors

### No hover/definition results

1. Wait for indexing to complete (check log file)
2. Ensure your workspace root contains `.e` files
3. Check for parse errors in the log file

### Performance issues

1. The finalized (F_code) build is used for distribution
2. Large workspaces may take time to index initially
3. The symbol database is cached and only re-indexes changed files

## API Design

simple_lsp follows Design by Contract principles:

```eiffel
feature -- LSP Operations

    handle_hover (a_params: JSON_OBJECT): detachable JSON_OBJECT
            -- Handle textDocument/hover request
        require
            params_exist: a_params /= Void
            has_position: a_params.has_key ("position")
        do
            -- Implementation
        ensure
            valid_result: Result /= Void implies Result.has_key ("contents")
        end
```

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Follow Eiffel coding standards
4. Add tests for new features
5. Submit a pull request

## License

MIT License - See [LICENSE](LICENSE) file.

## Resources

- [Simple Eiffel Organization](https://github.com/simple-eiffel)
- [Simple Eiffel Documentation](https://simple-eiffel.github.io)
- [Eiffel Language](https://www.eiffel.org/)
- [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
- [VS Code Extension API](https://code.visualstudio.com/api)
