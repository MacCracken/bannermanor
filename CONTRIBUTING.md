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

(Available once M2 ships the CYML font format.)

A new in-tree font needs:

1. `fonts/<name>.cyml` per the schema in
   `docs/adr/0001-cyml-font-format.md`.
2. Full ASCII coverage (A–Z, 0–9, space at minimum).
3. Attribution in the font header (`author`, `license`).
4. A test rendering a sentence through the font in
   `tests/bannermanor.tcyr`.
5. An entry in `docs/guides/fonts.md` with a preview line.
6. CHANGELOG entry under `Added`.

Note: BannerManor ships an opinionated, curated set of fonts —
new fonts are added by maintainer review for quality, not by
pull-request volume. Author them for personal use freely; PRs
into the in-tree set are evaluated against the existing aesthetic.

## Reporting Issues

Open an issue at https://github.com/MacCracken/bannermanor/issues.

For security-sensitive issues (input-length bypass, font-file
exploitation), see [`SECURITY.md`](SECURITY.md) instead.
