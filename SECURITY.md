# Security Policy

## Threat surface

BannerManor is an argument-input → stdout renderer. It reads its
text from argv and its font from a file; it never reads stdin (there
is no `read(0, ...)` anywhere in `src/`). It does not spawn
processes, open network sockets, or write to the filesystem beyond
standard output. The realistic threats:

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
  - **Font `name` / `description`, and the path echoed for a
    malformed font** — printed by `--list-fonts`, and sanitized the
    same way since 1.1.4 (F-011 / F-012). Before that they were the
    one font-to-terminal path with no filter.

## Reporting Vulnerabilities

Report vulnerabilities privately to **security@agnos.dev**. Do not
open public issues for security bugs.

We will acknowledge receipt within 48 hours and provide a timeline
for a fix.
