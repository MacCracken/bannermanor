# BannerManor — Benchmarks

> **What this is**: a small set of CPU-side benchmarks captured at
> each release, used as a **trend** for regression detection rather
> than an absolute performance claim. Three data points across M7
> (0.7.0, 0.8.0, 0.9.0) close out the roadmap's "3-point benchmark
> trend" item before v1.0.

## What we measure (and why)

The rendered banner's wall-clock time is dominated by the terminal's
write/echo loop, not by bnrmr's CPU work. To get a signal that
actually catches regressions in bnrmr's own code, we benchmark the
CPU-side hot path with no stdout writes in the timed region:

| ID | Subject | Why it matters |
|----|---------|----------------|
| B1 | `block_font_embed()` | Embedded-font construction — alloc + glyph data copy. Hit on every default-font invocation. |
| B2 | `font_load_file("fonts/block.cyml")` | Full CYML file load + parser end-to-end. Hit on every `--font NAME` invocation. |
| B3 | `fit_chars(80, 5, 1, 12)` ×100 | Layout-math hot loop (frame=80, 5×5 block font, 12-char banner). Per-render cost. |

Source: [`tests/bannermanor.bcyr`](../tests/bannermanor.bcyr). Run via
`cyrius bench tests/bannermanor.bcyr`.

## Methodology

- One batched run per subject (`bench_batch_start` → tight loop →
  `bench_batch_stop` divides total by iteration count). Min/max
  reported by `bench_report` are batch-level, so they equal avg by
  construction — the value to track is **avg**.
- Iteration counts chosen so each subject's batch is ≥ ~50 ms total
  wall time (amortizing the ~240 ns `clock_gettime` overhead the
  bench framework warns about).
- All measurements at the **same Cyrius toolchain pin** (`cyrius =
  "X.Y.Z"` in `cyrius.cyml`). A toolchain bump alongside a benchmark
  change is recorded explicitly so the trend doesn't conflate
  compiler and source effects.
- Hardware-specific: re-baseline if the dev machine changes.

## Trend

### Point 1 — 0.7.0 (baseline)

**Captured**: 2026-05-20
**Toolchain**: cyrius 6.0.1
**Host**: archaemenid (AMD Ryzen 7 5800H, Linux 7.0.5)

| ID | Subject | avg | iters |
|----|---------|-----|-------|
| B1 | `block_font_embed` | **7 ns** | 10 000 |
| B2 | `font_load_file(block.cyml)` | **68 µs** | 1 000 |
| B3 | `fit_chars ×100 (banner-worth)` | **587 ns** | 100 000 |

#### Notes on B1's 7 ns

That number is suspiciously low for an alloc + 69-glyph data copy
and may indicate the cyrius optimizer is hoisting the call out of
the bench loop (the result of `block_font_embed()` is identical on
every call and not stored). If a later release shows B1 jumping to
"normal" hundreds-of-ns territory, that is *not necessarily a
regression* — it may be a compiler change that disabled the hoist.
Check the disassembly or use a load-bearing sink for the return
value before declaring a regression.

#### Notes on B2

68 µs end-to-end for parse + alloc + decode of a 4.5 KB CYML font
gives a per-byte rate of ~15 ns/byte, dominated by `_font_get_int`'s
line-by-line key scan running once per geometry field. Realistic
target if we ever care: ≤ 10 ns/byte by switching the multi-key
scan to a single pass.

#### Notes on B3

100 `fit_chars` calls in 587 ns = **5.87 ns per call**. Pure integer
math; this should stay flat unless someone refactors the formula.

### Point 2 — 0.8.0 (pending)

Run after the next code release; capture deltas against Point 1.

### Point 3 — 0.9.0 (pending)

Run before the v1.0 cut; if the three points are flat-or-improving
the trend item is closed and M7 is complete.

## Re-running

```sh
cyrius bench tests/bannermanor.bcyr
```

Reports three lines, one per subject. Append a new "Point N" section
above with the captured numbers, host context, and toolchain pin.
