# 0005 — The 2.0 charter: what 2.0 takes, and argv text is UTF-8

**Status**: Proposed
**Date**: 2026-10-30

## Context

The v1.0 freeze allows no flag changes and no exit-code or stdout-byte
changes for any valid invocation. Everything that needs one waits for a
major version. The roadmap's "Deferred to 2.0" section lists those items;
until now nothing decided which of them 2.0 actually takes. Two were also
waiting on groundwork, and one on a question no release had answered.

**The groundwork is done (1.10.0).** The `.flf` loader keeps each glyph's
own width and which cells were hardblanks, and the layout adds a banner up
glyph by glyph instead of `n * width + (n - 1) * gap`. Every glyph still
advances by the font's width, so nothing rendered moved. The golden suite
and all 1,051 corpus fonts are byte-identical to 1.9.0. Variable-width
glyphs are now a change to one function, `glyph_advance`. What that change
does was measured with it applied (a 1.10.0 mutant), over the reference
corpus (cmatsuoka/figlet-fonts and xero/figlet-fonts):

- **681 of the 1,045 fonts that load render different bytes.** The other
  364 are fixed-width fonts, whose glyphs are all one width already.
- **The in-tree fonts do not move.** block, slim, big and clean are CYML
  schema 1, where every glyph is the font's width by definition.
- **Glyph width is not always one number.** In 1,920 of the corpus's
  99,275 glyphs (110 fonts), the rows differ in length. figlet takes a
  glyph's width from its first row; 1.10.0 records its longest row. In
  1,415 of those glyphs the first row is shorter, so the two disagree.
  These counts come from a Python reading of the loader's rules, which
  accepts the same 1,045 fonts bnrmr does.

The roadmap's earlier measurement still frames the size of it: across 752
fonts bnrmr renders a median 1.74× wider than figlet, of which uniform width
accounts for 1.64× and missing smushing for 1.09×. 42% of corpus fonts
declare a smushing layout that figlet applies by default.

**Unicode is waiting on one question: what encoding is argv text in?**
Today every byte at or above 0x80 is a cell of its own, drawn as the space
glyph, so `bnrmr "Café"` renders five cells for four characters (golden
`default-non-ascii`). Fixing that needs a decoding, and a decoding needs a
rule:

- **Linux** passes argv as bytes. Their encoding is whatever the caller's
  terminal or script used, almost always UTF-8. bnrmr reads no locale
  variable, and the golden suite runs every case under `LC_ALL=C`.
- **AGNOS** typed input is ASCII: the keyboard maps scancodes through a US
  QWERTY table (agnos `kernel/arch/x86_64/keyboard.cyr`), and USB HID
  keyboards are translated into the same table. A script or a file can
  still put any bytes into argv.
- **figlet** reads input as single bytes unless it is given a control file
  (`-C utf8`, its `utf8.flc`).

## Decision

**2.0 takes variable-width glyphs, opt-in smushing, non-ASCII text, stdin,
and two accepted-risk fixes. argv text is UTF-8 on both targets, whatever
the locale.**

### What 2.0 takes

| Deferred item | In 2.0 | Why |
|---|---|---|
| Variable-width `.flf` glyphs | **Yes, the default** | The largest rendering defect left. Parity target `figlet -W`. Groundwork shipped in 1.10.0. A glyph's width is its longest row (1.10.0's record), not figlet's first row: shorter rows are padded and no glyph art is cut. That matches figlet on every glyph whose rows are one length, which is 98.1% of corpus glyphs and every glyph in 935 of 1,045 fonts. |
| CYML schema 2 | **Yes** | The CYML half of the two items above and below: a per-entry `width`, and `char` values above 127. Schema 1 still loads and renders exactly as in 1.x. |
| Smushing and kerning | **Yes, opt-in** | One new flag, whose spelling is settled with the design. The default stays full width (`figlet -W`), so this adds no byte change of its own. The freeze makes a flag a major-version question, so leaving it out means waiting for 3.0. If its design is not ready when the rest is, 2.0 ships without it rather than waiting. |
| Non-ASCII text | **Yes** | Decoding by the rule below; one cell per code point; the charmap covers code points; `.flf`'s German and code-tagged glyphs load. The in-tree font set stays ASCII, and no Unicode font set ships, so the "3–5 fonts" charter is not reopened. A character an in-tree font lacks becomes one blank cell instead of one per byte. |
| Reading stdin | **Yes** | `echo hi \| bnrmr` renders, as figlet does. Only when no TEXT is given and stdin is not a terminal, read up to the 1 KB cap. Bare `bnrmr` on a terminal still prints usage. A trailing newline is dropped. How an inner newline renders is part of the design (figlet starts a new banner). |
| `--color=` with an empty value (A-06) | **Yes** | One line. The fifth value-taking flag starts rejecting an empty value, as the other four do. |
| A sub-glyph `--width` printing nothing (A-05) | **Yes** | With variable widths, "smaller than one glyph" means "smaller than the first glyph", and the blank rows are output nobody asked for. |
| Forcing color, and turning it off | **No** | bnrmr writes color only when asked (`--color`), so `NO_COLOR` has nothing to switch off. Forcing color into a pipe has no consumer. Reopened only on a request. |
| CYML `name` checked against the filename stem (A-11) | **No, closed** | Since 1.6.0 `--list-fonts` shows the stem, and `name` is unused metadata. The check would only turn working third-party fonts into errors. |
| Library surface (roadmap 1.11.0) | **No** | It stays a 1.x item, gated on a consumer's request. It is additive and breaks nothing, and bundling an unrequested second frozen surface into a breaking release would only make 2.0 bigger. |

