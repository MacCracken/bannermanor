# Getting started with BannerManor

The binary is `bnrmr` (vowel-dropped per the `commandress` → `cmdrs`
compression pattern).

## Build

```sh
cyrius deps                              # resolve stdlib
cyrius build src/main.cyr build/bnrmr    # compile (binary: bnrmr)
./build/bnrmr                             # prints scaffold version line
cyrius test                               # run tests/*.tcyr
```

## Layout

- `src/main.cyr` — entry point (currently scaffold only; M1+ fills CLI dispatch + render)
- `tests/bannermanor.{tcyr,bcyr,fcyr}` — tests / benchmarks / fuzz

Once M1+ ships, additional layout:

- `src/render.cyr` — character-grid composition
- `src/font.cyr` — CYML font parser
- `src/layout.cyr` — alignment / width / padding
- `src/color.cyr` — darshana ANSI routing
- `fonts/<name>.cyml` — opinionated default fonts shipped in-tree

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
5. CHANGELOG entry under `Added`.

## Adding a flag

1. Edit `src/main.cyr` CLI dispatch.
2. Add tests for every value the flag accepts + a malformed-value case.
3. Document in `docs/guides/cli.md`.
4. CHANGELOG entry. Mark `Breaking` if it alters exit codes or
   output bytes for an existing invocation.

See [`../adr/template.md`](../adr/template.md) when a non-trivial
design choice deserves an ADR.
