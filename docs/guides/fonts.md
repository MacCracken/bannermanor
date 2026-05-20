# Authoring a CYML font for BannerManor

This guide walks you through adding a new font to `fonts/`. The
canonical format and rationale live in
[`../adr/0001-cyml-font-format.md`](../adr/0001-cyml-font-format.md);
this is the practical how-to.

## What you'll produce

A single file at `fonts/<name>.cyml` that BannerManor can:

- list via `bnrmr --list-fonts`
- render with via `bnrmr --font <name> "your text"`

Every shipped font lives in-tree (CLAUDE.md: "self-contained — a user
can `bnrmr "hello"` with zero config files"). Authoring a font means
checking it into this repo.

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
| `name`        | yes      | Must match the filename stem (`example.cyml` → `"example"`). |
| `description` | no       | One-line description. Shown in `--list-fonts`.         |
| `width`       | yes      | Columns per glyph. Range: 1–64.                        |
| `height`      | yes      | Rows per glyph. Range: 1–32.                           |
| `gap`         | yes      | Spaces between adjacent glyphs at render time. Range: 0–16. |
| `author`      | no       | Free-form attribution. Required for in-tree fonts.     |
| `license`     | no       | SPDX identifier. Required for in-tree fonts.           |

Unknown keys are ignored — forward-compatible by design.

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
- **Short fonts** (5×5, 4×3 — cramped) **typically ship uppercase
  only** and let the fold do its job. `fonts/block.cyml` is the
  canonical example.
- Unsupported chars (NUL, control characters, DEL, bytes > 127)
  render as the space glyph silently. They are not an error.

There is a hard cap of 256 entries per font (the `lib/cyml.cyr`
parser's limit). ASCII fits comfortably; non-ASCII coverage is a
v2.0 question.

## Required attribution

Every in-tree font must declare `author` and `license`. The license
must be compatible with this project's GPL-3.0-only license.

If you're transliterating a glyph set from an existing source (a
public-domain figlet font, a Unicode block, your own prior work),
note the source in the description or as a comment near the top of
the file.

## Drop-in workflow

1. Author `fonts/<name>.cyml`. Pick a short, distinctive `name` —
   one-word lowercase is the convention. Match the filename stem.

2. Verify the file loads:

   ```sh
   bnrmr --list-fonts
   ```

   Your font should appear in alphabetical order with its geometry
   and description. A `(malformed — skipped)` line means the loader
   rejected the file — see the validation list below.

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

`font_load_file` rejects a font (returns 0) when any of these fail:

- File size exceeds 64 KB.
- The `[font]` block is missing or any required key (`schema`,
  `width`, `height`, `gap`) is missing or non-numeric.
- `schema != 1`.
- Geometry out of range (width > 64, height > 32, gap > 16, any < 0).
- An entry has no `char` field, or the value is not a single ASCII byte.
- Two entries declare the same `char`.
- Any entry body row has the wrong number of bytes, or contains a
  byte that is not `.` or `#`.

A rejected font causes `bnrmr --font <name>` to exit non-zero with
`bnrmr: failed to load font (missing or malformed)`. `--list-fonts`
surfaces it as `(malformed — skipped)` and continues with the rest.

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
