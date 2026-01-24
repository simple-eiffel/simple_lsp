# 7S-06: SIZING - simple_lsp


**Date**: 2026-01-23

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Codebase Metrics

### Source Files
- **Total Classes**: 24
- **Main Source**: 19 classes in src/
- **Testing**: 5 classes in testing/

### Lines of Code (Estimated)
- Core server: ~2000 LOC
- Handlers: ~4000 LOC (combined)
- Support classes: ~1500 LOC
- **Total**: ~7500 LOC

### Complexity Assessment

| Component | Complexity | Rationale |
|-----------|------------|-----------|
| LSP_SERVER | High | Main dispatch, state management |
| LSP_SYMBOL_DATABASE | High | SQL schema, queries, indexes |
| LSP_ECF_PARSER | Medium | XML-like parsing |
| Individual Handlers | Medium | Protocol compliance |
| LSP_MESSAGE | Low | Data structure |

## Performance Characteristics

### Memory Usage
- Symbol database: ~10-50MB depending on project size
- In-memory caches: ~5MB for document cache
- Per-request: Minimal (streaming)

### Response Times (Target)
- Hover: < 50ms
- Completion: < 100ms
- Definition: < 50ms
- References: < 200ms
- Workspace Symbol: < 500ms

### Scalability
- Tested with: 100+ class projects
- Database indexes: O(log n) lookups
- Full-text search: FTS5 optimized

## Build Metrics

- Compile time: ~30 seconds
- Test suite: ~10 tests
- Dependencies: 3 simple_* libraries

## Maintenance Burden

- Protocol updates: Track LSP spec changes
- Parser updates: Eiffel syntax evolution
- Database schema: Migrations as needed
