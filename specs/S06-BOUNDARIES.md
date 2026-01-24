# S06: BOUNDARIES - simple_lsp

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## System Boundaries

```
+------------------+     stdio      +------------------+
|   VS Code        | <-----------> |   simple_lsp     |
|   (LSP Client)   |   JSON-RPC    |   (LSP Server)   |
+------------------+               +------------------+
                                          |
                                          v
                                   +------------------+
                                   |  Symbol Database |
                                   |    (SQLite)      |
                                   +------------------+
                                          |
                                          v
                                   +------------------+
                                   |  File System     |
                                   |  - .e files      |
                                   |  - .ecf files    |
                                   |  - EIFGENs/      |
                                   +------------------+
```

## External Interfaces

### Input Boundaries

| Interface | Format | Source |
|-----------|--------|--------|
| LSP Requests | JSON-RPC 2.0 | stdin from client |
| Source Files | Eiffel (.e) | File system |
| Configuration | ECF (XML-like) | File system |
| Compiled Metadata | EIFGENs | File system |

### Output Boundaries

| Interface | Format | Destination |
|-----------|--------|-------------|
| LSP Responses | JSON-RPC 2.0 | stdout to client |
| Log Files | Plain text | .eiffel_lsp/lsp.log |
| Symbol Database | SQLite | .eiffel_lsp/symbols.db |

## Module Boundaries

### Core Module
- LSP_SERVER: Protocol handling
- LSP_MESSAGE: Message parsing
- LSP_LOGGER: Logging

### Handler Module
- All LSP_*_HANDLER classes
- Stateless request processors

### Storage Module
- LSP_SYMBOL_DATABASE: Symbol storage
- SQLite integration

### Parser Module
- LSP_ECF_PARSER: Configuration parsing
- Source file parsing (within handlers)

## Trust Boundaries

### Trusted
- VS Code client (spawns server)
- Local file system
- SQLite database

### Untrusted
- File content (may be malformed)
- User input in queries
- External library paths

## Versioning Boundaries

- LSP Protocol: 3.17
- Server Version: 0.8.7
- Database Schema: v1 (migrations supported)
