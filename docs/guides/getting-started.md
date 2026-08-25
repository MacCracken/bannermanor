# Getting started with BannerManor

The binary is `bnrmr` (vowel-dropped per the `commandress` → `cmdrs`
compression pattern). The user-facing usage is in
[`../../README.md`](../../README.md) — this guide is the codebase
orientation for someone who's about to read or change the source.

## Build

```sh
cyrius deps                              # resolve stdlib + darshana
cyrius build src/main.cyr build/bnrmr    # compile (binary: bnrmr)
./build/bnrmr "AGNOS"                    # smoke render
cyrius test                              # 2775 assertions
cyrius bench tests/bannermanor.bcyr      # render hot-path CPU bench
```

Toolchain pin: `cyrius = "6.5.35"` in `cyrius.cyml`.

## Source layout

- `src/main.cyr` — entry point. CLI parsing via `lib/flags.cyr`,
  flag dispatch, `--list-fonts` / `--version` / `--help`, input
  length cap.
- `src/render.cyr` — `render(font, text, len)` shim that preserves the
  M1 byte-identity contract; delegates to `render_layout` with
  neutral options.
- `src/layout.cyr` — layout orchestrator. Frame resolution, alignment,
  padding, color emission, TTY-aware default truncation. Pure helpers
  for `fit_chars` / `banner_width` / `align_pad` / `parse_uint`.
- `src/font.cyr` — `Font` struct + CYML loader. Validates schema,
  geometry, body shape. Also exposes the header-only loader used by
  `--list-fonts`.
- `src/flf.cyr` — legacy figlet `.flf` read adapter. Read-only; same
  `Font*` shape as the CYML loader.
- `src/font_block.cyr` — embedded `block` font. Default when no
  `--font` is passed.
- `src/color.cyr` — `--color` plumbing. SGR primitives sourced from
  darshana; no inline ANSI.
- `fonts/<name>.cyml` — in-tree default fonts (block / slim / big).
- `tests/bannermanor.{tcyr,bcyr,fcyr}` — tests / benchmarks / fuzz stub.

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