### argv text is UTF-8

- Every valid UTF-8 sequence decodes to one code point, which selects one
  glyph (one cell). ASCII is unchanged.
- A byte that does not begin a valid sequence is one cell of its own,
  drawn as the space glyph. That covers a stray continuation byte, an
  overlong form, a surrogate and anything past U+10FFFF. This is exactly
  how 1.x draws such a byte, so input that is not UTF-8 renders as it does
  today, except where it happens to form a valid sequence.
- bnrmr reads no locale variable, in 2.0 as in 1.x.
- The 1 KB input cap stays in bytes.
- Out of scope: the encoding of glyph art. Rows stay bytes and are scrubbed
  as today (F-001). Whether a `.flf` glyph may carry UTF-8 art, which the
  C1 scrub would cut, is a design question for 2.0, not this decision.

## Consequences

- **Positive** — 2.0 has a fixed scope that can be planned and reviewed.
- **Positive** — the common case does not move. `bnrmr TEXT` with an
  in-tree font and ASCII text renders the same bytes in 2.0: those fonts
  are schema 1, so variable width leaves them alone, and smushing is
  opt-in. What moves for them is the edge cases this ADR names: A-05's
  sub-glyph `--width`, A-06's `--color=`, and piped stdin with no TEXT,
  which prints the usage text today.
- **Positive** — `.flf` output approaches figlet's, which is what someone
  pointing `--font` at a figlet font expects. For 681 of 1,045 corpus fonts
  it gets narrower.
- **Negative** — every user of a variable-width figlet font sees different
  bytes. That is the point, and it is why the change waits for 2.0.
- **Negative** — a new flag, a second CYML schema to keep loading, and a
  UTF-8 decoder on untrusted input. The decoder joins the fuzz harness on
  day one.
- **Neutral** — 2.0 needs its own freeze sentence. The golden suite's
  frozen tier forks: 1.x records stay for the 1.x branch, and 2.0 records
  are reviewed with `scripts/flf-corpus.sh` as the diff tool (1.10.0's
  corpus check, 1.9.0 against 2.0).
- **Neutral** — the roadmap's "Deferred to 2.0" section becomes the 2.0
  plan, minus the two items closed here.

## Alternatives considered

- **Decode argv by the locale** (`LC_ALL`, `LC_CTYPE`, `LANG`). Output would
  then depend on the environment as well as the arguments. AGNOS has no
  locale, and the golden suite, which runs `LC_ALL=C`, would be testing
  byte mode. Rejected.
- **Latin-1: every byte is a code point,** as figlet without a control file.
  A UTF-8 `Café` would still render five cells, the defect this item exists
  to fix. Rejected.
- **Smushing by default** (the font's declared layout, figlet's default).
  It would move bytes for the 42% of corpus fonts that declare a layout, on
  top of variable width, and make the default depend on font metadata. The
  parity target set for 2.0 is `figlet -W`. Rejected as the default; the
  flag provides it.
- **Leave smushing to 3.0.** It is held for 3.0 only if its design is not
  ready when the rest of 2.0 is. It is not dropped outright, because the
  hardblank groundwork is already in place.
- **Use figlet's first-row width.** Byte parity with figlet on 1,415 more
  glyphs, but each of them would have rows longer than its own width, so
  they would overlap the next glyph or be cut. Rejected.
