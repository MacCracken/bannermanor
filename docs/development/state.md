# BannerManor — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.8.0** — tagged 2026-05-20. Closes the v1.0 defense-in-depth
items from the 0.7.0 audit: F-002 parser overflow caps (shared
`PARSER_INT_CAP = 1 048 576` rejects mid-accumulation overflow in
`parse_uint`, `_font_get_int`, `_flf_take_int`) and F-008 `ws_col`
clamp at 4096 in `term_width_ioctl`. Neither was reachable as a bug
in 0.7.0; both are belt-and-suspenders for future relaxations.
Benchmark point 2 of 3 captured against the new code path — no
regression. Ad-hoc stress sweep (50+ edge-case invocations)
surfaced [`issue 0002`](issues/0002-unbounded-pad-and-width.md):
huge `--pad` / `--width` produce unbounded output; deferred to the
M8 freeze pass for an opinionated cap.

**0.7.0** — tagged 2026-05-20. Closes the M7 security audit pass
(maintainer-MOTD dogfood + benchmark trend remain in M7). Fixes
F-001 — `.flf` glyph rows could smuggle ANSI control bytes (e.g.
ESC `0x1B`) through to stdout, the CWE-150 vector documented across
recent terminal CVEs and the OpenAI Codex CLI RCE. The per-byte
copy in `flf_load_file` now scrubs `0x00–0x1F`, `0x7F`, and
`0x80–0x9F` to space after the hardblank substitution. New synthetic
fixture `tests/fixtures/flf_esc_glyph.flf` + regression
`t_flf_strips_control_bytes`. Full report at
[`docs/audit/2026-05-20-audit.md`](../audit/2026-05-20-audit.md) — 10
findings (1 HIGH/fixed, 3 LOW/accepted, 6 informational), threat
model, external CVE survey covering figlet/.flf, ANSI escape
injection, CYML expansion, TIOCGWINSZ trust, and CLI argv→stdout
precedents.

**0.6.0** — tagged 2026-05-20. Closes M6 (legacy `.flf` read path).
Ships `src/flf.cyr` — a read-only adapter that loads figlet `.flf`
font files into the same `Font*` shape as the CYML loader. Activated
when `--font NAME` ends in `.flf`; the value is treated as a literal
path (the CYML branch's path-segment sanitization stays untouched).
1 MB file cap. Uniform-width fit (every glyph row padded with spaces
to the font's observed max width; `gap=0`). No smushing — hardblanks
render as spaces, matching figlet's no-smushing mode. ASCII 32–126
only; trailing German chars and code-tagged glyphs are skipped.
Synthetic test fixtures cover happy path + bad magic + bad height +
truncated.

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
  `--font` values ending in `.flf` route to the M6 legacy figlet
  adapter (`flf_load_file`); other names go through the CYML loader.
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
  0.8.0 audit hardening: `parse_uint` rejects values over
  `PARSER_INT_CAP` (F-002); `term_width_ioctl` clamps at
  `WS_COL_CAP = 4096` (F-008).
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
- `src/flf.cyr` — M6 legacy figlet font reader. `flf_load_file(path)`
  validates the `flf2a$` magic, parses height/baseline/maxlen/layout/
  comment-count from the header line, skips comment lines, decodes 95
  glyphs (ASCII 32..126) with per-glyph endmark detection and
  hardblank → space substitution, then assembles a uniform-width
  `Font*` (`gap=0`, width = observed max across all glyphs). 1 MB
  file cap. Activated by `--font` values that end in `.flf`. The
  per-byte copy scrubs C0/C1 control bytes + DEL to space (0.7.0
  audit fix F-001) so malicious `.flf` files cannot smuggle ANSI
  escapes through to the user's terminal.
- `src/font_block.cyr` — embedded "block" font. `block_font_embed()`
  builds a `Font*` from inline glyph data; this is the default used
  when no `--font` flag is passed (CLAUDE.md self-contained rule).
  Mirrors `fonts/block.cyml` byte-for-byte — drift checked in tests.
  Glyph data is split across `_block_raw_row_lo` (idx 0–36: space +
  0–9 + A–Z) and `_block_raw_row_hi` (idx 37–68: printable
  punctuation) to stay under cycc's 256-return-per-function limit.

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

- `tests/bannermanor.tcyr` — 2754 assertions covering: embedded font
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
  `render_layout` bounds), the M5 color path (`parse_color`
  across all 16 names + special values + unknowns, rainbow cycle,
  sentinel distinctness), and the M6 .flf adapter (`flf_load_file`
  happy path on `tiny.flf` — geometry, charmap, hardblank
  substitution — plus missing-file and three malformed-fixture
  rejections), and the 0.7.0 audit regression
  (`t_flf_strips_control_bytes` — ESC in a `.flf` glyph row loads as
  space, not 0x1B). Runs clean.
- `tests/fixtures/` — malformed-font fixtures consumed by the loader
  rejection tests (both CYML and .flf variants).
- `tests/bannermanor.bcyr` — render hot-path CPU benchmarks (B1
  `block_font_embed`, B2 `font_load_file(block.cyml)`, B3
  `fit_chars` ×100). Run via `cyrius bench tests/bannermanor.bcyr`.
  Trend lives in [`docs/benchmarks.md`](../benchmarks.md); point 1
  of 3 captured against 0.7.0.
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

M7 progress through 0.8.0:

- [x] Security audit pass (0.7.0)
- [x] Audit defense-in-depth follow-ups F-002 + F-008 (0.8.0)
- [in-flight] Maintainer-MOTD dogfooding (running 0.8.0). Issues
  filed: [`0001`](issues/0001-keystroke-interleave-during-render.md)
  (keystroke interleave, deferred past v1.0),
  [`0002`](issues/0002-unbounded-pad-and-width.md) (unbounded
  `--pad`/`--width`, deferred to M8 freeze).
- 3-point benchmark trend: points 1 + 2 captured; point 3 at 0.9.0.

M8 cuts v1.0.0 with the CLI flag surface frozen and the deferred
issues addressed. See [`roadmap.md`](roadmap.md) for sequence.
