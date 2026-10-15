# Issue 0014 — the font readers' file buffers were never freed

**Reported**: 2026-08-25 (1.1.4 audit, accepted risk A-09); filed 2026-10-15
**Version**: 0.2.0 through 1.2.0
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **fixed in 1.4.1** (2026-10-15). Filed and archived together.
**Severity**: low. Graceful growth, no failure and no wrong output.

## Observation

Each font reader bump-allocated its read buffer (64 KB for CYML, 1 MB for
`.flf`) and never released it. For a single `--font` load that is
harmless, since the process exits a moment later. `--list-fonts`,
however, calls `font_header_load` once per font file, so its memory grew
with the number of fonts. Measured at 1.2.0 as peak RSS: 13.4 MB with 3
fonts, 16.7 MB with 200.

The obvious fix, `alloc_reset()` between fonts, is wrong. It invalidates
every bump pointer, including the vector of paths the listing loop is
still walking.

## Fix (shipped 1.4.1)

CLAUDE.md's convention: `fl_alloc` / `fl_free` for individual-lifetime
data. This was the first use in `src/`. The three readers' copies of the
read loop became one `_slurp(path, cap, out_len)` (`src/font.cyr`), which
`fl_alloc`s the buffer. Each reader split into a read and a parse
(`_font_parse`, `_font_header_parse`, `_flf_parse`), so the buffer is
freed in exactly one place per reader, after the parse:

```
var buf = _slurp(path, MAX_FILE_BYTES, &len_box);
if (buf == 0) { return 0; }
var h = _font_header_parse(buf, load64(&len_box));
fl_free(buf);       # the FontHeader holds copies, never pointers into buf
return h;
```

Freeing is safe because nothing returned points into the buffer. The Font
copies its rows and charmap out; the FontHeader copies `name` and
`description`. bayan's zero-copy doc does point into it, but the doc is
dropped inside the parse.

Buffers over 4 KB come straight from `mmap` and go back with `munmap`, so
the memory really is returned. `freelist` and `mmap` joined
`[deps].stdlib`.

Measured, peak RSS for `--list-fonts`:

| fonts | 1.2.0 | 1.4.1 |
|---|---|---|
| 3 | 13,424 KB | 13,396 KB |
| 50 | 13,528 KB | 13,496 KB |
| 200 | 16,704 KB | 13,300 KB |

The split was also what the fuzz harness needed (issue 0010): it drives
the parse halves directly, with no files.

## AGNOS

The AGNOS mmap is 2 MB-granular, so each transient buffer there
briefly maps 2 MB, and unmaps it before the next font. Not runtime-
verified (no AGNOS target here). The AGNOS build compiles through
freelist's AGNOS branch, which the stdlib's other AGNOS consumers already
use.
