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

(Available at M2+.)

1. Author the font as `fonts/<name>.cyml` per the schema in
   `docs/adr/0001-cyml-font-format.md`.
2. Cover at least ASCII A–Z + 0–9 + space.
3. Add a test case rendering a sentence through the new font in
   `tests/bannermanor.tcyr`.
4. Add the font to `docs/guides/fonts.md` with a preview line.
5. CHANGELOG entry under `Added`.

## Adding a flag

1. Edit `src/main.cyr` CLI dispatch.
2. Add tests for every value the flag accepts + a malformed-value case.
3. Document in `docs/guides/cli.md`.
4. CHANGELOG entry. Mark `Breaking` if it alters exit codes or
   output bytes for an existing invocation.

See [`../adr/template.md`](../adr/template.md) when a non-trivial
design choice deserves an ADR.
