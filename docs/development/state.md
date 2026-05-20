# BannerManor — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.2.0** — tagged 2026-05-19. First post-scaffold release; bundles
M1 (first render path, hardcoded block font, 1 KB input cap, flags
`--version`/`--help`) and M2 (CYML font format, `fonts/block.cyml`,
`--font NAME` flag, loader with validation).

**Unreleased** — M3 complete. Ships: `--list-fonts`, header-only
loader, fold-fallback in `font_glyph_index`, `block.cyml` expanded
to full printable ASCII (69 glyphs), `fonts/slim.cyml` (4×5),
`fonts/big.cyml` (7×7), `docs/guides/fonts.md`, pin bumped to 6.0.1.
Final font set is the initial three (block/slim/big) covering
small / medium / large; more fonts can land in subsequent releases
without re-cutting M3. Ready for v0.3.0 tag. See `CHANGELOG.md`
`[Unreleased]` for the full list.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`bnrmr` — vowel-dropped per `commandress` → `cmdrs`).
Single-shot CLI: text in, banner bytes out, exit.

## Source

- `src/main.cyr` — entry point; concatenates argv, enforces 1 KB
  input cap, dispatches to the renderer. Flags: `--version`,
  `--help`, `--font NAME` (resolves to `fonts/NAME.cyml` relative
  to cwd), `--list-fonts` (alphabetic listing of `./fonts/*.cyml`
  with geometry + description from each font header).
- `src/render.cyr` — generic render pipeline. Takes a `Font*`; same
  code path serves the embedded default and any CYML-loaded font.
- `src/font.cyr` — `Font` struct + CYML loader (`font_load_file`).
  Validates file size, schema version, geometry bounds, and body
  shape; rejects malformed input rather than degrading. Also
  exposes `font_header_load()` — a lightweight header-only loader
  used by `--list-fonts`.
- `src/font_block.cyr` — embedded "block" font. `block_font_embed()`
  builds a `Font*` from inline glyph data; this is the default used
  when no `--font` flag is passed (CLAUDE.md self-contained rule).
  Mirrors `fonts/block.cyml` byte-for-byte — drift checked in tests.
  Glyph data is split across `_block_raw_row_lo` (idx 0–36: space +
  0–9 + A–Z) and `_block_raw_row_hi` (idx 37–68: printable
  punctuation) to stay under cycc's 256-return-per-function limit.

Planned by milestone:

- `src/layout.cyr` — alignment / width / padding (M4)
- `src/color.cyr` — darshana ANSI routing (M5)
- `src/flf.cyr` — legacy figlet font adapter (M6)

## Fonts

In-tree (`fonts/`):

- `fonts/block.cyml` — block font (5×5), schema 1. Coverage: full
  printable ASCII (32–126) = space, `0`–`9`, `A`–`Z`, all standard
  punctuation. 69 glyphs. Lowercase `a`–`z` renders via fold-fallback
  to uppercase (no separate lowercase glyphs at this size). Author:
  BannerManor; license: GPL-3.0-only.
- `fonts/slim.cyml` — slim font (4×5), schema 1. Same vertical size
  as block; one column narrower per glyph (5 char-cells per glyph at
  gap=1 vs block's 6 — ~16% horizontal compression). Full printable
  ASCII coverage, 69 glyphs, uppercase-only with fold-fallback for
  lowercase. Author: BannerManor; license: GPL-3.0-only.
- `fonts/big.cyml` — big font (7×7), schema 1. Chunky banner option,
  ~96% more cells per glyph than block. Full printable ASCII coverage,
  69 glyphs, uppercase-only with fold-fallback for lowercase. Author:
  BannerManor; license: GPL-3.0-only.

M3 ships the initial set of three (block/slim/big) — small / medium /
large at distinct sizes. CLAUDE.md leans "opinionated defaults, not
endless options"; more fonts can land in later releases. Schema and
loader contract documented in
[`docs/adr/0001-cyml-font-format.md`](../adr/0001-cyml-font-format.md);
authoring walkthrough at [`docs/guides/fonts.md`](../guides/fonts.md).

## Tests

- `tests/bannermanor.tcyr` — 2573 assertions covering: embedded font
  geometry, glyph-index lookup (space / digits / uppercase /
  lowercase folding / punctuation / unsupported / fold-is-fallback),
  row-shape invariant, renderer bounds, CYML loader happy path +
  missing-file path + malformed fixtures (bad schema, bad body byte,
  wrong row count), the M2 acceptance check (loaded `fonts/block.cyml`
  is byte-identical to the embedded font on every char and every row,
  now over 69 glyphs), the slim and big font loads + full-printable-
  ASCII coverage checks, and the M3 header loader (fields on
  `block.cyml`, missing-file, bad-schema rejection). Runs clean.
- `tests/fixtures/` — malformed-font fixtures consumed by the loader
  rejection tests.
- `tests/bannermanor.bcyr` — benchmark stub
- `tests/bannermanor.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert, bench,
  args, cyml, result

M5 adds `[deps.darshana]` for ANSI color primitives.

## Consumers

_None yet._ BannerManor is end-user-facing; consumers will be:

- agnoshi MOTD / login banner
- [`iam`](https://github.com/MacCracken/iam) — logo rendering on
  fastfetch-style output (if used)
- User script intros

## Next

M3 is done; v0.3.0 is ready to tag. M4 is next — layout flags
(`--align`, `--width`, `--pad`). See [`roadmap.md`](roadmap.md) for
the full sequence.
