# Announcing: Eiffel LSP for VS Code - Modern IDE Support for Eiffel Development

We're excited to announce **simple_lsp v0.6.0** - a Language Server Protocol implementation that brings modern IDE features to Eiffel development in Visual Studio Code.

## Features

- **Go to Definition** (Ctrl+Click) - Jump to class or feature definitions
- **Hover Documentation** - See signatures, comments, and full inheritance chains
- **Code Completion** (Ctrl+Space) - Autocomplete classes and features
- **Rename Symbol** (F2) - Safely rename across your entire workspace
- **Find All References** (Shift+F12) - Locate all usages
- **Document/Workspace Symbols** - Navigate your codebase quickly
- **Client/Supplier Display** - See who uses you and who you use

### Build Commands (with keybindings)

- **Melt** (Ctrl+Shift+B) - Quick compile
- **Freeze** (Ctrl+Shift+F) - Full workbench rebuild
- **Finalize** (Ctrl+Shift+R) - Release build with optimizations
- **Compile Tests** - Build test target (command palette)
- **Run Tests** - Execute test suite (command palette)
- **Clean** - Delete EIFGENs folder (command palette)

## Installation

**Option 1: Standalone Installer**
Download `simple_lsp_setup_0.6.0.exe` from:
https://github.com/simple-eiffel/simple_lsp/releases

**Option 2: Simple Ecosystem Installer (v1.1.0)**
Includes 50+ simple_* libraries PLUS the LSP with optional VS Code extension auto-install:
https://github.com/simple-eiffel/simple_setup/releases

## Technical Notes

- Written entirely in Eiffel using Design by Contract
- Leverages EIFGENs metadata for rich semantic info (769+ stdlib classes)
- SQLite-backed symbol database for fast lookups
- No runtime dependencies - statically linked

## Requirements

- Windows 10/11 (64-bit)
- VS Code 1.75+
- EiffelStudio 25.02+ (for building from source only)

## Links

- GitHub: https://github.com/simple-eiffel/simple_lsp
- Documentation: https://simple-eiffel.github.io/simple_lsp/
- Simple Eiffel Ecosystem: https://github.com/simple-eiffel

## What's Next

- Diagnostics (real-time syntax error highlighting)
- Signature Help
- ECF parsing for project-aware navigation

Feedback and contributions welcome!
