# Issue 0006 — bayan 1.5.2 made `font_load_file` ~45% slower

**Reported**: 2026-08-25
**Version**: 1.1.4 (P(-1) audit addendum)
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **open** — deferred from 1.1.4; upstream (bayan)
**Severity**: performance

## Observation

The cyrius 6.2.24 → 6.5.35 bump at 1.1.3 folded `bayan` forward from
1.0.1 to 1.5.2 (absorbing PDF, YAML and Grisu2 `dtoa`). Holding the
compiler, source, fixtures and host fixed and varying only
`lib/bayan.cyr`:

| `lib/bayan.cyr` | `font_load_file(block.cyml)`, 3 runs |
|-----------------|---------------------------------------|
| 1.0.1 | 59.1 / 58.8 / 61.6 µs |
| 1.5.2 | 86.2 / 85.5 / 87.0 µs |

**~27 µs, ~45%.** The 1.0.1 figure is within noise of the 58 µs recorded
at `docs/benchmarks.md` Point 3 on cyrius 6.0.1, so B2 was flat for three
toolchain generations and then stepped once, here.

## Measurement caveat — read this before re-running

An A/B that swaps files in `lib/` and re-runs a cyrius command **does not
work**. `cyrius bench` and `cyrius build` run dep resolution first and
restore any `lib/` file whose hash does not match `cyrius.lock`, including
stdlib modules, and `--no-deps` does not prevent it:

```
$ cp <bayan-1.0.1> lib/bayan.cyr && md5sum lib/bayan.cyr
ce3f7331…  lib/bayan.cyr        # 1.0.1
$ cyrius bench … >/dev/null && md5sum lib/bayan.cyr
17bb46bf…  lib/bayan.cyr        # 1.5.2 — silently restored
```

This invalidated the A/B originally published at Point 4 (corrected at
1.1.4). The working method is to point `CYRIUS_HOME` at a snapshot whose
`lib/bayan.cyr` is the version under test, so the restore reinstates the
intended library rather than undoing the swap.

## Not diagnosed

Candidates, in the order worth checking: the two-pass entry-marker scan
that replaced the fixed 256-slot array; instruction-cache locality in a
module that grew 3,528 → 15,598 lines; a changed value-scan inner loop.
`cyml_parse` is 62–65% of `font_load_file`, so it is the only part worth
profiling — the four `_font_get_int` calls are 3.5–5%.

## Note

bnrmr uses 9 symbols from bayan and links the whole bundle to get them,
which is also most of its 516 KB binary. A narrower CYML-only entry point
from bayan would address both this and the footprint.
