# BannerManor — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.3.0** — tagged 2026-05-20. Closes M3 (the default font set).
Ships `--list-fonts`, header-only loader, fold-fallback in
`font_glyph_index`, `block.cyml` expanded to full printable ASCII
(69 glyphs), `fonts/slim.cyml` (4×5), `fonts/big.cyml` (7×7),
`docs/guides/fonts.md`, pin bumped to 6.0.1. Default font set is
the initial three (block/slim/big) covering small / medium / large;
more fonts land post-v1.

**0.4.0** — tagged 2026-05-20. Closes M4 (layout flags). Ships
`--align L|C|R`, `--width N` (glyph-boundary truncation), `--pad N`,
plus short forms `-f` and `-w` and a CLI parser refactor to
`lib/flags.cyr` (handles `--name=value`, `--` terminator). Frame
width detection: `--width` → `TIOCGWINSZ` → `$COLUMNS` → 80. Render
path goes through `render_layout`; `render()` is preserved as a
thin neutral-options wrapper so the M1 byte-identity contract
holds. `--width N` smaller than one glyph renders nothing —
documented in `--help` and the layout-module comments.

**0.5.0** — tagged 2026-05-20. Closes M5 (color via darshana).
Ships `--color NAME` covering the 16 ANSI named foreground colors
+ `rainbow` (per-row 6-color cycle). SGR sequences route through
darshana 0.3.5's `tty_sgr` / `tty_sgr_reset` primitives — no inline
ANSI in bnrmr. Stdout TTY detection via TIOCGWINSZ: piped output
gets plain bytes, TTY output gets color. New `src/color.cyr`
module; `render_layout` gained a 7th `color` parameter.

**0.2.0** — tagged 2026-05-19. First post-scaffold release; bundles
M1 (first render path, hardcoded block font, 1 KB input cap, flags
`--version`/`--help`) and M2 (CYML font format, `fonts/block.cyml`,
`--font NAME` flag, loader with validation).

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`bnrmr` — vowel-dropped per `commandress` → `cmdrs`).
Single-shot CLI: text in, banner bytes out, exit.

## Source

- `src/main.cyr` — entry point. Builds a flag context via
  `lib/flags.cyr` and dispatches to the renderer. Flags:
  `--version`, `-h/--help`, `-f/--font NAME`, `--list-fonts`,
  `--align L|C|R`, `-w/--width N`, `--pad N`, `--color NAME`.
  Positional args concatenate (space-separated) into the 1 KB-capped
  render text.
- `src/render.cyr` — `render(font, text, len)` shim; delegates to
  `render_layout` (in `src/layout.cyr`) with neutral options
  (width=0, align=left, pad=0). Preserves the M1+M2 byte-identical
  output contract for callers that don't opt into layout flags.
- `src/layout.cyr` — M4 layout orchestrator. Detects terminal
  width via `TIOCGWINSZ` with COLUMNS env + 80-col fallback.
  Pure helpers: `banner_width`, `fit_chars`, `align_pad`,
  `parse_uint`, `stdout_is_tty` (M5). Public renderer:
  `render_layout(font, text, len, width, align, pad, color)`.
- `src/color.cyr` — M5 `--color` plumbing. `parse_color(name)` maps
  ANSI 16-color names + `rainbow` to SGR codes / sentinels;
  `rainbow_color_for_row(r)` returns the SGR code for row `r` in
  the 6-step rainbow cycle. All SGR emission goes through darshana
  (`tty_sgr` / `tty_sgr_reset`).
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

- `tests/bannermanor.tcyr` — 2641 assertions covering: embedded font
  geometry, glyph-index lookup (space / digits / uppercase /
  lowercase folding / punctuation / unsupported / fold-is-fallback),
  row-shape invariant, renderer bounds, CYML loader happy path +
  missing-file path + malformed fixtures (bad schema, bad body byte,
  wrong row count), the M2 acceptance check (loaded `fonts/block.cyml`
  is byte-identical to the embedded font on every char and every row,
  now over 69 glyphs), the slim and big font loads + full-printable-
  ASCII coverage checks, the M3 header loader (fields on
  `block.cyml`, missing-file, bad-schema rejection), the M4 layout
  math (`banner_width`, `fit_chars`, `align_pad`, `parse_uint`,
  `render_layout` bounds), and the M5 color path (`parse_color`
  across all 16 names + special values + unknowns, rainbow cycle,
  sentinel distinctness). Runs clean.
- `tests/fixtures/` — malformed-font fixtures consumed by the loader
  rejection tests.
- `tests/bannermanor.bcyr` — benchmark stub
- `tests/bannermanor.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert, bench,
  args, cyml, result, flags
- `darshana ≥ 0.3.5` — SGR primitives (`tty_sgr`, `tty_sgr_reset`,
  `TTY_FG_*` constants) for `--color`. Currently resolved via
  `path = "../darshana"` for development; flips to `git + tag`
  at release-cut time.

## Consumers

_None yet._ BannerManor is end-user-facing; consumers will be:

- agnoshi MOTD / login banner
- [`iam`](https://github.com/MacCracken/iam) — logo rendering on
  fastfetch-style output (if used)
- User script intros

## Next

M5 is done; v0.5.0 is ready to tag. M6 is next — legacy `.flf` read
adapter for users with existing figlet font libraries. See
[`roadmap.md`](roadmap.md) for the full sequence.
