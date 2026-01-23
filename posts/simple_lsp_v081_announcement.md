# Eiffel LSP v0.8.1: Parser Fix, Comprehensive Documentation, and Easy Installation

We're pleased to announce **simple_lsp v0.8.1** - a maintenance release that fixes a significant parser bug and comes with comprehensive new documentation for both users and developers.

## What's Fixed

### The Parser Escape Sequence Bug

Version 0.8.0 had an issue where strings containing `%%` (the Eiffel escape sequence for a literal percent sign) followed by a closing quote would confuse the lexer. This caused:

- False "Expected class name" errors appearing in VS Code's Problems panel
- Errors pointing to lines with strings like `"Overall score: " + score.out + "%%"`
- Keywords inside strings (like `"Found class: "`) being incorrectly flagged

**Root cause:** The lexer checked if a quote was escaped by looking at the immediately preceding character. But `%%"` (escaped percent + closing quote) was incorrectly treated as `%"` (escaped quote).

**The fix:** A new `is_escaped_quote` function counts consecutive `%` characters before a quote:
- `%"` = 1 percent (odd) = escaped quote, continue scanning
- `%%"` = 2 percents (even) = escaped percent + real closing quote, stop

This fix lives in **simple_eiffel_parser** and benefits any project using that library.

## New Documentation

We've added comprehensive documentation to help both VS Code users and developers working with the LSP codebase:

### For VS Code Users: [User Guide](https://simple-eiffel.github.io/simple_lsp/user-guide.html)

Step-by-step instructions organized by use case:
- **Navigating Code** - Go to Definition, Find References, Document Symbols
- **Understanding Code** - Hover for signatures, inheritance chains, DbC contracts
- **Writing Code** - Code completion, signature help
- **Refactoring** - Rename symbols safely across your workspace
- **Building** - Melt, Freeze, Finalize with keyboard shortcuts
- **Testing** - Compile and run test targets

Each use case shows exactly what keys to press and what to expect.

### For Developers: [API Reference](https://simple-eiffel.github.io/simple_lsp/api-reference.html)

Complete documentation of the LSP's internal architecture:
- All handler classes (hover, completion, navigation, etc.)
- Symbol database API
- Parser integration
- Configuration options

### System Design: [Architecture Guide](https://simple-eiffel.github.io/simple_lsp/architecture.html)

How the pieces fit together:
- Request flow from VS Code through JSON-RPC to handlers
- Symbol database design and SQLite schema
- EIFGENs metadata integration
- Extension points for new features

## Installation Options

### Option 1: Standalone LSP Installer

For users who just want the VS Code extension:

**Download:** [simple_lsp/dist](https://github.com/simple-eiffel/simple_lsp/tree/main/dist/windows)

Contents:
- `simple_lsp.exe` - The language server (4.3 MB, statically linked)
- `eiffel-lsp-0.8.1.vsix` - VS Code extension
- `install.bat` - Automated installation script

The Inno Setup installer version is also available in the releases.

### Option 2: Simple Ecosystem Installer (v1.3.1)

For users who want the complete Eiffel development environment:

**Download:** [simple_setup/output](https://github.com/simple-eiffel/simple_setup/tree/main/output)

The `simple_ecosystem_1.3.1_setup.exe` installer includes:
- 59 simple_* libraries (JSON, SQL, HTTP, Win32, etc.)
- Pre-built LSP server and VS Code extension
- Automatic environment variable configuration
- Optional VS Code extension auto-install during setup

## Features Reminder

If you're new to simple_lsp, here's what it provides:

**Navigation:**
- Go to Definition (Ctrl+Click or F12)
- Find All References (Shift+F12)
- Document Symbols (Ctrl+Shift+O)
- Workspace Symbols (Ctrl+T)

**Intelligence:**
- Hover documentation with full inheritance chains
- Code completion for classes and features
- Signature help for feature arguments
- Client/Supplier relationship display

**Building:**
- Melt (Ctrl+Shift+B) - Quick compile
- Freeze (Ctrl+Shift+F) - Full workbench rebuild
- Finalize (Ctrl+Shift+R) - Optimized release build
- Test compilation and execution

**DbC Integration:**
- Preconditions and postconditions shown in hover
- Class invariants displayed
- Contract coverage visible in tooltips

## Technical Details

- Written entirely in Eiffel using Design by Contract
- Uses EIFGENs metadata for 769+ ISE library classes
- SQLite-backed symbol database
- No runtime dependencies (statically linked)
- SCOOP-compatible architecture

## Requirements

- Windows 10/11 (64-bit)
- VS Code 1.75+
- EiffelStudio 25.02+ (for building from source only)

## Links

- **GitHub:** https://github.com/simple-eiffel/simple_lsp
- **Documentation:** https://simple-eiffel.github.io/simple_lsp/
- **Ecosystem Installer:** https://github.com/simple-eiffel/simple_setup
- **All Simple Libraries:** https://github.com/simple-eiffel

## Upgrading

If you have a previous version installed:

1. Download the new VSIX from dist/windows or use the installer
2. In VS Code: `code --install-extension eiffel-lsp-0.8.1.vsix --force`
3. Reload VS Code (Ctrl+Shift+P > "Developer: Reload Window")

The OUTPUT panel should show `simple_lsp v0.8.1 connected` when the extension activates.

## Acknowledgments

Thanks to Eric Bezault for testing and feedback on the ecosystem. The inline C pattern is used throughout the simple_* libraries.

---

*This release demonstrates the value of Design by Contract - the parser bug was caught because a precondition (`not_at_end`) failed during testing, making the issue immediately visible rather than silently corrupting data.*
