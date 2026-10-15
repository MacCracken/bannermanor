# BannerManor — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.4.2** — 2026-10-15. **CLI parsing on cmdit.** The stdlib table parser (`lib/flags.cyr`) is replaced by [cmdit](https://github.com/MacCracken/cmdit) 1.4.0, pinned as a `[deps.cmdit]` git dependency. cmdit is the same getopt-long core as a distlib. The flag table moved into `src/cli.cyr` (`cli_flags`), so the suite parses synthetic argv with it, and the parse-error lines into `report_parse_error`. `cmdit_argv` replaced bnrmr's own `build_argv_array`. Before the swap the golden suite gained 33 parser-grammar cases (318 in all), and every record is byte-identical across it, on x86_64 and on aarch64 under qemu. cmdit's auto `-V` is dropped (the freeze adds no flags), and help, the `--version` literal and every value check stay bnrmr's. One diagnostic changed, under ADR 0002 ruling 1: a command line too long for the stdlib's 2 MiB `/proc` read now reports `argument parse error` (exit 1, as before) instead of whatever the truncated argv produced. Binary 244,184 → 292,008 bytes: the whole cmdit bundle links. Suite 3006 → 3061. See `CHANGELOG.md` [1.4.2].

**1.4.1** — 2026-10-15. **The contract checked in CI; one write per run; CYML-only bayan; a real fuzz gate.** The roadmap's planned 1.3.0, 1.3.1, 1.4.0 and 1.4.1 landed as one release (no 1.3.x or 1.4.0 was tagged). The golden matrix is committed and gated (`scripts/golden.sh`: 285 invocations in three tiers — frozen renders, error paths, snapshot help/version/listing — 112 of them on a pty), and its frozen tier is byte-identical to 1.2.0 on x86_64 and on aarch64 under qemu. CI gained `deps --locked`, strict lint, both cross-builds, a smoke step, the golden suite, the fuzz harness and a 100% reference-coverage floor. Pads, gaps and `--pad` lines are written in runs ([issue 0005](issues/archive/0005-write-per-cell-syscall-cost.md)): `--width 4096 --align right A` went from 20,465 `write(2)` calls to 15, and wide renders now cost the same as natural ones. Every stdout write goes through `lib/io.cyr`'s `file_write`. bayan's CYML-only sublib replaced the full bundle ([issue 0013](issues/archive/0013-full-bayan-bundle-linked.md)): 597,040 → 244,184 bytes. The three font readers share one `_slurp` and free their buffers ([issue 0014](issues/archive/0014-transient-read-buffers-never-freed.md)); dead named limits are wired in ([0012](issues/archive/0012-dead-geometry-constants.md)); `src/cli.cyr` made the CLI testable; the fuzz harness drives the real parsers ([0010](issues/archive/0010-fuzz-harness-is-a-no-op.md)). The only stdout change: `--help` lists `--`. ADR 0002 (what the freeze covers) was proposed and accepted, which unblocks roadmap 1.5.0. Suite 2828 → 3006. See `CHANGELOG.md` [1.4.1].

**1.2.0** — 2026-10-12. **Toolchain, darshana, and the stdout probes.** cyrius pin `6.6.2 → 6.7.9` (the 6.7 language minor) with `lib/` re-vendored from `[deps].stdlib` (`rm -rf lib/ && cyrius deps`: 109 files → 32 — the old tree was a full-snapshot `lib sync --full`; 79 modules nothing includes are gone, `alloc_cx` and `poison` are new) and `cyrius.lock` regenerated. No source change was needed for the language bump: no compile error and no warning on any target. darshana pin `1.0.0 → 1.3.0` (1.3.0 needs cyrius ≥ 6.7.2, which is why the toolchain moved first). `src/layout.cyr`'s two hand-rolled `TIOCGWINSZ` probes now ride darshana's `tty_winsize` ([issue 0019](issues/archive/0019-darshana-probes-hand-rolled.md)); the local `TIOCGWINSZ` re-declaration is gone. **AGNOS behavior change, deliberate**: the width probe now returns the framebuffer console grid instead of a hard 0 ([issue 0018](issues/archive/0018-agnos-console-width-never-queried.md)), so AGNOS banners truncate and align to the console — redirected stdout included, because agnos has no per-fd terminal query; `--color` stays off on AGNOS for that same reason. Linux output is byte-identical — a 224-invocation golden matrix (112 piped, 112 on a pty) on x86_64 and aarch64 — except the `--version` literal. Suite 2775 → 2828, the first tests of either probe. See `CHANGELOG.md` [1.2.0].

