# 7S-04: SIMPLE-STAR - simple_lsp


**Date**: 2026-01-23

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Ecosystem Dependencies

### Required simple_* Libraries

| Library | Purpose | Version |
|---------|---------|---------|
| simple_json | JSON parsing/generation for LSP messages | latest |
| simple_sql | SQLite database for symbol storage | latest |
| simple_ucf | Universe configuration for cross-library nav | latest |

### ISE Base Libraries Used

| Library | Purpose |
|---------|---------|
| base | Core data structures (ARRAYED_LIST, etc.) |
| time | Timestamps for logging |

## Integration Points

### simple_json Integration
- Parse incoming JSON-RPC requests
- Generate JSON-RPC responses
- SIMPLE_JSON_OBJECT for structured data
- SIMPLE_JSON_VALUE for generic values

### simple_sql Integration
- LSP_SYMBOL_DATABASE uses SIMPLE_SQL_DATABASE
- Schema: symbols, classes, features, files
- FTS5 full-text search for workspace symbols

### simple_ucf Integration
- SIMPLE_UCF for universe configuration
- Cross-library navigation support
- Library path resolution

## Ecosystem Fit

### Category
Developer Tools / IDE Support

### Phase
Phase 5 - API documentation and comprehensive features

### Maturity
Production-ready (v0.8.7)

### Consumers
- VS Code Eiffel extension
- Any LSP-compatible editor
- Claude Code integration potential

## Future Ecosystem Integration

- simple_oracle: Could provide context for AI-assisted coding
- simple_test: Integration with test discovery
- simple_doc: Documentation generation from hover data
