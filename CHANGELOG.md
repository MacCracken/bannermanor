# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.5.0] — 2026-05-20

Closes M5 — color. `--color NAME` lands with the 16 ANSI named
foregrounds plus a `rainbow` per-row cycle. SGR primitives are
sourced from darshana 0.3.5 — no inline ANSI in bnrmr.

### Added — M5 (color via darshana)
- `bnrmr --color NAME` — colorize the banner. Accepts the 8 base ANSI
  colors (`black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`,
  `white`) and the 8 bright variants (`bright_red`, `bright-cyan`, …
  both underscore and dash forms accepted). Special value `rainbow`
  cycles a 6-color hue rotation per banner row.
- TTY auto-detection: SGR sequences are emitted only when stdout is
  attached to a TTY (probed via TIOCGWINSZ). Pipes / redirects
  receive plain bytes. Roadmap M5 acceptance: `bnrmr --color cyan
  "AGNOS"` renders colored on TTY, plain on `bnrmr ... | cat`.
- `src/color.cyr` — new module. `parse_color(name)` maps user strings
  to either an SGR code (30..37 / 90..97), `COLOR_NONE`, `COLOR_RAINBOW`,
  or `-3` (unknown — distinct from default). `rainbow_color_for_row(r)`
  returns the SGR code for row `r` modulo 6.
- `src/layout.cyr` — `stdout_is_tty()` helper. `render_layout` gained
  a 7th `color` param; per-row SGR-set/reset wrapping when color
  != `COLOR_NONE` and stdout is a TTY.
- `tests/bannermanor.tcyr` — coverage for `parse_color` (all 16 names
  in underscore + dash forms, special values, unknown names),
  `rainbow_color_for_row` (full 6-step cycle + wrap), and sentinel
  distinctness. 2641 assertions (up from 2608).

### Changed — M5
- `src/render.cyr` — `render()` shim passes `COLOR_NONE` through to
  `render_layout`'s new color parameter. Byte-identical behavior
  preserved.
- `cyrius.cyml` — `[deps.darshana]` resolves the sibling library.
  Currently pinned via `path = "../darshana"` for development; will
  flip to `git + tag = "0.3.5"` at release-cut time.
- `lib/darshana.cyr` — vendored from `darshana@0.3.5` via `cyrius
  deps`. Provides `tty_sgr`, `tty_sgr_reset`, and the 16
  `TTY_FG_*` SGR constants.
- `VERSION` and the `--version` string bumped to `0.5.0`.

## [0.4.0] — 2026-05-20

Closes M4 — layout flags. `--align`, `--width`, `--pad` land, CLI
parser migrated to `lib/flags.cyr` (getopt-long shape), terminal
width detection wired through ioctl + COLUMNS + 80-col fallback.

### Added — M4 (layout flags)
- `bnrmr --align V` — banner alignment within the frame. `V` is one
  of `left` (default), `center`, `right`. Short aliases `L`/`C`/`R`
  and `centre` are accepted. Frame width = `--width N` if given,
  else terminal width (TIOCGWINSZ on stdout), else `$COLUMNS`, else
  80 (documented fallback so `bnrmr --align center 'hi' | cat`
  still centers).
- `bnrmr --width N` (short: `-w N`) — truncate input at the glyph
  boundary so no banner row exceeds N columns. `--width 0` is the
  default and means unlimited. Truncation is always whole-glyph; a
  glyph is never half-rendered.
- `bnrmr --pad N` — N blank lines above and below the banner.
- `bnrmr -h` short alias for `--help`; `-f NAME` short alias for
  `--font NAME`.
- `src/layout.cyr` — new module. Exposes `term_width_ioctl()`,
  `term_width_env()`, `resolve_frame()`, `banner_width()`,
  `fit_chars()`, `align_pad()`, `parse_uint()`, and the
  `render_layout(font, text, len, width, align, pad)` orchestrator.
- `tests/bannermanor.tcyr` — coverage for layout math (`fit_chars`,
  `align_pad`, `banner_width`, `parse_uint`) and `render_layout`
  bounds. 2608 assertions (up from 2573).

### Changed — M4
- `src/main.cyr` — CLI arg parsing now goes through `lib/flags.cyr`
  (getopt-long-style: supports `--name value`, `--name=value`,
  short forms like `-f`, and `--` terminator). Replaces the previous
  hand-rolled `streq_lit` ladder. `--help` text rewritten to list
  the full M4 flag surface.
