# S01: PROJECT INVENTORY - simple_lsp

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Project Structure

```
simple_lsp/
  src/
    lsp_application.e          # Entry point
    lsp_server.e               # Main server loop and dispatch
    lsp_message.e              # JSON-RPC message parsing
    lsp_symbol_database.e      # SQLite symbol storage
    lsp_ecf_parser.e           # ECF configuration parsing
    lsp_logger.e               # Logging facility
    ecf_target.e               # ECF target representation
    ecf_library.e              # ECF library reference
    ecf_cluster.e              # ECF cluster definition
    lsp_hover_handler.e        # Hover information
    lsp_completion_handler.e   # Code completion
    lsp_navigation_handler.e   # Go to definition, references
    lsp_rename_handler.e       # Rename refactoring
    lsp_document_highlight_handler.e  # Highlight occurrences
    lsp_semantic_tokens_handler.e     # Semantic highlighting
    lsp_signature_help_handler.e      # Function signatures
    lsp_contract_lens_handler.e       # Flat contract view
    lsp_call_hierarchy_handler.e      # Call hierarchy
    lsp_type_hierarchy_handler.e      # Type hierarchy
    lsp_implementation_handler.e      # Find implementations
    lsp_test_runner_handler.e         # Test discovery/execution
  testing/
    test_app.e                 # Test application entry
    lib_tests.e                # Test suite
    lsp_test_suite.e           # LSP-specific tests
  research/                    # 7S research documents
  specs/                       # Specification documents
  simple_lsp.ecf               # Library ECF configuration
```

## File Counts

| Category | Count |
|----------|-------|
| Source (.e) | 24 |
| Configuration (.ecf) | 1 |
| Documentation (.md) | 15+ |

## Dependencies

### simple_* Ecosystem
- simple_json
- simple_sql
- simple_ucf

### ISE Libraries
- base
- time

## Build Targets

| Target | Type | Purpose |
|--------|------|---------|
| simple_lsp | library | Reusable library |
| simple_lsp_app | executable | Standalone LSP server |
| simple_lsp_tests | executable | Test suite |

## Version

Current: v0.8.7
