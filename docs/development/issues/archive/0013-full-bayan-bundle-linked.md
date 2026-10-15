# Issue 0013 — the whole bayan bundle linked for nine CYML functions

**Reported**: 2026-08-25 (1.1.4 audit, finding O-002); filed 2026-10-15
**Version**: 1.1.2 through 1.2.0
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **fixed in 1.4.1** (2026-10-15). Filed and archived together.
**Severity**: low. Footprint only: the extra code was unreachable.

## Observation

`src/font.cyr` needs nine functions from bayan: the CYML parser and its
doc/entry accessors. It included `lib/bayan.cyr`, the stdlib's full
bundle, which also carries JSON, YAML, TOML, PDF, bigint, u128, base64,
CSV and Grisu2 `dtoa`, 17,567 lines in all at bayan 1.5.13. cyrius's DCE
pass NOPs unreachable functions but does not strip them, so the bundle
was most of the binary: 516 KB at 1.1.3, 597 KB at 1.2.0.

## Fix (shipped 1.4.1)

bayan publishes a CYML-only sublib, `dist/bayan-cyml.cyr` (592 lines),
next to the bundle. bnrmr now depends on it directly:

```toml
[deps.bayan]
git = "https://github.com/MacCracken/bayan.git"
tag = "1.5.13"
modules = ["dist/bayan-cyml.cyr"]
```

and `bayan` left `[deps].stdlib`. `lib/` was regenerated from the manifest
(`rm -rf lib/ && cyrius deps`). It now holds `lib/bayan-cyml.cyr` instead
of `lib/bayan.cyr`, and `cyrius deps --locked` confirms it.

- **Same parser.** 1.5.13 is the bayan the cyrius 6.7.9 stdlib bundles:
  `lib/bayan.cyr` was byte-identical to bayan 1.5.13's `dist/bayan.cyr`.
  The sublib's `cyml.cyr` section is byte-identical to the bundle's.
- **Renamed calls.** The sublib has no unprefixed `cyml_*` names. Those
  were the bundle's `_compat.cyr` shims, marked deprecated ("will be
  removed once consumers re-pin"). The nine calls are now the canonical
  `bayan_cyml_*`.
- **Output.** The golden suite (285 invocations, both tiers that load a
  font) is byte-identical, and so is the 3006-assertion suite.

| target | 1.2.0 | 1.4.1 |
|---|---|---|
| x86_64 | 597,040 B | 244,184 B |
| AGNOS | 609,104 B | 260,352 B |
| aarch64 | 756,672 B | 338,296 B |

The 1.4.1 figures also include `lib/freelist.cyr` and `lib/mmap.cyr`,
which arrived the same release (issue 0014) and cost about 25 KB.

## Not recovered

Issue 0006's parse regression. The parser code is identical, so
`font_load_file` costs what it did: benchmark B2 is flat
(`docs/benchmarks.md` Point 7). The roadmap expected this, and it is why
0006 and 0013 were never one item.
