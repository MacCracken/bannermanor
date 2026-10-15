# Security Policy

## Threat surface

BannerManor is an argument-input → stdout renderer. It reads its
text from argv and its font from a file; it never reads stdin (there
is no `read(0, ...)` anywhere in `src/`). It does not spawn
processes, open network sockets, or write to the filesystem beyond
standard output and standard error.

What it reads besides argv: two environment variables (`COLUMNS`, and
`BNRMR_FONTS` since 1.6.0) and, for `--font NAME` and `--list-fonts`,
the font directories on its search path ([ADR
0003](docs/adr/0003-font-search-path.md)): `$BNRMR_FONTS`, `./fonts`
under the current directory, and `<prefix>/share/bannermanor/fonts`
beside an installed `<prefix>/bin/bnrmr`. A font `NAME` cannot contain
`/`, `\`, `.` or a control byte, so it cannot leave whichever directory
it is joined to. `BNRMR_FONTS` is refused if it holds a control byte.
Running `bnrmr --list-fonts` or `--font` in a directory someone else
controls means reading their `./fonts`. That is why every font string
that reaches the terminal is sanitized (below).

The realistic threats:

- **Input-length DoS** — unbounded text input exhausting memory
  or producing pathologically large output. The 1 KB input cap is
  load-bearing.
- **Malformed font file** — a crafted `.cyml` or `.flf` font that
  triggers parser bugs (out-of-bounds reads, integer overflow,
  infinite loops).
- **ANSI escape injection** — a font file is untrusted data, and
  bnrmr writes font-derived bytes straight to a terminal. All color
  is routed through darshana; no ANSI is ever emitted inline. Font
  content is handled by three different mechanisms, which are worth
  stating separately because they differ:
  - **CYML glyph bodies** — only `.` and `#` are legal. Any other
    byte *rejects* the font (`src/font.cyr`).
  - **`.flf` glyph rows** — *sanitized* in place, not rejected: C0
    (`0x00-0x1F`), DEL and C1 (`0x80-0x9F`) are folded to spaces
    (`src/flf.cyr`, the F-001 fix from 0.7.0).
  - **Font `description`, and any path echoed for a malformed or
    unusable font** — printed by `--list-fonts` and in diagnostics,
    and sanitized since 1.1.4 (F-011 / F-012): the same byte set
    becomes spaces in the listing and `?` in a diagnostic. Before
    1.1.4 they were the one font-to-terminal path with no filter.
- **Echoed argv** — since 1.5.0 a parse error names the flag that was
  typed (`bnrmr: unknown flag: --bogus`), on stderr. The echo shows
  C0, DEL and C1 bytes as `?` and is cut at 64 bytes.

## Reporting Vulnerabilities

Report vulnerabilities privately to **security@agnos.dev**. Do not
open public issues for security bugs.

We will acknowledge receipt within 48 hours and provide a timeline
for a fix.
