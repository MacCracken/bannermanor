# Issue 0008 — a CYML glyph body is never required to be fully consumed

**Reported**: 2026-08-25 (1.1.4 audit, finding C-003); filed 2026-10-15
**Version**: 0.2.0 onward
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **open**, unblocked. [ADR 0002](../../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
ruling (3), accepted 2026-10-15, permits the fix. Scheduled for roadmap
1.5.0.
**Severity**: low. Correctness of the format contract, with no security
consequence: the extra bytes are never rendered.

## Observation

ADR 0001 says every entry body has "exactly `height` rows of exactly
`width` bytes". `_font_decode_body` (`src/font.cyr`) checks each of the
`height` rows, then stops. After the last row it looks at one byte. If
that byte is `\n`, anything after it is accepted without being read:

```
if (pos < blen) {
    if (load8(body + pos) != 10) { return 0 - 1; }
}
```

So a body with more rows than `height` loads, and the surplus rows are
silently dropped. Reproduced on 1.2.0 with a 3×3 font whose `I` glyph
carries two extra rows (`#.#`, `###`). It loads, exits 0 and renders
`I` from the first three rows. The surplus does not even have to be
glyph-shaped: after the `\n` the decoder reads nothing, so any bytes are
accepted. (Within a row the decoder is strict: a row longer than `width`
is rejected, because the byte after `width` must be `\n`.)

## Why it matters

Mostly authoring feedback. A font author who miscounts `height`, or
pastes a taller glyph into a shorter font, gets a font that loads and
renders a truncated glyph, where the format promises a rejection.
`bnrmr --list-fonts` cannot catch it either, because the header loader
never decodes bodies.

## Why it was gated

The fix is one line: reject `pos < blen` after the last row. But it
turns a font that loads today into a load failure (`--font NAME` exits
1 where it exited 0). That font violates the format's own documented
rule, and the freeze sentence did not say whether it protects such a
font. ADR 0002 ruling (3), accepted 2026-10-15, settles it: a font that
breaks a structural rule of its format is not protected. The fix is a
`Changed` entry in a 1.x minor, with the golden frozen tier
byte-identical and every in-tree font still loading.

## Acceptance

- A body with more than `height` rows, or any bytes after the last row's
  newline, is rejected by `font_load_file`.
- The three in-tree fonts and every committed golden record are
  unchanged: no shipped font has a surplus row (checked by the golden
  suite, which loads all three).
- A fixture with one surplus row, plus a test asserting it is rejected.
