# Issue 0002 — `--pad` and `--width` accept arbitrarily large values

**Reported**: 2026-05-20
**Version**: 0.8.0-pre (during ad-hoc stress sweep)
**Reporter**: maintainer (M7 ad-hoc fuzz-by-hand)
**Status**: **fixed in 1.0.0** (2026-05-20)
**Severity**: cosmetic / user-DoS-of-self

## Observation

Both `--pad N` and `--width N` are checked only for `N >= 0`. A user
who passes a very large value gets exactly what they asked for:

```
$ bnrmr --pad 100000 "X" | wc -l
200005

$ bnrmr --width 1000000 --align center "X" | head -1 | wc -c
500006
```

A million-byte line per banner row, or two hundred thousand newlines,
appears at stdout. Process completes successfully; there is no
buffer overflow, no allocation explosion in-process (output is
emitted incrementally), and exit is 0.

## Why this isn't a security issue

- Input is user-typed. There's no attacker-controlled vector — the
  command line is trusted.
- bnrmr does not allocate proportional to `--pad` or `--width`; it
  emits bytes in a tight loop and exits.
- No process state is corrupted, no other process is affected.

## Why it's still worth fixing

The "principle of least surprise" — a tool that takes a number and
faithfully produces 500 KB of stdout when the user fat-fingered an
extra digit is mildly hostile. Most CLIs (`yes`, `seq`, `head -c`)
have similar permissive behavior, but bnrmr's invariant in CLAUDE.md
is "opinionated defaults, not endless options." A reasonable cap
matches that ethos.

## Suggested caps (for v1.0 / M8 freeze)

- `--width`: cap at 4096 (matches the F-008 `WS_COL_CAP`). A 4096-col
  banner is already absurd; nothing reasonable wants more.
- `--pad`: cap at 64. A 64-line top/bottom pad fills any reasonable
  terminal; more is decorative and the user can wrap in their own
  newlines if they really want.

If either is exceeded, reject with `bnrmr: --pad max 64` /
`bnrmr: --width max 4096` and exit 1. Consistent with the existing
negative-value rejection messages.

## Decision

Defer the cap to the v1.0 freeze (M8), where the CLI flag surface is
intentionally being locked. Adding the cap is a small breaking
behavior change (previously-valid invocations start exiting 1), which
is exactly what the M8 `Breaking` CHANGELOG section is for. Filing
this issue so the cap doesn't get forgotten during the freeze pass.

## Resolution (2026-05-20)

Shipped in 1.0.0. Caps applied as suggested:

- `--width N`: cap `WIDTH_CAP = 4096` in `src/layout.cyr`'s
  `LayoutLimits` enum. `src/main.cyr` rejects `> WIDTH_CAP` with
  `bnrmr: --width max 4096` and exits 1. Matches the F-008
  `WS_COL_CAP` numeric value by design; the two are kept as separate
  named constants because the *reason* differs (CLI input rejection
  vs. ioctl output clamping).
- `--pad N`: cap `PAD_CAP = 64`. `src/main.cyr` rejects `> PAD_CAP`
  with `bnrmr: --pad max 64` and exits 1.

The reject-path mirrors the existing negative-value rejections one
block above in `main.cyr` — same `println` + `return 1` shape, same
error-string style. Smoke-verified post-build:

- `--width 4097 "X"` → exit 1, `bnrmr: --width max 4096`
- `--width 4096 "X"` → renders (no regression at the boundary)
- `--pad 65 "X"`     → exit 1, `bnrmr: --pad max 64`
- `--pad 64 "X"`     → renders 133 lines (64 + 5 + 64)
- `--pad 0 --width 0 "X"` → renders 5 lines (default behavior unchanged)
- Negative values still rejected with the pre-1.0 messages.

This is the single `Breaking` documented in the 1.0.0 CHANGELOG.

## Test cases that surfaced this

Captured during the 0.8.0 pre-release ad-hoc stress sweep, alongside
50+ other edge cases (path traversal in `--font`, ANSI in font names,
NUL truncation, control bytes in text, `/dev/zero` as a `.flf`, etc.
— all of which behaved correctly). See git history for the full
sweep transcript if needed.
