# Issue 0009 — no `write(2)` return value is checked anywhere

**Reported**: 2026-08-25 (1.1.4 audit, finding C-004); filed 2026-10-15
**Version**: 0.2.0 onward
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **fixed in 1.5.0** (2026-10-15), under [ADR 0002](../../../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
ruling (2), together with issue 0005's Option 2 (one write per row).
**Severity**: medium. A failed render reports success.

## Observation

bnrmr writes stdout from three places: `render_layout`'s row loop and pad
helpers (`src/layout.cyr`), the `--list-fonts` printers (`src/cli.cyr`),
and `println`/`fmt_int` (stdlib). None looks at what `write(2)` returns.

```
$ bnrmr "hi" > /dev/full; echo $?
0
```

Nothing was written, and the exit status says the banner rendered. The
same goes for a closed stdout (`bnrmr hi >&-`), a pipe whose reader has
gone, and a short write on a full disk. (SIGPIPE terminates the process
on a closed pipe before the return could be seen; the other cases are
silent.)

## Why it matters

The documented use is `bnrmr ... > /etc/motd` from a provisioning script,
where `$?` is the only signal. A full filesystem leaves an empty or
truncated MOTD and a script that thinks it succeeded.

## Why it was gated

Exiting nonzero on a failed write changes the exit code of an invocation
that exits 0 today. Whether an exit code on an I/O failure is part of the
v1.0 freeze was open until ADR 0002 ruling (2), accepted 2026-10-15: an
invocation whose bytes never reached fd 1 is not valid, so exit 0 there
is a defect, not frozen behavior. The fix is a `Fixed` entry in a 1.x
minor.

## Shape of the fix

Not a bare nonzero check:

- **Retry on partial writes.** `write(2)` may return fewer bytes than
  asked on a pipe or a slow device, and that is not an error. Loop until
  the buffer is out or a real error comes back.
- **Classify errno.** Retry on `EINTR`, which is unreachable today
  (bnrmr installs no signal handlers) but is correct to handle. Fail on
  `ENOSPC` / `EIO` / `EBADF` / `EPIPE`.
- **One site, not many.** After 1.4.1, layout's emit calls go through
  `_emit` / `_emit_run` (`src/layout.cyr`), and so do the `--list-fonts`
  printers in `src/cli.cyr`. `println`, `fmt_int` (which `--list-fonts`
  uses for the geometry digits) and darshana's `tty_sgr` still write on
  their own. Roadmap 1.5.0's
  one-write-per-row path (issue 0005 Option 2) collapses the render to a
  single write per row, so the checked write is one call.
- **Exit code.** The proposed code is 1, as for every other bnrmr
  failure. ADR 0002 decides.

## Acceptance

- `bnrmr hi > /dev/full` exits nonzero.
- Every golden record is unchanged, since none of them fails a write.
- A test that points fd 1 at a full device or a closed descriptor and
  asserts the return. The pty / pipe redirection helpers in
  `tests/bannermanor.tcyr` already show how.

## Fix (shipped 1.5.0)

`_emit` (`src/layout.cyr`) is the one stdout writer. Every byte bnrmr
writes to stdout goes through it: banner rows, `--help`, `--version`,
`--list-fonts` (whose numbers now go through `_emit_int` instead of the
stdlib's unchecked `fmt_int`), and the `--pad` runs.

- **Short writes** are continued until the buffer is out.
- **`EINTR`** is retried at once, up to 100 times in a row. **`EAGAIN`**
  (a non-blocking stdout) is retried after a 1 ms pause, up to 1000 times.
- **Anything else**, and a write that makes no progress, is a failure.
  It is recorded once (`_out_err`), nothing more is written, and `main()`
  exits 1 with `bnrmr: write error: <reason>` on stderr. The reason is
  named for ENOSPC, EBADF, EIO, EFBIG and EDQUOT.
- The errno values are bnrmr's own (`WriteErrno`), because the AGNOS
  syscall table defines neither `EINTR` nor `EAGAIN`. On AGNOS a failed
  write returns -1 and is a failure.

```
$ bnrmr hi > /dev/full; echo $?
bnrmr: write error: no space left on device
1
$ sh -c 'bnrmr hi >&-; echo $?'
bnrmr: write error: stdout is not open
1
```

`t_emit_checked` points fd 1 at `/dev/full` and checks the return, the
sticky flag, that nothing more is attempted, and `render_layout`'s -4;
`t_write_error_text` checks the reasons. With issue 0005's Option 2 (one
write per row, same release) a banner row is a single `_emit`, so the
checked write is one call per row, not one per glyph.
