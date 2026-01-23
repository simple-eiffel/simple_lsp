# The DbC Universe Heatmap Comes to VS Code

**December 10, 2025 - From CLI tool to IDE integration in one session**

## The Starting Point

Yesterday we built the DbC Universe Heatmap - a COBE satellite-style visualization of Design by Contract coverage across an entire Eiffel ecosystem. It lived in simple_oracle as a CLI command that generated standalone HTML files.

Today's goal: **Bring it into VS Code so developers can see their DbC coverage without leaving the editor.**

## The Challenge

The heatmap already existed in two forms:
1. `oracle-cli dbc output.html` - generates a static file
2. A web page hosted at simple-eiffel.github.io

But VS Code integration meant:
- The LSP server needed to respond to a custom `eiffel/dbcMetrics` request
- The VS Code extension needed a webview panel with D3.js
- Real data had to flow from the Eiffel parser through the LSP to JavaScript
- Navigation had to work: Universe → Library → Classes → Open file

## Session Timeline

### Morning: The Foundation (v0.6.0 → v0.7.0)

Started around 7 PM. First step was adding the DbC metrics endpoint to simple_lsp. The LSP server already had handlers for hover, completion, go-to-definition. Adding `eiffel/dbcMetrics` followed the same pattern:

```eiffel
handle_dbc_metrics_request (a_id: INTEGER; a_params: detachable SIMPLE_JSON_OBJECT)
    -- Return DbC coverage metrics for heatmap visualization
```

The handler calls DBC_ANALYZER (from simple_eiffel_parser), scans all libraries based on SIMPLE_* environment variables, and returns JSON with:
- Overall score and counts
- Per-library metrics
- Per-class metrics with file paths

### The First Bug: Hardcoded 50%

Built the VS Code webview. Pressed Ctrl+Shift+H. Got a beautiful heatmap... with everything at 50%. Every single library.

The problem: The TypeScript extension was calling the endpoint but not actually reading the response. It was using placeholder data from an earlier test. Classic integration bug - both sides worked perfectly in isolation.

### The Second Bug: Drill-Down Shows Same Colors

Fixed the data flow. Universe view now showed real numbers: 34% overall, libraries ranging from 15% to 78%. Clicked on simple_json to drill down... and all classes showed the same purple color.

The problem: When drilling down, the code was making a fresh LSP request but the cached universe data only had library-level details. The extension was using the library's score for all its classes instead of per-class metrics.

Fix: Cache the full response including class-level data, use it when rendering drill-down views.

### The Third Bug: "Universe" Breadcrumb Does Nothing

Navigation worked going down: Universe → Library → Classes. But clicking "Universe" in the breadcrumb to go back up... nothing happened. No error in Output panel. Just nothing.

Larry: *"Check your logs."*

Added console.log debugging:
```typescript
console.log('[Heatmap] showUniverse called');
console.log('[Heatmap] currentData exists:', currentData ? 'yes' : 'no');
```

Opened DevTools (Ctrl+Shift+I). Found the real error:
```
Cannot read properties of null (reading 'style')
```

The culprit: `document.getElementById('loading').style.display = 'none'` - the loading element had been removed from DOM after first render. Added null check:

```typescript
const loadingEl = document.getElementById('loading');
if (loadingEl) loadingEl.style.display = 'none';
```

### The Version Sync Dance

Through the debugging, I kept rebuilding the extension. Larry noticed the VS Code output panel still showed "v0.7.0" when we were supposed to be on 0.7.2.

The problem: I was rebuilding the TypeScript extension (`npm run compile`) but not the Eiffel LSP binary. The version string comes from `lsp_server.e`, not `package.json`.

Larry's rule: **When VSIX version changes, LSP binary version MUST change too.** They ship together. Recorded this in simple_oracle knowledge base.

### The W_code vs F_code Lesson

Rebuilt the LSP. Larry: *"W_code???"*

Workbench code is 35MB with full debugging. Finalized code with `-keep` is ~13MB with contracts preserved. For releases, always use F_code.

Also learned: it's `-finalize -keep`, not `-finalize -keep all`. The `-keep` flag alone preserves contracts.

### v0.7.3 → v0.7.4: It Works!

Final test at 10:22 PM. Larry provided six screenshots:

1. **Universe View** - 33 libraries, real scores ranging from dark purple (15%) to orange (60%+)
2. **Drill into simple_process** - 3 classes visible with their individual scores
3. **Click "Universe" breadcrumb** - Returns to full universe view
4. **Drill into simple_setup** - 6 classes, all properly colored by their scores
5. **Navigation works both ways** - Universe ↔ Library transitions smooth
6. **Real data throughout** - No more 50% placeholders

## What We Built

**Keyboard shortcut**: `Ctrl+Shift+H` in any Eiffel file

**Features**:
- Force-directed D3.js graph in VS Code webview
- Real-time metrics from LSP scanning actual source files
- Drill-down navigation: Universe → Library → Class
- Click class node to open that file in editor
- Dark-mode color scheme matching VS Code
- Breadcrumb navigation to go back up

**The Tech Stack**:
- simple_lsp (Eiffel) - LSP server with custom `eiffel/dbcMetrics` endpoint
- simple_eiffel_parser (Eiffel) - DBC_ANALYZER class for contract counting
- VS Code extension (TypeScript) - Webview panel with D3.js
- D3.js v7 - Force-directed graph physics simulation

## What We Learned

1. **Integration bugs hide in the seams** - Both LSP and extension worked alone. The bug was in how they communicated.

2. **Console.log is still king** - DevTools revealed what Output panel didn't.

3. **Version sync matters** - When you bundle a binary with an extension, their versions must move together.

4. **F_code for releases** - Workbench builds are for development. Finalized with contracts is the sweet spot: optimized but still DbC-safe.

5. **Null checks in DOM** - Elements can disappear. Always check before accessing `.style`.

## Timeline Summary

| Time | Milestone |
|------|-----------|
| ~7:00 PM | Started v0.6.0 → v0.7.0 integration |
| ~8:00 PM | First heatmap renders (with 50% bug) |
| ~8:30 PM | Real metrics showing in Universe view |
| ~9:00 PM | Drill-down fixed |
| ~9:30 PM | Universe breadcrumb crash found |
| ~10:00 PM | DevTools reveals DOM null error |
| ~10:22 PM | v0.7.4 fully working |
| ~10:45 PM | Pushed to GitHub, installers built |

**Total time: ~4 hours** from "let's put this in VS Code" to working feature with installer.

## The Result

The DbC Universe Heatmap is now a first-class VS Code feature. Every Eiffel developer using simple_lsp can instantly see their Design by Contract coverage across their entire project - without leaving the editor, without running a separate command.

Where's the heat? That's where the thinking happened.
Where's the cold? That's where the work remains.

Now you can see it right in your IDE.

---

**Available in**: simple_lsp v0.7.4, simple_ecosystem_setup v1.2.0

**GitHub**: [simple-eiffel/simple_lsp](https://github.com/simple-eiffel/simple_lsp)

*Built with Claude Opus 4.5 + Claude Code in a single evening session.*
