<p align="center">
  <img src="https://raw.githubusercontent.com/simple-eiffel/.github/main/profile/assets/logo.svg" alt="simple_ library logo" width="400">
</p>

# simple_lsp

**[Documentation](https://simple-eiffel.github.io/simple_lsp/)** | **[GitHub](https://github.com/simple-eiffel/simple_lsp)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![VS Code](https://img.shields.io/badge/VS%20Code-1.75+-007ACC.svg)](https://code.visualstudio.com/)
[![Status](https://img.shields.io/badge/Status-Alpha-red.svg)]()

Experimental Eiffel Language Server Protocol (LSP) implementation for VS Code.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

> **Warning: Alpha Software**
>
> This is an experimental learning project, **not ready for production use**. While it demonstrates LSP concepts and works for small personal projects, it has significant limitations:
>
> - Parser may report false errors on valid Eiffel code (including kernel classes)
> - May crash on large projects (e.g., Gobo)
> - Initial indexing can take 10-15 minutes on large codebases
> - Code completion is basic and not context-aware
>
> **EiffelStudio remains the recommended IDE for serious Eiffel development.**
>
> Contributions and feedback welcome!

**Developed using AI-assisted methodology:** Built interactively with Claude Opus 4.5 as a learning exercise.

## Status

**Alpha** - Experimental proof-of-concept, suitable for exploration and very small projects only.

This is a hobby project exploring LSP implementation in Eiffel. It demonstrates many LSP features but lacks the robustness and accuracy required for professional work.

## Overview

simple_lsp experiments with bringing IDE features to Eiffel in VS Code:

- **Go to Definition** (Ctrl+Click) - Jump to class or feature definitions
- **Hover Documentation** - See feature signatures, comments, and inheritance chains
- **Code Completion** (Ctrl+Space) - Basic autocomplete of classes and features
- **Document Symbols** (Ctrl+Shift+O) - Outline view of current file
- **Workspace Symbols** (Ctrl+T) - Search symbols across workspace
- **Find All References** (Shift+F12) - Find symbol definitions
- **Build Commands** - Melt, Freeze, Finalize from VS Code
- **EIFGENs Integration** - Read metadata from compiled projects

## Known Limitations

Being upfront about the current state:

| Issue | Description |
|-------|-------------|
| **False Positives** | Parser reports errors on valid code, including EiffelStudio kernel classes |
| **Crashes on Large Projects** | May crash when opening large codebases like Gobo |
| **Slow Indexing** | Initial workspace scan can take 10-15 minutes on large codebases |
| **Basic Completion** | Shows all symbols, not context-aware (does not filter by type) |
| **Limited References** | Finds definitions, not all usages |
| **No ECF Support** | Does not read project configuration files |
| **Single Workspace** | No multi-root workspace support |
| **Windows Only** | Linux/macOS builds not available |

## Who Is This For?

- **Learners** exploring how LSP servers work
- **Experimenters** wanting to try VS Code with Eiffel on small personal projects
- **Contributors** interested in helping improve Eiffel tooling

**Not for:** Production development, large projects, or professional Eiffel work.

## Quick Start

### Windows Installer

1. Download simple_lsp_setup_0.6.0.exe from [Releases](https://github.com/simple-eiffel/simple_lsp/releases)
2. Run the installer
3. Open VS Code with a folder containing .e files
4. Try it out on a small project

The installer will:
- Install simple_lsp.exe to your chosen location
- Optionally add to PATH and set SIMPLE_LSP environment variable
- Install the VS Code extension

### Manual Installation

Download the release archive and extract:

    simple_lsp/
    ├── simple_lsp.exe          # LSP server
    ├── eiffel-lsp-0.3.1.vsix   # VS Code extension
    ├── install.bat             # Optional install script
    └── README.md

**Option A: Run install.bat**

    cd simple_lsp
    install.bat

**Option B: Manual setup**
1. Copy simple_lsp.exe to a permanent location (e.g., C:\tools\simple_lsp\)
2. Set environment variable: setx SIMPLE_LSP "C:\tools\simple_lsp"
3. Install VS Code extension via Extensions: Install from VSIX

## VS Code Configuration

The extension automatically finds simple_lsp.exe by searching:

1. eiffel.lsp.serverPath setting (if configured)
2. SIMPLE_LSP environment variable
3. Bundled with extension
4. Workspace .eiffel_lsp/ folder
5. System PATH
6. Common install locations

## Requirements

- **Windows 10/11** (64-bit)
- **VS Code 1.75+**
- No additional runtime dependencies (statically linked)

## How It Works

1. VS Code launches simple_lsp.exe when you open an Eiffel file
2. The server parses and indexes all .e files in your workspace
3. Symbol information is stored in .eiffel_lsp/symbols.db (SQLite)
4. The server responds to LSP requests (hover, definition, completion, etc.)
5. Debug logs are written to .eiffel_lsp/lsp.log

## Roadmap (Aspirational)

These are ideas we would like to explore, not commitments:

- **Better parsing** - Reduce false positives, handle edge cases
- **Context-aware completion** - Filter by expected type
- **ECF support** - Read project configuration
- **Incremental indexing** - Faster updates on file changes
- **Linux/macOS builds** - Cross-platform support
- **Stability improvements** - Handle large projects without crashing

## Contributing

Contributions welcome! This is an experimental project, so we especially appreciate:

- Bug reports with reproduction steps
- Parser improvements (reducing false errors)
- Performance optimizations
- Linux/macOS testing and builds
- Documentation improvements

## License

MIT License - See [LICENSE](LICENSE) file.

## Resources

- [Simple Eiffel Organization](https://github.com/simple-eiffel)
- [Simple Eiffel Documentation](https://simple-eiffel.github.io)
- [Eiffel Language](https://www.eiffel.org/)
- [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
- [VS Code Extension API](https://code.visualstudio.com/api)
