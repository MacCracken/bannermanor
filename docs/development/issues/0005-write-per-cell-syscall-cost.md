# Issue 0005 — one `write(2)` per glyph cell and per pad space

**Reported**: 2026-08-25
**Version**: 1.1.4 (P(-1) audit, O-001)
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **open** — deferred from 1.1.4
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
