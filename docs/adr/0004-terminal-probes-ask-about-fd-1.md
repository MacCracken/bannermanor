# 0004 — Terminal probes ask about fd 1, through a wrapper where one answers that

**Status**: Accepted
**Date**: 2026-10-15

## Context

bnrmr makes two decisions about its standard output, and both depend on
whether fd 1 is a terminal:

- **Width.** Without `--width`, output to a terminal is cut to the
  terminal's width so a banner does not wrap into itself (issue 0004);
  output to a pipe or a file is not cut. The man page states both halves.
- **Color.** `--color` writes SGR only when stdout is a terminal. In a
  pipe or a file the bytes are plain.

Since 1.2.0 both come from one probe, `term_width_ioctl`, which calls
darshana's `tty_winsize(1, ...)`. Color is "the probe answered a width"
(`stdout_is_tty`), so the two cannot disagree (F-020).

On Linux that probe is per-fd: TIOCGWINSZ is asked of fd 1 and fails on
a pipe or a file. On AGNOS it never was. darshana's AGNOS `tty_winsize`
calls winsize#60, which reports the framebuffer console's grid whatever
fd 1 is, and darshana's AGNOS `tty_isatty` answers 1 whenever the console
is up. Through 1.6.0 that forced two departures from the Linux behavior:

- **Color was off on AGNOS altogether** (`stdout_is_tty` returned 0).
  Following the probe would have written escape bytes into
  `bnrmr --color red X > /etc/motd`.
- **A redirected or piped banner was cut to the console's width.** Issue
  0018 recorded this as deliberate and bounded: plain text either way,
  and nothing could tell fd 1 from the console.

agnos 1.57.13 added `fd_kind#111`, which answers what an fd is (console,
file, pipe, channel, ...), and cyrius 6.7.11 wraps it as `sys_fd_kind`.
darshana 1.3.0, the current release, does not use it yet. Its roadmap
lists a per-fd AGNOS `tty_isatty` as eligible work, and agnos's ABI
document names darshana as the intended consumer
(`tty_isatty(fd)` = `fd_kind(fd) == 1`).

So the question for 1.7.0 was not only *what* the AGNOS answer is, but
*where* bnrmr gets it while the wrapper that should give it does not.

## Decision

**A probe asks about fd 1, and it goes through a target-bridged wrapper
when one exists and answers that question. Where no wrapper answers it,
bnrmr gates inline, behind `#ifdef CYRIUS_TARGET_AGNOS`, using a stdlib
`sys_*` wrapper (never a raw syscall number: architecture note 001), and
says in the comment which wrapper should replace the gate.**

Applied in 1.7.0:

1. **Width**: darshana's `tty_winsize` answers the right question on
   Linux, and on AGNOS whenever fd 1 is the console. bnrmr keeps calling
   it, behind one inline gate, `_winsize_describes_stdout` in
   `src/layout.cyr`: always 1 on Linux, and on AGNOS
   `sys_fd_kind(1) == FDK_CONSOLE`.
2. **Color**: derived from the width probe on both targets again
   (`term_width_ioctl() > 0`). The AGNOS `return 0` stub is gone.
3. **Only the console counts on AGNOS.** `FDK_FILE` (agnsh's `>`) and
   `FDK_PIPE` (agnsh's `|`) are not terminals, as on Linux. `FDK_CHAN`,
   the channel a terminal emulator hands its child, is not counted
   either: winsize#60 would give the console's size, not that window's,
   and darshana's planned `tty_isatty` draws the same line. A `-1` (a
   kernel older than 1.57.13, where #111 is an unknown syscall, or a
   closed fd 1) is not a terminal.

When darshana's AGNOS `tty_isatty(fd)` asks `fd_kind`, the gate goes and
bnrmr routes through darshana. That will not change any byte, because
both draw the line at the console.

## Consequences

- **Positive** — `--color` works on the AGNOS console, the roadmap's
  last AGNOS gap in the flag surface. A redirected or piped banner on
  AGNOS has the bytes it has on Linux: plain, and uncut. Width and color
  still come from one probe, so they cannot disagree.
- **Positive** — `scripts/agnos-smoke.py` checks this on a real agnos
  kernel in QEMU. The 1.6.0 binary fails exactly the two checks this
  ADR changes (console color, redirected width) and passes the others,
  so the checks are shown to fail when they should.
- **Negative** — an AGNOS output change. `bnrmr TEXT > file` with a
  banner wider than the console was cut through 1.6.0 and is whole from
  1.7.0. That is the documented contract (the man page: "output to a
  pipe or file is not" cut), which AGNOS had departed from only because
  it could not tell a file from the console. Linux bytes do not move.
- **Negative** — on an agnos kernel older than 1.57.13, console output
  loses its width cut (fd_kind answers -1, so it is treated like a
  file). agnos ships its kernel and its userland together
  (`stage-tools.sh`), so a 1.7.0 bnrmr on an older kernel is not a
  shipped combination.
- **Negative** — bnrmr owns an AGNOS-only branch that no Linux test can
  execute. `cyrius test` compiles it out; `cyrius build --agnos` proves
  only that it compiles. The QEMU harness is manual, not a CI step.
- **Neutral** — bnrmr in an AGNOS terminal emulator (stdout `FDK_CHAN`)
  gets no color and no width cut until there is a per-fd window size to
  ask. That is the same answer darshana's planned wrapper gives.
- **Neutral** — the toolchain moves to cyrius 6.7.11, the first release
  with `sys_fd_kind`.

## Alternatives considered

- **Wait for darshana.** Keeps bnrmr free of AGNOS branches, but leaves
  `--color` a no-op on AGNOS for an unscheduled darshana release, when
  the kernel and the stdlib already answer the question. Rejected; the
  gate is written to be removed when darshana catches up.
- **Call syscall 111 directly** (`syscall(111, 1)`). Avoids the cyrius
  bump, but it is the pattern architecture note 001 exists to forbid:
  111 means something else on Linux (`getpgrp` on x86_64), and lint
  would not notice.
- **Gate color only, keep the console-wide width.** Keeps every AGNOS
  byte of 1.6.0 except console color. Rejected: color and width would be
  two rules again (F-020 made them one), and the width cut on a
  redirected stdout was only ever a consequence of not being able to ask.
- **Count `FDK_CHAN` as a terminal.** Closer to Linux, where a pty is a
  tty. Rejected for now: the size bnrmr would cut to and align within is
  the console's, not the window's, and agnos's own guidance leaves the
  call to the caller with darshana's line at the console.
- **Fall back to the console probe when fd_kind answers -1** (an older
  kernel). Keeps old-kernel console geometry, but -1 also means "fd 1 is
  closed", and the branch would only serve a combination agnos does not
  ship.
