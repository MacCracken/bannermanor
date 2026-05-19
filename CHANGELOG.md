# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] — 2026-05-19

First post-scaffold release. Bundles milestones M1 (first render path)
and M2 (CYML font format) into one tag.

### Added — M2 (CYML font format)
- `docs/adr/0001-cyml-font-format.md` — schema decision: multi-entry
  CYML with `[font]` file header and per-glyph entries; `.` for
  background, `#` for stroke (avoids `lib/cyml.cyr` body trimming);
  rationale against `.flf` as canonical.
- `fonts/block.cyml` — first canonical CYML font, extracted from the
  embedded block font; same 37 glyphs (space, 0–9, A–Z).
- `src/font.cyr` — `Font` struct (width / height / gap / count /
  rows / charmap) + `font_load_file()` CYML loader. Validates file
  size (≤ 64 KB), schema (= 1), geometry bounds, body shape (height
  rows × width bytes, `.`/`#` only), and rejects duplicate `char`
  entries.
- `src/render.cyr` — renamed `render_block()` → `render(font, ...)`;
  same code path now serves both embedded and on-disk fonts.
- `src/main.cyr` — `--font NAME` resolves to `fonts/NAME.cyml` (path
  separator / `..` / control char rejected at the name level). Default
  (no flag) uses `block_font_embed()` so `bnrmr "hello"` still works
  with zero config.
- `tests/bannermanor.tcyr` — M2 coverage: loader happy path, missing
  file → 0, malformed fixtures (bad schema, bad body byte, wrong row
  count) → 0, and the M2 acceptance check: every char's glyph index
  and every glyph's rows are byte-identical between embedded and
  `fonts/block.cyml`. 1334 assertions.
- `tests/fixtures/{bad_schema,bad_body_byte,wrong_row_count}.cyml`
  — malformed-font fixtures.
- `cyml` and `result` added to `[deps].stdlib` in `cyrius.cyml`.

### Changed — M2
- `src/font_block.cyr` is now a `block_font_embed()` builder that
  returns a `Font*` instead of providing `block_glyph_index` /
  `block_row` directly. Embedded and on-disk fonts share one
  `Font*`-typed code path through the renderer.

### Added — M1 (first render path)
- `src/render.cyr` — first render pipeline: composes glyph rows into
  a banner on stdout, with a 1 KB input length cap.
- `src/font_block.cyr` — hardcoded 5×5 "block" font covering space,
  `0`–`9`, `A`–`Z`. Lowercase ASCII folds to uppercase; unsupported
  characters render as the space glyph (no error).
- `src/main.cyr` — argv concatenation + length-cap enforcement +
  render dispatch. Flags: `--version`, `--help`. With no args, prints
  usage.
- `tests/bannermanor.tcyr` — coverage for glyph index lookup, row
  shape invariant, renderer bounds.
- `args` added to `[deps].stdlib` in `cyrius.cyml`.

## [0.1.0]

### Added
- Initial project scaffold
