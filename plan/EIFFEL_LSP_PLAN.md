# Eiffel Language Server Protocol (LSP) Implementation Plan

## CONCRETE IMPLEMENTATION ROADMAP

**Prepared for:** Larry (Simple Eiffel Ecosystem)
**Date:** December 9, 2025
**Status:** Phase 1 Complete - MVP Delivered
**Goal:** Build simple_lsp - a native Eiffel LSP server for VS Code

---

## Current Status: MVP Complete

**simple_lsp v0.1.0 is working!** The following features are implemented and functional:

| Feature | Status | Description |
|---------|--------|-------------|
| Go to Definition | **Working** | Ctrl+Click on classes and features |
| Hover Documentation | **Working** | Signatures and comments on hover |
| Code Completion | **Working** | Ctrl+Space for classes and features |
| Document Symbols | **Working** | Ctrl+Shift+O for file outline |
| Workspace Symbols | **Working** | Ctrl+T to search all symbols |
| Find References | **Working** | Shift+F12 to find definitions |

**Distribution:**
- Windows installer (Inno Setup) - 4.2MB
- VS Code extension (.vsix)
- Finalized binary with contracts enabled (F_code with -keep)

---

## Executive Summary

This document provides a **step-by-step actionable plan** to build an Eiffel LSP server using our existing simple_* infrastructure. The approach leverages SQLite for symbol storage, shells out to ec.exe for semantic analysis, and produces a Windows binary that speaks JSON-RPC over stdio.

### What We Built

VS Code spawns simple_lsp.exe which handles:
- JSON-RPC over stdin/stdout (using simple_json)
- Symbol database in SQLite (using simple_sql)
- Eiffel source parsing (simple_eiffel_parser)
- File operations (simple_file)
- Process handling (simple_process)

### Why This Approach Worked

1. We already had simple_json - JSON parsing/building was done
2. We already had simple_sql - SQLite wrapper was done
3. We already had simple_process - Can shell out to ec.exe
4. SQLite is debuggable - Can inspect symbol table with any SQL tool
5. Native binary - No Node.js/TypeScript runtime dependency

---

## Roadmap: Coming Soon

### Phase 2: Core LSP Features (Next)

| Feature | Priority | Description |
|---------|----------|-------------|
| **Rename Symbol** | High | Safely rename features/classes across workspace |
| **Signature Help** | High | Show parameter hints while typing |
| **Diagnostics** | High | Real-time syntax error highlighting |
| **Folding Ranges** | Medium | Collapse feature clauses, invariants, notes |
| **Formatting** | Medium | Auto-format Eiffel code on save |
| **Semantic Tokens** | Medium | Rich syntax highlighting (contracts, agents) |
| **Call Hierarchy** | Low | View incoming/outgoing calls for any feature |
| **Type Hierarchy** | Low | Visualize inheritance relationships |

### Phase 2.5: EIFGENs Metadata Integration (NEW - Ulrich's Suggestion)

When ISE EiffelStudio compiles a system, it generates rich metadata in C source files that we can parse for accurate semantic information. This enables a **hybrid approach**:

- **Parser mode**: Works on incomplete/broken code during active editing
- **Compiler mode**: Uses EIFGENs metadata for accurate semantic queries after successful build

| Feature | Priority | Description |
|---------|----------|-------------|
| **EIFGENs Detection** | High | Detect valid compiled output in EIFGENs folder |
| **eparents.c Parser** | High | Extract class hierarchy and inheritance chains |
| **evisib.c Parser** | High | Extract complete class name table |
| **enames.c Parser** | Medium | Extract feature names per class |
| **eskelet.c Parser** | Medium | Extract attribute types |
| **Hybrid Symbol Resolution** | Medium | Merge parser + compiler data intelligently |
| **Timestamp Validation** | Medium | Check if compilation is newer than sources |

**Key files in `EIFGENs/<target>/W_code/E1/`:**

| File | Contents |
|------|----------|
| `eparents.c` | 1000+ classes with inheritance hierarchy (ptf arrays) |
| `enames.c` | Feature names indexed by class ID |
| `eskelet.c` | Attribute type info (SK_REF, SK_BOOL, SK_INT32) |
| `evisib.c` | type_key[] array with all class names |
| `ecall.c` | Routine dispatch tables |

