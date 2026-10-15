# Issue 0007 — positionals past the 128th were silently discarded

**Reported**: 2026-08-25 (1.1.4 audit, finding B-002); filed 2026-10-15
**Version**: 0.4.0 through 1.1.5
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **fixed in 1.2.0** by the toolchain, not by a bnrmr change.
Filed and archived together at 1.4.1, when the issue register was
reconciled.
**Severity**: low. A valid invocation lost part of its text with exit 0.

## Observation

`bnrmr` joins its positional arguments with spaces into the render text,
capped at 1 KB. The argv count is capped at 256 (`src/main.cyr`). Between
those two limits, the stdlib flag parser stopped storing positionals at its
initial capacity and dropped the rest without a word:

```
fn _flags_push_positional(h, tok): i64 {
    var pc = load64(h + 40);
    if (pc >= load64(h + 32)) { return 0; }     # FLAGS_POS_MAX = 128: dropped
    ...
```

(`lib/flags.cyr` from the scaffold, `1a53bae`, through 1.1.5's vendored
copy.) So `bnrmr $(seq 1 200)`, or 200 one-letter words — 399 bytes,
well under the text cap — rendered the first 128 and exited 0.

## Fix

The cyrius 6.7.9 `lib/` re-vendor at 1.2.0 brought a `lib/flags.cyr`
whose positional array doubles when full; a refused growth is
`FLAG_ERR_NOMEM`, never a silent drop. bnrmr's error switch prints
`bnrmr: argument parse error` for that code and exits 1.

## Not recorded at the time

1.2.0's CHANGELOG states that its 224-invocation golden matrix is
byte-identical to 1.1.5. That was true of the matrix, but the matrix had
no case past 128 positionals, so this output change shipped unrecorded.
It is a correction rather than a contract break: the old output was the
defect.

## Regression cover

`tests/golden/cases.sh`: `positionals-200-past-128` renders all 200
words; `positionals-255-at-argc-cap` sits at the argc limit;
`positionals-256-too-many` is rejected. These records are what the cmdit
migration had to reproduce, since cmdit capped positionals at 128 until
its 1.3.1. It did: 1.4.2 moved to cmdit 1.4.0 with all three
byte-identical.
