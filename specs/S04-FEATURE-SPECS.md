# S04: FEATURE SPECIFICATIONS - simple_lsp

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## LSP_SERVER Features

### Lifecycle Features

| Feature | Type | Description |
|---------|------|-------------|
| make | Command | Initialize server with workspace root |
| run | Command | Main message loop |
| shutdown | Command | Clean server shutdown |

### Access Features

| Feature | Type | Description |
|---------|------|-------------|
| workspace_root | Query | Root directory path |
| is_initialized | Query | Client sent initialize? |
| is_running | Query | Server in main loop? |
| Version | Constant | Server version string |

### Message I/O Features

| Feature | Type | Description |
|---------|------|-------------|
| read_message | Query | Read LSP message from stdin |
| write_message | Command | Write LSP message to stdout |
| extract_content_length | Query | Parse Content-Length header |

### Message Processing Features

| Feature | Type | Description |
|---------|------|-------------|
| process_message | Command | Parse and dispatch message |
| dispatch_message | Command | Route to appropriate handler |

### Handler Features (all private)

| Feature | Handles |
|---------|---------|
| handle_initialize | initialize request |
| handle_initialized | initialized notification |
| handle_shutdown | shutdown request |
| handle_exit | exit notification |
| handle_did_open | textDocument/didOpen |
| handle_did_change | textDocument/didChange |
| handle_did_save | textDocument/didSave |
| handle_did_close | textDocument/didClose |
| handle_definition | textDocument/definition |
| handle_hover | textDocument/hover |
| handle_completion | textDocument/completion |
| handle_document_symbol | textDocument/documentSymbol |
| handle_workspace_symbol | workspace/symbol |
| handle_references | textDocument/references |
| handle_document_highlight | textDocument/documentHighlight |
| handle_semantic_tokens | textDocument/semanticTokens/full |
| handle_signature_help | textDocument/signatureHelp |
| handle_rename | textDocument/rename |
| handle_prepare_rename | textDocument/prepareRename |
| handle_dbc_metrics | eiffel/dbcMetrics |
| handle_prepare_call_hierarchy | textDocument/prepareCallHierarchy |
| handle_incoming_calls | callHierarchy/incomingCalls |
| handle_outgoing_calls | callHierarchy/outgoingCalls |
| handle_prepare_type_hierarchy | textDocument/prepareTypeHierarchy |
| handle_supertypes | typeHierarchy/supertypes |
| handle_subtypes | typeHierarchy/subtypes |
| handle_implementation | textDocument/implementation |
| handle_discover_tests | eiffel/discoverTests |
| handle_run_test | eiffel/runTest |
| handle_run_all_tests | eiffel/runAllTests |

## LSP_APPLICATION Features

| Feature | Type | Description |
|---------|------|-------------|
| make | Command | Entry point - create and run server |
| argument_count | Query | Number of command line args (C external) |
| argument | Query | Get argument at position (C external) |
