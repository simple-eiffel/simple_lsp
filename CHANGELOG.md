# Changelog

All notable changes to simple_lsp will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2025-12-10

### Added
- Handler architecture: LSP_RENAME_HANDLER, LSP_HOVER_HANDLER, LSP_COMPLETION_HANDLER, LSP_NAVIGATION_HANDLER
- DBC assertions enabled in finalized builds for better debugging

### Fixed
- **Critical**: Rename crash when database re-initialized after workspace root change
  - Handlers now re-created when symbol_db/logger are re-created
  - DBC `is_open` precondition caught the stale database reference bug
- TextDocumentEdit now includes required `version` field (null) per LSP spec

## [0.5.0] - 2025-12-10

### Added
- **Rename Symbol** (F2) - Rename classes and features across workspace
  - Finds all occurrences of symbol in all indexed files
  - Preserves case and handles whole-word matching
  - Preview changes before applying
- Filter self-references from client/supplier display

### Fixed
- Classes no longer show themselves in their own "Clients" list

## [0.4.0] - 2025-12-10

### Added
- **Client/Supplier Display** in hover
  - **Suppliers:** Shows types that a class uses (return types, arguments, locals, inheritance)
  - **Clients:** Shows classes that use this type
  - Filters out basic types (INTEGER, BOOLEAN, STRING, etc.)
- Type reference tracking stored in symbol database

## [0.3.1] - 2025-12-10

### Added
- Type alias resolution for standard library classes
  - INTEGER -> INTEGER_32, STRING -> STRING_8, NATURAL -> NATURAL_32
  - REAL -> REAL_32, DOUBLE -> REAL_64, CHARACTER -> CHARACTER_8
- Hover info now works for all stdlib type aliases

### Fixed
- INTEGER and other type aliases now show proper inheritance chains

## [0.3.0] - 2025-12-10

### Added
- **EIFGENs Metadata Integration**: Parse compiled metadata for rich semantic info
  - Loads 769+ classes from EIFGENs/*/W_code/E1/ (eparents.c, enames.c)
  - Shows full inheritance chains on hover for all compiled classes
  - Works for both workspace classes and standard library
- **Build Commands** in VS Code:
  - `Eiffel: Melt (Quick Compile)` - Ctrl+Shift+B
  - `Eiffel: Freeze (Full Workbench)` - Ctrl+Shift+F
  - `Eiffel: Finalize (Release Build)` - Ctrl+Shift+R
  - `Eiffel: Compile Tests` and `Eiffel: Run Tests`
  - `Eiffel: Clean (Delete EIFGENs)`
- **Version Reporting**: Server reports version on connection
  - Shows `simple_lsp v0.3.1 connected` in VS Code
  - serverInfo in LSP initialize response

### Changed
- Extension keybindings improved for ergonomics
- Hover display now shows "(compiled)" or "(workspace)" source indicator
- Hover shows "(alias for X)" when viewing type aliases

### Fixed
- Windows path handling with spaces in ec.exe path (shell:false fix)
- ECF parsing errors with deprecated concurrency setting

## [0.2.0] - 2025-12-09

### Added
- Basic LSP server with stdio communication
- Go to Definition for classes and features
- Hover documentation with signatures and comments
- Code completion for classes and features
- Document symbols (Ctrl+Shift+O)
- Workspace symbols (Ctrl+T)
- Find references (basic - finds definitions)
- SQLite symbol database for persistence
- VS Code extension with syntax highlighting

### Technical
- simple_eiffel_parser integration for source parsing
- simple_sql for symbol storage
- simple_json for LSP protocol
- simple_file for file operations

## [0.1.0] - 2025-12-08

### Added
- Initial release
- Project structure and build configuration
- VS Code extension skeleton
- Inno Setup installer script