**Benefits:**
- Accurate inheritance chains (vs. parser guessing)
- Resolved generic types
- Complete feature dispatch information
- Type-accurate hover information

**See:** `reference_docs/research/EIFGENS_METADATA_DESIGN.md` for full design

### Phase 3: Advanced Features

| Feature | Description |
|---------|-------------|
| **ECF Parsing** | Understand project configuration, library paths, targets |
| **Cross-Project Navigation** | Jump to definitions in simple_* libraries |
| **Inheritance Chain Display** | Show full inheritance path with redefinitions |
| **Contract Visualization** | Display require/ensure/invariant in hover with inheritance |
| **Agent Signature Expansion** | Expand agent types to show full signatures |
| **SCOOP Awareness** | Highlight separate calls, detect potential issues |

### Phase 4: Eiffel-Specific Innovations

Features that leverage Eiffel's unique Design by Contract capabilities:

| Innovation | Description |
|------------|-------------|
| **Contract Lens** | CodeLens showing contract coverage per feature |
| **Invariant Inspector** | Hover over class to see full invariant chain |
| **Void-Safety Hints** | Inline hints for detachable/attached status |
| **Creation Procedure Finder** | Quick access to all creation procedures for a type |
| **Feature Origin Tracking** | Show which ancestor introduced/redefined a feature |
| **Catcall Detection** | Highlight potential catcall violations |
| **Once Status** | Show once feature values and initialization status |
| **Implicit Code Lens** | Make implicit code explicit: `create x` → `create x.default_create`, `a := b` → `a := b.to_a` (conversions), `a.x := b` → `a.set_x (b)`, `my_agent.call (x)` → `my_agent.call ([x])` |
| **Contract View** | Display flat contract view showing all inherited require/ensure/invariant |
| **Client View** | Show only exported features visible to a specific client class |
| **Live Editing** | Update symbols and diagnostics for unsaved file changes in real-time |

### Phase 5: simple_* Ecosystem Integration

Leveraging other simple_* libraries for powerful features:

| Integration | Library | Description |
|-------------|---------|-------------|
| **AI Code Assistant** | simple_ai_client | Claude-powered code suggestions, explanations, refactoring |
| **Live File Watching** | simple_watcher | Instant re-indexing when files change |
| **Project Knowledge Base** | simple_oracle | Learn your codebase patterns, remember across sessions |
| **Documentation Generation** | simple_markdown | Generate markdown docs from code comments |
| **Test Runner Integration** | simple_testing | Run tests from VS Code, show coverage |
| **Build System** | simple_process | Compile from VS Code, show errors inline |

**Oracle + EIFGENs Integration:**

The Oracle can leverage compiled metadata for cross-project analysis:

| Oracle Feature | Description |
|----------------|-------------|
| `scan-compiled <path>` | Ingest EIFGENs metadata into Oracle knowledge base |
| `class-info <name>` | Show compiled class details (type index, parents, features) |
| `ancestors <name>` | Display full inheritance chain from compiler data |
| `query "inherited features"` | Natural language queries against compiled metadata |
| Cross-project aggregation | Which classes are most commonly inherited across ecosystem? |

### Phase 6: Visionary Features (Research)

Ideas we're exploring that could revolutionize Eiffel development:

| Vision | Description |
|--------|-------------|
| **Pick-and-Drop for VS Code** | EiffelStudio's revolutionary interaction model in VS Code (see below) |
| **Contract-Driven Completion** | Suggest code that satisfies postconditions |
| **Invariant-Aware Refactoring** | Ensure refactorings preserve class invariants |
| **SCOOP Visualization** | Show separate object communication graph |
| **Design by Contract Metrics** | Track contract coverage, complexity, quality |
| **AI Contract Synthesis** | Generate contracts from natural language specs |
| **Oracle-Powered Search** | Natural language queries: "find all features that modify balance" |
| **Cross-Session Learning** | LSP learns your patterns, suggests based on history |
| **Collaborative Contracts** | Share contract templates across team/organization |

#### Pick-and-Drop for VS Code

