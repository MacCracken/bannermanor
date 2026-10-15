# Issue 0011 — `--list-fonts` hung on a FIFO under `fonts/`

**Reported**: 2026-08-25 (1.1.4 audit, accepted risk A-08); filed 2026-10-15
**Version**: 0.3.0 through 1.1.5, on Linux
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **fixed in 1.2.0** by the toolchain, not by a bnrmr change.
Filed and archived together at 1.4.1, when the issue register was
reconciled.
**Severity**: low. An interruptible self-DoS that needs an
attacker-writable CWD.

## Observation

1.1.4 gated all three font readers on `S_IFREG`, so `--font NAME` no
longer blocks on a FIFO. `--list-fonts` still did, and not in bnrmr's
code. `cmd_list_fonts` calls `find_files("fonts", ".cyml")`, which walks
with `dir_walk`, which asks `is_dir` about every entry. On Linux, 1.1.5's
vendored `lib/fs.cyr` answered by opening the path:

```
fn is_dir(path: Str): i64 {
    var fd = sys_open(str_data(path), O_RDONLY, 0);    # blocks on a FIFO
```

`open(2)` on a FIFO with no writer blocks. So any FIFO under `fonts/`
hung the listing, even one the extension filter would have skipped
(`fonts/notafont.txt`), and before bnrmr printed its header line. The
audit left it as accepted risk, because the blocking site was in `lib/`,
which CLAUDE.md forbids editing.

## Fix

cyrius 6.6.10 rewrote the Linux `is_dir` to ask `stat(2)` instead of
`open(2)`. Its own comment explains why: a directory you may not read
was reported as a file and its subtree vanished. That `lib/fs.cyr`
reached bnrmr with 1.2.0's `lib/` re-vendor. Verified on 1.2.0 with
FIFOs at `fonts/notafont.txt`, `fonts/hang.cyml` and
`fonts/sub/deep.cyml`. `--list-fonts` exits 0 at once, listing the two
`.cyml` FIFOs as `(malformed — skipped)`: the header loader's
`S_IFREG` gate rejects them without opening them. `--font hang` exits 1.

The roadmap's planned fix (enumerate with `dir_list`, which opens only
the directory) is no longer needed for the hang. It is still the way to
make `--list-fonts` stop recursing (roadmap, "Fonts findable").

## AGNOS

The AGNOS branch of `is_dir` still opens the path, with `AO_DIRECTORY`.
On Linux, `O_DIRECTORY` makes `open(2)` fail fast on a non-directory. No
AGNOS runtime is available here to confirm that agnos does the same.
Recorded rather than asserted.

## Regression cover

None committed: git cannot hold a FIFO, so the golden suite cannot carry
one. `t_reader_fifo` (`tests/bannermanor.tcyr`, 1.4.1) creates a FIFO at
run time and pushes it through all three readers, which covers the
reader gate. The walker half belongs to the stdlib.
