# 7S-05: SECURITY - simple_lsp

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Security Model

### Trust Boundary
- LSP server runs locally with user's file system access
- Communication via stdio (no network exposure by default)
- VS Code spawns process - inherits user permissions

### Threat Assessment

| Threat | Risk | Mitigation |
|--------|------|------------|
| Malicious workspace | Medium | Path validation, sandbox to workspace |
| SQL injection | Low | Parameterized queries via simple_sql |
| Path traversal | Medium | Normalize and validate all file paths |
| Denial of service | Low | Timeout on long operations |
| Information leak | Low | Only access files in workspace |

## Input Validation

### File Paths
- Validate URI format before conversion
- Normalize paths to prevent traversal
- Restrict to workspace root and configured libraries

### JSON Input
- Use simple_json's safe parsing
- Validate expected structure before access
- Handle malformed input gracefully

### User Content
- Class/feature names validated against Eiffel syntax
- No execution of user-provided code
- Search terms sanitized for FTS5 queries

## Data Protection

### Symbol Database
- Stored in .eiffel_lsp directory
- Contains only metadata, not source code
- Can be regenerated from source files

### Log Files
- Stored in .eiffel_lsp/lsp.log
- Contains debug information only
- No sensitive data logged

## Access Control

- No authentication (local process)
- File access limited by OS permissions
- SQLite database is user-readable only
