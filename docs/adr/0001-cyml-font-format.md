# 0001 — CYML font format

**Status**: Accepted
**Date**: 2026-05-19

## Context

BannerManor needs a font format. The two real options were the legacy
figlet `.flf` format and a CYML schema authored in-tree.

`.flf` is the path of least resistance for adoption — decades of
public-domain figlet fonts exist — but the format is brittle:
hand-edited single-line header (`flf2a$ 6 5 16 15 11 ...`), a
character-marker convention (`$`, `@`, `@@`) that's invisible to most
editors, no metadata beyond the header magic, and an implicit
"smushing" character-overlap algorithm that's hard to specify rigorously.

CYML is the agnosticos toolchain's native format: TOML header on top,
markdown body below, multi-entry via `[[entries]]`. Cyrius ships a
parser in `lib/cyml.cyr`. Authoring is editor-friendly (TOML highlight
+ raw text body), metadata is structured, and the format is already
familiar to anyone touching agnosticos.

Two practical issues with CYML for *glyph data* specifically:

1. `_cyml_trim` strips leading and trailing whitespace from entry bodies.
   A naive ` `/`#` glyph grid loses its left and right columns to the trim.
2. Multi-entry parsing is bounded at 256 entries — fine for ASCII fonts,
   but a hard wall for any future Unicode-coverage goal.

(2) is out of scope for v1.0 (CLAUDE.md restricts coverage to ASCII).
(1) needs a workaround.

## Decision

**The canonical font format for BannerManor is CYML, multi-entry, one
entry per glyph. `.flf` is supported in M6 as a read-only adapter only;
it is never the canonical format.**

### File-level header

```toml
[font]
schema = 1
name = "block"
description = "Block font: 5 rows tall, 5 cols wide"
width = 5
height = 5
gap = 1
author = "BannerManor"
license = "GPL-3.0-only"
```

- `schema` — format version. Bumped on any breaking shape change. Loader
  rejects unknown values.
- `width`, `height`, `gap` — geometry. Every glyph body must match.
- `name` — must match the file stem (`block.cyml` → `name = "block"`).
- `description`, `author`, `license` — informational; used by
  `--list-fonts` (M3).

### Per-glyph entries

```toml
[[entries]]
char = "A"
---
.###.
#...#
#####
#...#
#...#
```

- `char` — exactly one ASCII byte. Quoted TOML string. Space is `" "`.
- Body — exactly `height` rows, each exactly `width` bytes, each byte
  one of `.` (background) or `#` (stroke). Loader maps `.` to ASCII
  space (32) at parse time and stores the row as a `width`-byte buffer.

### Why `.` for background

`_cyml_trim` in `lib/cyml.cyr` strips leading whitespace from entry
bodies, which would destroy any glyph whose first row starts with a
space (most of them) and the entire space glyph. Using a non-whitespace
sentinel for background — `.` here — sidesteps the trim entirely.

`#` and `.` are also the conventional ASCII art "ink" and "paper"
characters, so the format reads naturally without a key.

### Validation (loader contract)

- File size ≤ 64 KB.
- File-level `[font]` block parses and contains schema, width, height,
  gap, name.
- `schema` is in the supported set (currently `{1}`).
- Every entry has a single-byte `char`.
- Every entry body has exactly `height` rows of exactly `width` bytes.
- Every body byte is either `.` (0x2E) or `#` (0x23).
- Duplicate `char` values are rejected.
- Unknown TOML keys are ignored (forward-compat headroom).

Anything else returns a load failure; the CLI prints a clear error and
exits non-zero. No partial-font fallback — a malformed font file is a
user-fixable error, not a runtime degradation.

## Consequences

**Positive.**
- Authoring is plain text, plain editor. No special tooling.
- Metadata is structured and queryable (M3's `--list-fonts` is trivial).
- Schema versioning is explicit — future breaking changes are
  expressible without ambiguity.
- Both the in-tree default font and on-disk fonts go through the same
  `Font*` struct, so the renderer has one code path.

**Negative.**
- We do not consume figlet's font library directly — every default font
  is authored in-tree. M6 (.flf read path) closes this for users with
  existing `.flf` collections; it does not solve the in-tree question.
- `.` for background is a learned convention. Anyone copying glyphs out
  of a figlet font must transliterate spaces to `.`.
- The 256-entry cap in `lib/cyml.cyr`'s parser blocks Unicode-coverage
  fonts. Acceptable through v1.0 (ASCII-only by charter); a Unicode
  story would need either a parser upgrade or a different
  glyph-encoding shape.

**Neutral.**
- The format is BannerManor-specific. Other agnosticos tools that
  consume ASCII art (none today) would need to either share this loader
  or define their own.
- Schema-versioning gives us a clean migration path but obligates us to
  maintain backward compatibility for `schema = 1` once a `schema = 2`
  exists.

## Alternatives considered

**`.flf` as the canonical format.** Rejected. The format is fragile,
metadata-poor, and the smushing semantics are out of scope for v1.0.
We get the user-facing benefit (existing fonts work) via the M6 adapter
without inheriting the format's authoring problems.

**Single-entry CYML with all glyphs in one body.** Rejected. Would
require an in-body separator convention; gives up free per-glyph
metadata (e.g., per-glyph `width` for future variable-width fonts).
Multi-entry is the format's native shape.

**Glyph rows in the TOML header as a quoted array
(`rows = ["...", "...", ...]`).** Rejected. `lib/toml.cyr` parses
arrays as opaque bracketed-byte blobs; we'd still need a custom array
parser, with worse authoring ergonomics (every row quoted and
comma-separated on one logical line) and no real upside.

**Pure space/`#` body with a per-row sentinel prefix** (e.g., leading
`|` stripped by the loader). Rejected. Adds visual noise without a
benefit `.` doesn't already deliver.

**JSON / YAML.** Rejected. Both require stdlib machinery we don't
otherwise need; neither buys anything over CYML for this use case;
CYML is the agnosticos default.
