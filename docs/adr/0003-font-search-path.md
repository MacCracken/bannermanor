# 0003 — Where `--font NAME` looks: the font search path

**Status**: Accepted
**Date**: 2026-10-15

## Context

Through 1.5.0, `--font NAME` loaded exactly one file: `fonts/NAME.cyml`,
relative to the current directory. `--list-fonts` walked the same `fonts/`.
That works only from a checkout of this repository ([issue
0015](../development/issues/archive/0015-fonts-not-findable-when-installed.md)):

- An installed `bnrmr` finds no fonts. `bnrmr -f block X` fails while a bare
  `bnrmr X` renders the same font from its embedded copy.
- The release published the binary alone, so `slim` and `big` did not exist for
  anyone who downloaded it.
- agnos stages `bnrmr` into its rootfs as `/bin/bnrmr`, where there is no
  project root at all.

The `.flf` branch already accepted any path, which made the legacy format more
deployable than the first-party one.

The listing had its own defects (accepted risks A-11 and A-12):

- It showed each font's `name` field, which `--font` never reads, so it could
  advertise a name `--font` refused.
- It recursed 64 levels deep while `build_font_path` rejects `/`, so a nested
  font listed under a name no spelling could load.
- It dropped an over-long description instead of shortening it, and padded
  names to a fixed 10 columns.

Constraints:

- **Nothing that works today may change.** Every `--font NAME` that resolves
  under 1.5.0 must resolve to the same file.
- **The freeze adds no flags** (CHANGELOG 1.0.0).
- **The golden suite must stay hermetic.** It runs `build/bnrmr` on whatever
  host CI or a developer has, so the search path cannot depend on what is
  installed system-wide.
