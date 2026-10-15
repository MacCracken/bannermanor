# Authoring a CYML font for BannerManor

This guide walks you through adding a new font to `fonts/`. The
canonical format and rationale live in
[`../adr/0001-cyml-font-format.md`](../adr/0001-cyml-font-format.md);
this is the practical how-to.

## What you'll produce

A single file, `<name>.cyml`, that BannerManor can:

- list via `bnrmr --list-fonts`
- render with via `bnrmr --font <name> "your text"`

Every shipped font lives in-tree (CLAUDE.md: "self-contained — a user
can `bnrmr "hello"` with zero config files"). Authoring a shipped font
means checking it into this repo's `fonts/`, which `scripts/install.sh`
and the release tarball install as `<prefix>/share/bannermanor/fonts/`.

A font of your own does not have to be in-tree. `--font NAME` looks for
`NAME.cyml` in each of these, and takes the first it finds ([ADR
0003](../adr/0003-font-search-path.md)):

1. the directory in `$BNRMR_FONTS`, if set;
2. `./fonts`, relative to where you run `bnrmr`;
3. `<prefix>/share/bannermanor/fonts`, when `bnrmr` is installed as
   `<prefix>/bin/bnrmr`;
4. the built-in `block` font, for `--font block` only.

So `BNRMR_FONTS=~/my-fonts bnrmr --font mine HI` works from anywhere. A
font named like a shipped one shadows it, and `--list-fonts` shows
which one wins.

## File shape

A font file has one TOML header section at the top and one entry per
glyph. Background pixels are `.`, stroke pixels are `#`.

```toml
# fonts/example.cyml — minimal 3x3 font.

[font]
schema = 1
name = "example"
description = "A demo font."
width = 3
height = 3
gap = 1
author = "Your Name <you@example.com>"
license = "GPL-3.0-only"

[[entries]]
char = " "
---
...
...
...

[[entries]]
char = "A"
---
.#.
###
#.#
```

The `---` separates each entry's TOML header from its glyph body.
There is no `---` after the file-level `[font]` block — the first
`[[entries]]` line ends the file header.

## Field reference

### File header (`[font]`)

| Key           | Required | Meaning                                                |
|---------------|----------|--------------------------------------------------------|
| `schema`      | yes      | Format version. Must be `1`.                          |
| `name`        | no       | Metadata. Neither `--font` nor `--list-fonts` uses it: both go by the file stem (`example.cyml` is `--font example`). By convention, match the stem. Nothing enforces that (see [ADR 0002](../adr/0002-freeze-scope-error-paths-and-malformed-input.md), ruling 3). Through 1.5.0 `--list-fonts` showed this field, and called a font without one malformed. |
| `description` | no       | One line, shown by `--list-fonts`. Over 255 bytes it is shortened with `...` (through 1.5.0 it was left out). |
| `width`       | yes      | Columns per glyph. Range: 1–64.                        |
| `height`      | yes      | Rows per glyph. Range: 1–32.                           |
| `gap`         | yes      | Spaces between adjacent glyphs at render time. Range: 0–16. |
| `author`      | no       | Free-form attribution. Required for in-tree fonts.     |
| `license`     | no       | SPDX identifier. Required for in-tree fonts.           |

Unknown keys are ignored — forward-compatible by design. Control bytes in
`name` and `description` are shown as spaces (a font cannot put escape
sequences on your terminal through `--list-fonts`).

### Entry header (`[[entries]]`)

| Key           | Required | Meaning                                                |
|---------------|----------|--------------------------------------------------------|
| `char`        | yes      | The single ASCII byte this glyph renders.              |

`char` is a TOML string of length 1. Two escapes are supported:

- `char = "\""` — the double-quote character (ASCII 34)
- `char = "\\"` — the backslash character (ASCII 92)

No other escapes are processed. Use the literal character for
everything else: `char = "#"`, `char = "'"`, `char = "@"` all work.

### Entry body

Exactly `height` rows of exactly `width` bytes, each byte one of:

- `.` — background, rendered as a space at output time
- `#` — stroke, rendered as `#` at output time

The body ends at the next `[[entries]]` block or end-of-file. A
trailing newline is allowed but not required.

## Why `.` for background

The CYML parser trims leading and trailing whitespace from entry
bodies. A glyph whose first row is `   #` (three leading spaces) would
lose those spaces and arrive at the renderer as `#`, mangling the
shape. Using `.` for background sidesteps the trim. See
[ADR 0001](../adr/0001-cyml-font-format.md) for the full rationale.

## Character coverage

A first-class BannerManor font should cover **all printable ASCII**
(bytes 32 through 126, 95 characters total).

The renderer applies one fallback rule: lowercase ASCII (`a`–`z`)
falls back to uppercase (`A`–`Z`) when the font has no lowercase
glyph registered. This means a font that ships only uppercase still
renders any input — `bnrmr "hello"` produces an uppercase `HELLO`.

Implications:

- **Tall fonts** (height ≥ 7 — enough vertical room for legible
  lowercase with descenders) **should ship both cases**.
  `fonts/clean.cyml` (7×8, since 1.8.0) is the example: 95 entries,
  both cases, with row 7 kept for the descenders of `g j p q y`.
- **Short fonts** (5×5, 4×3 — cramped) **typically ship uppercase
  only** and let the fold do its job. `fonts/block.cyml` is the
  canonical example.
- Unsupported chars (NUL, control characters, DEL, bytes > 127)
  render as the font's space glyph silently, or its first glyph if it
  has no space. They are not an error.

How many entries a font can have: bnrmr refuses a file with more than
256 (`MAX_GLYPHS` in `src/font.cyr`, its own policy; the CYML parser
sets no cap). The limit that binds first is the charmap, though. Every
entry needs its own `char` below 128, so **128 entries is the most a
font can load**. Printable ASCII is 95, so this only matters for a font
that also maps control characters. Non-ASCII coverage is a v2.0
question.

## Required attribution

Every in-tree font must declare `author` and `license`. The license
must be compatible with this project's GPL-3.0-only license.

If you're transliterating a glyph set from an existing source (a
public-domain figlet font, a Unicode block, your own prior work),
note the source in the description or as a comment near the top of
the file.

