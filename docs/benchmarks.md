# BannerManor — Benchmarks

> **What this is**: a small set of benchmarks captured at each
> release, used as a **trend** for regression detection rather than an
> absolute performance claim. Seven points so far, 0.7.0 through 1.4.1.
> The first three (0.7.0, 0.8.0, 0.9.0) closed the roadmap's pre-v1.0
> "3-point benchmark trend" item.

## What we measure (and why)

Two sides of the render path. B1–B3 are CPU-side, with no stdout writes
in the timed region. B4 (since 1.4.1) is the write side, with stdout
pointed at `/dev/null`, so it measures bnrmr's own syscall pattern and
not the terminal. Until 1.4.1 the write side was left out on the
premise that it was "dominated by the terminal". It was not: through
1.2.0, `render_layout` issued one `write(2)` per pad space (issue 0005).

| ID | Subject | Why it matters |
|----|---------|----------------|
| B0 | `_calibration` (an empty call) | The harness floor. A row near it is "at the floor", not fast. |
| B1 | `block_font_embed()` | Embedded-font construction — alloc + glyph data copy. Hit on every default-font invocation. |
| B2 | `font_load_file("fonts/block.cyml")` | Full CYML file read + parse end to end. Hit on every `--font NAME` invocation. |
| B3 | `fit_chars(80, 5, 1, 12)` ×100 | Layout-math hot loop (frame=80, 5×5 block font, 12-char banner). Per-render cost. |
| B4 | `render_layout` ×3: natural, `--width 4096` centered, `--width 4096` right-aligned | The write path. Must not scale with banner width. |

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

#### CORRECTION (1.1.4) — the A/B published here at 1.1.3 was invalid

The original Point 4 claimed "the 1.1.3 dep bump is bench-flat", on the
strength of an A/B that swapped the vendored `lib/` and re-ran the
bench. **That A/B did not measure what it claimed**, and the conclusion
was wrong.

`cyrius bench` (and `cyrius build`) run dep resolution first, which
restores any `lib/` file whose hash does not match `cyrius.lock` —
including stdlib modules. Reproduced directly:

```
$ cp <bayan-1.0.1> lib/bayan.cyr && md5sum lib/bayan.cyr
ce3f73319a570f11fd14f80e71dbf5a6  lib/bayan.cyr     # 1.0.1
$ cyrius bench tests/bannermanor.bcyr >/dev/null && md5sum lib/bayan.cyr
17bb46bf6c86bbc41dd5f23b8e5b6c72  lib/bayan.cyr     # 1.5.2 — silently restored
```

Both rows of the old table therefore compiled against bayan 1.5.2. It
compared the current library against itself, which is why it came out
flat. Passing `--no-deps` does not prevent the restore either.

#### The corrected A/B — bayan 1.5.2 *is* the regression

Re-run by pointing `CYRIUS_HOME` at a snapshot whose `lib/bayan.cyr` is
the version under test, so the restore reinstates the intended library
rather than undoing the swap. Compiler, source, fixtures and host all
held fixed; only bayan differs:

| `lib/bayan.cyr` | B2 `font_load_file(block.cyml)`, 3 runs |
|-----------------|------------------------------------------|
| 1.0.1 (shipped through 1.1.2) | **59.1 / 58.8 / 61.6 µs** |
| 1.5.2 (shipped at 1.1.3)      | **86.2 / 85.5 / 87.0 µs** |

**bayan 1.5.2 costs ~27 µs — a ~45% regression in `font_load_file`** —
and it arrived in the 1.1.3 toolchain bump. The 1.0.1 figure also
lands within noise of the 58 µs recorded at Point 3 on cyrius 6.0.1,
which retires the other half of the original story: there was no
gradual drift across 6.0.1 → 6.2.24. B2 was flat for three toolchain
generations and then stepped once, here.

Root cause is not diagnosed. bayan 1.5.2 folded in PDF, YAML and
Grisu2 `dtoa`; whether the cost is a changed CYML scan, worse locality
in a much larger module, or the two-pass entry count that replaced the
fixed 256-slot scan is open. Filed as follow-up — the parse is 62–65%
of B2, so it is the only thing worth profiling.

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

