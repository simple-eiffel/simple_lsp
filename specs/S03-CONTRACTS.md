# S03: CONTRACTS - simple_lsp

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## LSP_SERVER Contracts

### make (a_workspace_root: STRING)
```eiffel
require
  root_not_void: a_workspace_root /= Void
  root_not_empty: not a_workspace_root.is_empty
ensure
  root_set: workspace_root = a_workspace_root
  not_initialized: not is_initialized
  not_running: not is_running
  json_created: json /= Void
  db_created: symbol_db /= Void
  parser_created: parser /= Void
  logger_created: logger /= Void
  -- ... all handlers created
```

### run
```eiffel
require
  not_already_running: not is_running
ensure
  stopped: not is_running
```

### read_message: detachable STRING
```eiffel
ensure
  result_has_content: Result /= Void implies not Result.is_empty
```

### write_message (a_json: STRING)
```eiffel
require
  json_not_void: a_json /= Void
  json_not_empty: not a_json.is_empty
```

### extract_content_length (a_header: STRING): INTEGER
```eiffel
require
  header_not_void: a_header /= Void
  header_has_prefix: a_header.starts_with ("Content-Length:")
ensure
  non_negative: Result >= 0
```

### process_message (a_content: STRING)
```eiffel
require
  content_not_void: a_content /= Void
  content_not_empty: not a_content.is_empty
```

### dispatch_message (a_msg: LSP_MESSAGE)
```eiffel
require
  msg_not_void: a_msg /= Void
```

### handle_initialize (a_msg: LSP_MESSAGE)
```eiffel
require
  msg_not_void: a_msg /= Void
  is_request: a_msg.is_request
ensure
  initialized: is_initialized
```

## LSP_APPLICATION Contracts

### argument (n: INTEGER): STRING
```eiffel
require
  valid_index: n >= 1 and n <= argument_count
```

## Class Invariants

### LSP_SERVER
- All handlers non-void after initialization
- Symbol database non-void
- Logger non-void
- Workspace root non-empty
