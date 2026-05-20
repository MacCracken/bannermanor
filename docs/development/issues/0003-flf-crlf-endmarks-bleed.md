# Issue 0003 — CRLF-line `.flf` fonts bleed endmark bytes into output

**Reported**: 2026-05-20
**Version**: 0.8.0
**Reporter**: maintainer (M7 dogfood — added `modular.flf` to repo top
level for testing, third-party JavE-exported FIGlet font from 2006)
**Status**: real bug, fix proposed for 0.9.0
**Severity**: rendering correctness (cosmetic, no security impact)

## Observation

`./build/bnrmr --font ./modular.flf "BNRMR"` renders:

```
 _______ #  __    _ #  ______  #  __   __ #  ______  #
|  _    |# |  |  | |# |    _ | # |  |_|  |# |    _ | #
| |_|   |# |   |_| |# |   | || # |       |# |   | || #
|       |# |       |# |   |_|| # |       |# |   |_|| #
|  _   | # |  _    |# |    __ |# |       |# |    __ |#
| |_|   |# | | |   |# |   |  ||# | ||_|| |# |   |  ||#
|_______|##|_|  |__|##|___|  ||##|_|   |_|##|___|  ||##
```

Every glyph row ends with a literal `#` byte. The last row of each
glyph ends with `##`. These are the FIGlet **endmarks** — they
should be stripped by the loader, not rendered.

## Root cause

`modular.flf` uses **Windows CRLF line endings** (`\r\n`), confirmed
via `cat -A`:

```
flf2a$ 7 7 11 -1 11 0 0 0^M$
...
$ #^M$       ← first glyph row 0
$ #^M$
$ #^M$
...
$ ##^M$      ← first glyph last row (doubled endmark)
```

`src/flf.cyr`'s endmark auto-detection reads the byte immediately
preceding `\n`:

```
# src/flf.cyr ~ line 201
if (r == 0) {
    endmark = load8(buf + line_end - 1);
}
```

For a CRLF line, `buf[line_end - 1]` is `\r` (0x0D), **not** the
actual endmark `#`. The subsequent strip-trailing-endmark loop then
strips trailing `\r`s, which yes there is exactly one of, but
**leaves the actual `#` endmarks in the row data**. F-001's
control-byte scrub doesn't help here — the `\r`s have already been
stripped by the time the row bytes are copied; the `#`s are
printable and pass through.

The downstream effect: every glyph row is one byte wider than the
font intended, and the rightmost column is always the endmark
character. For `modular.flf` specifically the endmark is `#`, but
the same bug applies to any CRLF `.flf` with any endmark — `@`, `$`,
whatever.

## Why our existing fixtures didn't catch this

`tests/fixtures/tiny.flf` and `tests/fixtures/flf_esc_glyph.flf`
were both authored as raw bytes via `printf` / Python, both with
Unix LF line endings. CRLF was not in the test matrix.

## Proposed fix (for 0.9.0)

In `flf_load_file`, before computing the endmark and stripping
trailing bytes, trim a trailing `\r` from each line. A 3-line
change:

```cyrius
# After: var line_end = _flf_eol(buf, total, cursor);
var actual_end = line_end;
if (actual_end > line_start && load8(buf + actual_end - 1) == 13) {
    actual_end = actual_end - 1;
}
# Then use actual_end where the current code uses line_end for
# llen / endmark detection. cursor still advances past line_end + 1
# (the original \n position) so file traversal is unchanged.
```

This treats `\r\n` as the line terminator on input without altering
the byte-offset bookkeeping. Pure Unix-LF files are unaffected
(the trim is a no-op when the byte is not `\r`).

### Test additions

- New fixture `tests/fixtures/flf_crlf.flf` — minimal CRLF-line
  `.flf` (e.g., re-encoded `tiny.flf` with `\r\n`).
- Assertion: `flf_load_file` of the CRLF fixture produces a Font*
  whose glyph rows contain none of the endmark byte.
- Regression check that the existing LF-line `tiny.flf` still
  produces identical bytes (no behavior change for LF).

## Real-world significance

A non-trivial fraction of `.flf` fonts in the wild are CRLF — many
were authored on Windows (the JavE FIGlet export tool used for
`modular.flf` is a Java app that historically wrote CRLF). Without
this fix, `bnrmr` is silently miscompatible with that body of
fonts, with a failure mode that looks like a font-design feature
("oh, this font just has shadow `#`s") rather than a parser bug.

## Decision

Fix lands in **0.9.0** alongside benchmark point #3 — clean release
cargo that closes M7's dogfood-finds-and-resolves loop.
