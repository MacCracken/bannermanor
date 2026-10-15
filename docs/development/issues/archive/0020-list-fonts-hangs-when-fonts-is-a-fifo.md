# Issue 0020 — `--list-fonts` hung when a search directory was a FIFO

**Reported**: 2026-10-15 (1.7.0, reading cyrius 6.7.11's migration notes)
**Version**: 1.5.0 and 1.6.0 confirmed, on Linux; earlier not checked
**Reporter**: maintainer
**Status**: **fixed in 1.7.0** by the toolchain (cyrius 6.7.11), not by a
bnrmr change. Filed and archived together.
**Severity**: low. An interruptible self-DoS that needs a FIFO named
`fonts` in the current directory, or `BNRMR_FONTS` pointing at one.

## Observation

Issue 0011 closed the hang on a FIFO *under* `fonts/`. A FIFO *at* a
search directory was a different path, and nothing covered it:

```
$ mkfifo fonts
$ timeout 3 bnrmr --list-fonts; echo $?
124
```

1.6.0's listing reads each search directory with the stdlib's
`dir_list_checked` (`_lr_scan_dir`, `src/cli.cyr`). Through cyrius 6.7.9
that opened the path `O_RDONLY`, and `open(2)` on a FIFO with no writer
blocks, before bnrmr prints a byte. 1.5.0, which walked `fonts/` with
`find_files`, hung the same way.

`--font NAME` was never affected: it `stat`s `fonts/NAME.cyml`, which
fails with `ENOTDIR` when `fonts` is not a directory, and reports the font
not found.

## Fix

cyrius 6.7.11 opens directories for listing with `O_DIRECTORY |
O_CLOEXEC` (its CHANGELOG, and ecosystem-migration LIB-2), so the kernel
refuses a non-directory at path resolution. With 1.7.0's re-vendored
`lib/fs.cyr`, the listing returns at once, exit 0:

```
Searched: ./fonts (unreadable: ./fonts)
```

On aarch64 the stdlib uses the arm64 value of `O_DIRECTORY` (`040000`,
which is x86_64's `O_DIRECT`); the aarch64 golden run under qemu passes.

## Regression cover

`t_list_dir_fifo` (`tests/bannermanor.tcyr`, 1.7.0) makes a FIFO at run
time and asserts `_lr_scan_dir` returns -1 with no rows. On a scratch tree
pinned back to cyrius 6.7.9 the suite hung in that test (its FIFO was
left behind when `timeout` killed the run), so it does fail on the old
behavior; in CI the 300 s test deadline turns a hang into a failure.
