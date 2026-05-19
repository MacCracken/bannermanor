# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `src/render.cyr` — first render pipeline: composes glyph row-strings
  into a banner on stdout, with a 1 KB input length cap (M1 contract).
- `src/font_block.cyr` — hardcoded 5×5 "block" font covering space,
  `0`–`9`, `A`–`Z`. Lowercase ASCII folds to uppercase; unsupported
  characters render as the space glyph (no error). Designed for
  trivial extraction into `fonts/block.cyml` at M2.
- `src/main.cyr` — argv concatenation + length-cap enforcement +
  render dispatch. New flags: `--version`, `--help`. With no args,
  prints usage.
- `tests/bannermanor.tcyr` — coverage for `block_glyph_index`
  (space, digits, uppercase, lowercase-folds-to-upper, unsupported),
  row-shape invariant for every glyph, and renderer bounds-check
  (negative len, over-cap, way-over-cap). 260 assertions.
- `args` added to `[deps].stdlib` in `cyrius.cyml`.

## [0.1.0]

### Added
- Initial project scaffold
