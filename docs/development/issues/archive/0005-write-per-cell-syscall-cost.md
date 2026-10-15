# Issue 0005 — one `write(2)` per glyph cell and per pad space

**Reported**: 2026-08-25
**Version**: 1.1.4 (P(-1) audit, O-001)
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **fixed in 1.4.1** (2026-10-15), by Option 1. Option 2 remains on the roadmap with issue 0009.
**Severity**: performance / self-inflicted

## Observation

`render_layout` (`src/layout.cyr`) emits stdout one syscall at a time:
`_write_spaces` loops `syscall(1, 1, " ", 1)` per space, `_write_newlines`
does the same per newline, and the glyph loop writes `w` bytes per glyph
followed by one syscall per gap column.

Measured — a banner's cost scales with its width, not its content:

```
no --width (natural)         :  0.67 ms/render
--align center --width 200   :  0.77 ms/render
--align center --width 1000  :  1.84 ms/render
--align center --width 4096  :  5.49 ms/render
```

An 8× slowdown at the width cap, almost entirely syscall overhead. At the
extreme, a wide render issues 28,637 `write(2)` calls to emit 28,679 bytes.

The bench harness never caught this: `tests/bannermanor.bcyr` deliberately
benchmarks only the CPU side, on a premise (now corrected) that the write
side was "bounded by terminal/pipe throughput, not bnrmr's code."

## Why it was not fixed in 1.1.4

The fix is buffering, and buffering has to interleave correctly with
darshana's `tty_sgr` / `tty_sgr_reset`, which do their own unbuffered
writes between the pad and the glyph run on every colored row. Getting
that ordering wrong reorders bytes, and the M1 byte-identity contract
(reaffirmed at 1.0.0) makes that unacceptable. 1.1.4 was a hardening
release; this needed more room than it had.

## Shape of the fix

Two options, in increasing order of ambition:

1. **Chunked writes only.** Keep the current structure; replace the
   per-space and per-gap loops with writes from a static space buffer.
   Zero ordering risk — the darshana calls stay exactly where they are —
   and it removes the width-scaling term, which is the whole measured
   cost. This is the conservative fix and probably the right one.
2. **A row buffer.** Compose each row into one allocation and flush once,
   flushing before and after each darshana call to preserve order. Bigger
   win on the glyph writes; more surface to get wrong.

Option 2's endgame is darshana's `_buf` family (`tty_sgr_buf`, etc.),
which composes SGR into a caller-supplied buffer and would allow a single
write per frame. `cyrius.cyml` has anticipated this since 1.1.2.

## Acceptance

- Piped output byte-identical across the full golden suite.
- Colored output byte-identical on a real pty (`script -qec`).
- `--width 4096` render cost within noise of natural-width render cost.
- A B4 benchmark subject covering the write path.

## Fix (shipped 1.4.1) — Option 1

`src/layout.cyr` writes runs of spaces and newlines from buffers allocated
once per process: 4096 spaces, the most any frame source allows, and 64
newlines, `PAD_CAP`. A left pad, a gap or a `--pad` block is therefore one
write instead of one per byte. The inter-glyph gap is written straight from
the space buffer. Glyph rows are still one write each, and darshana's
`tty_sgr` / `tty_sgr_reset` calls did not move, so colored rows interleave
exactly as before. Every write goes through `_emit` → `lib/io.cyr`'s
`file_write` (accepted risk A-10 normalized at the same time).

Measured on archaemenid, cyrius 6.7.9, against the 1.2.0 binary:

| | `write(2)` calls (qemu -strace) | wall time, whole process (500 runs) |
|---|---|---|
| `bnrmr AGNOS` | 50 → 50 | 567–578 → 562 µs |
| `--width 4096 --align center AGNOS` | 10,215 → 55 | 4.2 → 0.56 ms |
| `--width 4096 --align right A` | 20,465 → 15 | 7.7 → 0.55 ms |
| `--pad 64 --font big HI` | 156 → 30 | |

In process, the new B4 bench subject (`tests/bannermanor.bcyr`, fd 1 on
`/dev/null`) puts the 4096-column centered render at 21 µs against 18 µs
at natural width. It was 3.3 ms before.

The natural-width render did get about 0.9 µs slower in process: 18.0 µs
against 17.1 µs. That is the cost of the extra call layers (`_emit` →
`file_write` → `sys_write`) on each of its 50 writes. It does not show at
the process level, where the smaller binary (issue 0013) more than pays
for it.

## Acceptance

- Piped output byte-identical across the full golden suite: **yes**. The
  frozen tier of `scripts/golden.sh` matches the 1.2.0 binary.
- Colored output byte-identical on a real pty: **yes**. The suite's pty leg
  is 112 cases through script(1), every `--color` spelling included.
- `--width 4096` render cost within noise of natural width: **yes** at
  the process level (562 vs 564 µs); 21 vs 18 µs in process.
- A B4 benchmark subject covering the write path: **yes**, three rows.

## Not done here

Option 2, one write per row, is roadmap 1.5.0 together with issue 0009
(checked writes). It needs darshana's `_buf` SGR composers so that a
colored row can be assembled in one buffer.
