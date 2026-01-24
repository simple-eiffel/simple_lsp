# 7S-03: SOLUTIONS - simple_lsp

**BACKWASH** | Generated: 2026-01-23 | Library: simple_lsp

## Alternative Solutions Evaluated

### 1. EiffelStudio Built-in Editor
- **Pros**: Full compiler integration, complete feature set
- **Cons**: Not portable to other editors, tied to IDE

### 2. Existing Language Servers
- **Research**: No mature Eiffel LSP implementations found
- **Outcome**: Need to build from scratch

### 3. Tree-sitter Based Parsing
- **Pros**: Fast incremental parsing
- **Cons**: No Eiffel grammar available, would need creation
- **Decision**: Use simple regex-based parsing for MVP

### 4. Compiler Integration
- **Approach**: Parse EIFGENs metadata from compiled output
- **Pros**: Accurate type information post-compilation
- **Cons**: Requires compilation, slower feedback
- **Decision**: Hybrid - use both source parsing and EIFGENs

## Architecture Decisions

### Symbol Database (SQLite)
- **Rationale**: Fast indexed queries, persistent across sessions
- **Tables**: symbols, classes, features, files, universe
- **Location**: .eiffel_lsp/symbols.db in workspace

### Handler Pattern
- **Design**: Separate handler class per LSP capability
- **Classes**: LSP_HOVER_HANDLER, LSP_COMPLETION_HANDLER, etc.
- **Benefit**: Clean separation, easy to extend

### JSON Processing
- **Choice**: simple_json library
- **Rationale**: Ecosystem consistency, DBC support

### ECF Parsing
- **Choice**: Custom LSP_ECF_PARSER
- **Rationale**: Extract library dependencies, cluster paths

### EIFGENs Metadata
- **Source**: Compiled project metadata
- **Data**: Inheritance, feature signatures, contracts
- **Benefit**: Accurate post-compilation information

## Technology Stack

- Eiffel (EiffelStudio 25.02)
- SQLite via simple_sql
- JSON via simple_json
- File operations via Eiffel base library