### Importing a font from a catalog

In-tree fonts after the first three come from existing catalogs, not
new drawing. `fonts/clean.cyml` is the worked example: X11's `clR7x8`
bitmap, as converted to `.flf` in the figlet font collection. What an
import has to satisfy:

- **Two-tone.** A body is `#` on `.`, so only a font drawn in one stroke
  character carries over. figlet's line-art fonts (`_ | / \`) do not.
- **One fixed cell.** Every glyph is `width` columns. A monospace bitmap
  fits as drawn; a proportional font would be padded to its widest
  glyph, and its spacing would suffer for it.
- **A license compatible with GPL-3.0-only**, in `license` as an SPDX
  identifier. If the license requires its notice in every copy, as HPND
  does, put the notice in the file's header comment verbatim: the file
  is what `scripts/install.sh` and the release tarball ship.
- **The provenance chain** in the header comment: the original, every
  conversion in between, and the SHA-256 of the file you converted from.

Transcribe cell for cell, `#` for stroke and `.` for space, and change
nothing else. A column that is blank in every glyph (the `.flf` cell's
spacing) becomes `gap`, so the spacing stays the original's. Then prove
the transcription: render printable ASCII with `--font <name>` and with
`--font path/to/source.flf`; the two must match line for line, apart
from trailing blanks. Check that comparison fails when you change one
pixel.

## Drop-in workflow

1. Author `fonts/<name>.cyml`. Pick a short, distinctive file name —
   one-word lowercase is the convention: it is what `--font` takes. Set
   `name` to the same word.

2. Verify the file loads:

   ```sh
   bnrmr --list-fonts
   ```

   Your font should appear in alphabetical order with its geometry and
   description. Since 1.6.0 the listing runs the same full loader as
   `--font`, so a clean row means the glyphs load too. A
   `(malformed — skipped)` line means they do not; see the validation
   list below. `(--font cannot spell this name — skipped)` means the
   file name has a character `--font` refuses, such as a second dot.