EiffelStudio's Pick-and-Drop is a unique interaction paradigm:
- Right-click **picks** an entity (class, feature, type)
- Cursor changes to show you're "carrying" something
- Right-click on target **drops** with context-aware action

**VS Code Implementation Concept:**

```
Ctrl+Shift+P  → Pick entity under cursor
Status bar    → Shows "🎯 Carrying: SIMPLE_JSON"
Ctrl+Shift+D  → Drop at cursor location (context-aware)
```

| Pick | Drop On | Action |
|------|---------|--------|
| Class | Editor | Insert class name |
| Class | Inherit clause | Add inheritance |
| Feature | Editor | Insert feature call with signature template |
| Feature | Create clause | Add as creation procedure |
| Class | Feature param | Set as parameter type |
| Type | Result line | Set return type |
| Feature | require block | Insert as precondition |

**Implementation approach:**
1. Extension maintains "picked entity" state
2. Status bar shows what you're carrying
3. Drop command queries LSP for valid drop actions
4. CodeActions provide context-aware drop options

### Platform Support Roadmap

| Platform | Status |
|----------|--------|
| Windows 10/11 (64-bit) | **Available** |
| Linux (x64) | Planned |
| macOS (Intel) | Planned |
| macOS (Apple Silicon) | Planned |

---

## Current Limitations

Being transparent about what's not yet implemented:

