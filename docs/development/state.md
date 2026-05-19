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

- `src/main.cyr` — entry point; concatenates argv, enforces 1 KB
  input cap, dispatches to the renderer. Flags: `--version`, `--help`.
- `src/render.cyr` — M1 render pipeline (block font, fixed 5×5 grid,
  1-space inter-glyph gap, hard input cap).
- `src/font_block.cyr` — M1 hardcoded block font (ASCII space, 0–9,
  A–Z; lowercase folds). Slated for extraction to `fonts/block.cyml`
  at M2 — see roadmap M2 acceptance.

Planned by milestone:

- `src/font.cyr` — CYML font parser (M2)
- `src/layout.cyr` — alignment / width / padding (M4)
- `src/color.cyr` — darshana ANSI routing (M5)
- `src/flf.cyr` — legacy figlet font adapter (M6)

## Fonts

_None shipped to `fonts/` yet._ M1 carries the block font in-tree at
`src/font_block.cyr`; M2 promotes it to `fonts/block.cyml` as the
first canonical CYML font. M3 broadens to 3–5 fonts total.

## Tests

- `tests/bannermanor.tcyr` — 260 assertions covering: block_glyph_index
  (space / digits / uppercase / lowercase folding / unsupported chars),
  row-shape invariant for every glyph, renderer bounds (negative len,
  over-cap, way-over-cap). Runs clean.
- `tests/bannermanor.bcyr` — benchmark stub
- `tests/bannermanor.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert, bench, args

M2 adds `lib/cyml.cyr` for font parsing (already in stdlib path).
M5 adds `[deps.darshana]` for ANSI color primitives.

## Consumers

_None yet._ BannerManor is end-user-facing; consumers will be:

- agnoshi MOTD / login banner
- [`iam`](https://github.com/MacCracken/iam) — logo rendering on
  fastfetch-style output (if used)
- User script intros

## Next

M1 work landed on the working tree (render pipeline + block font +
input cap + tests + flags). Pending before v0.2.0 tag: user-driven
commit, VERSION bump, and CHANGELOG header rename from `[Unreleased]`
to `[0.2.0]`. After tag: M2 — CYML font format ADR + parser, and
extraction of `src/font_block.cyr` into `fonts/block.cyml`.

See [`roadmap.md`](roadmap.md) for the full M2–M8 sequence.