**1.1.5** — 2026-09-11. Toolchain-only: cyrius pin `6.5.35 → 6.6.2`, no source change. See `CHANGELOG.md` [1.1.5].

**1.1.4** — 2026-08-25. **P(-1) hardening pass.** Ten repairs, no change to any rendered banner byte — the golden suite (79 invocations across every font, alignment, color, `.flf` and error path) is byte-identical to 1.1.3 except the `--version` literal. Security: **F-011 (HIGH)** — `--list-fonts` printed a font's `name`/`description` straight to the terminal, so a font file could inject ANSI (screen clear, OSC title-set, OSC 8 hyperlink); this is the metadata half of the F-001 vector the 0.7.0 audit closed for `.flf` glyph rows only, and it needed no `--font` opt-in. **F-012 (MEDIUM)** — the malformed-font branch echoed the raw filesystem path, reachable via a filename. Both now scrub C0/DEL/C1 to space at the parser boundary. **F-013** — `$COLUMNS` was the only frame-width source without a ceiling (and the only one at all on AGNOS); now clamped at `WS_COL_CAP`. **F-015** — `--width`/`--pad` accepted i64 modular wraparound (`--pad 18446744073709551617` rendered with pad=1), defeating the caps issue 0002 froze at v1.0; both now parse through `parse_uint`'s F-002 guard. Compatibility: the `.flf` hardblank range widened from 33..126 to the FIGfont v2 rule (17 of 1052 reference fonts were rejected, including three shipped with figlet), and endmark detection now trims trailing whitespace as figlet's `readfontchar()` does (7 of 379 archive fonts stopped leaking literal `@` into rendered art). Hardening: font readers reject non-regular files, so a FIFO no longer blocks forever. **AGNOS**: every font load had died silently since 1.1.0 — the three readers used raw x86_64 syscall numbers for open/read/close, which are getpid/exit/spawn on AGNOS; all 12 sites now go through `lib/io.cyr` (`file_open` / `file_read` / `file_close`). Suite 2762 → 2775. Full report: [`docs/audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md). See `CHANGELOG.md` [1.1.4].

**1.1.3** — 2026-08-25. Toolchain + dep refresh. cyrius pin `6.2.24 → 6.5.35` (stdlib re-synced via `cyrius lib sync --full`; `lib/agnosys.cyr` retired upstream and pruned, four modules new to the snapshot: `async_macos`, `async_win`, `thread_macos`, `yantra`). darshana pin `0.7.1 → 1.0.0` — darshana's v1.0 API freeze, so the `tty_sgr` / `tty_sgr_reset` / `TTY_FG_*` surface bnrmr consumes is now contractually frozen. `bayan` folded forward `1.0.1 → 1.5.2`; all nine consumed `cyml_*` symbols keep their arity, and the CYML load path is byte-stable. `[deps].stdlib` gained `atomic`, `fs` and `fnptr` — a pre-existing declaration gap, not new. CI's hand-rolled toolchain install replaced with the tarball's `install.sh` (6.5.25 made the versioned layout mandatory). Render output byte-identical to 1.1.2 except the `--version` literal. See `CHANGELOG.md` [1.1.3].

**1.1.2** — 2026-06-19. Toolchain + dep refresh. cyrius pin `6.1.14 → 6.2.24` (stdlib re-synced via `cyrius lib sync`); the CYML parser moved out of the core stdlib into `bayan` (`cyml.cyr` no longer ships in the snapshot), so `[deps].stdlib` and `src/font.cyr`'s include flip `cyml → bayan`. darshana pin `0.5.3 → 0.7.1`. No API or behavior changes — consumed `cyml_*` and `tty_sgr*` symbols are byte-stable. See `CHANGELOG.md` [1.1.2].

**1.1.1** — 2026-06-08. agnos argv fix: `bnrmr TEXT` printed help instead of rendering, because the `var r = main();` entry idiom ran `main` as a module-global initializer — before cyrius's init-stack capture — so `argc()`/`argv()` returned 0/null. `main` is now called from a bare top-level statement. cyrius pin `6.0.56 → 6.1.14`. See `CHANGELOG.md` [1.1.1].