Verdict (as corrected at 1.1.4): **1.1.3 regressed B2 by ~45%**, via
the bayan 1.0.1 → 1.5.2 fold-forward. Not a code change in bnrmr — the
render and CYML-load paths are byte-identical — but a real cost, and
the original "bench-flat" verdict published here was an artifact of a
broken A/B, not a measurement.

### Point 5 — 1.1.4

**Captured**: 2026-08-25
**Toolchain**: cyrius 6.5.35
**Host**: archaemenid (AMD Ryzen 7 5800H, Linux 7.1.9)
**Code delta vs 1.1.3**: the P(-1) hardening repairs — control-byte
scrubbing on CYML header strings and the malformed-font path echo, a
`COLUMNS` clamp, `--width`/`--pad` parsed through `parse_uint`, the
dead `lens_scratch` allocation removed, `.flf` hardblank widened to the
spec rule, and the two TTY probes reconciled.

| ID | Subject | 1.1.4 avg | Δ vs 1.1.3 | iters |
|----|---------|-----------|------------|-------|
| B1 | `block_font_embed` | **7 ns** | 0 ns (flat) | 10 000 |
| B2 | `font_load_file(block.cyml)` | **85 µs** | 0 µs (flat) | 1 000 |
| B3 | `fit_chars ×100` | **606 ns** | 0 ns (flat) | 100 000 |

Three runs: B1 7 / 6 / 7 ns, B2 85.3 / 84.8 / 85.8 µs, B3 607 / 604 /
608 ns. Nothing moved, which is the expected result — none of the
repairs touch a benchmarked path. B2 remains at the elevated level the
corrected Point 4 attributes to bayan 1.5.2.

Not covered by any benchmark: the stdout write path. `render_layout`
issues one `write(2)` per space and per glyph cell, so a banner's cost
scales with its width — measured at 0.67 ms for a natural-width render
against 5.49 ms at `--width 4096`, an 8× difference that is almost
entirely syscall overhead. A B4 subject for it, and the buffering that
would fix it, are deferred past 1.1.4 (see `docs/development/issues/`).

Verdict: **no regression**. The hardening is free.

### Point 6 — 1.2.0

**Captured**: 2026-10-12
**Toolchain**: cyrius 6.7.9 (A/B against the 1.1.5 tree at 6.6.2)
**Host**: archaemenid (AMD Ryzen 7 5800H, Linux 7.2.8)
**Code delta vs 1.1.5**: cyrius 6.6.2 → 6.7.9 with `lib/` re-vendored,
darshana 1.0.0 → 1.3.0, and the two stdout probes routed through
darshana's `tty_winsize`. None of the three subjects calls a probe.

A/B, not a lib-swap: the 1.1.5 tree (`git archive HEAD`, with its own
pin, `lib/` and lock) and the 1.2.0 tree each built and run by
`cyrius bench` under their own pins, interleaved three-and-three,
twice. So the Point 4 trap — `cyrius bench` restoring `lib/` to the
lock — cannot make the rows compare one library against itself; but the
toolchain and the library move together here, and these rows do not
separate them.

| ID | Subject | 1.2.0 median | 1.1.5 median | Δ | iters |
|----|---------|--------------|--------------|---|-------|
| B1 | `block_font_embed` | **7.5 ns** | 7 ns | noise (5–12 ns in both) | 10 000 |
| B2 | `font_load_file(block.cyml)` | **90.6 µs** | 89.7 µs | +1% (flat) | 1 000 |
| B3 | `fit_chars ×100` | **672 ns** | 642 ns | +4.5% | 100 000 |

Six runs each. B2: 1.2.0 89.2–91.9 µs against 1.1.5 88.2–91.9 µs —
overlapping, flat. B3: 1.2.0 655–683 ns against 1.1.5 635–662 ns —
every 1.2.0 run above every 1.1.5 run, so it is real, and small: 6.4 →
6.7 ns per `fit_chars` call. `fit_chars`' source did not change, so it
is the toolchain (codegen, or `lib/bench.cyr`'s timing), not bnrmr.
B2 sits above Point 5's 85 µs in BOTH rows, so that gap is the host
(Linux 7.1.9 → 7.2.8 since Point 5), not this release.

Verdict: **no regression worth acting on**. B3's +0.3 ns per call is
recorded so the next point can tell whether it is a trend.

### Point 7 — 1.4.1

**Captured**: 2026-10-15
**Toolchain**: cyrius 6.7.9
**Host**: archaemenid (AMD Ryzen 7 5800H, Linux 7.2.8), timer floor
1.3–1.4 µs per clock read (hpet)
**Code delta vs 1.2.0**:
- the write path writes runs (issue 0005, Option 1), and every write
  goes through `lib/io.cyr`'s `file_write`;
- bayan's CYML-only sublib replaces the full bundle (same parser code,
  issue 0013);
