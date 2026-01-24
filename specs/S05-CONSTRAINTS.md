# S05: CONSTRAINTS - simple_lsp

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Technical Constraints

### Platform
- **OS**: Windows primary, Linux/macOS compatible
- **Compiler**: EiffelStudio 25.02+
- **Concurrency**: SCOOP (concurrency=scoop in ECF)

### Protocol
- **LSP Version**: 3.17 compatible
- **Transport**: stdio (stdin/stdout)
- **Encoding**: UTF-8
- **Message Format**: Content-Length header + JSON body

### Dependencies
- simple_json: JSON parsing
- simple_sql: SQLite database
- simple_ucf: Universe configuration

## Design Constraints

### Stateless Handlers
- Each handler is stateless between requests
- All state stored in symbol database
- Thread-safe design for potential SCOOP parallelization

### File System
- Read-only access to source files
- Write access to .eiffel_lsp/ directory only
- No modification of user source files (except rename)

### Memory
- Document cache limited to recently accessed files
- Symbol database on disk, not fully in memory
- Streaming message I/O

## Operational Constraints

### Response Time
- Initialization: < 5 seconds for large projects
- Navigation: < 100ms typical
- Completion: < 200ms with filtering

### Compatibility
- VS Code LSP client 1.0+
- Any LSP 3.17 compatible client
- EiffelStudio project structure expected

## Known Limitations

1. **No Incremental Parsing**
   - Full re-parse on document changes
   - Future: Tree-sitter integration

2. **No Live Diagnostics**
   - Requires manual compilation for errors
   - Future: Compiler integration

3. **Limited Refactoring**
   - Only rename supported
   - Future: Extract method, etc.

4. **Single Workspace**
   - One workspace root per server instance
   - Future: Multi-root workspace support
