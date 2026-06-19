# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.2] — 2026-06-19 (toolchain + dep refresh — cyrius 6.2.24, cyml → bayan)

### Changed

- **cyrius toolchain pin 6.1.14 → 6.2.24.** Re-synced the vendored stdlib snapshot into `lib/` with `cyrius lib sync`. The 6.2.x stdlib reorg dropped several modules from the core snapshot (`base64`, `bigint`, `csv`, `json`, `linalg`, `matrix`, `toml`, `u128`, and `cyml`); the stale copies were pruned from `lib/`.
- **CYML parser moved out of the core stdlib into `bayan`.** `cyml.cyr` no longer ships in the cyrius snapshot as of 6.2.x — the `cyml_parse` / `cyml_doc_*` / `cyml_entry_*` surface bannermanor's font loader depends on now lives in `bayan`. Updated `[deps].stdlib` (`cyml` → `bayan`) and `src/font.cyr`'s `include "lib/cyml.cyr"` → `include "lib/bayan.cyr"`. The consumed symbols are unchanged, so the font loader is byte-stable.
- **`cyrius.cyml [deps.darshana]`** — pin bumped `0.5.3` → `0.7.1` to track the latest release. The `tty_sgr` / `tty_sgr_reset` / `TTY_FG_*` symbols bannermanor consumes remain present and byte-stable.
- **`src/main.cyr`** — `--version` literal bumped to `bnrmr 1.1.2`.

### Notes

- **No API or behavior changes.** Build clean, full suite green (2762 tests). The CYML font-load path (now via `bayan`) and the `--color` darshana path were smoke-checked.

## [1.1.1] — 2026-06-08 (agnos argv fix)

### Changed

- cyrius toolchain pin 6.0.56 → 6.1.14.

### Fixed

- **agnos: `bnrmr TEXT` printed help instead of rendering.** `argc()`/`argv()` returned 0/null because the `var r = main();` entry idiom runs `main` as a module-global initializer — *before* cyrius's init-stack capture — so the command-line args were never seen. `main` is now called from a bare top-level statement (`_agnos_entry();`), which runs after the capture, so native `argc`/`argv` resolve and `bnrmr agnos` renders. Root cause + reproducer filed as a cyrius issue (agnos argv init-rsp capture).

## [1.1.0] — 2026-06-06 (AGNOS as a build target — builds + renders on both Linux and agnos)

### Added

