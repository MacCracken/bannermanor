# Issue 0018 — AGNOS: the console width is never queried

**Reported**: 2026-10-12
**Version**: 1.1.5 (present since AGNOS became a target at 1.1.0)
**Reporter**: darshana's consumer survey (2026-10-12); confirmed by reading the source
**Status**: **fixed in 1.2.0** (2026-10-12)
**Severity**: rendering correctness on AGNOS — issue 0004's class, on the
other target. No security impact.

## Observation

`term_width_ioctl` (`src/layout.cyr`) hard-returned 0 on AGNOS:

```cyrius
fn term_width_ioctl(): i64 {
    # AGNOS has no ioctl/TIOCGWINSZ — return 0 so callers fall back to the
    # default width (the fb console size isn't queryable from userland yet).
    #ifdef CYRIUS_TARGET_AGNOS
    return 0;
    #endif
    ...
```

The premise is false. agnos exposes the live framebuffer console grid as
syscall #60, `winsize` — the stdlib's `sys_winsize()`, returning
`(cols << 16) | rows`, or -1 when the framebuffer is not up — and
darshana's AGNOS `tty_winsize` wraps it with the Linux peer's contract.
That function was already linked into every AGNOS `bnrmr`; nothing called
it.

With the width probe stuck at 0, three things never happened on AGNOS:

1. **Issue 0004's narrow-terminal truncation never engaged.** A banner
   wider than the console wrapped into itself, row by row — the exact
   defect 0004 fixed on Linux at 1.0.0.
2. **`--align center|right` aligned inside `$COLUMNS` or 80 columns**,
   whatever the console's real width.
3. **The F-008 `WS_COL_CAP` clamp never executed there**, leaving
   `$COLUMNS` the only AGNOS frame source (the 1.1.4 audit's F-013 note).

`stdout_is_tty`'s AGNOS arm carried a companion premise, "the fb console
renders glyphs literally and doesn't interpret ANSI escapes", also false
since agnos 1.43.1 (`fb_ansi_feed`, an SGR/CSI interpreter in the FB
console). Its return value stays 0 for a different reason — see below.

## Fix (shipped 1.2.0)

Both probes now go through darshana's `tty_winsize(1, …)` (issue
[0019](0019-darshana-probes-hand-rolled.md)), which bridges the two
targets. On AGNOS that is the console grid.

**Behavior change on AGNOS, deliberate:**

- On the console, a banner with no `--width` truncates at the console
  width on a glyph boundary, and center/right alignment uses the console
  width. `$COLUMNS` is consulted only when the framebuffer console is down
  (the query returns -1).
- **A redirected or piped stdout gets the same geometry.** agnos has no
  per-fd terminal query, and darshana's AGNOS `tty_winsize` ignores its
  `fd` — the grid is a property of the framebuffer, not of fd 1. So on
  AGNOS `bnrmr X | cat` and `bnrmr X > file` truncate and align to the
  console width, where Linux leaves piped output untruncated (the M1
  byte-identity contract 0004 preserved for pipes). The bytes are plain
  text either way. agnos does redirect stdout for real (`exec_redirect`
  #62, agnos 1.45.15), so this is reachable.

**Not changed: color on AGNOS stays off.** `stdout_is_tty` still returns
0 there. darshana's AGNOS `tty_isatty` answers 1 whenever the console is
up, a redirected fd 1 included, so following it would write SGR into
`bnrmr --color red X > /etc/motd` — the Linux contract is plain bytes on a
non-TTY. The width and the color decision diverge on AGNOS on purpose: a
wrong width costs a plain-text line length, a wrong TTY verdict puts
escape bytes in a file. Color on AGNOS waits for an agnos fd-kind query
(darshana has filed the per-fd `tty_isatty` with agnos).

**Linux is unchanged**: byte-identical across a 224-invocation golden
matrix (every font, the `.flf` path, every alignment, width, pad, color
and error path; 112 piped and 112 on a pty at seven window sizes), on
x86_64 and on aarch64 under qemu.

## Verification

- `cyrius build --agnos` compiles `term_width_ioctl` through darshana's
  AGNOS arm.
- **Not runtime-verified on AGNOS** — there is no AGNOS target in this
  environment, and an `--agnos` binary cannot be run on the Linux host
  past its first `winsize` call: agnos #60 is Linux `exit`.
- The clamp and zero-column rule are a pure helper, `_usable_cols`, shared
  by both targets and tested on x86_64 and aarch64 (`t_usable_cols` — the
  suite itself does not run on AGNOS); darshana's own suite tests the
  AGNOS decode (`_agnos_winsize_unpack`).
