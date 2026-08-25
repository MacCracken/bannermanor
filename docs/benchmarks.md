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

### Point 2 — 0.8.0

**Captured**: 2026-05-20
**Toolchain**: cyrius 6.0.1
**Host**: archaemenid (AMD Ryzen 7 5800H, Linux 7.0.5)
**Code delta vs 0.7.0**: F-002 parser overflow caps (one extra
`n > PARSER_INT_CAP` comparison per digit in `parse_uint`,
`_font_get_int`, `_flf_take_int`) + F-008 `ws_col` clamp at 4096.
Both are hot-path defense-in-depth.

| ID | Subject | 0.8.0 avg | Δ vs 0.7.0 | iters |
|----|---------|-----------|------------|-------|
| B1 | `block_font_embed` | **6 ns** | −1 ns (−14%) | 10 000 |
| B2 | `font_load_file(block.cyml)` | **58 µs** | −10 µs (−15%) | 1 000 |
| B3 | `fit_chars ×100` | **572 ns** | −15 ns (−3%) | 100 000 |

#### Reading the deltas

All three subjects got nominally *faster*, which is at first
counterintuitive — F-002 added a comparison to every digit consumed
in three parsers. Two explanations, neither alarming:

- **Single-batch run-to-run noise.** Each batch totals 50–70 ms of
  wall time on a laptop with frequency scaling and background load;
  ±15% drift batch-to-batch is normal. The benchmark trend is for
  catching order-of-magnitude regressions, not 10% movement.
- **B1 stays suspiciously fast.** Still consistent with the
  hoisting-out-of-loop hypothesis noted at Point 1. The hoist
  apparently survived the source change.

Verdict: **no regression**. Parser overflow guards cost less than
the bench-frame noise floor on this hardware.

### Point 3 — 0.9.0

**Captured**: 2026-05-20
**Toolchain**: cyrius 6.0.1
**Host**: archaemenid (AMD Ryzen 7 5800H, Linux 7.0.5)
**Code delta vs 0.8.0**: issue 0003 fix — one extra `eff_end` /
trailing-`\r` check per glyph row in `flf_load_file`. The CYML loader
(B2's subject) is unchanged. B1's `block_font_embed` is unchanged.
Only `.flf` loads pay the new comparison, and the benchmark set
doesn't cover that path — so the bench is effectively a no-op
regression check that 0.9.0 didn't accidentally touch the CYML hot
path.

| ID | Subject | 0.9.0 avg | Δ vs 0.8.0 | iters |
|----|---------|-----------|------------|-------|
| B1 | `block_font_embed` | **7 ns** | +1 ns (noise) | 10 000 |
| B2 | `font_load_file(block.cyml)` | **58 µs** | 0 µs (flat) | 1 000 |
| B3 | `fit_chars ×100` | **572 ns** | 0 ns (flat) | 100 000 |

#### Reading the deltas

- **B1's single-ns jitter is the bench-frame floor.** Three back-to-
  back runs at 0.9.0 produced 7 / 11 / 9 ns on the same binary; the
  hoist-out-of-loop hypothesis from Point 1 continues to hold.
  Anything in this range is noise.
- **B2 + B3 are byte-stable.** The CYML loader and `fit_chars` were
  not touched at 0.9.0, and the numbers agree to the resolution the
  bench can measure. Confirms the CRLF fix is isolated to the .flf
  read path.

Verdict: **no regression**. M7's 3-point benchmark trend is now
complete; across 0.7.0 → 0.8.0 → 0.9.0 the CPU hot paths have stayed
flat-or-faster, well inside batch noise.

### Point 4 — 1.1.3

**Captured**: 2026-08-25
**Toolchain**: cyrius 6.5.35
**Host**: archaemenid (AMD Ryzen 7 5800H, Linux 7.1.9)
**Code delta vs 0.9.0**: none in bnrmr's own source — the render and
CYML-load paths are untouched from 0.9.0 through 1.1.3. What moved is
underneath: three toolchain generations (6.0.1 → 6.1.14 → 6.2.24 →
6.5.35), the CYML parser's relocation into `bayan`, and `bayan` itself
folding forward 1.0.1 → 1.5.2.

| ID | Subject | 1.1.3 avg | Δ vs 0.9.0 | iters |
|----|---------|-----------|------------|-------|
| B1 | `block_font_embed` | **7 ns** | 0 ns (flat) | 10 000 |
| B2 | `font_load_file(block.cyml)` | **87 µs** | +29 µs (+50%) | 1 000 |
| B3 | `fit_chars ×100` | **610 ns** | +38 ns (+7%) | 100 000 |

Three back-to-back runs: B1 7 / 7 / 8 ns, B2 88.3 / 86.3 / 86.8 µs,
B3 624 / 609 / 610 ns. B2's spread is under 3%, so the +29 µs is real,
not batch noise.

#### The regression is NOT from this release

B2 is measured through the CYML parser, which changed owner and version
in this window — the obvious suspect. It is the wrong one. Holding the
compiler fixed at 6.5.35 and swapping only the vendored `lib/`:

| `lib/` snapshot | B2 (3 runs) |
|-----------------|-------------|
| cyrius 6.2.24 + darshana 0.7.1 (pre-upgrade) | 87.4 / 86.6 / 87.6 µs |
| cyrius 6.5.35 + darshana 1.0.0 (post-upgrade) | 88.3 / 86.3 / 86.8 µs |

Identical. **The 1.1.3 dep bump is bench-flat**; `bayan` 1.5.2 parses
`block.cyml` no slower than 1.0.1 did despite quadrupling in size.

The +29 µs therefore entered somewhere across 6.0.1 → 6.2.24 — the
1.1.0, 1.1.1 and 1.1.2 releases, none of which captured a bench point.
That is the gap: Point 3 was measured on cyrius 6.0.1 and the trend was
declared complete at v1.0, so three toolchain bumps shipped unmeasured.
Attributing the drift to a specific one would need a bisect over those
snapshots, which is filed as follow-up rather than done here.

#### Reading the deltas

- **B1 is flat.** Embedded-font construction touches no stdlib that
  moved.
- **B2 is the only real mover**, and the A/B above localises it away
  from this release.
- **B3's +38 ns** is ~6%, close enough to the batch-to-batch spread
  (609–624 ns within a single sitting) that it is not worth a claim
  either way.

Note the bench harness now prints a `[timer floor …]` line and
subtracts a runtime-calibrated clock-read cost from every sample, so
Point 4's absolute numbers are not strictly comparable to Points 1–3.
The A/B table above is, because both of its rows were measured under
the same harness.

Verdict: **no regression from 1.1.3**; a pre-existing, previously
unmeasured B2 drift is now on the record.

## Re-running

```sh
cyrius bench tests/bannermanor.bcyr
```

Reports three lines, one per subject. Append a new "Point N" section
above with the captured numbers, host context, and toolchain pin.
