# Issue 0015 — an installed bnrmr cannot find any font

**Reported**: 2026-08-25
**Version**: 1.1.4 (deferred-work sweep)
**Reporter**: maintainer
**Status**: **open**
**Severity**: usability — affects the shipped AGNOS deployment

## Observation

`build_font_path` (`src/main.cyr`) hardcodes a CWD-relative `fonts/`
prefix, and `cmd_list_fonts` walks `fonts/` the same way. Run from
anywhere but the project root:

```
$ cd /tmp
$ bnrmr "HI"                 # works — embedded font, no file needed
$ bnrmr --list-fonts
Available fonts (fonts/):

  (none found — try running from the project root)
$ bnrmr -f block "HI"
bnrmr: failed to load font (missing or malformed)
```

So `--font block` fails while bare `bnrmr` renders the *same* font from
the embedded copy, and `--list-fonts` advertises nothing.

## Why it matters

This is not hypothetical. `agnos/scripts/burn/stage-tools.sh` stages
`bnrmr` into the AGNOS rootfs at `/bin/bnrmr`, and `agnoshi` documents
`bnrmr AGNOS` as its canonical bareword-launch example. On that system
every invocation is from `/`, `/home` or wherever the shell happens to
be — never from a project root, which does not exist there. Two of the
three shipped fonts are unreachable in the only deployment that ships.

`.github/workflows/release.yml` compounds it: `files: build/*` publishes
the binary alone. The release tarball contains no fonts, so even a user
who installs it correctly has nothing for `--font` to find.

## Shape of the fix

A search path, resolved in order, first hit wins:

1. `$BNRMR_FONTS` if set (explicit override, useful for testing)
2. `./fonts/` (preserves today's behavior exactly — must stay first
   among the implicit entries so the repo workflow is unchanged)
3. an install-relative dir — `/usr/share/bannermanor/fonts`, and the
   AGNOS equivalent
4. the embedded font as the final fallback, as today

And package the fonts: `release.yml` should ship `fonts/*.cyml`
alongside the binary.

## Contract note

Additive by construction — every path that resolves today resolves to
the same file, so no rendered byte moves. `--list-fonts` output changes
only where it currently prints "(none found)". The `--font NAME`
sanitization in `build_font_path` must be preserved for every entry in
the search path; only the prefix varies, never the allowed byte set.

## Acceptance

- Golden suite byte-identical when run from the project root.
- `bnrmr -f block` works from an arbitrary CWD after install.
- Release artifact contains the fonts.
- Path traversal still rejected on every search-path entry.
