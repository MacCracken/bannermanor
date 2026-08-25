# Issue 0017 — documentation precision pass (deferred from the 1.1.4 audit)

**Reported**: 2026-08-25
**Version**: 1.1.4 (audit deferral)
**Reporter**: maintainer
**Status**: **open** — scheduled for 1.2.1
**Severity**: documentation — a font author would write a wrong font

## Scope

The 1.1.4 audit fixed the substantive documentation defects and deferred
the precision work. These are the deferred items, all verified against
the code at 1.1.4.

### `docs/guides/fonts.md` + `docs/adr/0001-cyml-font-format.md`

1. **`name` is documented as required and stem-matching.** Neither is
   enforced on the render path — `font_load_file` never reads `name` at
   all, and nothing anywhere compares it to the filename. Only
   `font_header_load` (the `--list-fonts` preview) requires it.
2. **One validation list is presented for two loaders with different
   gates.** `--font NAME` and `--list-fonts` can disagree in both
   directions: a font with a bad body byte lists clean but fails to
   render; a font missing `name` renders but lists as malformed.
3. **The zero-entry rejection is undocumented.**
4. **Geometry rejection is stated as "any < 0"** when `width == 0` and
   `height == 0` also reject.
5. **The entry cap is published as 256.** The charmap is 128 bytes and
   `font_set_char` rejects any char >= 128, so >128 entries cannot load.
   State both numbers and which one binds.
6. **The size gate is stated as "exceeds 64 KB"** when the code rejects
   at `>= 65536` — a file of exactly 64 KB is refused.
7. **ADR 0001 should record the `cyml_expand_value` policy.** bnrmr must
   never call it from a font loader (`${file:}` / `${env:}` expansion is
   package-metadata-only). The rule has held across two audits but lives
   only in audit prose, and it is the constraint a future loader
   extension would violate first.

### `src/color.cyr` and the `--color` error text

`src/color.cyr` documents a separator-less `brightX` form that does not
parse — `--color brightred` exits 1. The error text also omits the
`bright-<name>` dash alias that `--help` gained in 1.1.4, so the two
user-facing surfaces now disagree with each other.

**Do not** add the missing `streq` arms: that widens a frozen flag
surface. Fix the prose to match the code.

### `src/layout.cyr` and `state.md`

Both still say a sub-glyph `--width` renders "nothing". It renders
`height` blank rows — SGR-wrapped on a TTY, plus any `--pad` lines.
`--help` was corrected at 1.1.4; these two were not.

### `print_usage`

Add a `--` line. The terminator works (`bnrmr -- "-HI"` renders) but is
undiscoverable, and the error a user actually hits names "bundled short
flags", which is not what they did wrong.

Document the 128-positional cap — reachable with ordinary input, since
128 five-letter words is 767 bytes and passes the 1 KB text cap.

## Acceptance

Every documented constraint is enforced, and every enforced constraint
is documented — checked in both directions. No `src/` behavior change;
the golden suite proves it.