- **AGNOS platform support** (VERSION → 1.1.0; cyrius pin 6.0.1 → 6.0.56). `bnrmr` now builds under `cyrius build --agnos` and renders ASCII banners on AGNOS (MOTD / splash text in the agnsh environment, output via the agnos `write` syscall). The only Linux-ism was terminal-size detection (`ioctl`/`TIOCGWINSZ`), gated inline with `#ifdef CYRIUS_TARGET_AGNOS` in `src/layout.cyr`:
  - `term_width_ioctl` → returns 0 on agnos so callers fall back to the default banner width;
  - `stdout_is_tty` → returns 0 (non-TTY) on agnos, keeping auto-color off (the fb console renders glyphs literally and doesn't interpret ANSI).
  - **The real fb-console-size query (`ioctl`/`TIOCGWINSZ` equivalent) is deferred to the 1.43.x graphics work** — terminal geometry is a console/graphics concern, so it lands with that arc (alongside the GPU surface). Until then, the default width is correct for banners.
- Inline gating, no shared platform-abstraction layer (extract later only if needed). The Linux path is unchanged (verified: Linux build OK + renders correctly).

### Validated

- `cyrius build --agnos src/main.cyr` → **OK** (`bnrmr_agnos`, 169 KB; darshana color dep builds for agnos too). Linux build + render unaffected (`./bnrmr AGNOS` renders the banner).

## [1.0.1] — 2026-05-23 (darshana pin bump — ecosystem alignment)

### Changed

- **`cyrius.cyml [deps.darshana]`** — pin moved from `0.3.5` → `0.5.3` so every AGNOS consumer of darshana is on the same release. Triggered by agora's M2-B work landing the same alignment for the telnet-MOTD coloring path; consolidating the ecosystem on one darshana version means a single audit surface when darshana 1.0 freezes.
- **`src/main.cyr`** — `--version` literal bumped to `bnrmr 1.0.1`.

### Notes

- **No API or behavior changes.** The `tty_sgr` / `tty_sgr_reset` / `TTY_FG_*` symbols bannermanor consumes are byte-stable from darshana 0.3.5 through 0.5.3 — the 0.5.x additions are the `_buf` family (e.g. `tty_sgr_buf` for buffer-targeted SGR emission), which bannermanor doesn't use yet. Adopting the `_buf` variants for single-write piped-output rendering is a future bite, not blocking.
- v1.0 frozen surface (CLI flags, CYML font schema, default font set) unchanged. The "freeze is the contract change" framing from [1.0.0] still holds.

## [1.0.0] — 2026-05-20

**v1.0**. The CLI flag surface, the CYML font format, and the default
in-tree font set are frozen — no signature changes from 0.9.0 to 1.0.0
in any of the three. The freeze itself is the contract change.

What the freeze locks:

- **CLI flags**: `--font` (`-f`), `--width` (`-w`), `--align`, `--pad`,
  `--color`, `--list-fonts`, `--help` (`-h`), `--version`. No flags
  added, no flags removed, no exit-code or stdout-byte changes for
  any valid invocation. New flags after 1.0.0 are an SCHEMA-MAJOR
  question, not a minor.
- **CYML font format**: schema = 1 (see `docs/adr/0001-cyml-font-format.md`).
  Body convention (`.` background, `#` stroke), `[font]` header
  fields, per-glyph entries — frozen. Schema 2 is the next-major
  question.
- **Default font set**: `block`, `slim`, `big`. Frozen as the in-tree
  trio. Additional fonts can ship in 1.x without breaking the
  contract (presence is additive, never subtractive).
- **`.flf` adapter contract**: read-only, uniform-width fit, no
  smushing, ASCII 32..126, 1 MB cap, C0/C1/DEL scrub. Bug fixes (like
  0.9.0's CRLF handling) are non-breaking; the documented limitations
  in CHANGELOG 0.6.0 are intentional and stay.

Issue 0002's `--pad` / `--width` caps land here as the freeze's one
documented `Breaking`. Issue 0001 (keystroke interleave) stays
deferred — the cost/risk analysis in its filing is unchanged.

### Breaking
- **`--pad N` capped at 64**; values 65..PARSER_INT_CAP are rejected
  with `bnrmr: --pad max 64` and exit 1. Pre-1.0 these were accepted
  and produced unbounded blank lines around the banner.
- **`--width N` capped at 4096**; values 4097..PARSER_INT_CAP are
  rejected with `bnrmr: --width max 4096` and exit 1. Pre-1.0 these
  were accepted and produced unbounded line lengths. The cap matches
  `WS_COL_CAP` (the 0.8.0 F-008 terminal-cols clamp) by design —
  a `--width` larger than the largest column count any terminal will
  ever report is by definition unreasonable. Issue 0002 documents
  the rationale; this closes it.

### Fixed
- **Banner wraps into itself on narrow terminals (issue 0004).**
  `render_layout` previously only called `fit_chars` when `--width N`
  was set explicitly. With the default (`--width 0`), the banner was
  emitted at full width regardless of terminal size; the terminal's
  soft-wrap broke row alignment when the banner was wider than the
  TTY (caught dogfooding `bnrmr --font modular.flf "BANNERMANOR 1.0"`
  on a 129-col terminal: 15 glyphs × ~9 cols ≈ 135 cols, ~6 cols
  over). The renderer now resolves an effective truncation width
  from `term_width_ioctl()` when `--width` is unset; whole-glyph
  truncation rules are identical to `--width N`. **Piped output is
  byte-identical to pre-1.0**: `term_width_ioctl()` returns 0 when
  stdout isn't a TTY, `fit_chars(0, ...)` returns `len` unchanged, so
  `bnrmr ... | cat` still emits the full untruncated banner — the M1
  byte-identity contract is preserved. The
  `t_layout_render_layout_default_matches_render` test (which runs
  non-TTY) still passes for this reason. Found and fixed in 1.0.0.

### Added
- `src/layout.cyr` — `WIDTH_CAP = 4096` and `PAD_CAP = 64` in
  `LayoutLimits`. Kept as separate constants from `WS_COL_CAP`
  because the *reason* differs (CLI input rejection vs. ioctl
  output clamping), even though the numeric value happens to match.

### Changed
- `src/main.cyr` — `--width` and `--pad` validation grows an
  upper-bound check immediately after the existing
  non-negative check. Error message style matches the existing
  negative-rejection messages (`bnrmr: <flag> max N`, exit 1).
- `VERSION` and the `--version` string bumped to `1.0.0`.

### Closed (out of M7 / M8)
- Issue 0002 (`--pad` / `--width` unbounded) — fixed in this release.
- Issue 0001 (keystroke interleave) — formally deferred past 1.0.0.
  Documented in the issue file; revisit in a future minor if the
  cost/benefit shifts.
- Issue 0003 (CRLF `.flf` endmark bleed) — fixed in 0.9.0.

## [0.9.0] — 2026-05-20

Closes **M7**. Fixes the one real bug surfaced by the maintainer-MOTD
dogfood cycle (issue 0003 — CRLF-line `.flf` fonts bleed endmark bytes
into glyph rows), and captures the **third and final benchmark trend
point** so the v1.0 "3-point benchmark trend" criterion is satisfied.

Issue 0001 (keystroke interleave during render) was already deferred
past v1.0 in 0.7.0; issue 0002 (unbounded `--pad` / `--width`) stays
deferred to the M8 freeze pass where the cap becomes a documented
`Breaking` change. No remaining open M7 work; M8 is next and cuts v1.0.

### Fixed
- **Issue 0003 — CRLF-line `.flf` fonts bleed endmark bytes.** `src/flf.cyr`
  previously read the byte immediately preceding `\n` as the endmark
  character. For CRLF-terminated `.flf` files (common from Windows
  authoring tools like JavE — `modular.flf` in the repo top level was
  the dogfood reproducer), that byte was `\r`, so the real endmark
  (`#`, `@`, `$`, …) was left embedded in glyph row data — visible at
  render time as a literal column of endmark characters down the
  right edge of every glyph. The loader now trims a trailing `\r`
  from each line before endmark detection and the strip-trailing-
  endmark loop. Pure-LF `.flf` files are unaffected (the trim is a
  no-op when the trailing byte is not `\r`). `cursor` still advances
  past the original `\n` position so file traversal is unchanged.

### Added
- `tests/fixtures/flf_crlf.flf` — `tests/fixtures/tiny.flf` byte-for-byte
  with every `\n` re-encoded as `\r\n`. Reproduces the issue 0003
  vector in a 493-byte fixture.
- `tests/bannermanor.tcyr` — `t_flf_crlf_endmarks_stripped`: asserts
  the CRLF fixture loads, glyph rows do not contain the `@` endmark,
  and the CRLF and LF fixtures produce byte-identical glyph row 0
  across all 95 glyphs. 2762 assertions (up from 2754).
- `docs/benchmarks.md` — point 3 captured (block_font_embed 7 ns,
  font_load_file 58 µs, fit_chars ×100 = 572 ns). Flat against 0.8.0;
  the CRLF trim is in `.flf` parsing which the benchmark set doesn't
  exercise. M7's 3-point trend item is closed.

### Changed
- `VERSION` and the `--version` string bumped to `0.9.0`.

## [0.8.0] — 2026-05-20

Closes the **v1.0 defense-in-depth items** from the 0.7.0 audit. Both
were tagged "future work" in `docs/audit/2026-05-20-audit.md`; both
are now belt-and-suspenders against future regressions even though
the audit confirmed neither was reachable as a bug in 0.7.0.

Also captures **benchmark trend point 2 of 3** against the new
parsers and clamps. M7's MOTD dogfood is in-flight on archaemenid;
one cosmetic issue surfaced (0001, keystroke interleave) and was
deferred past v1.0; one observed-but-deferred issue (0002, unbounded
`--pad` / `--width`) was filed for the M8 freeze pass.

### Added
- `docs/development/issues/archive/0002-unbounded-pad-and-width.md` — filed
  from the pre-release ad-hoc stress sweep. `--pad 100000` produces
  200 005 newlines, `--width 1000000` produces a 500 KB line.
  No security impact (user-controlled); flagged for M8 freeze.
- `docs/benchmarks.md` — point 2 captured (block_font_embed 6 ns,
  font_load_file 58 µs, fit_chars 5.72 ns). No regression vs 0.7.0;
  deltas all within bench-frame noise floor.

### Changed
- **F-002 (defense in depth) — parser overflow caps.** `parse_uint`
  (`src/layout.cyr`), `_font_get_int` (`src/font.cyr`), and
  `_flf_take_int` (`src/flf.cyr`) now reject any value that exceeds
  the shared `PARSER_INT_CAP` (1 048 576) during accumulation,
  rather than risk silent i64 wrap. Downstream bounds were already
  tighter (`width ≤ 64`, `height ≤ 32`, etc.) — this guard is for
  a future relaxation that might widen those caps.
- **F-008 (defense in depth) — `ws_col` clamp.** `term_width_ioctl`
  (`src/layout.cyr`) clamps the TIOCGWINSZ-reported column count at
  `WS_COL_CAP` (4096). No current bnrmr code path sizes an
  allocation from cols, but a `resize -s 65535 65535` attack
  documented in the audit's external survey is now structurally
  defeated.

## [0.7.0] — 2026-05-20

Closes the **M7 security audit pass**. One concrete vulnerability
(F-001: `.flf` glyph rows could smuggle ANSI control bytes through to
stdout, CWE-150) is fixed in this release. The remainder of the audit
documents positive observations and defense-in-depth recommendations
for v1.0. See [`docs/audit/2026-05-20-audit.md`](docs/audit/2026-05-20-audit.md)
for the full report.

M7 is not closed by this release — the maintainer-MOTD dogfood cycle
and the 3-point benchmark trend (`docs/benchmarks.md`) remain.

### Security
- **F-001 (HIGH) — `.flf` glyph row control-byte injection.** The
  `.flf` loader (`src/flf.cyr`) previously copied glyph row bytes
  verbatim after hardblank→space substitution. A malicious `.flf`
  could embed an ESC (`0x1B`) or other C0/C1 control byte inside a
  glyph; `bnrmr --font evil.flf "X"` would emit real ANSI to the
  user's terminal — the same vector documented in the OpenAI Codex
  CLI RCE (CVE-2026-…) and the `gh run view --log` advisory. The
  per-byte copy now scrubs `0x00–0x1F`, `0x7F`, and `0x80–0x9F` to
  space after the hardblank substitution. CYML body bytes were
  already restricted to `'.'` and `'#'` and were never exposed.

### Added
- `docs/audit/2026-05-20-audit.md` — full 0.7.0 audit report:
  10 findings (1 HIGH/fixed, 3 LOW/accepted, 6 informational), threat
  model, external CVE survey, future-work tracking for v1.0
  defense-in-depth.
- `tests/fixtures/flf_esc_glyph.flf` — synthetic 1-row `.flf` whose
  space glyph carries a literal ESC byte; consumed by the new
  regression test.
- `tests/bannermanor.tcyr` — `t_flf_strips_control_bytes` (loaded ESC
  row reads back as space; non-control bytes preserved). 2754
  assertions (up from 2751).

### Changed
- `src/flf.cyr` — per-byte glyph copy now applies the control-byte
  scrub described under Security.

## [0.6.0] — 2026-05-20

Closes M6 — legacy `.flf` read adapter. Users with existing figlet
font libraries can now `bnrmr --font path/to/standard.flf "hello"`
and get a banner; CYML stays canonical.

### Added — M6 (legacy .flf read path)
- `bnrmr --font NAME.flf` — when the `--font` value ends in `.flf`,
  the value is taken as a literal filesystem path and dispatched to
  the new `flf_load_file` adapter. Other values continue through the
  CYML loader (`fonts/NAME.cyml`) with the existing path-segment
  sanitization untouched.
- `src/flf.cyr` — new module. `flf_load_file(path)` validates the
  `flf2a$` magic line, parses the 6 standard header ints
  (height / baseline / max-length / old-layout / comment-count), skips
  comment lines, decodes 95 glyph blocks (ASCII 32..126) with
  per-glyph endmark detection and hardblank → space substitution,
  then assembles a uniform-width `Font*` (gap=0, width = observed
  max across all glyphs). Same `Font*` shape as the CYML loader, so
  the renderer is unchanged.
- `tests/fixtures/tiny.flf` — synthetic 95-glyph fixture; exercises
  header parse, comment-skip with CL=0, endmark strip, hardblank
  substitution, geometry registration.
- `tests/fixtures/flf_bad_magic.flf` / `flf_bad_height.flf` /
  `flf_truncated.flf` — malformed fixtures consumed by the loader
  rejection tests.
- `tests/bannermanor.tcyr` — `t_load_tiny_flf` (geometry, charmap,
  hardblank assertions), `t_load_flf_missing`, and
  `t_load_flf_malformed` (three malformed fixtures → 0). 2751
  assertions (up from 2641).

### Notes — M6 (known limitations, intentional for v0.6)
- **Uniform-width fit.** Every glyph row is right-padded with spaces
  to the font's observed max width; gap = 0. Narrow glyphs (e.g.
  `.` `!` `,`) carry trailing whitespace, so output diverges from
  `figlet -W` for fonts with significant width variance. Variable
  per-glyph widths would require extending the Font* model and the
  renderer's per-row byte emission loop — pushed beyond v0.6.
- **No smushing or kerning.** The header's old-layout / full-layout
  fields are parsed and discarded; hardblanks render as spaces, which
  matches figlet's no-smushing mode. Smushing rules are out of scope
  for v1.0.
- **ASCII 32..126 only.** The 7 trailing "German" required chars
  (196 / 214 / 220 / 228 / 246 / 252 / 223) and any code-tagged
  glyphs after the standard block are *skipped*, not failed on. v1.0
  is ASCII-only per `roadmap.md` "Out of scope".
- **1 MB file cap.** Bounded read; oversized files are rejected.

### Changed — M6
- `src/main.cyr` — `--font` dispatch grows a `.flf` branch (delegates
  to `flf_load_file`); CYML branch unchanged. `print_usage` gains
  one line documenting the `.flf` form. Header comment block
  refreshed to list M5 + M6.
- `VERSION` and the `--version` string bumped to `0.6.0`.

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
