<p align="center">
  <img src="https://raw.githubusercontent.com/simple-eiffel/claude_eiffel_op_docs/main/artwork/LOGO.png" alt="simple_ library logo" width="400">
</p>

# simple_lsp

**[Documentation](https://simple-eiffel.github.io/simple_lsp/)** | **[GitHub](https://github.com/simple-eiffel/simple_lsp)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![VS Code](https://img.shields.io/badge/VS%20Code-1.75+-007ACC.svg)](https://code.visualstudio.com/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()

Eiffel Language Server Protocol (LSP) implementation for VS Code and other editors.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

**Developed using AI-assisted methodology:** Built interactively with Claude Opus 4.5 following rigorous Design by Contract principles.

## Overview

simple_lsp brings modern IDE features to Eiffel development in VS Code:

- **Go to Definition** (Ctrl+Click) - Jump to class or feature definitions
- **Hover Documentation** - See feature signatures, comments, and **inheritance chains** on hover
- **Code Completion** (Ctrl+Space) - Autocomplete classes and features as you type
- **Document Symbols** (Ctrl+Shift+O) - Outline view of current file
- **Workspace Symbols** (Ctrl+T) - Search all symbols across workspace
- **Find All References** (Shift+F12) - Find all definitions of a symbol
- **Build Commands** - Melt (Ctrl+Shift+B), Freeze (Ctrl+Shift+F), Finalize (Ctrl+Shift+R)
- **EIFGENs Integration** - Rich semantic info from compiled metadata (inheritance, all 769+ stdlib classes)

## Quick Start

### Windows Installer (Recommended)

1. Download `simple_lsp_setup_0.6.0.exe` from [Releases](https://github.com/simple-eiffel/simple_lsp/releases)
2. Run the installer
3. Open VS Code with any folder containing `.e` files
4. Start coding!

The installer will:
- Install `simple_lsp.exe` to your chosen location
- Optionally add to PATH and set SIMPLE_LSP environment variable
- Install the VS Code extension

### Manual Installation

Download the release archive and extract:

```
simple_lsp/
├── simple_lsp.exe          # LSP server
├── eiffel-lsp-0.3.1.vsix   # VS Code extension
├── install.bat             # Optional install script
└── README.md
```

**Option A: Run install.bat**
```cmd
cd simple_lsp
install.bat
```

**Option B: Manual setup**
1. Copy `simple_lsp.exe` to a permanent location (e.g., `C:\tools\simple_lsp\`)
2. Set environment variable:
   ```cmd
   setx SIMPLE_LSP "C:\tools\simple_lsp"
   ```
3. Install VS Code extension:
   - Open VS Code
   - Press `Ctrl+Shift+P` > "Extensions: Install from VSIX..."
   - Select `eiffel-lsp-0.6.0.vsix`

## Distribution Files

The `dist/` folder contains distribution infrastructure:

```
dist/
├── simple_lsp_setup.iss    # Inno Setup installer script
├── readme_before.txt       # Pre-install information
├── output/                 # Generated installers go here
└── windows/
    └── install.bat         # Manual install script
```

To build the installer yourself:
```cmd
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" dist\simple_lsp_setup.iss
```

## VS Code Configuration

The extension automatically finds `simple_lsp.exe` by searching:

1. `eiffel.lsp.serverPath` setting (if configured)
2. `SIMPLE_LSP` environment variable
3. Bundled with extension
4. Workspace `.eiffel_lsp/` folder
5. System PATH
6. Common install locations (`C:\Program Files\simple_lsp\`, etc.)

To manually configure, add to VS Code `settings.json`:
```json
{
    "eiffel.lsp.serverPath": "C:/path/to/simple_lsp.exe"
}
```

## Requirements

- **Windows 10/11** (64-bit)
- **VS Code 1.75+**
- No additional runtime dependencies (statically linked)

## How It Works

1. VS Code launches `simple_lsp.exe` when you open an Eiffel file
2. The server parses and indexes all `.e` files in your workspace
3. Symbol information is stored in `.eiffel_lsp/symbols.db` (SQLite)
4. The server responds to LSP requests (hover, definition, completion, etc.)
5. Debug logs are written to `.eiffel_lsp/lsp.log`

## Building from Source

### Prerequisites

- EiffelStudio 25.02+
- Visual Studio 2022 (for C compilation)
- Node.js 18+ (for VS Code extension)

### Environment Variables

Set these to point to your simple_* library clones:
```bash
export SIMPLE_LSP=/path/to/simple_lsp
export SIMPLE_JSON=/path/to/simple_json
export SIMPLE_SQL=/path/to/simple_sql
export SIMPLE_FILE=/path/to/simple_file
export SIMPLE_PROCESS=/path/to/simple_process
export SIMPLE_EIFFEL_PARSER=/path/to/simple_eiffel_parser
export SIMPLE_REGEX=/path/to/simple_regex
```

### Build Commands

```bash
# Compile LSP server (finalized with contracts)
cd /path/to/simple_lsp
ec.exe -batch -config simple_lsp.ecf -target simple_lsp_exe -finalize -keep -c_compile

# Build VS Code extension
cd vscode-extension
npm install
npm run compile
npx vsce package
```

### Build Outputs

- `EIFGENs/simple_lsp_exe/F_code/simple_lsp.exe` - Optimized with contracts (13MB)
- `vscode-extension/eiffel-lsp-0.6.0.vsix` - VS Code extension

## Project Structure

```
simple_lsp/
├── src/                           # Eiffel source code
│   ├── lsp_server.e               # Main LSP server (orchestration)
│   ├── lsp_hover_handler.e        # Hover documentation handler
│   ├── lsp_completion_handler.e   # Code completion handler
│   ├── lsp_navigation_handler.e   # Go-to-definition, references
│   ├── lsp_rename_handler.e       # Symbol rename handler
│   ├── lsp_message.e              # JSON-RPC message handling
│   ├── lsp_symbol_database.e      # SQLite symbol storage
│   └── lsp_logger.e               # Debug logging
├── vscode-extension/              # VS Code extension
│   ├── src/extension.ts           # Extension entry point
│   ├── syntaxes/                  # Syntax highlighting
│   └── package.json               # Extension manifest
├── dist/                          # Distribution files
│   ├── simple_lsp_setup.iss       # Inno Setup script
│   └── windows/install.bat        # Manual installer
├── docs/                          # Documentation
├── simple_lsp.ecf                 # Eiffel project config
├── LICENSE                        # MIT License
└── README.md                      # This file
```

## Dependencies

This project depends on other simple_* libraries (only needed for building from source):

- [simple_json](https://github.com/simple-eiffel/simple_json) - JSON parsing
- [simple_sql](https://github.com/simple-eiffel/simple_sql) - SQLite database
- [simple_file](https://github.com/simple-eiffel/simple_file) - File operations
- [simple_process](https://github.com/simple-eiffel/simple_process) - Process handling
- [simple_eiffel_parser](https://github.com/simple-eiffel/simple_eiffel_parser) - Eiffel source parsing
- [simple_regex](https://github.com/simple-eiffel/simple_regex) - Regular expressions

**Note:** End users don't need these - the distributed binary is self-contained.

## Troubleshooting

### Server not starting

1. Check the Output panel in VS Code (View > Output > "Eiffel LSP")
2. Verify `simple_lsp.exe` exists at the configured path
3. Try setting the path explicitly in settings
4. Check `.eiffel_lsp/lsp.log` for errors

### No hover/definition results

1. Wait for indexing to complete (check log file)
2. Ensure your workspace root contains `.e` files
3. Check for parse errors in the log file

### Performance issues

1. The finalized (F_code) build is used for distribution
2. Large workspaces may take time to index initially
3. The symbol database is cached and only re-indexes changed files

## API Design

simple_lsp follows Design by Contract principles:

```eiffel
feature -- LSP Operations

    handle_hover (a_params: JSON_OBJECT): detachable JSON_OBJECT
            -- Handle textDocument/hover request
        require
            params_exist: a_params /= Void
            has_position: a_params.has_key ("position")
        do
            -- Implementation
        ensure
            valid_result: Result /= Void implies Result.has_key ("contents")
        end
```

---

## Roadmap: Coming Soon

simple_lsp is under active development. Here's what's planned:

### Core LSP Features

| Feature | Status | Description |
|---------|--------|-------------|
| ~~**Client/Supplier Display**~~ | ✅ **DONE in v0.6.0** | Show clients and suppliers in hover (who uses me, who I use) |
| ~~**Rename Symbol**~~ | ✅ **DONE in v0.6.0** | Safely rename features/classes across workspace |
| ~~**Diagnostics**~~ | ✅ **DONE in v0.6.0** | Real-time syntax error highlighting |
| ~~**Signature Help**~~ | ✅ **DONE in v0.6.0** | Show parameter hints while typing |
| **Folding Ranges** | Planned | Collapse feature clauses, invariants, notes |
| **Formatting** | Planned | Auto-format Eiffel code on save |
| **Semantic Tokens** | Planned | Rich syntax highlighting (contracts, agents, etc.) |
| **Call Hierarchy** | Planned | View incoming/outgoing calls for any feature |
| **Type Hierarchy** | Planned | Visualize inheritance relationships |
| **Document Highlight** | Planned | Highlight all occurrences of symbol in scope |
| **Go to Type Definition** | Planned | Jump from variable to its class definition |
| **Go to Implementation** | Planned | Find effective implementations of deferred features |
| **Inlay Hints** | Planned | Inline type annotations and parameter names |
| **Code Actions** | Planned | Quick fixes, auto-add precondition, extract feature |

### Advanced Features (Planned)

| Feature | Description |
|---------|-------------|
| **ECF Parsing** | Understand project configuration, library paths, targets |
| **UCF (Universe Configuration)** | Multi-project scope - define library ecosystems for heat maps and cross-project tools |
| **Cross-Project Navigation** | Jump to definitions in simple_* libraries |
| ~~**Inheritance Chain Display**~~ | ✅ **DONE in v0.3.0** - Show full inheritance path from EIFGENs |
| **Contract Visualization** | Display require/ensure/invariant in hover with inheritance |
| **Agent Signature Expansion** | Expand agent types to show full signatures |
| **SCOOP Awareness** | Highlight separate calls, detect potential issues |

### Eiffel-Specific Innovations

These features leverage Eiffel's unique capabilities:

| Innovation | Description |
|------------|-------------|
| **Contract Lens** | CodeLens showing contract coverage per feature |
| **Invariant Inspector** | Hover over class to see full invariant chain |
| **Void-Safety Hints** | Inline hints for detachable/attached status |
| **Creation Procedure Finder** | Quick access to all creation procedures for a type |
| **Feature Origin Tracking** | Show which ancestor introduced/redefined a feature |
| **Catcall Detection** | Highlight potential catcall violations |
| **Once Status** | Show once feature values and initialization status |
| **Contract Heat Map** | Color classes by contract density/coverage |
| **Contract Diff** | Compare contracts between versions/branches |
| **"Prove This" Mode** | Highlight what needs testing to prove a postcondition |
| **Assertion Failure Replay** | Record state at contract violation, replay |

### AutoTest Replacement (VS Code Test Explorer)

Full replacement for EiffelStudio's AutoTest tool:

| Feature | Description |
|---------|-------------|
| **Test Tree View** | Sidebar showing all test classes and features |
| **Live Results Streaming** | See tests pass/fail in real-time as they run |
| **Contract Violation Details** | Show exact precondition/postcondition/invariant that failed with values |
| **Test History** | Track pass/fail over time, show regression |
| **Coverage Visualization** | Which features have test coverage |
| **Filter/Search** | Find tests by name, status, class under test |
| **Inline Test Status** | CodeLens above each test feature showing last result |
| **Cherry-Pick Execution** | Run single test, test class, or subset |
| **Test Duration** | Show timing per test |
| **Click-to-Navigate** | Click failed test → jump to assertion line |
| **Re-run Failed** | One-click re-run failures only |

### Interactive Visualizations (Webview)

Interactive diagrams with click-to-navigate:

| Visualization | Description |
|---------------|-------------|
| **BON Class Diagrams** | Auto-generated, click class → open file |
| **Inheritance Tree** | Visual hierarchy, click ancestor → jump to parent |
| **Client/Supplier Graph** | Who uses whom, click edge → show call site |
| **Cluster Diagrams** | Group classes hierarchically, expand/collapse |
| **Contract Annotations** | Show require/ensure on diagrams (unlike UML) |
| **Dependency Matrix** | Find circular dependencies, hub classes |
| **SCOOP Region View** | Show separate regions, processor boundaries |

### Integration with simple_* Ecosystem

Leveraging other simple_* libraries for powerful features:

| Integration | Library | Description |
|-------------|---------|-------------|
| **AI Code Assistant** | simple_ai_client | Claude-powered code suggestions, explanations, refactoring |
| **Live File Watching** | simple_watcher | Instant re-indexing when files change |
| **Project Knowledge Base** | simple_oracle | Learn your codebase patterns, remember across sessions |
| **Documentation Generation** | simple_markdown | Generate markdown docs from code comments |
| **Test Runner Integration** | simple_testing | Run tests from VS Code, show coverage |
| ~~**Build System**~~ | simple_process | ✅ **DONE in v0.3.0** - Melt/Freeze/Finalize from VS Code |

### Visionary Features (Research)

Ideas we're exploring that could revolutionize Eiffel development:

| Vision | Description |
|--------|-------------|
| **Contract-Driven Completion** | Suggest code that satisfies postconditions |
| **Invariant-Aware Refactoring** | Ensure refactorings preserve class invariants |
| **SCOOP Visualization** | Show separate object communication graph |
| **Design by Contract Metrics** | Track contract coverage, complexity, quality |
| **AI Contract Synthesis** | Generate contracts from natural language specs |
| **Oracle-Powered Search** | Natural language queries: "find all features that modify balance" |
| **Cross-Session Learning** | LSP learns your patterns, suggests based on history |
| **Collaborative Contracts** | Share contract templates across team/organization |
| **Per-Test Contract Coverage** | "Which test exercises this precondition?" |
| **Diff Viewer for Assertions** | Side-by-side expected postcondition vs actual state |
| **Graph Analysis** | Find "hub" classes, detect architectural issues |
| **Design-Time Diagramming** | Sketch class relationships in BON, generate stubs |

### Platform Support

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

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Follow Eiffel coding standards
4. Add tests for new features
5. Submit a pull request

Areas where we especially need help:
- Linux/macOS testing and builds
- ECF parsing implementation
- Advanced parser features (type inference)
- VS Code extension improvements

## License

MIT License - See [LICENSE](LICENSE) file.

## Resources

- [Simple Eiffel Organization](https://github.com/simple-eiffel)
- [Simple Eiffel Documentation](https://simple-eiffel.github.io)
- [Eiffel Language](https://www.eiffel.org/)
- [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
- [VS Code Extension API](https://code.visualstudio.com/api)
