# 001 — No raw syscall numbers in `src/`

**Invariant**: every system call bnrmr makes goes through a stdlib wrapper
(`lib/io.cyr`'s `file_open` / `file_read` / `file_write` / `file_close` /
`xstat`, `lib/syscalls*.cyr`'s `sys_*`) or a named constant (`SYS_EXIT`).
`src/` contains no `syscall(<number>, ...)`. Since 1.4.1 that has been true
of every site. Before that it was true of every site except stdout writes,
and those were safe only by coincidence.

## Why it is not obvious

bnrmr builds for three targets: x86_64 Linux, aarch64 Linux and AGNOS. A raw
syscall number means something different, or nothing, on each. Code with raw
numbers compiles cleanly everywhere, and `cyrius lint` does not look at
syscall arguments. So a wrong number is invisible until the binary runs on
the target, and there is no AGNOS runtime in CI.

## Why the stdout writes happened to be safe

Through 1.2.0, `src/layout.cyr` and `src/main.cyr` wrote stdout with
`syscall(1, 1, buf, n)` at 19 sites. That was correct on all three targets,
for three reasons that have nothing to do with each other:

1. **x86_64 Linux**: `write` is syscall 1.
2. **AGNOS**: `SYS_WRITE` is also 1, with the same argument order
   (`lib/syscalls_x86_64_agnos.cyr`). Nobody designed this; AGNOS's numbering
   just agrees with Linux here.
3. **aarch64 Linux**: `write` is 64, not 1. But the aarch64 backend
   translates x86_64 numbers passed as literals (its ESYSXLAT chain maps
   1 → 64), so `syscall(1, ...)` works there too. Confirmed at 1.1.4 by
   disassembly and by byte-identical output under qemu.

The 1.1.4 audit accepted this (A-10) and noted that the safety was
accidental.

## The counterexample that shipped

The three font readers used the same pattern for `open` / `read` / `close`:
`syscall(2, ...)`, `syscall(0, ...)`, `syscall(3, ...)`. On x86_64 Linux,
and on aarch64 through the translation, those are right. On AGNOS, 2 is
`getpid`, 0 is `exit` and 3 is `spawn`. So the "open" returned the
process's pid, a positive number that passed the `fd < 0` check, and the
following "read" exited the process. Every `--font` and `--list-fonts` on
AGNOS died silently, from 1.1.0, when AGNOS became a target, until 1.1.4.
That is four releases. Lint was clean throughout, and so were the Linux
build, tests and golden diff.

The fix (1.1.4) routed them through `lib/io.cyr`, whose wrappers carry the
per-target bridge. AGNOS's `open` is `(name, namelen, ao_flags)` with its
own flag bits, so a corrected number alone would still have been wrong.
1.4.1 did the same for the writes: `_emit` in `src/layout.cyr` calls
`file_write`, and every stdout byte bnrmr writes itself goes through it.

## How to keep it

- `grep -n 'syscall(' src/` should show only named constants (`SYS_EXIT`).
  Lint will not tell you: it is a style scanner and never reads syscall arguments.
- A new kind of call goes through a stdlib wrapper. If none exists, gate it
  `#ifdef CYRIUS_TARGET_AGNOS` and say why, as `stdout_is_tty` does.
- The test harnesses are held to the same rule (1.4.1 replaced their
  `syscall(60, ...)`, which is `exit` on x86_64 only, with `SYS_EXIT`).
  `SYS_EXIT` is 93 on aarch64 and 0 on AGNOS.
