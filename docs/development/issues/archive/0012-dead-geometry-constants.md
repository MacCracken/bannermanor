# Issue 0012 — named geometry limits declared and never used

**Reported**: 2026-08-25 (1.1.4 audit, refuted finding 1, "deferred as issue
0012"); filed 2026-10-15
**Version**: 0.2.0 through 1.2.0
**Reporter**: maintainer (P(-1) hardening pass)
**Status**: **fixed in 1.4.1** (2026-10-15). Filed and archived together.
**Severity**: maintainability. No defect: every constant equalled the
literal written in its place.

## Observation

Five enums declared the limits the code enforces, and the code ignored
them, repeating the literals instead:

- `FontLimits` (`src/font.cyr`): `MAX_FILE_BYTES`, `MAX_WIDTH`,
  `MAX_HEIGHT`, `MAX_GLYPHS`, `SUPPORTED_SCHEMA`, `HDR_NAME_CAP`,
  `HDR_DESC_CAP`. All unused; only `PARSER_INT_CAP` was referenced.
- `FontField` / `FontHdrField`: the struct offsets, unused. The accessors
  spelled `f + 8`, `h + 24`.
- `FlfLimits` (`src/flf.cyr`): all six unused.
- `MainLimits` (`src/main.cyr`) and `RenderLimits` (`src/render.cyr`):
  unused.

The audit refuted this as a *bounds* finding: every literal matched its
constant, and the one guard that looked unreachable was bounded by
another. But it is the kind of drift that turns into a bounds bug the
first time someone changes one copy and not the other.

## Why it was not mechanical

- **The literal 32 means three things in `src/flf.cyr`**: the first glyph's
  char code (`FLF_FIRST_CH`), the height cap (`FLF_MAX_HEIGHT`), and the
  space byte that hardblanks and control bytes are rewritten to. A
  search-and-replace would have tied the space byte to a geometry limit.
  The space byte stays a literal, commented at each site.
- **`flf.cyr`'s constants were commented "match font.cyr"**, but they are
  not the same limit. `MAX_WIDTH` / `MAX_HEIGHT` are CYML schema 1, frozen
  at v1.0. `FLF_MAX_WIDTH` / `FLF_MAX_HEIGHT` are how large a FIGfont the
  adapter agrees to load, which the roadmap raises in 1.5.0 (ADR 0002
  ruling 3 permits it). The comment was exactly the instruction that would have
  changed both together.

## Fix (shipped 1.4.1)

- Wired in everywhere the literal named the same quantity: geometry
  checks, struct offsets, buffer sizes, the `.flf` glyph count and stride,
  the 1 KB input cap.
- Added the two limits that had no name: `MAX_GAP` (16) and
  `CHARMAP_SIZE` (128, the binding entry limit, as opposed to the
  `MAX_GLYPHS` policy cap).
- `MAX_INPUT` moved from `render.cyr` into `layout.cyr`, where the cap is
  enforced, and replaced `main.cyr`'s duplicate `BUF_CAP`.
  `FONT_PATH_CAP` names the 80-byte path buffer.
- `flf.cyr`'s comment now says why its limits are separate from
  schema 1's.

**No code change.** cyrius folds an enum constant into the same
instruction as its literal: a minimal program built both ways is
byte-identical, and each extra enum member adds 8 bytes. The bnrmr
binary grew by exactly 16 bytes, for three new members less one removed.
The golden suite is byte-identical across the change.
