# 7S-01: SCOPE - simple_lsp


**Date**: 2026-01-23

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Problem Statement

IDE support for Eiffel development has historically been limited to EiffelStudio's built-in editor. Developers using modern editors like VS Code lack essential features like code navigation, completion, hover documentation, and contract-aware tooling. The Language Server Protocol (LSP) provides a standardized way to bring these features to any editor.

## Library Purpose

simple_lsp provides a complete LSP server implementation for Eiffel, enabling:

1. **Code Navigation** - Go to definition, find references, workspace symbols
2. **Intelligent Completion** - Context-aware code completion with contract hints
3. **Hover Documentation** - Feature signatures, contracts, and inheritance info
4. **Contract Lens** - Flat view of contracts with inheritance attribution
5. **Semantic Highlighting** - Token-based syntax highlighting
6. **Rename Refactoring** - Safe identifier renaming across files
7. **Call/Type Hierarchies** - Navigate call chains and inheritance trees
8. **Test Integration** - Discover and run tests from the editor

## Target Users

- Eiffel developers using VS Code or other LSP-compatible editors
- Teams adopting Eiffel who prefer modern development tools
- Educators teaching Eiffel in environments with VS Code

## Scope Boundaries

### In Scope
- Full LSP protocol implementation (JSON-RPC over stdio)
- Symbol database (SQLite) for fast lookups
- ECF configuration parsing
- EIFGENs metadata parsing for compiled information
- Cross-library navigation via universe configuration
- Contract-aware features (DBC emphasis)

### Out of Scope
- Compilation (delegates to EiffelStudio's ec.exe)
- Debugging support (future consideration)
- GUI components (pure language server)
- Non-Eiffel language support

## Success Metrics

- Response latency < 100ms for navigation operations
- Symbol database indexing < 10s for 100+ class projects
- Zero false positives in find references
- Complete contract display in hover