- the font readers share one `_slurp` and `fl_free` their buffers
  (issue 0014).

**New subjects**: B0 `_calibration`, an empty call that shows the
harness floor, and **B4**, the write path: three `render_layout` rows,
timed with fd 1 on `/dev/null`. The write side had never been
benchmarked, at first on the false premise that it was "bounded by
terminal/pipe throughput".

**B4, A/B against 1.2.0's write path.** Built from this tree, with only
`src/layout.cyr` swapped for 1.2.0's: nothing restores `src/` (see
architecture note 002 for why the same trick fails on `lib/`). The arms
were run back to back, twice each:

| B4 row | 1.2.0 `layout.cyr` | 1.4.1 | iters |
|---|---|---|---|
| natural (`AGNOS`) | 16.9 / 17.4 µs | 18.0 / 18.0 / 18.2 µs | 2 000 |
| `--width 4096 --align center` (`AGNOS`) | **3.31 / 3.24 ms** | **20.6 / 21.5 µs** | 2 000 |
| `--width 4096 --align right` (`A`) | **6.53 / 6.66 ms** | **5.6 / 5.8 µs** | 2 000 |

The wide rows are 150× and 1,150× cheaper, and now cost about what a
natural row does. That is issue 0005's acceptance bar. The natural row
is **~0.9 µs slower** in process. Each of its 50 writes now passes
through `_emit` → `file_write` → `sys_write`, and a cyrius call costs
about 12 ns, with no inlining. An earlier cut, before gaps were written
straight from the run buffer, cost 2.4 µs.

**Whole process** (500 invocations each, wall clock; this is what a user
sees):

| invocation | 1.2.0 | 1.4.1 |
|---|---|---|
| `bnrmr AGNOS` | 567–578 µs | 562 µs |
| `--width 4096 --align center AGNOS` | 4.2 ms | 0.56 ms |
| `--width 4096 --align right A` | 7.7 ms | 0.55 ms |

At process level the natural render is slightly *faster*. The binary
shrank from 597 KB to 244 KB, which more than pays for the extra call
layers.

**B0–B3**, from the same session:

| ID | Subject | 1.4.1 | vs Point 6 |
|----|---------|-------|------------|
| B0 | `_calibration` | **2 ns** | new |
| B1 | `block_font_embed` | **6 ns** | noise |
| B2 | `font_load_file(block.cyml)` | **87.4 / 91.2 µs** | flat (90.6) |
| B3 | `fit_chars ×100` | **608 / 619 ns** | flat (672) |

B2 now also pays an mmap and munmap for its 64 KB read buffer (`fl_alloc`
takes anything over 4 KB from `mmap`), and it is flat anyway. The sublib
is the same parser, so issue 0006's ~45% bayan regression is untouched,
as expected.

**A run under load is not a point.** Later the same day, with other
cyrius compiles pushing the load average to 8–19, every row read 25–50%
high, B2 included (110–118 µs), and that code had not changed. Those
rows were discarded. If B1 or B2 moves and nothing it calls changed,
check `/proc/loadavg` before you check the code.

**History file**: `scripts/bench-history.sh` (new) appends a run to
`docs/benchmarks/history.csv` (date, version, toolchain, host, the
measured timer floor, row, average, iterations). It refuses an empty or
short run. Record from a quiet machine.

Verdict: **issue 0005 is fixed**: wide renders no longer scale with
width. **No regression worth acting on.** The natural path's +0.9 µs in
process is the price of routing writes through the per-target wrapper,
and it does not show at the process level.

## Re-running

```sh
cyrius bench tests/bannermanor.bcyr
cyrius bench tests/bannermanor.bcyr | sh scripts/bench-history.sh   # record it
```

Reports one line per subject (seven since 1.4.1) after the timer-floor
line. Append a new "Point N" section above with the captured numbers,
host context, and toolchain pin. Check `/proc/loadavg` first: a busy host
inflates every row.
