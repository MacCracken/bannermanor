# 002 — `cyrius build` and `cyrius bench` restore `lib/` from the lock

**Invariant**: any file in `lib/` whose hash does not match `cyrius.lock` is
overwritten with the locked version before `cyrius build`, `cyrius bench`,
`cyrius test` or `cyrius fuzz` compiles anything. This applies to stdlib
modules and git dependencies alike, and `--no-deps` does not stop it.

## Why it is not obvious

Nothing says it happened. The command prints its usual output, and the file
you edited is quietly back to the locked bytes. Re-verified at cyrius 6.7.9
on a scratch copy of the tree: a byte appended to `lib/bayan-cyml.cyr` (a
git dependency) was undone by `cyrius build --no-deps`, and one appended to
`lib/string.cyr` (a stdlib module) was undone by `cyrius bench`.

## What it broke

The obvious way to A/B a dependency is to swap its file in `lib/`, rerun the
bench, and compare. That compares the library with itself. At 1.1.3 this
produced a published conclusion that "the 1.1.3 dep bump is bench-flat",
which carried through a full release. The real figure was a ~45% regression
in `font_load_file` from bayan 1.0.1 → 1.5.2. It was corrected at 1.1.4
(`docs/benchmarks.md` Point 4, issue 0006).

## How to A/B a library correctly

Point `CYRIUS_HOME` at a snapshot whose `lib/<module>.cyr` is the version
under test, so the restore puts back the version you meant to measure. Or
build each arm from its own tree, with its own pin, `lib/` and lock, as
`docs/benchmarks.md` Point 6 did with `git archive`. Run the control arm
through the same rig, never a number from an earlier session.

Swapping files in `src/` is fine: nothing restores `src/`. That is how 1.4.1
measured 1.2.0's write path against its own (`docs/benchmarks.md` Point 7).

## Corollary

CLAUDE.md's "do not modify `lib/`" is not only a policy. The toolchain
enforces it, silently. To change what `lib/` holds, change the manifest
(`[deps].stdlib`, a `[deps.<name>]` pin) and run `cyrius deps`. At 1.4.1,
`rm -rf lib/ && cyrius deps` regenerated it from scratch, then
`cyrius deps --locked` confirmed that `lib/` and the lock match.