- **The `--font NAME` byte rules** (no `/`, `\`, `.`, control byte; at most 64
  bytes) are bnrmr's only containment on the CYML branch, and must hold for
  every directory.

## Decision

**`--font NAME` (a CYML name, not a `.flf` path) is looked up in an ordered
list of directories. The first `NAME.cyml` that exists is the font, whether or
not it then loads.**

1. **`$BNRMR_FONTS`**, if set and non-empty: one directory.
2. **`./fonts`**: today's only entry, still the first implicit one.
3. **The install directory**: `<prefix>/share/bannermanor/fonts`, where the
   running executable is `<prefix>/bin/bnrmr`. The executable comes from
   `/proc/self/exe` on Linux, or from `argv[0]` when that is an absolute path
   (AGNOS, or Linux without `/proc`). If the executable does not sit in a
   directory named `bin`, there is no install directory.
4. **The built-in block font**, for `NAME` = `block` only, when no
   `block.cyml` exists in any of the above.

Rules that go with it:

- **First match wins, even if it is malformed.** A broken `./fonts/slim.cyml`
  is an error that names the file, never a silent fall-through to another
  `slim`. This is how `PATH` behaves, and it is what 1.5.0 did with its single
  entry.
- **`BNRMR_FONTS` is validated** like the `--font` value it extends: non-empty,
  under 1024 bytes, no control byte. An invalid value is an error (exit 1,
  stderr), and only when a lookup actually consults it: `--font NAME` or
  `--list-fonts`. A plain `bnrmr X` never reads it. A valid value naming a
  directory that does not exist is a miss, the same as a missing `./fonts`.
- **The name rules are unchanged** and apply before any directory is
  consulted. A directory can only be prepended to a name that has already
  passed them, so no entry can be escaped.
- **Diagnostics separate the two failures** (ADR 0002 ruling 1):
  `bnrmr: font 'X' not found (searched: …)` and
  `bnrmr: font 'X' is malformed: <path>`. Through 1.5.0 one line covered
  both.

**`--list-fonts` lists exactly what `--font` would accept.**

- Each directory in the search path is read one level deep (`dir_list`, not
  the recursive walk).
- A font is shown by its **file stem**, the spelling `--font` takes, and the
  first directory to define a stem wins, as in a lookup.
- A font is checked with the **full loader**, so one with a broken glyph body
  is reported as malformed rather than listed clean. The header no longer
  needs a `name`.
- A file whose stem `--font` cannot spell (a dot, say) is listed as such and
  skipped.
- The built-in block font is listed when no `block.cyml` shadows it.
- Rows are sorted by name. The name column is as wide as the widest name,
  and at least 10. A description over 255 bytes is shortened with `...`
  instead of dropped.
- A last line names the directories searched, marking any that are missing
  or unreadable.

### How this sits with ADR 0002

None of this moves a byte of an invocation that succeeds under 1.5.0.
With `BNRMR_FONTS` unset, `./fonts` is consulted first, so every lookup that
succeeds today resolves to the same file and renders the same banner (the
golden frozen tier).

What changes is that some failing invocations now succeed: a name found in the
install directory, `block` anywhere. That is ruling 2's exception, "additive
and does not widen the CLI surface". The freeze froze flags, and adding a
place to look adds no flag, spelling or grammar.

`BNRMR_FONTS` is an environment input, like `COLUMNS`, which bnrmr read
before the freeze. It is not a flag.

The listing's format is documentation, not banner bytes, so it is the
snapshot tier, which moves on purpose. It moves once, here. The roadmap asked
whether a shipped default font that fails outside a checkout is a defect.
Under ruling 2's exception it is, and fixing it is permitted in a minor.

## Consequences

**Positive.**
- An installed `bnrmr` finds its fonts with no configuration, whatever prefix
  it was installed under: `/usr`, `/usr/local`, `~/.local`, or an unpacked
  release tarball, whose `bin/` and `share/` sit side by side.
- `bnrmr -f block` works everywhere, matching the bare `bnrmr`.
- The golden suite stays hermetic. `build/bnrmr` is not under a `bin/`
  directory, so the suite never sees the host's installed fonts.
  `scripts/golden.sh` stages its own install tree for the cases that test
  this.
- `--list-fonts` no longer advertises a font `--font` cannot load, and no
  longer recurses.

**Negative.**
- The listing format changes for everyone. Scripts that parsed it (none are
  known) see stems instead of `name` fields, sorted rows, and a new last
  line.
- A font whose `name` differs from its stem now lists under its stem. That is
  the honest spelling, but it is a visible change for such fonts.
- A `PATH`-like list in `BNRMR_FONTS` is not supported. Adding one later
  would change the meaning of a directory whose name contains `:`.
- On AGNOS the install directory depends on `argv[0]` being absolute
  (`/bin/bnrmr` maps to `/share/bannermanor/fonts`). Staging fonts there is
  agnos's change, not this repository's.

**Neutral.**
- There are no hardcoded `/usr/share` or `/usr/local/share` entries. The
  bin-relative rule covers both, and a hardcoded entry would make test
  results depend on the host's installed state.
- `scripts/install.sh` and the release tarball lay files out to match the
  install directory rule. The man page documents the order.

## Alternatives considered

**`./fonts` before `$BNRMR_FONTS`.** This is what the roadmap first wrote, to
keep every current lookup unchanged. Rejected: with the variable unset the
two orders are identical, and with it set, an override that loses to the
current directory overrides nothing. Setting the variable is the user's
explicit act.

**Hardcoded system directories** (`/usr/local/share/bannermanor/fonts`,
`/usr/share/bannermanor/fonts`). Rejected. They fail for any other prefix,
and they make the golden suite's results depend on whether the machine
running it has bnrmr installed: a developer who ran `install.sh` would see
the suite fail.

**Fall through past a malformed first match.** Rejected: a broken font would
silently render some other font of the same name. A loud failure that names
the file is the fix a font author needs.

**Keep listing by `name`, plus a fallback scan from name to file.** The
roadmap's other option. Rejected: it keeps two spellings for one font, and
`name` is metadata (ADR 0002 ruling 3, ADR 0001 amendment). The stem is the
one spelling that works.

**A `--font-dir` flag.** Rejected: new flags are 2.0 questions.
