# Eric Bezault's Feedback on simple_lsp

**Date:** December 10, 2025
**Context:** Response to our blog post about simple_lsp

## Clarification on Eric's VS Code Extension

Eric corrected our mischaracterization:

> Just to make things clear, my VS Code extension is not for Gobo Eiffel.
> It is for Eiffel, implemented with Gobo Eiffel. When browsing and
> editing the Eiffel classes in VS Code, it does not matter whether
> these classes are meant to be compiled with EiffelStudio's compiler
> or with the Gobo Eiffel compiler.

**Key point:** Eric's extension works with ANY Eiffel code, regardless of which compiler you use. It's *implemented* with Gobo Eiffel but is not *limited* to Gobo projects.

## Live Editing Feature

Eric pointed out a critical feature his extension supports that we haven't implemented:

> Did Claude think about updating its knowledge about the Eiffel file
> being edited on the fly, even though it has not been saved to disk
> yet? My VS Code extension does that: Go to Definition (across files),
> Hover Documentation (across files), Document symbols, Compilation
> errors red squiggles (displayed as you type, and across files), all
> that work even on class texts being edited and not saved to disk yet.

**Action:** Added "Live Editing" to our roadmap - updating symbols and diagnostics for unsaved changes.

## Implicit Code Lens Suggestion

Eric suggested a feature we hadn't considered:

> In the nice things to have, which I did not see in your wish list
> but is on mine, there is a way to make implicit code explicit
> (Implicit Code Lens). For example:
>
> - `create x` → `create x.default_create`
> - `a := b` (with conversion) → `a := b.to_a`
> - `a.x := b` → `a.set_x (b)` (assigner)
> - `my_agent.call (x)` → `my_agent.call ([x])` (manifest tuple)
>
> And probably others like that.

**Action:** Added "Implicit Code Lens" to roadmap - this is a brilliant idea for making Eiffel's syntactic sugar visible.

## Our Response

1. Fixed all documentation to correctly describe Eric's extension
2. Added Live Editing to roadmap
3. Added Implicit Code Lens to roadmap
4. Acknowledge Eric's extension as a mature, full-featured option

---

**Contact:**
Eric Bezault
mailto:ericb@gobosoft.com
http://www.gobosoft.com
