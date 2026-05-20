# Issue 0001 — Keystrokes appear interleaved with banner during render

**Reported**: 2026-05-20
**Version**: 0.7.0
**Reporter**: maintainer (M7 dogfood)
**Status**: observed, deferred (not blocking v1.0)
**Severity**: cosmetic

## Observation

When `bnrmr` is run interactively at a zsh prompt and the user types
during the banner's row-by-row output, the typed bytes are echoed
into the terminal mid-draw, breaking the visual alignment of the
banner rows.

### Live capture (archaemenid, 2026-05-20)

Maintainer typed `ssh arch` at the prompt while their fastfetch-style
greeting was rendering `ARCHAEMENID`. The first six typed keystrokes
(captured as `asdasd` — finger-position drift on the home row) landed
on row 1 of the banner before bnrmr wrote the first glyph row:

```
asdasd ###  ####   #### #   #  ###  ##### #   # ##### #   # ##### ####
#   # #   # #     #   # #   # #     ## ## #     ##  #   #   #   #
##### ####  #     ##### ##### ####  # # # ####  # # #   #   #   #
#   # #  #  #     #   # #   # #     #   # #     #  ##   #   #   #
#   # #   #  #### #   # #   # ##### #   # ##### #   # ##### ####
Distro: Arch Linux
Host:   archaemenid
```

Rows 2–5 are byte-correct; only row 1 is contaminated. The
contamination appears at column 0 because that's the cursor position
at the moment between zsh emitting its post-prompt newline and bnrmr
starting its first row write. The kernel's TTY echo discipline placed
the typed bytes there, then bnrmr's `write(2)` for row 1 appended
immediately after — pushing the banner glyphs to the right.

The banner geometry is still correct — the bytes bnrmr writes are
unchanged. The interleaving is a display-time artifact.

## Hypothesis

bnrmr's `render_layout` writes the banner row-by-row via raw
`syscall(1, 1, ...)` calls with no explicit terminal-mode change.
The TTY is in its default *cooked* mode with echo on, so any bytes
the user types between bnrmr's `write(2)` calls are echoed by the
kernel's line discipline directly into the output stream — they
appear *between* bnrmr's rows because that's literally where the
TTY received them.

Contributing factors likely include:

- zsh's line editor (zle) repainting the prompt or syntax-highlighter
  state in response to keystrokes, especially with plugins like
  `zsh-autosuggestions` or `zsh-syntax-highlighting`.
- `.zshrc` features (right-side prompt, command-completion async
  fetches) emitting output during the render window.

## Workarounds (user side)

- Don't type while a banner renders (the render is single-shot and
  brief — typically &lt; 5 ms; this isn't usually a real annoyance).
- Run bnrmr in a non-interactive subshell or pipe through `cat`:
  `bnrmr "TEXT" | cat` — the pipe path is already TTY-detected and
  emits plain bytes, no SGR, with no interleave artifact since the
  destination isn't a live TTY.

## Possible fixes (deferred)

None of these are committed for v1.0. Listed for future consideration:

1. **Switch stdin to non-canonical mode + echo-off for the render
   window.** Save terminal state with `tcgetattr`, clear ICANON / ECHO
   on stdin, render, restore. Risk: if bnrmr is killed mid-render,
   the terminal stays in raw mode — users hate this. Need a SIGINT /
   SIGTERM handler to restore; non-trivial.
2. **Buffer the entire banner and write it in a single `write(2)`.**
   Reduces the *window* during which echo can interleave but doesn't
   eliminate it; kernel can still split a single write across echo
   events on heavily-loaded terminals.
3. **Document the behavior in the manpage** and move on. Probably the
   right answer — the cost / risk of (1) and (2) outweighs the
   benefit for a banner generator.

## Decision

Defer past v1.0. The behavior is annoying but cosmetic, the
single-shot render window is small, and the fix surface (TTY mode
manipulation with crash-safe restore) is larger than the bug.
Documented here so future contributors don't re-litigate.