3. Render a probe string:

   ```sh
   bnrmr --font <name> "AGNOS"
   bnrmr --font <name> "the quick brown fox"
   bnrmr --font <name> "0123456789 !@#\$%^&*()"
   ```

   The "AGNOS" render is the M3 acceptance bar — every shipped font
   must render it cleanly.

4. Add a test in `tests/bannermanor.tcyr` covering the new font:

   ```cyrius
   fn t_load_<name>_cyml() {
       test_group("font_load_file / fonts/<name>.cyml");
       var f = font_load_file("fonts/<name>.cyml");
       assert(f != 0, "loaded");
       # ...assert width/height/gap/count match expectations
   }
   ```

   Wire it into `main()` and rerun `cyrius test`.

5. Update `CHANGELOG.md` under `[Unreleased]` → `Added`, noting the
   character coverage.

6. Bump the asset list in `docs/development/state.md`.

## Loader validation

Two loaders read a font file, and they check different things.

**`bnrmr --font <name>`** (`font_load_file`) refuses the font, with
`bnrmr: failed to load font (missing or malformed)` on stderr and exit 1, when:

- the path is not a regular file, the file is empty, or it is
  **65,536 bytes or larger**: a file of exactly 64 KiB is refused, so
  the largest loadable font is 65,535 bytes;
- `schema`, `width`, `height` or `gap` is missing or not a number;
- `schema` is not `1`;
- geometry is out of range: width 1–64, height 1–32, gap 0–16. A width
  or height of `0` is out of range too;
- the file has no `[[entries]]`, or more than 256;
- an entry has no `char`, or its value is not a single ASCII byte
  (below 128), or two entries declare the same `char`;
- an entry body does not have exactly `height` rows (only blank lines
  may follow the last one), has a row that is not exactly `width`
  bytes, or has a byte other than `.` and `#`.

It never reads `name`, `description`, `author` or `license`. Surplus
rows have been a load failure since 1.5.0. Through 1.4.2 they were
silently ignored, so a font that worked then can fail now
([issue 0008](../development/issues/archive/0008-cyml-body-not-fully-consumed.md)).

**`bnrmr --list-fonts`** runs the same `font_load_file` on every
`*.cyml` it finds, and shows `(malformed — skipped)` for exactly the
fonts `--font` would refuse (since 1.6.0). It reads each search
directory one level deep, and lists a font by its file stem.

Through 1.5.0 the listing used a header-only loader, which never decoded
an entry and required `name`, so the two disagreed in both directions:
a font with a bad glyph body listed cleanly and failed `--font`, and a
font with no `name` rendered and listed as malformed. They no longer
disagree.

## Design tips for the body

These aren't rules, just things that come up repeatedly:

- **Reserve at least one blank column on one side of every glyph**
  for the gap. If your width is 5 and every glyph uses all 5 columns,
  the inter-glyph gap visually merges with adjacent strokes.
- **Test mixed-width input early.** `bnrmr --font <name> "Mi"` will
  expose horizontal-balance problems faster than `bnrmr --font <name>
  "AAAA"`.
- **Punctuation matters.** Comma, period, and apostrophe usually want
  to sit on the bottom row only — leaving the upper rows blank
  visually distinguishes them from quote-style glyphs.
- **`'` and `"` should anchor to the same row.** Otherwise quoted
  phrases look uneven.
- **`,` and `;` ideally share their lower descender shape** so the
  reader sees a punctuation family rather than two unrelated glyphs.

## Related

- [`../adr/0001-cyml-font-format.md`](../adr/0001-cyml-font-format.md)
  — full schema rationale, alternatives considered.
- [`../development/state.md`](../development/state.md) — current list
  of shipped fonts.
- [`../../fonts/block.cyml`](../../fonts/block.cyml) — the canonical
  worked example.
- [`../../fonts/clean.cyml`](../../fonts/clean.cyml) — a font imported
  from a catalog, with both cases, its license notice and its
  provenance.
