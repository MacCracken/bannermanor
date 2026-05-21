# Issue 0004 — Banner wraps into itself when wider than the TTY

**Reported**: 2026-05-20
**Version**: 1.0.0-pre (caught during M8 dogfood)
**Reporter**: maintainer (M8 final smoke pass on archaemenid)
**Status**: **fixed in 1.0.0** (2026-05-20)
**Severity**: rendering correctness (cosmetic, no security impact)

## Observation

`./build/bnrmr --font ./modular.flf "BANNERMANOR 1.0"` on a 129-col
terminal renders 7 cleanly-formed rows, *but* the terminal soft-wraps
each row partway through because the banner is ~135 cols wide. The
visual result: each banner row spills onto a second visual line,
breaking the glyph alignment. Captured by `stty size`:

```
$ stty size
42 129

$ ./build/bnrmr --font ./modular.flf "BANNERMANOR 1.0"
# row 1 wraps after the "BANNERMANO" portion
# row 2 wraps differently because of leading spaces
# alignment is broken across rows
```

`figlet` on the same terminal truncates at the glyph boundary by
default — the user expectation is "the banner should fit my terminal
unless I asked otherwise."

## Root cause

`render_layout` in `src/layout.cyr` only invoked `fit_chars` when the
user passed `--width N`:

```cyrius
var draw_len = len;
if (width > 0) {
    draw_len = fit_chars(width, w, g, len);
}
```

With the default `--width 0` (the M1 "render in full" contract for
scripts and tests), `draw_len = len` was used unconditionally — the
banner was emitted at its natural width regardless of terminal size.
On a TTY narrower than the banner, the kernel's TTY layer wrapped
each row at its own column boundary, which is what the user
sees.

The M1 byte-identity contract was the original justification for
this — `bnrmr "TEXT" | cat` should produce identical bytes to
`render(font, text, len)`. That contract was right for *pipes*; it
just shouldn't apply to TTYs, which have a real column count to
honor.

## Fix (shipped 1.0.0)

`render_layout` now resolves an effective truncation width from
`term_width_ioctl()` when `--width` is unset:

```cyrius
var clamp_w = width;
if (clamp_w == 0) { clamp_w = term_width_ioctl(); }
var draw_len = fit_chars(clamp_w, w, g, len);
```

- **TTY out** (`term_width_ioctl()` returns the live cols):
  `fit_chars(cols, w, g, len)` truncates at the glyph boundary —
  banner fits without wraparound.
- **Pipe / redirect out** (`term_width_ioctl()` returns 0 because the
  ioctl fails on a non-TTY fd):
  `fit_chars(0, w, g, len)` returns `len` unchanged — full
  untruncated banner. M1 byte-identity contract preserved for
  `bnrmr ... | cat`, scripts, and the test suite.
- **Explicit `--width N`**: unchanged. User's override always wins.

The `t_layout_render_layout_default_matches_render` test continues
to pass because `cyrius test` runs non-TTY; the helper falls into
the pipe branch and produces byte-identical output to `render()`.

## Smoke verification

Post-fix:

```
$ ./build/bnrmr --width 129 --font ./modular.flf "BANNERMANOR 1.0" | head -1 | wc -c
127
```

127 cols ≤ 129; whole-glyph truncation dropped the `.0` tail to keep
the banner inside the TTY. Comparable invocation with no `--width`
on a 129-col TTY produces the same 127-col first row.

Pipe path:

```
$ ./build/bnrmr --font ./modular.flf "BANNERMANOR 1.0" | head -1 | wc -c
136
```

136 = 135-col banner + newline — full untruncated, exactly as the
pre-fix piped path produced.

Test suite: 2762 / 2762 still passing.

## Decision

Found and fixed in 1.0.0 — 1.0 was not yet tagged when the bug
surfaced, so the fix folds into the v1.0 cut rather than waiting
for 1.0.1. CHANGELOG entry under `Fixed` documents the behavior
delta and the preserved M1 contract.
