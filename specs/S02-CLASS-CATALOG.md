# S02: CLASS CATALOG - simple_lsp

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Core Classes

### LSP_APPLICATION
- **Purpose**: Application entry point
- **Role**: Initialize and run LSP server
- **Key Features**: Command line argument handling

### LSP_SERVER
- **Purpose**: Main server implementation
- **Role**: Message loop, dispatch, lifecycle management
- **Key Features**:
  - JSON-RPC message reading/writing
  - Method dispatch to handlers
  - Workspace indexing
  - EIFGENs metadata loading

### LSP_MESSAGE
- **Purpose**: JSON-RPC message representation
- **Role**: Parse incoming messages, extract method/params/id
- **Key Features**: Request vs notification detection

### LSP_SYMBOL_DATABASE
- **Purpose**: Persistent symbol storage
- **Role**: SQLite-backed symbol indexing
- **Key Features**:
  - Class/feature storage
  - Full-text search (FTS5)
  - Cross-reference queries

### LSP_LOGGER
- **Purpose**: Logging facility
- **Role**: Debug/info/error logging to file
- **Key Features**: File-based logging with levels

## Handler Classes

### LSP_HOVER_HANDLER
- **Purpose**: textDocument/hover implementation
- **Provides**: Feature signatures, contracts, documentation

### LSP_COMPLETION_HANDLER
- **Purpose**: textDocument/completion implementation
- **Provides**: Context-aware code suggestions

### LSP_NAVIGATION_HANDLER
- **Purpose**: Navigation features
- **Provides**: Definition, references, document/workspace symbols

### LSP_RENAME_HANDLER
- **Purpose**: textDocument/rename implementation
- **Provides**: Safe identifier renaming

### LSP_DOCUMENT_HIGHLIGHT_HANDLER
- **Purpose**: textDocument/documentHighlight
- **Provides**: Highlight all occurrences of symbol

### LSP_SEMANTIC_TOKENS_HANDLER
- **Purpose**: Semantic token highlighting
- **Provides**: Token-based syntax highlighting

### LSP_SIGNATURE_HELP_HANDLER
- **Purpose**: textDocument/signatureHelp
- **Provides**: Function parameter hints

### LSP_CONTRACT_LENS_HANDLER
- **Purpose**: Eiffel-specific contract view
- **Provides**: Flat contracts with inheritance attribution

### LSP_CALL_HIERARCHY_HANDLER
- **Purpose**: Call hierarchy navigation
- **Provides**: Incoming/outgoing calls

### LSP_TYPE_HIERARCHY_HANDLER
- **Purpose**: Type hierarchy navigation
- **Provides**: Supertypes/subtypes

### LSP_IMPLEMENTATION_HANDLER
- **Purpose**: textDocument/implementation
- **Provides**: Find implementations of deferred features

### LSP_TEST_RUNNER_HANDLER
- **Purpose**: Test integration
- **Provides**: Test discovery and execution

## Support Classes

### LSP_ECF_PARSER
- **Purpose**: Parse ECF configuration files
- **Provides**: Library paths, cluster definitions

### ECF_TARGET / ECF_LIBRARY / ECF_CLUSTER
- **Purpose**: ECF structure representation
- **Provides**: Data classes for ECF elements
