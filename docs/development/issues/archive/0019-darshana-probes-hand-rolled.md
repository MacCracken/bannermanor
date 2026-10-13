# Issue 0019 — `src/layout.cyr` hand-rolls darshana's terminal probes

**Reported**: 2026-10-12
**Version**: 1.1.5
**Reporter**: darshana's consumer survey (2026-10-12); confirmed by reading the source
**Status**: **fixed in 1.2.0** (2026-10-12)
**Severity**: maintainability, with one latent hazard. No behavior defect
on Linux.

## Observation

darshana has been a dependency since bannermanor 0.5.0, and its frozen v1.0 surface
includes `tty_winsize` and `tty_isatty`. `src/layout.cyr` re-implemented
both:

- `term_width_ioctl` issued its own `syscall(SYS_IOCTL, 1, TIOCGWINSZ, &ws)`
  and decoded `ws_col` — `tty_winsize(1, …)` plus a zero check and the
  F-008 clamp.
- `stdout_is_tty` issued the same ioctl again — close to `tty_isatty(1)`,
  with one difference worth keeping: since 1.1.4 (F-020) it reports a
  terminal answering 0 columns as **not** a TTY, where `tty_isatty` answers
  1.
- Each carried its own `#ifdef CYRIUS_TARGET_AGNOS` stub, for a target
  darshana already bridges (issue [0018](0018-agnos-console-width-never-queried.md)).
- `enum LayoutLimits` declared `TIOCGWINSZ = 0x5413` (and two winsize
  offsets) in the same compilation unit as darshana's public
  `var TIOCGWINSZ = 0x5413`.

**The hazard in the duplicate constant.** The two agree, so cyrius says
nothing. Had they differed, the enum — declared after darshana's `var`,
because `src/layout.cyr` includes `src/color.cyr` (and so darshana) first
— would have won for the whole unit, darshana's own `tty_winsize`
included: cyrius resolves a duplicate symbol to its last definition, with
only a `duplicate symbol … redefined with conflicting value` warning
(verified with cyrius 6.7.9 on a minimal program).

## Fix (shipped 1.2.0)

- One probe, through darshana: `term_width_ioctl` calls
  `tty_winsize(1, &rows, &cols)` and passes the answer to a pure
  `_usable_cols(rc, cols)` — 0 for a failed query or 0 columns, otherwise
  `cols` clamped at `WS_COL_CAP` (F-008). The same code now serves Linux
  and AGNOS.
- `stdout_is_tty` on Linux is `term_width_ioctl() > 0`, so the two probes
  cannot disagree (F-020 holds by construction, not by two copies of one
  test). On AGNOS it keeps returning 0 — see 0018 for why.
- `TIOCGWINSZ`, `WS_ROW_OFF` and `WS_COL_OFF` are gone from
  `LayoutLimits`; `src/` issues no `ioctl` of its own.

Two darshana helpers were considered and not used, each for a semantic
reason:

- **`tty_isatty(1)`** answers 1 for a 0-column pty, which would turn color
  back on for the wrapping-colored-banner case issue 0004 exists to
  prevent.
- **`tty_winsize_or`** treats a 0 in *either* dimension as "size
  unknown". bnrmr reads columns only, so a terminal reporting 0 rows and
  80 columns is an 80-column terminal here; `tty_winsize_or` would have
  made it a pipe.

Linux output is byte-identical (0018 has the matrix).

## Regression tests

`tests/bannermanor.tcyr`, which never exercised either probe before —
the suite's own stdout is whatever the runner gave it. The new Linux tests
point fd 1 at a descriptor they control and restore it before asserting:

- `t_usable_cols` — the pure rule, including the clamp and a failed query.
- `t_probes_non_tty` — fd 1 on `/dev/null` and on a pipe: width 0, not a
  TTY.
- `t_probes_pty` — fd 1 on a pty slave at 24×80, 0×80, 0×0, 24×0, 24×1,
  50×5000 and 24×4096: width and TTY verdict for each. The 0×0 / 24×0
  rows fail if `stdout_is_tty` becomes `tty_isatty(1)`; the 0×80 row
  fails under `tty_winsize_or`; the 50×5000 row fails without the clamp
  (each mutation run and observed red).
- `t_render_pty_vs_pipe` — `render_layout` on the pty against the same
  render on a pipe, byte for byte: `--color red` and `rainbow` wrap every
  plain row in `ESC[<code>m … ESC[0m`; a 0-column pty renders exactly the
  plain bytes; an 11-column pty truncates `AGNOS` to `AG`; center on an
  80-column pty equals an explicit `--width 80`. This is also the first
  check of darshana's SGR bytes on the TTY path.
