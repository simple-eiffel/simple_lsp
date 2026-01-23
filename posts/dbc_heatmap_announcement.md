# The DbC Heatmap: How an AI and a Human Built a COBE Satellite for Eiffel in One Session

**A story of Design by Contract, physics simulations, and seeing your code in a whole new way.**

## The Genesis

It started with a simple question during an ongoing project to build the "simple_*" Eiffel library ecosystem - a collection of 53+ libraries covering everything from JSON parsing to Win32 API wrappers to LSP servers. We'd just finished integrating **simple_ucf** (Universe Configuration File) - a TOML-based way to define an entire Eiffel ecosystem - into both **simple_lsp** (our Language Server Protocol implementation) and **simple_oracle** (Claude's external memory and development intelligence platform).

The question: *"How do we visualize Design by Contract coverage across an entire universe of libraries?"*

## The Design Conversation

The initial proposal was a heatmap with color coding. But the color scale was backwards - it had cold colors for good coverage. That's wrong. Heat means good. Cold means bad. Red-hot code is well-contracted code. Black/cold code needs attention.

Then came the visualization question. Something neural-network-ish - a map that presents itself in some base form and then reshapes itself through physics simulation. That led to D3.js force-directed graphs - nodes connected by links, with physics that lets you drag things around and watch them settle into natural clusters.

The concept crystallized: *"Ask oracle for a heatmap of the universe - like the COBE satellite applied to an Eiffel ecosystem."*

The COBE (Cosmic Background Explorer) satellite mapped the early universe's temperature variations. We'd do the same for DbC coverage.

## The Implementation

### Step 1: The Analyzer Classes

Four Eiffel classes:
- `DBC_HEATMAP_ANALYZER` - The main engine
- `DBC_LIBRARY_METRICS` - Aggregates per library
- `DBC_CLASS_METRICS` - Tracks class-level coverage
- `DBC_FEATURE_METRICS` - Individual feature contracts

The analyzer uses **simple_eiffel_parser** (a native Eiffel parser) to walk through every `.e` file, counting:
- `require` clauses (preconditions)
- `ensure` clauses (postconditions)
- `invariant` sections (class invariants)

### Step 2: The First Crash

First run: segmentation fault. Classic corrupted EIFGENs situation. Fresh compile fixed that.

Next run: `EIFFEL_PARSER` precondition violation - `not_at_end` failed. Some files were empty or malformed. Solution: wrap the parser call in a rescue clause with retry. DbC caught the problem; defensive coding fixed it.

### Step 3: The First Visualization... Disaster

The HTML generated. Everything was clumped in the top-left corner - a sad little blob of overlapping nodes instead of a beautiful network.

Problems identified:
- Node IDs weren't unique (class names collided across libraries)
- No initial positions (everything started at 0,0)
- Forces too weak to spread things out

### Step 4: The Fix

- Unique IDs: `lib_simple_json`, `lib_simple_json_SIMPLE_JSON`, etc.
- Initial circular layout: Libraries arranged in a ring around the Universe center
- Stronger forces: -800 repulsion for center, -300 for nodes
- Smart sizing: Universe = 50px, libraries scale with class count, classes = 8px
- Limit clutter: Only top 5 classes per library shown
- Labels only on library+ nodes (hover for tooltips on small nodes)

### Step 5: The Reveal

Refresh. And there it was - a living, breathing map of an entire Eiffel ecosystem's contract coverage.

## What We Built

**Live Demo: [https://simple-eiffel.github.io/simple_oracle/dbc_heatmap.html](https://simple-eiffel.github.io/simple_oracle/dbc_heatmap.html)**

A physics-based force-directed graph showing:

**Color Scale (Dark Mode):**

| Score | Color | Meaning |
|-------|-------|---------|
| 90-100% | Red-orange | Excellent DbC |
| 75-89% | Orange | Good coverage |
| 50-74% | Burnt orange | Moderate |
| 25-49% | Muted magenta | Needs work |
| 1-24% | Dark purple | Poor |
| 0% | Near-black | No contracts |

**Interactive Features:**
- Drag any node - physics simulation responds
- Hover for detailed tooltips (score, features, requires, ensures)
- Nodes sized by importance (Universe > Libraries > Classes)
- Links show relationships

**The Simple Eiffel Ecosystem Results:**
- **34%** overall DbC score
- **33** libraries discovered from environment
- **105** classes analyzed
- **1080** features examined
- **401** with preconditions (37%)
- **346** with postconditions (32%)
- **76** classes with invariants (72%)

## The Technical Stack

All built in Eiffel:
- **simple_oracle** - Analysis engine and CLI
- **simple_eiffel_parser** - Native Eiffel source parsing
- **simple_ucf** - Universe configuration (TOML-based)
- **simple_json** - JSON generation for D3.js data
- **simple_file** - File operations
- **D3.js v7** - Force-directed graph visualization
- **Alpine.js** - Lightweight interactivity

## Generate Your Own

```bash
# Set up your SIMPLE_* environment variables, then:
oracle-cli dbc my_project_heatmap.html
```

Or use a UCF file to define your universe explicitly.

## The Philosophy

Design by Contract isn't just documentation. It's not just runtime checking. It's a **philosophy** that makes your intent explicit and machine-verifiable. The heatmap lets you see that philosophy manifested across an entire codebase.

Where's the heat? That's where the thinking happened. Where's the cold? That's where the work remains.

## What's Next

- Integration into VS Code via simple_lsp
- Drill-down views (click a library to see all its classes)
- Historical tracking (watch your DbC score improve over time)
- CI integration (fail builds if DbC drops below threshold)

---

*This entire feature - from concept to working visualization - was built in a single Claude Code session. The conversation, the crashes, the fixes, the reveal. That's what AI-assisted development looks like when you have a human who knows what they want and an AI that can execute.*

*Design by Contract isn't just a feature - it's a philosophy. Now you can see it.*

**[View the Live Heatmap](https://simple-eiffel.github.io/simple_oracle/dbc_heatmap.html)**
