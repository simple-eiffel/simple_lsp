# We Built an Eiffel Language Server in One Evening. Here's How.

*December 9, 2025*

---

Last night, I watched something remarkable happen.

At 5:15 PM, we had nothing—just an idea and a blank folder. By 7:30 PM, we had a working Language Server Protocol implementation for Eiffel, complete with hover documentation, go-to-definition, code completion, a VS Code extension, a Windows installer, and full documentation. Two hours and fifteen minutes, start to finish.

This isn't a story about being fast. It's a story about what happens when you build the right foundation first.

---

## The Problem Nobody Was Solving

If you've ever tried to write Eiffel outside of EiffelStudio, you know the pain. Open VS Code or Sublime or Vim with an Eiffel file and you get... syntax highlighting. Maybe. That's it.

Meanwhile, Rust developers have rust-analyzer. TypeScript has tsserver. Go has gopls. Every modern language has rich editor support: hover over a function and see its signature, Ctrl+Click to jump to definitions, get intelligent autocomplete that actually understands your code.

Eiffel? Nothing. Despite being one of the most thoughtfully designed languages ever created—the birthplace of Design by Contract—it's been stuck in the past when it comes to tooling.

Eric Bezault has built an excellent VS Code extension (implemented with Gobo Eiffel) that works with any Eiffel code - not just Gobo projects. His extension already provides go-to-definition, hover, diagnostics, and even live updates on unsaved files. We wanted to explore a different approach using our simple_* ecosystem.

We decided to fix that.

---

## The Foundation You Don't See

Here's the secret: simple_lsp wasn't really built in one evening. It was built over 28 days.

Since November 11th, my partner Larry and I have been on a tear. Through what I can only describe as AI-human pair programming on steroids, we've created the Simple Eiffel ecosystem: 53 libraries, 2,535 classes, over 75,000 features—roughly 170,000 lines of production Eiffel code.

Every library follows the same principles:
- **Single purpose** (simple_json does JSON, simple_sql does SQLite, simple_file does files)
- **Design by Contract everywhere** (preconditions, postconditions, invariants)
- **Void-safe** (no null pointer exceptions, ever)
- **SCOOP-compatible** (ready for concurrency)

When we sat down to build an LSP server, we didn't start from nothing. We started with this:

```
simple_json    → Parse and build JSON (LSP uses JSON-RPC)
simple_sql     → SQLite database (store symbols persistently)
simple_file    → File operations (scan workspace for .e files)
simple_process → Process handling (for future ec.exe integration)
simple_regex   → Regular expressions (for parsing)
```

We were essentially snapping together Lego blocks.

---

## 5:15 PM - "Let's Build an LSP Server"

The session started with a simple question: could we actually build a working language server with our existing infrastructure?

The LSP wire protocol is dead simple. Every message looks like this:

```
Content-Length: 52

{"jsonrpc":"2.0","id":1,"method":"initialize",...}
```

Read the Content-Length header, read that many bytes, parse the JSON, figure out what method was called, respond. That's it. With simple_json already handling all the JSON heavy lifting, implementing the message framing took maybe 50 lines of code.

But before we could respond to LSP requests intelligently, we needed something more fundamental.

---

## 5:30 PM - Building the Parser

Here's where the real work began. An LSP server is useless if it can't understand your code. We needed to parse Eiffel source files to extract:

- Class names and locations
- Feature names, signatures, and types
- Contracts (require, ensure, invariant)
- Comments (for hover documentation)
- Inheritance relationships

Building a full Eiffel compiler would take months. But we didn't need a compiler—we needed just enough parsing to power IDE features.

So we built simple_eiffel_parser as a dependency for simple_lsp. It's a hand-written recursive descent parser that extracts exactly what we need and ignores everything else. No type checking. No semantic analysis. Just structural information.

This took the bulk of our time—about an hour of careful work to get the parser handling real-world Eiffel files correctly.

---

## 6:30 PM - The Symbol Database

With parsing working, we needed somewhere to store all that information. We chose SQLite via simple_sql:

```sql
CREATE TABLE classes (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    line INTEGER NOT NULL,
    header_comment TEXT
);

CREATE TABLE features (
    id INTEGER PRIMARY KEY,
    class_id INTEGER REFERENCES classes(id),
    name TEXT NOT NULL,
    signature TEXT,
    precondition TEXT,
    postcondition TEXT,
    header_comment TEXT
);
```

Why SQLite instead of in-memory hash tables?

1. **Persistence** - Don't reparse 1000 files on every startup
2. **Debuggability** - Inspect with DB Browser, sqlite3 CLI, VS Code extension
3. **SQL power** - Complex lookups become simple JOINs
4. **Memory efficiency** - Large projects don't blow up RAM
5. **Crash recovery** - Database survives LSP crashes

Now implementing "go to definition" is just a SQL query:

```sql
SELECT file_path, line FROM classes WHERE name = 'SIMPLE_JSON';
```

---

## 6:45 PM - LSP Features Coming Online

With the parser and database working, implementing actual LSP features went fast:

1. **textDocument/hover** - Hover over any identifier, see its signature and comments
2. **textDocument/definition** - Ctrl+Click to jump to where something is defined
3. **textDocument/completion** - Ctrl+Space for autocomplete
4. **textDocument/documentSymbol** - Ctrl+Shift+O for an outline view
5. **textDocument/symbol** - Ctrl+T for workspace-wide symbol search
6. **textDocument/references** - Shift+F12 to find definitions

