# Issue 0009 — no `write(2)` return value is checked anywhere

**Reported**: 2026-08-25 (1.1.4 audit, finding C-004); filed 2026-10-15
**Version**: 0.2.0 onward
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **open**, unblocked. [ADR 0002](../../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
ruling (2), accepted 2026-10-15, makes it a defect to fix. Scheduled with
the one-write-per-row emit path (roadmap 1.5.0).
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
