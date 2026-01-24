# 7S-02: STANDARDS - simple_lsp


**Date**: 2026-01-23

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Applicable Standards

### Language Server Protocol (LSP) 3.17
- **Source**: Microsoft LSP Specification
- **URL**: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
- **Relevance**: Core protocol this library implements
- **Compliance**: Full compliance with core capabilities

### JSON-RPC 2.0
- **Source**: JSON-RPC Working Group
- **URL**: https://www.jsonrpc.org/specification
- **Relevance**: Transport protocol for LSP messages
- **Compliance**: Full compliance

### Eiffel ECMA-367
- **Source**: ECMA International
- **Relevance**: Eiffel language syntax and semantics
- **Compliance**: Parsing based on standard syntax

## Protocol Messages Supported

### Lifecycle
- initialize / initialized
- shutdown / exit

### Text Document Synchronization
- didOpen / didChange / didSave / didClose

### Language Features
- textDocument/definition
- textDocument/references
- textDocument/hover
- textDocument/completion
- textDocument/documentSymbol
- textDocument/documentHighlight
- textDocument/semanticTokens/full
- textDocument/signatureHelp
- textDocument/rename
- textDocument/prepareRename
- textDocument/implementation

### Workspace Features
- workspace/symbol

### Hierarchies
- textDocument/prepareCallHierarchy
- callHierarchy/incomingCalls
- callHierarchy/outgoingCalls
- textDocument/prepareTypeHierarchy
- typeHierarchy/supertypes
- typeHierarchy/subtypes

### Custom Extensions
- eiffel/dbcMetrics
- eiffel/discoverTests
- eiffel/runTest
- eiffel/runAllTests

## Coding Standards

- Design by Contract throughout
- SCOOP compatibility (concurrency=scoop)
- Inline C only where necessary (command line args)
- simple_* ecosystem dependencies preferred