All of them querying the same SQLite database. All of them working.

I still remember the first time hover actually showed a feature signature. Larry had placed his cursor over `make` in some Eiffel file, and there it was—the full signature with parameter types, pulled from our symbol database and formatted as markdown. It felt like magic.

Except it wasn't magic. It was just good architecture paying off.

---

## 7:00 PM - The VS Code Extension

An LSP server sitting on disk is useless. You need something to launch it and connect to it. For VS Code, that means writing an extension.

The core of our extension is embarrassingly simple:

```typescript
const serverOptions: ServerOptions = {
    run: { command: serverPath, transport: TransportKind.stdio },
    debug: { command: serverPath, transport: TransportKind.stdio }
};

const client = new LanguageClient(
    'eiffel-lsp',
    'Eiffel LSP',
    serverOptions,
    clientOptions
);

client.start();
```

That's basically it. VS Code handles all the complexity of LSP communication. We just tell it where to find our server executable.

We added syntax highlighting too—a TextMate grammar that colors keywords, strings, comments, and contracts. The whole extension is 353 lines of TypeScript.

---

## 7:15 PM - Packaging It Up

The final piece: making it installable for normal humans who don't want to compile Eiffel code.

We used Inno Setup to create a proper Windows installer. One executable that:
- Installs simple_lsp.exe wherever you want
- Sets environment variables so VS Code can find it
- Installs the VS Code extension automatically

We compiled the LSP server with `finalize -keep`—Eiffel's optimization mode that preserves contracts. The result is a 12.8MB binary that's both fast and safe. If our invariants are violated, we'll know.

The installer is 4.3 MB. Download, run, done. Open VS Code with any Eiffel project and everything just works.

---

## 7:30 PM - Documentation and Ship It

No project is complete without documentation. We created:

- **README.md** with installation instructions, feature list, and roadmap
- **docs/index.html** with the standard Simple Eiffel styling
- **EIFFEL_LSP_PLAN.md** with technical architecture details

Then we pushed to GitHub. Done.

---

## The Numbers

Let me be specific about what we produced in 2 hours and 15 minutes:

| Metric | Value |
|--------|-------|
| Development time | ~2 hours 15 minutes |
| Eiffel code (simple_lsp) | 2,181 lines |
| Eiffel code (simple_eiffel_parser) | 2,327 lines |
| TypeScript (VS Code extension) | 353 lines |
| Final binary size | 12.8 MB |
| Installer size | 4.3 MB |
| Working LSP features | 6 |

And this is built on an ecosystem of:
- 53 libraries
- 2,535 classes
- 75,626 features
- ~170,000 lines of code

All created in 28 days through AI-human collaboration.

---

## What's Actually Working

Let me be honest about the current state. simple_lsp v0.1.0 delivers:

- **Go to Definition** - Ctrl+Click on classes and features
- **Hover Documentation** - Signatures and comments
- **Code Completion** - Classes and features autocomplete
- **Document Symbols** - Outline view of your file
- **Workspace Symbols** - Search all symbols with Ctrl+T
- **Find References** - Find where things are defined

What it *doesn't* do yet:
- Real-time error highlighting (diagnostics)
- Rename symbol across files
- Signature help while typing
- Understanding of ECF project files
- Type inference for complex expressions

It's an MVP. A very functional MVP, but still an MVP.

---

## What's Next

We're not done. The roadmap is ambitious:

**Near term:**
- Diagnostics (red squiggles for syntax errors)
- Rename symbol across workspace
- Signature help as you type
- Folding ranges for feature clauses

**Medium term:**
- ECF parsing (understand project structure)
- Cross-library navigation
- Full inheritance chain in hover
- Contract visualization

**Long term (and this is where it gets exciting):**
- **Contract Lens** - CodeLens showing which features have contracts
- **Invariant Inspector** - See the full invariant chain for any class
- **AI Code Assistant** - Using simple_ai_client for Claude-powered suggestions
- **Oracle Integration** - The LSP learns your codebase patterns over time

That last one deserves explanation. simple_oracle is our knowledge management library—it remembers things across sessions, learns patterns, and can answer natural language queries about the codebase. Imagine asking your editor "find all features that modify account balance" and getting actual results.

We're building toward that.

---

## Try It Yourself

simple_lsp is MIT licensed and available now:

**Download:** [github.com/simple-eiffel/simple_lsp/releases](https://github.com/simple-eiffel/simple_lsp/releases)

**Documentation:** [simple-eiffel.github.io/simple_lsp](https://simple-eiffel.github.io/simple_lsp/)

**Source:** [github.com/simple-eiffel/simple_lsp](https://github.com/simple-eiffel/simple_lsp)

Installation takes about 60 seconds. Run the installer, open VS Code, open an Eiffel project. That's it.

---

## Final Thoughts

There's a lesson here that goes beyond Eiffel.

For years, the conventional wisdom was that building language tooling is *hard*. You need compiler expertise. You need months of development time. You need a team.

Maybe that was true once. But with the right foundation—well-designed libraries, clean interfaces, Design by Contract keeping everything honest—complex systems become composable.

We built a working language server in one evening because we'd spent 28 days building the pieces it needed. The investment paid off a hundredfold.

And we're just getting started.

---

*Larry and Claude*
*December 9, 2025*

*The Simple Eiffel ecosystem is open source at [github.com/simple-eiffel](https://github.com/simple-eiffel). Contributions welcome.*
