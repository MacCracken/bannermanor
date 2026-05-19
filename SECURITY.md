# Security Policy

## Threat surface

BannerManor is a stdin / argument-input → stdout renderer. It does
not spawn processes, open network sockets, or write to the
filesystem beyond standard output. The realistic threats:

- **Input-length DoS** — unbounded text input exhausting memory
  or producing pathologically large output. The 1 KB input cap is
  load-bearing.
- **Malformed font file** — a crafted `.cyml` or `.flf` font that
  triggers parser bugs (out-of-bounds reads, integer overflow,
  infinite loops).
- **ANSI escape injection** — if a font emits raw ANSI sequences,
  it could alter terminal state in surprising ways. BannerManor
  routes all color through darshana; fonts that include literal
  escapes in glyph data are rejected at parse time.

## Reporting Vulnerabilities

Report vulnerabilities privately to **security@agnos.dev**. Do not
open public issues for security bugs.

We will acknowledge receipt within 48 hours and provide a timeline
for a fix.
