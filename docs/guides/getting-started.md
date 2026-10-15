# Getting started with BannerManor

The binary is `bnrmr` (vowel-dropped per the `commandress` → `cmdrs`
compression pattern). The user-facing usage is in
[`../../README.md`](../../README.md) — this guide is the codebase
orientation for someone who's about to read or change the source.

## Build

```sh
cyrius deps                              # resolve stdlib + darshana + bayan-cyml + cmdit
cyrius build src/main.cyr build/bnrmr    # compile (binary: bnrmr)
./build/bnrmr "AGNOS"                    # smoke render
cyrius test                              # 3268 assertions
sh scripts/golden.sh                     # 346 invocations, byte for byte
cyrius fuzz tests/bannermanor.fcyr       # font-parser regression gate
cyrius bench tests/bannermanor.bcyr      # render path, CPU and write side
sh scripts/install.sh "$HOME/.local"     # bin/, share/bannermanor/fonts/, man page
```

CI (`.github/workflows/ci.yml`) runs all of these, plus the doc pin check,
`cyrius deps --locked`, `cyrius lint --strict`, the AGNOS and aarch64
cross-builds and `cyrius coverage --min 100`. A change that moves a
rendered byte fails the golden suite's `frozen` tier. If the move is
intended (it should not be in 1.x, see ADR 0002), re-baseline with
`sh scripts/golden.sh --update` and review the diff.

Toolchain pin: `cyrius = "6.7.11"` in `cyrius.cyml`.

## Source layout

- `src/main.cyr` — `main()` only: read argv (`cmdit_argv`), parse,
  validate, resolve the font, call the renderer. Nothing can include it (its
  entry statement runs at include time), so logic goes in `src/cli.cyr`.
- `src/fontpath.cyr` — where `--font NAME` looks (1.6.0,
  [ADR 0003](../adr/0003-font-search-path.md)): `$BNRMR_FONTS`,
  `./fonts`, the install directory beside the executable, the built-in
  block. The rules are pure functions; `fontpath_setup` reads the
  environment and `/proc/self/exe`.
- `src/cli.cyr` — the testable rest of the CLI: the flag table
  (`cli_flags`, on [cmdit](https://github.com/MacCracken/cmdit) since
  1.4.2) and its error lines, `--font` name containment, the `--width` /
  `--pad` / `--align` parsers, joining the text under the 1 KB cap,
  `--help`, `--list-fonts`.
- `src/render.cyr` — `render(font, text, len)` shim that preserves the
  M1 byte-identity contract; delegates to `render_layout` with
  neutral options.
- `src/layout.cyr` — layout orchestrator and the write path. Frame
  resolution, alignment, padding, color emission, TTY-aware default
  truncation. Pure helpers for `fit_chars` / `banner_width` /
  `align_pad` / `parse_uint` / `_usable_cols`. The stdout width and TTY
  probes go through darshana's `tty_winsize`. Each banner row is composed
  in one buffer and written once through `_emit` (`lib/io.cyr`'s
  `file_write`), which checks the write and makes the exit 1 if stdout
  fails; diagnostics go to stderr through `_err_line`. `src/` uses no
  raw syscall numbers
  ([architecture note 001](../architecture/001-no-raw-syscall-numbers.md)).
- `src/font.cyr` — `Font` struct + CYML loader. Validates schema,
  geometry, body shape. Also exposes the header-only loader used by
  `--list-fonts`. `_slurp` is the one file read for every font reader;
  each loader is a read plus a parse (`_font_parse`,
  `_font_header_parse`), and the fuzz harness drives the parse halves
  directly.
- `src/flf.cyr` — legacy figlet `.flf` read adapter. Read-only; same
  `Font*` shape as the CYML loader (`flf_load_file` = `_slurp` +
  `_flf_parse`).
- `src/font_block.cyr` — embedded `block` font. Default when no
  `--font` is passed.
- `src/color.cyr` — `--color` plumbing. SGR primitives sourced from
  darshana; no inline ANSI.
- `fonts/<name>.cyml` — in-tree fonts (block / slim / big, and clean
  since 1.8.0).
- `tests/bannermanor.{tcyr,bcyr,fcyr}` — tests / benchmarks / fuzz
  harness. `tests/fixtures/` holds the malformed and boundary fonts
  they share.
- `tests/golden/` + `scripts/golden.sh` — the golden suite: case list,
  fixture CWDs, and the three committed record files (`frozen`, `error`,
  `snapshot`).

A deeper module-by-module description lives in
[`../development/state.md`](../development/state.md) under "Source".

## Adding a font

See [`fonts.md`](fonts.md) for the full authoring walkthrough
(schema fields, body convention, validation gates, drop-in workflow).
Short version:

1. Author `fonts/<name>.cyml` per the schema in
   [`../adr/0001-cyml-font-format.md`](../adr/0001-cyml-font-format.md).
2. Cover all printable ASCII (32–126); lowercase folds to uppercase
   when the font has no lowercase glyphs.
3. Verify with `bnrmr --list-fonts` and `bnrmr --font <name> "AGNOS"`.
4. Add a test case in `tests/bannermanor.tcyr`.
5. CHANGELOG entry under `Added`; bump the asset list in
   `docs/development/state.md`.

## ADRs

The v1.0 surface is frozen, but design questions that go beyond v1.0
(variable per-glyph `.flf` widths, Unicode, smushing rules, etc.)
should land as ADRs first. See [`../adr/template.md`](../adr/template.md).
What the freeze covers, exactly (error paths, failed writes, malformed
fonts), is [ADR 0002](../adr/0002-freeze-scope-error-paths-and-malformed-input.md).
