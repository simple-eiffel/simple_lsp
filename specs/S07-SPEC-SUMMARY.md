# S07: SPECIFICATION SUMMARY - simple_lsp

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Library Identity

- **Name**: simple_lsp
- **Version**: 0.8.7
- **Category**: Developer Tools / IDE Support
- **Status**: Production

## Purpose Statement

simple_lsp provides a Language Server Protocol implementation for Eiffel, enabling modern IDE features in any LSP-compatible editor. It emphasizes Eiffel's Design by Contract philosophy with contract-aware features.

## Key Capabilities

1. **Code Navigation**
   - Go to definition
   - Find all references
   - Workspace symbol search
   - Document symbols

2. **Code Intelligence**
   - Hover documentation with contracts
   - Code completion
   - Signature help
   - Semantic highlighting

3. **Refactoring**
   - Rename symbol

4. **Eiffel-Specific**
   - Flat contract view with inheritance
   - DBC metrics
   - Test discovery and execution

5. **Hierarchy Navigation**
   - Call hierarchy (incoming/outgoing)
   - Type hierarchy (supertypes/subtypes)
   - Implementation finder

## Architecture Summary

- **Pattern**: Handler-based dispatch
- **Storage**: SQLite symbol database
- **Protocol**: JSON-RPC 2.0 over stdio
- **Parsing**: Regex-based + EIFGENs metadata

## Dependencies

- simple_json (JSON processing)
- simple_sql (Database)
- simple_ucf (Universe configuration)

## Quality Attributes

| Attribute | Target |
|-----------|--------|
| Response Time | < 100ms typical |
| Memory | < 100MB for large projects |
| Reliability | No crashes on malformed input |
| Maintainability | Handler separation |

## Compliance

- LSP 3.17 specification
- JSON-RPC 2.0 specification
- Eiffel ECMA-367 syntax
