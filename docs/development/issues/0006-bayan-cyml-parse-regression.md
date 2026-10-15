# Issue 0006 — bayan 1.5.2 made `font_load_file` ~45% slower

**Reported**: 2026-08-25
**Version**: 1.1.4 (P(-1) audit addendum)
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **open** — diagnosed at 1.8.1 and filed with bayan as `docs/development/issues/2026-10-15-cyml-parse-scans-every-byte-twice.md`, with a repro and a proposed fix. Closes when bnrmr moves `[deps.bayan]` to the release that carries it.
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

## Update — 1.4.1 (2026-10-15)

1.4.1 replaced the full bayan bundle with its CYML-only sublib (issue
0013). The parser code is byte-identical, so as expected B2 did not move:
87–91 µs across the 1.4.1 runs, against 90.6 µs at 1.2.0
(`docs/benchmarks.md` Point 7). The smaller module did not help, which
counts somewhat against the instruction-cache explanation above. Still
undiagnosed, still upstream. The next step is a profile of
`bayan_cyml_parse` itself, or an A/B against a bayan with the two-pass
marker scan reverted, built the way architecture note 002 describes.

## Update — 1.8.1 (2026-10-15): diagnosed

**Cause.** bayan 1.5.1 made the `[[entries]]` scan two-pass: count the
markers, allocate exactly, then find them again. 1.5.1 did this to remove
a 256-entry cap that silently truncated. Each pass calls
`_cyml_is_entries` once per byte, so the parser now makes about two calls
per input byte where 1.4.0 made one (about 7,250 against 3,600 for
`block.cyml`). The call is the cost; the work inside it is one compare.
`src/cyml.cyr` did not change at 1.5.2. 1.5.2 was only the first bundle
a cyrius release folded in after 1.5.1, so it is where this issue first
saw the change.

**Evidence.** The parser alone was benchmarked in five scratch builds:
same compiler (cyrius 6.7.11), same stdlib, same input, only the parser
varied. Fastest of 9 interleaved rounds, on a loaded host, so read the
ratios:

| parser | `block.cyml` | `clean.cyml` | vs bayan 1.5.14 |
|---|---|---|---|
| bayan 1.0.1 | 41.7 µs | 85.7 µs | 0.48–0.56× |
| bayan 1.5.14 | 77.6 µs | 179.8 µs | 1.00× |
| 1.5.14, one pass, call per byte | 40.2 µs | 93.0 µs | 0.52–0.60× |
| 1.5.14, two passes, newline-driven (proposed) | 29.8 µs | 60.1 µs | 0.33–0.43× |
| 1.5.14, one pass, newline-driven | 21.7 µs | 39.2 µs | 0.22–0.33× |

Restoring one pass brings back 1.0.1's time, so the second pass is the
whole regression. The proposed fix keeps 1.5.1's exact two-pass design
but looks for a marker only at line starts, and is faster than 1.0.1 was.
All five parsers return identical results on the four fonts. The
1.5.14-based ones also agree on 1.5.1's leading-newline and 300-entry
cases, which 1.0.1 gets wrong. With the parse at 62–65% of B2, the fix
should bring `font_load_file` under its pre-regression 59 µs.

**Ruled out**: instruction-cache locality. The 1.4.1 sublib did not help,
and the A/B above holds the module size nearly constant across the
1.5.14 arms.

**Filed upstream**: bayan
`docs/development/issues/2026-10-15-cyml-parse-scans-every-byte-twice.md`,
with `docs/development/issues/repros/2026-10-15-cyml-parse-scans-every-byte-twice.cyr`.
The repro compares the proposed parser with today's on 12 documents and
exits with the number that differ (0), and prints the timings. Making the
patch wrong on one case was checked to make it report a difference.

**What is left here**: move `[deps.bayan]` to the bayan release that
carries the fix, record B2 before and after, and close this issue.
