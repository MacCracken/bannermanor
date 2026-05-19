# BannerManor — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-05-19 via `cyrius init bannermanor`. No releases yet.

## Toolchain

- **Cyrius pin**: `6.0.0` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`bnrmr` — vowel-dropped per `commandress` → `cmdrs`).
Single-shot CLI: text in, banner bytes out, exit.

## Source

- `src/main.cyr` — entry point; currently prints scaffold version line

M1 onward fills:

- `src/render.cyr` — character-grid composition (hardcoded font at M1)
- `src/font.cyr` — CYML font parser (M2)
- `src/layout.cyr` — alignment / width / padding (M4)
- `src/color.cyr` — darshana ANSI routing (M5)
- `src/flf.cyr` — legacy figlet font adapter (M6)

## Fonts

_None shipped yet._ M3 ships 3–5 in-tree fonts under `fonts/`.

## Tests

- `tests/bannermanor.tcyr` — primary suite (currently empty per cyrius init defaults)
- `tests/bannermanor.bcyr` — benchmark stub
- `tests/bannermanor.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert, bench

M2 adds `lib/cyml.cyr` for font parsing (already in stdlib path).
M5 adds `[deps.darshana]` for ANSI color primitives.

## Consumers

_None yet._ BannerManor is end-user-facing; consumers will be:

- agnoshi MOTD / login banner
- [`iam`](https://github.com/MacCracken/iam) — logo rendering on
  fastfetch-style output (if used)
- User script intros

## Next

See [`roadmap.md`](roadmap.md). Next ship is M1 (hardcoded block-letter font + first render path), targeting v0.2.0.