- `src/render.cyr` — `render(font, text, len)` is now a thin wrapper
  over `render_layout` with neutral options (`width=0`,
  `align=ALIGN_LEFT`, `pad=0`). Byte-for-byte identical to the
  pre-M4 output for callers that don't opt into layout flags
  (covered by the existing test suite).
- `cyrius.cyml` — `[deps].stdlib` adds `flags`.
- `VERSION` and the `--version` string bumped to `0.4.0`.

### Contract — M4
- If `--width N` is smaller than a single glyph (i.e. `N < font width`),
  bnrmr emits no banner. A clean "no output" is the documented
  behavior — preferred over partial-glyph rendering or silently
  overflowing the frame. Documented under `--width` in `--help`.

## [0.3.0] — 2026-05-20

Closes M3 — the default font set. Block expanded to full printable
ASCII; two new fonts (`slim`, `big`) shipped; `--list-fonts` and a
font-authoring guide land alongside. Toolchain pin caught up to
`cycc` 6.0.1.

### Added — M3
- `bnrmr --list-fonts` lists fonts in `./fonts`, alphabetically, with
  geometry (`WxH gap=N`) and description pulled from each font's `[font]`
  header. Malformed font files are surfaced as `(malformed — skipped)`
  rather than aborting the listing.
- `src/font.cyr` — `font_header_load(path)` lightweight loader. Parses
  only the `[font]` file header, validates schema + geometry, and
  returns a `FontHeader*` carrying width / height / gap / name /
  description. Skips glyph decode (cheaper than `font_load_file`).
- `src/font.cyr` — `_font_get_str()` TOML-style `key = "value"` parser
  used by the header loader. `_font_get_char()` now accepts `\"` and
  `\\` escapes so fonts can declare `char = "\""` and `char = "\\"`.
- `fonts/block.cyml` — 32 punctuation glyphs added: `! " # $ % & ' ( ) * + , - . / : ; < = > ? @ [ \ ] ^ _ \` { | } ~`.
  Glyph count goes from 37 to 69 (space + 0–9 + A–Z + printable
  punctuation). `bnrmr "Hello, World!"` now renders the punctuation
  inline instead of falling through to blank space glyphs.
- `fonts/slim.cyml` — second in-tree default font. 4×5, gap=1; one
  column narrower per glyph than block (~16% horizontal compression).
  Full printable ASCII coverage (69 glyphs), uppercase-only with
  fold-fallback for lowercase. Reachable via `bnrmr --font slim TEXT`
  and listed by `bnrmr --list-fonts`.
- `fonts/big.cyml` — third in-tree default font. 7×7, gap=1; chunky
  banner option, ~96% more cells per glyph than block. Full printable
  ASCII coverage (69 glyphs), uppercase-only with fold-fallback for
  lowercase. Closes the M3 default-font set at three (small / medium
  / large at distinct sizes).
- `src/font_block.cyr` — mirrors the new glyphs byte-for-byte; the
  M2 acceptance test now covers 69 glyphs × 5 rows. `_block_raw_row`
  was split into `_block_raw_row_lo` (idx 0–36) and `_block_raw_row_hi`
  (idx 37–68) to stay under cycc's 256-return-per-function limit.
- `docs/guides/fonts.md` — full font-authoring walkthrough (schema,
  body convention, validation gates, drop-in workflow, design tips).
- `tests/bannermanor.tcyr` — `font_header_load` happy path / missing
  file / bad-schema rejection; `t_glyph_punctuation` covering all 32
  new chars; `t_glyph_fold_is_fallback` pinning the fold-fallback
  semantics; `t_load_slim_cyml` and `t_load_big_cyml` each validating
  geometry and full printable-ASCII coverage on the new fonts. 2573
  assertions (up from 1334).

### Changed — M3
- `font_glyph_index` lowercase fold is now a **fallback**: a font that
  registers a lowercase glyph gets that glyph honored; only fonts
  with no lowercase entry (like `block.cyml`) fall through to the
  uppercase. Lets future taller fonts ship distinct lowercase without
  changing block's behavior.
- `cyrius.cyml` pin bumped from `6.0.0` to `6.0.1` — matches local
  cycc, silences toolchain-drift warning.
- `VERSION` and the `--version` string bumped to `0.3.0`.

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