- **Syntax errors** don't show inline diagnostics (parser recovers but doesn't report)
- **Cross-file analysis** is limited to symbol database (no type inference yet)
- **Completion** shows all symbols, not context-aware filtering
- **References** finds definitions, not all usages
- **No ECF support** yet (doesn't read project configuration)
- **Single workspace** only (no multi-root workspace support)

---

## Architecture Deep Dive

### The Wire Protocol

LSP uses a simple framing format over stdio:

```
Content-Length: 52

{"jsonrpc":"2.0","id":1,"method":"initialize",...}
```

Read Content-Length header, read that many bytes of JSON, parse, dispatch, respond.

### SQLite Symbol Database

Why SQLite instead of in-memory hash tables?

1. **Persistence** - Do not reparse 1000 files on every startup
2. **Debuggability** - Can inspect with DB Browser, sqlite3 CLI, VS Code extension
3. **SQL queries** - Complex lookups become simple JOINs
4. **Memory efficient** - Large projects do not blow up RAM
5. **Crash recovery** - Database survives LSP crashes

Location: `.eiffel_lsp/symbols.db` in project root

### Schema

```sql
CREATE TABLE classes (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    file_path TEXT NOT NULL,
    line INTEGER NOT NULL,
    column INTEGER NOT NULL,
    is_deferred BOOLEAN DEFAULT 0,
    is_expanded BOOLEAN DEFAULT 0,
    is_frozen BOOLEAN DEFAULT 0,
    header_comment TEXT,
    file_mtime INTEGER NOT NULL
);
CREATE INDEX idx_classes_name ON classes(name);
CREATE INDEX idx_classes_file ON classes(file_path);

CREATE TABLE features (
    id INTEGER PRIMARY KEY,
    class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    line INTEGER NOT NULL,
    column INTEGER NOT NULL,
    return_type TEXT,
    signature TEXT,
    precondition TEXT,
    postcondition TEXT,
    header_comment TEXT,
    is_deferred BOOLEAN DEFAULT 0,
    is_frozen BOOLEAN DEFAULT 0,
    export_status TEXT DEFAULT 'ANY'
);
CREATE INDEX idx_features_class ON features(class_id);
CREATE INDEX idx_features_name ON features(name);

CREATE TABLE inheritance (
    id INTEGER PRIMARY KEY,
    child_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    parent_name TEXT NOT NULL,
    parent_id INTEGER REFERENCES classes(id),
    rename_clause TEXT,
    redefine_list TEXT,
    undefine_list TEXT,
    select_list TEXT
);

CREATE TABLE arguments (
    id INTEGER PRIMARY KEY,
    feature_id INTEGER NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    arg_type TEXT NOT NULL,
    position INTEGER NOT NULL
);

CREATE TABLE locals (
    id INTEGER PRIMARY KEY,
    feature_id INTEGER NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    local_type TEXT NOT NULL,
    line INTEGER NOT NULL
);

CREATE TABLE parse_errors (
    id INTEGER PRIMARY KEY,
    file_path TEXT NOT NULL,
    line INTEGER NOT NULL,
    column INTEGER NOT NULL,
    message TEXT NOT NULL,
    severity TEXT DEFAULT 'error'
);
```

---

## Two-Level Diagnostics (Planned)

### Level 1: Fast (Our Parser) - Milliseconds
- Syntax errors (missing end, bad tokens)
- Basic structure validation
- Runs on every keystroke (debounced)

### Level 2: Full (ec.exe) - Seconds
- Type checking
- Contract violations
- Validity rules (VDRD, VHPR, etc.)
- Runs on save (or manual trigger)

---

## SQLite Debugging Examples

When something goes wrong, you can inspect the symbol database:

```sql
-- Find all features in SIMPLE_JSON
SELECT f.name, f.kind FROM features f
JOIN classes c ON f.class_id = c.id
WHERE c.name = 'SIMPLE_JSON';

-- Check inheritance chain
WITH RECURSIVE ancestors(id, name, depth) AS (
    SELECT id, name, 0 FROM classes WHERE name = 'SIMPLE_JSON'
    UNION ALL
    SELECT c.id, c.name, a.depth + 1
    FROM ancestors a
    JOIN inheritance i ON i.child_id = a.id
    JOIN classes c ON c.name = i.parent_name
)
SELECT * FROM ancestors;

-- Find all features named 'make'
SELECT c.name as class_name, f.signature
FROM features f
JOIN classes c ON f.class_id = c.id
WHERE f.name = 'make';
```

Tools: DB Browser for SQLite (GUI), sqlite3 CLI, VS Code SQLite Extension

---

## File Structure (Current)

```
/d/prod/
  simple_lsp/                    -- LSP server (COMPLETE)
    simple_lsp.ecf
    src/
      lsp_server.e
      lsp_message.e
      lsp_symbol_database.e
      lsp_logger.e
      lsp_application.e
    vscode-extension/            -- VS Code extension
      package.json
      src/extension.ts
      syntaxes/eiffel.tmLanguage.json
    dist/                        -- Distribution
      simple_lsp_setup.iss       -- Inno Setup installer
      windows/install.bat
    docs/                        -- Documentation
      index.html
      css/style.css
  simple_eiffel_parser/          -- Eiffel source parser (COMPLETE)
    simple_eiffel_parser.ecf
    src/
```

---

## Success Criteria

### MVP (Complete!)
- [x] Server starts and connects to VS Code
- [x] Go to definition for classes works
- [x] Go to definition for features works
- [x] Hover shows feature signature
- [x] Basic completion
- [x] Document symbols (outline view)
- [x] Workspace symbols (Ctrl+T)
- [x] Find references

### Production Quality (Phase 2)
- [ ] Syntax errors show as red squiggles (Diagnostics)
- [ ] Rename symbol across files
- [ ] Signature help while typing
- [ ] ec.exe integration for semantic errors
- [ ] Cross-file go-to-definition for libraries
- [ ] Inheritance-aware feature lookup
- [ ] Contract display in hover

### Advanced (Phase 3+)
- [ ] ECF parsing for library awareness
- [ ] Full inheritance chain in hover
- [ ] SCOOP-aware features
- [ ] AI integration via simple_ai_client
- [ ] Oracle-powered pattern learning

---

## Notes on Eric Bezault's Extension

Eric has built an Eiffel VS Code extension (implemented with Gobo Eiffel) that works with any Eiffel code.
Our approach is simpler/faster but less accurate for complex inheritance.
Consider contributing to Eric's extension if full semantic accuracy is required.

---

## Reality Check: Our Actual Productivity

The simple_* ecosystem proves this is achievable:

In 28 days (Nov 11 - Dec 9, 2025), the AI+human team produced:
- 54 libraries
- 2,535+ classes
- 75,626+ features
- ~170,000 lines of code

That is ~1.9 libraries per day or ~6,000 LOC per day.

**simple_lsp was built in ~1 day** including:
- LSP server with 6 working features
- VS Code extension with syntax highlighting
- Windows installer
- Full documentation

---

Generated by Claude for the Simple Eiffel ecosystem
December 9, 2025
