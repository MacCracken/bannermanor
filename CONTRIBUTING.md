# Contributing to BannerManor

Contributions are welcome. All contributions must be licensed under
GPL-3.0-only.

## Development

Follow the conventions in [`CLAUDE.md`](CLAUDE.md) and the AGNOS
[first-party standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md).

Build and test before submitting:

```sh
cyrius deps
cyrius build src/main.cyr build/bnrmr
cyrius test
```

## Font additions

The full walkthrough lives in [`docs/guides/fonts.md`](docs/guides/fonts.md).
Short version — a new in-tree font needs:

1. `fonts/<name>.cyml` per the schema in
   [`docs/adr/0001-cyml-font-format.md`](docs/adr/0001-cyml-font-format.md).
2. Full printable-ASCII coverage (32–126; lowercase folds to
   uppercase if no lowercase glyphs are registered).
3. Attribution in the font header (`author`, `license` — GPL-3.0-only
   compatible).
4. A `t_load_<name>_cyml` test in `tests/bannermanor.tcyr` covering
   geometry, count, and at least one rendered glyph.
5. An entry in [`docs/development/state.md`](docs/development/state.md)
   under the in-tree fonts list.
6. CHANGELOG entry under `Added`.

Note: BannerManor ships an opinionated, curated set of fonts —
new fonts are added by maintainer review for quality, not by
pull-request volume. Author them for personal use freely; PRs
into the in-tree set are evaluated against the existing aesthetic.

## Adding a flag

Note that the v1.0 CLI flag surface is **frozen** (see
[`CHANGELOG.md`](CHANGELOG.md)). New flags after 1.0.0 are a
2.0 question, not a minor — don't add one in a 1.x PR without a
discussion first.

If a future major does open the surface up, the workflow is:

1. Edit `src/main.cyr` CLI dispatch and `print_usage`.
2. Add tests for every accepted value plus a malformed-value case.
3. CHANGELOG entry. Mark `Breaking` if it alters exit codes or output
   bytes for an existing invocation.

See [`docs/adr/template.md`](docs/adr/template.md) when a
non-trivial design choice deserves an ADR.

## Reporting issues

Open an issue at https://github.com/MacCracken/bannermanor/issues.

For security-sensitive issues (input-length bypass, font-file
exploitation), see [`SECURITY.md`](SECURITY.md) instead.
