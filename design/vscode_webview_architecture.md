# VS Code Webview Architecture for simple_lsp

## Overview

This document explores architectural patterns for extending simple_lsp with browser-based interactive features in VS Code using HTMX, Alpine.js, and CSS.

## Key Concepts

### 1. Custom Editors vs Side Panels

**Custom Editor (Full Replacement)**
- Completely replaces VS Code's default text editor for a file type
- Renders file content in a webview (HTML/CSS/JS)
- No native syntax highlighting, editing, or extension integration
- User builds entire editing experience from scratch

**Side Panel/Webview (Augmentation)**
- Opens alongside the standard text editor
- Shows interactive visualizations, diagnostics, or tools
- Best of both worlds: native editor + custom features
- Recommended approach for most use cases

### 2. Companion Editor Webview Architecture

An innovative approach: create a webview that acts as a "companion" to the standard editor.

**Architecture:**
```
┌────────────────────────────────────────────────────────────────┐
│                        VS Code Window                          │
├────────────────────────────┬───────────────────────────────────┤
│   Standard .e Editor       │   Companion Webview               │
│   (Monaco - native)        │   (HTML + HTMX + Alpine)          │
│                            │                                   │
│   - Syntax highlighting    │   - Contract heat map             │
│   - LSP integration        │   - DbC badges and colors         │
│   - Native editing         │   - Collapsible feature regions   │
│   - All extensions work    │   - Interactive diagrams          │
│                            │   - Pick-n-Drop targets           │
└────────────────────────────┴───────────────────────────────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │   simple_lsp    │
                              │   HTTP/SSE      │
                              └─────────────────┘
```

**Data Flow:**
1. User edits `.e` file in standard editor
2. File changes trigger LSP notifications
3. simple_lsp processes changes, updates internal state
4. Webview polls/SSE from simple_lsp for updates
5. HTMX refreshes affected regions
6. Alpine manages reactive UI state

### 3. HTMX Integration

HTMX enables the webview to communicate with simple_lsp via HTTP without heavy JavaScript frameworks.

**Example: Contract Heat Map Updates**
```html
<div hx-get="/api/contracts/heat-map"
     hx-trigger="sse:contract-changed"
     hx-swap="outerHTML">
  <!-- Heat map renders here -->
</div>
```

**Example: Feature Details on Click**
```html
<div class="feature-block"
     hx-get="/api/feature/{feature_name}/contracts"
     hx-trigger="click"
     hx-target="#contract-panel">
  feature_name
</div>
```

### 4. Alpine.js for Reactive UI

Alpine handles local UI state without needing a build step.

**Example: Collapsible Contract Sections**
```html
<div x-data="{ showPreconditions: true, showPostconditions: true }">
  <button @click="showPreconditions = !showPreconditions">
    Preconditions
  </button>
  <div x-show="showPreconditions" x-transition>
    <!-- Precondition list from HTMX -->
  </div>
</div>
```

**Example: Contract Filter Tabs**
```html
<div x-data="{ filter: 'all' }">
  <button @click="filter = 'all'" :class="{ active: filter === 'all' }">All DbC</button>
  <button @click="filter = 'require'" :class="{ active: filter === 'require' }">Requires</button>
  <button @click="filter = 'ensure'" :class="{ active: filter === 'ensure' }">Ensures</button>

  <template x-if="filter === 'all'">
    <div hx-get="/api/contracts?filter=all" hx-trigger="load"></div>
  </template>
  <!-- etc -->
</div>
```

### 5. Pick-n-Drop Simulation

EiffelStudio's Pick-n-Drop can be simulated in the webview using drag-and-drop HTML5 APIs with HTMX.

**Concept:**
- "Pebble" = draggable item (class name, feature name, type)
- "Hole" = drop target (parameter, variable, type annotation)
- Dragging triggers visual feedback
- Dropping sends HTMX request to simple_lsp for code generation

**Example:**
```html
<!-- Draggable class pebble -->
<span class="pebble pebble-class"
      draggable="true"
      @dragstart="$dispatch('pebble-picked', { type: 'class', name: 'CUSTOMER' })">
  CUSTOMER
</span>

<!-- Drop hole for type -->
<span class="hole hole-type"
      @dragover.prevent
      @drop="$dispatch('pebble-dropped', { target: 'parameter-type-1' })"
      hx-post="/api/pick-drop"
      hx-vals='{"action": "set-type"}'>
  [drop type here]
</span>
```

### 6. Browser-fied .e File Display

Could we render `.e` files as interactive HTML while keeping the source files untouched?

**Yes, with these approaches:**

**A. Read-Only Visualization**
- Webview reads `.e` file content
- Renders with syntax highlighting + DbC decorations
- Changes sync back from standard editor
- Webview is for viewing/interacting, not editing

**B. Full Editor Replacement (Complex)**
- Embed Monaco editor in webview
- Add HTMX/Alpine layers around it
- Changes write back to `.e` file
- Complexity: must implement all editor features

**C. Side-by-Side Sync (Recommended)**
- Standard editor for editing
- Webview for enhanced visualization
- Two-way sync via LSP events
- Best balance of features and complexity

## Implementation Priorities

1. **Side Panel Foundation** - Basic webview with HTMX/Alpine loading
2. **Contract Heat Map** - Visual hierarchy with clickable drill-down
3. **AutoTest Panel** - Test runner with real-time results
4. **Pick-n-Drop MVP** - Simple drag-drop for common operations
5. **Full Editor Companion** - Synchronized enhanced view

## Technical Requirements

- simple_lsp HTTP endpoints for data
- Server-Sent Events (SSE) for real-time updates
- Minimal CSS framework (Tailwind or custom)
- Alpine.js (~15KB) for reactivity
- HTMX (~14KB) for server communication

## File Structure

```
simple_lsp/
├── vscode-extension/
│   ├── src/
│   │   ├── webviews/
│   │   │   ├── contract-heat-map.html
│   │   │   ├── autotest-panel.html
│   │   │   └── companion-editor.html
│   │   ├── styles/
│   │   │   └── webview.css
│   │   └── extension.ts
│   └── package.json
└── src/
    └── http_api/
        ├── contract_endpoints.e
        ├── test_endpoints.e
        └── pick_drop_endpoints.e
```

## Next Steps

1. Add HTTP server capability to simple_lsp
2. Create basic webview panel in VS Code extension
3. Implement Contract Heat Map as proof of concept
4. Test HTMX/Alpine integration
5. Iterate based on usability feedback

---

*Last updated: 2025-12-10*