**1.1.0** — 2026-06-06. **AGNOS as a build target.** `bnrmr` builds under `cyrius build --agnos` and renders on AGNOS. The only Linux-ism was terminal-size detection, gated inline with `#ifdef CYRIUS_TARGET_AGNOS` in `src/layout.cyr`: `term_width_ioctl` returns 0 (callers fall back to the default width) and `stdout_is_tty` returns 0 (auto-color stays off — the fb console renders glyphs literally). cyrius pin `6.0.1 → 6.0.56`. See `CHANGELOG.md` [1.1.0].

**1.0.1** — 2026-05-23. Ecosystem-alignment patch: darshana pin `0.3.5 → 0.5.3` to match agora's M2-B consumption of the same surface. No API or behavior changes; the `tty_sgr` / `tty_sgr_reset` / `TTY_FG_*` symbols bannermanor uses are byte-stable across the 0.3 → 0.5 range. See `CHANGELOG.md` [1.0.1].

**1.0.0** — tagged 2026-05-20. **M8 — v1.0 freeze.** CLI flag
surface (`--font`/`-f`, `--width`/`-w`, `--align`, `--pad`,
`--color`, `--list-fonts`, `--help`/`-h`, `--version`), CYML font
format (schema 1), default font set (`block` / `slim` / `big`), and
the `.flf` adapter contract are all frozen at their 0.9.0 shape.
The freeze itself is the contract change — no signatures move.
Issue 0002's `--pad` / `--width` caps land as the freeze's one
documented `Breaking`: `--pad` rejects > 64 with
`bnrmr: --pad max 64` exit 1, `--width` rejects > 4096 with
`bnrmr: --width max 4096` exit 1. Pre-1.0 these were accepted and
produced unbounded output (issue 0002's filing). `WIDTH_CAP` /
`PAD_CAP` named in `src/layout.cyr`'s `LayoutLimits` enum. Final
M8 dogfood pass also surfaced and fixed
[`issue 0004`](issues/archive/0004-tty-wrap-on-narrow-terminal.md) —
without `--width`, the renderer skipped `fit_chars` entirely, so
banners wider than the TTY wrapped into themselves and broke row
alignment. `render_layout` now clamps the truncation width to
`term_width_ioctl()` when `--width` is unset; piped output stays
byte-identical (M1 contract preserved). Issue 0001 (keystroke
interleave) formally deferred past 1.0.0. All M7 + M8 acceptance
criteria met; v1.0 ships.

**0.9.0** — tagged 2026-05-20. Closes M7. Fixes
[`issue 0003`](issues/archive/0003-flf-crlf-endmarks-bleed.md) — CRLF-line
`.flf` fonts (common from Windows authoring tools; the
`modular.flf` JavE export in the repo top level was the dogfood
reproducer) were mistaking `\r` for the endmark, leaving the real
endmark bytes embedded as a phantom column in every glyph row.
`src/flf.cyr` now trims a trailing `\r` from each line before
endmark detection and the strip loop; pure-LF files unaffected.
Regression covered by `tests/fixtures/flf_crlf.flf` (493 bytes,
`tiny.flf` re-encoded with CRLF) and `t_flf_crlf_endmarks_stripped`
in the test suite. Benchmark trend's third point captured — flat
against 0.8.0 — closing the v1.0 "3-point benchmark trend" item.
M8 freeze is next; issues 0001 (deferred past v1.0) and 0002
(deferred to M8) remain on hold per their filings.

**0.8.0** — tagged 2026-05-20. Closes the v1.0 defense-in-depth
items from the 0.7.0 audit: F-002 parser overflow caps (shared
`PARSER_INT_CAP = 1 048 576` rejects mid-accumulation overflow in
`parse_uint`, `_font_get_int`, `_flf_take_int`) and F-008 `ws_col`
clamp at 4096 in `term_width_ioctl`. Neither was reachable as a bug
in 0.7.0; both are belt-and-suspenders for future relaxations.
Benchmark point 2 of 3 captured against the new code path — no
regression. Ad-hoc stress sweep (50+ edge-case invocations)
surfaced [`issue 0002`](issues/archive/0002-unbounded-pad-and-width.md):
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

**0.5.0** — tagged 2026-05-20. Closes M5 (color via darshana).
Ships `--color NAME` covering the 16 ANSI named foreground colors
+ `rainbow` (per-row 6-color cycle). SGR sequences route through
darshana 0.3.5's `tty_sgr` / `tty_sgr_reset` primitives — no inline
ANSI in bnrmr. Stdout TTY detection via TIOCGWINSZ: piped output
gets plain bytes, TTY output gets color. New `src/color.cyr`
module; `render_layout` gained a 7th `color` parameter.

**0.4.0** — tagged 2026-05-20. Closes M4 (layout flags). Ships
`--align L|C|R`, `--width N` (glyph-boundary truncation), `--pad N`,
plus short forms `-f` and `-w` and a CLI parser refactor to
`lib/flags.cyr` (handles `--name=value`, `--` terminator). Frame
width detection: `--width` → `TIOCGWINSZ` → `$COLUMNS` → 80. Render
path goes through `render_layout`; `render()` is preserved as a
thin neutral-options wrapper so the M1 byte-identity contract
holds. `--width N` smaller than one glyph renders nothing —
documented in `--help` and the layout-module comments. *(Corrected
later: it renders `height` blank rows, not nothing. `--help` was fixed
at 1.1.4 and the layout comment at 1.4.1. The behavior is frozen,
accepted risk A-05.)*

**0.3.0** — tagged 2026-05-20. Closes M3 (the default font set).
Ships `--list-fonts`, header-only loader, fold-fallback in
`font_glyph_index`, `block.cyml` expanded to full printable ASCII
(69 glyphs), `fonts/slim.cyml` (4×5), `fonts/big.cyml` (7×7),
`docs/guides/fonts.md`, pin bumped to 6.0.1. Default font set is
the initial three (block/slim/big) covering small / medium / large;
more fonts land post-v1.

**0.2.0** — tagged 2026-05-19. First post-scaffold release; bundles
M1 (first render path, hardcoded block font, 1 KB input cap, flags
`--version`/`--help`) and M2 (CYML font format, `fonts/block.cyml`,
`--font NAME` flag, loader with validation).

## Toolchain

- **Cyrius pin**: `6.7.9` (in `cyrius.cyml [package].cyrius`)

## Shape

Binary (`bnrmr` — vowel-dropped per `commandress` → `cmdrs`).
Single-shot CLI: text in, banner bytes out, exit.

## Source

- `src/main.cyr` — `main()` and the AGNOS-safe entry, nothing else.
  Reads argv (`cmdit_argv`), parses it with the table from
  `cli_flags()`, validates `--align` / `--width` / `--pad` / `--color`,
  resolves the font (embedded block; `fonts/NAME.cyml`; or a `.flf`
  path) and calls `render_layout`. The
  `--version` literal lives here (`scripts/doc-pin-check.sh` reads it).
  Entry is a bare top-level `_agnos_entry();`, not `var r = main();`
  (the 1.1.1 AGNOS argv fix), which is why no harness can include this
  file.
- `src/cli.cyr` — the rest of the command line, split out at 1.4.1 so
  the suite can test it: `cli_flags` (the cmdit flag table, 1.4.2: no
  `-V`, no value validation, which stays below), `report_parse_error`
  (the stdlib parser's error wording, kept byte for byte),
  `build_font_path` (the `--font NAME` →
  `fonts/NAME.cyml` containment: no `/`, `\`, `.` or control byte, 64
  bytes max), `_is_flf_path`, `parse_align`, `_parse_count_flag` (the
  `--width` / `--pad` parser and its exit-code sentinels),
  `join_positionals` (the 1 KB cap), `print_usage`, and `cmd_list_fonts`
  with its F-012 path scrub (`_write_scrubbed`).
- `src/render.cyr` — `render(font, text, len)`, the M1-contract shim:
  `render_layout` with neutral options.
- `src/layout.cyr` — layout and the write path.
  - **Frame**: `--width`, else the terminal width of fd 1 from
    darshana's `tty_winsize` (TIOCGWINSZ on Linux, the framebuffer
    console grid on AGNOS), else `$COLUMNS`, else 80. Every source caps
    at 4096 (`WIDTH_CAP` rejects, `WS_COL_CAP` clamps).
  - **Pure helpers**: `banner_width`, `fit_chars`, `align_pad`,
    `parse_uint` (F-002 cap), `_usable_cols`.
  - **`stdout_is_tty`**: `term_width_ioctl() > 0` on Linux, so a
    0-column terminal is not a TTY (F-020). Always 0 on AGNOS, because
    agnos cannot say whether fd 1 is the console; color stays off there.
  - **Writes**: every stdout byte bnrmr writes itself goes through
    `_emit` → `lib/io.cyr`'s `file_write`. Runs of spaces and newlines
    are written from per-process buffers in as few writes as possible
    (issue 0005), so a 4096-column row costs what a short one does.
    darshana's `tty_sgr` / `tty_sgr_reset` write the color around each
    row.
  - `render_layout(font, text, len, width, align, pad, color)` is the
    renderer.
- `src/color.cyr` — `parse_color` (16 names in `bright_X` and `bright-X`
  spellings, plus `rainbow`) and the rainbow cycle. All SGR goes through
  darshana; no inline ANSI.
- `src/font.cyr` — the `Font` / `FontHeader` structs and accessors, the
  schema-1 limits (`FontLimits`), and the readers:
  - `_slurp(path, cap, out_len)` is the one file read: `S_IFREG` gate,
    `lib/io.cyr` open / read / close, an `fl_alloc`'d buffer the caller
    frees.
  - `font_load_file` = `_slurp` + `_font_parse`; `font_header_load`
    (for `--list-fonts`) = `_slurp` + `_font_header_parse`. Both free the
    buffer after the parse.
  - The two loaders gate differently: the header loader never decodes
    entries and requires `name` (see `docs/guides/fonts.md`).
  - CYML parsing is bayan's CYML-only sublib (`lib/bayan-cyml.cyr`,
    `bayan_cyml_*`). No loader ever calls `bayan_cyml_expand_value`
    (ADR 0001, F-004).
  - Header strings are scrubbed of C0 / DEL / C1 at the parser boundary
    (F-011).
- `src/flf.cyr` — the `.flf` adapter: `flf_load_file` = `_slurp` (1 MB
  cap) + `_flf_parse`. Validates the `flf2a` magic, the FIGfont v2
  hardblank rule, height 1–32, up to 1024 comment lines, glyph rows up to
  64 columns after endmarks (`FlfLimits`, deliberately separate from
  schema 1's). Trims trailing whitespace before endmark detection
  (figlet's rule; covers CRLF, issue 0003). Hardblank → space, then
  C0 / DEL / C1 → space (F-001). Uniform-width `Font*`, `gap = 0`,
  ASCII 32–126.
- `src/font_block.cyr` — the embedded block font, the default when no
  `--font` is given. Mirrors `fonts/block.cyml` byte for byte; a test
  checks it. Split in two functions to stay under cycc's 256-return
  limit.

## Fonts

In-tree (`fonts/`), all schema 1, full printable ASCII (95 characters
as 69 glyphs: no lowercase, which folds to uppercase), author
BannerManor, GPL-3.0-only:

- `fonts/block.cyml` — 5×5, gap 1. The default, also embedded.
- `fonts/slim.cyml` — 4×5, gap 1. One column narrower than block.
- `fonts/big.cyml` — 7×7, gap 1. The chunky option.

Schema and loader contract: [ADR 0001](../adr/0001-cyml-font-format.md)
(amended 1.4.1). Authoring and both loaders' validation lists:
[`docs/guides/fonts.md`](../guides/fonts.md). The fourth font, the first
with lowercase, is on the roadmap.

## Tests

- `tests/bannermanor.tcyr` — **3061 assertions**, run on x86_64 and on
  aarch64 under qemu. In outline:
  - **Fonts**: embedded-font geometry, glyph lookup and the lowercase
    fold, and row shape. The three CYML fonts load, and `block.cyml`
    equals the embedded font byte for byte.
  - **CYML parser**: every schema-1 limit from both sides, the 64 KB
    gate (in memory and through a real file), the 128-entry ceiling, and
    zero / duplicate / non-ASCII entries. Both loaders' disagreements are
    pinned, and so is today's behavior on surplus rows (issue 0008).
  - **`.flf` adapter**: happy path, CRLF, the control-byte scrub, the
    hardblank rules, the envelope (64 / 65 columns, 32 / 33 rows,
    1024 / 1025 comments) and the 1 MB gate.
  - **Readers**: a directory, an empty file and a FIFO, each rejected
    without blocking.
  - **Layout math and color parsing.**
  - **The CLI** (`src/cli.cyr`): the cmdit flag table on synthetic argv
    (values, repeats, `--`, help over version, no `-V`, no prefix
    matching, bundling, the error codes), the parse-error wording, font
    paths, the count parser's sentinels, the 1 KB join, the F-012 scrub,
    `--help` naming every flag, `--list-fonts`.
  - **The probes and the TTY path**: fd 1 pointed at `/dev/null`, a pipe
    and a pty at seven window sizes, and a byte-exact render on a pty
    against a pipe, for color, rainbow, 0 columns and narrow-terminal
    truncation.
  - **Reference coverage**: 37/37 public functions
    (`cyrius coverage --min 100` in CI).
- `tests/golden/` + `scripts/golden.sh` — the frozen-output contract,
  byte for byte: 318 invocations (217 frozen renders, 76 error paths, 25
  snapshot), 112 on a pty through script(1). The `parse-*` cases (1.4.2)
  pin the flag grammar the cmdit swap had to keep. Since 1.4.1 this is a CI
  step; before that it existed only as shell history.
- `tests/bannermanor.fcyr` — the fuzz gate: 26 seeds × 1,000 mutants
  through all three parsers (78,003 parses), with scrub, geometry and
  charmap oracles and a guard page after every input. A no-op stub until
  1.4.1 (issue 0010).
- `tests/bannermanor.bcyr` — B0 `_calibration`, B1 `block_font_embed`,
  B2 `font_load_file`, B3 `fit_chars`, and the B4 write path (three
  `render_layout` rows, fd 1 on `/dev/null`). The trend is in
  [`docs/benchmarks.md`](../benchmarks.md), seven points from 0.7.0 to
  1.4.1. Point 4 records bayan 1.5.2's ~45% B2 regression (issue 0006,
  still open). Runs are recorded with `scripts/bench-history.sh` into
  `docs/benchmarks/history.csv`.
- `tests/fixtures/` — 24 fixtures, the malformed and boundary fonts the
  tests and the fuzz seeds share.

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, atomic, io, vec, str, syscalls, assert,
  bench, args, result, fs, fnptr, freelist, mmap. `freelist` and `mmap`
  arrived at 1.4.1 (`fl_alloc` / `fl_free` for the read buffers).
  `bayan` left the list at 1.4.1 and `flags` at 1.4.2, each replaced by a
  git dependency below.
- `darshana = 1.3.0` (pinned at 1.2.0) — SGR primitives (`tty_sgr`,
  `tty_sgr_reset`, `TTY_FG_*`) and `tty_winsize`, all inside darshana's
  frozen v1.0 surface. Requires cyrius ≥ 6.7.2.
- `[deps.bayan]`, tag 1.5.13, module `dist/bayan-cyml.cyr` — the
  CYML-only sublib: nine `bayan_cyml_*` functions. 1.5.13 is the bayan
  the cyrius 6.7.9 stdlib bundles, so the parser is byte-identical to
  what 1.2.0 linked.
- `[deps.cmdit]`, tag 1.4.0, module `dist/cmdit.cyr` — the CLI parser
  since 1.4.2, replacing the stdlib's `flags`. Same getopt-long core
  (error codes 0..4 are `flags.cyr`'s) plus the `cmdit_argv` bridge.
  bnrmr gives it no validation and uses neither its help nor its error
  printer. 1.4.0 pins cyrius 6.7.9, as bnrmr does. The whole bundle links
  (shell-completion generators included): the binary grew about 48 KB
  net when it replaced `flags`.
- `lib/` is the output of `cyrius deps` over the above: 34 files,
  regenerated from scratch at 1.4.1 and 1.4.2. `cyrius deps --locked` checks it in
  CI. Never edit `lib/` by hand: the toolchain restores it from the lock
  anyway (architecture note 002).

## Consumers

bnrmr is end-user-facing; nothing links it. Known uses of its output:

- **agora** embeds `bnrmr "AGORA"` art (block font, rendered at 1.0.0) in
  its MOTD, with the provenance in `src/main.cyr`. It consumes the bytes,
  not the crate.
- **anuenue** documents `bnrmr "AGNOS" | anuenue` as its rainbow-banner
  pipeline (README, `docs/guides/integrating-anuenue.md`).
- **agnos** stages `bnrmr` into the AGNOS rootfs at `/bin/bnrmr`
  (`scripts/burn/stage-tools.sh`), and **agnoshi** uses `bnrmr AGNOS` as
  its bareword-launch example. An installed `bnrmr` still finds no fonts
  outside a checkout (issue 0015), which is why roadmap 1.6.0 exists.
- Intended, not yet wired: [`iam`](https://github.com/MacCracken/iam)
  logo rendering, and user script intros.

## Next

[`roadmap.md`](roadmap.md) is the forward plan, and its issue register is
current. The next release, 1.5.0, is unblocked:
[ADR 0002](../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
was accepted on 2026-10-15. It covers diagnostics on stderr (issue 0016),
checked writes (0009), surplus-row rejection (0008) and the `.flf`
ceilings. Shipped milestones are in the roadmap's closed-record table and
in [`CHANGELOG.md`](../../CHANGELOG.md).
