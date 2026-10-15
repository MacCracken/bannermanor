# Issue 0015 — an installed bnrmr cannot find any font

**Reported**: 2026-08-25
**Version**: 1.1.4 (deferred-work sweep)
**Reporter**: maintainer
**Status**: **fixed in 1.6.0** (2026-10-15), per [ADR 0003](../../../adr/0003-font-search-path.md)
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

## Fix (shipped 1.6.0)

[ADR 0003](../../../adr/0003-font-search-path.md) records the decisions.
In brief:

- **A search path** (`src/fontpath.cyr`): `$BNRMR_FONTS`, then `./fonts`,
  then `<prefix>/share/bannermanor/fonts` when the executable is
  `<prefix>/bin/bnrmr`, then the built-in block font for `--font block`.
  The first match wins, even if it is malformed, and the error names the
  file. This differs from the shape proposed above in two ways:
  - The environment variable is `BNRMR_FONTS` and comes first, as
    proposed. With it unset, `./fonts` is first among the implicit
    entries, so every lookup that worked before resolves to the same
    file.
  - **No hardcoded `/usr/share/...`.** The install directory is derived
    from the executable's location, which covers `/usr`, `/usr/local`,
    `~/.local` and an unpacked tarball. A fixed system directory would
    also have made the golden suite depend on whether the host had
    bnrmr installed.
- **Packaging.** `scripts/install.sh [PREFIX]` installs `bin/bnrmr`,
  `share/bannermanor/fonts/*.cyml` and `share/man/man1/bnrmr.1`. The
  release now publishes a tarball with that layout (plus its sha256)
  beside the bare binary, and the release job unpacks it in a scratch
  directory and renders `big` from `/` before publishing.
- **`--list-fonts` lists what `--font` finds**: stems, one level deep,
  validated by the full loader, the built-in block included, the
  directories searched on the last line. The `(none found — try running
  from the project root)` line is gone, because the built-in block is
  always listed.

## Acceptance

- **Golden suite byte-identical from the project root**: the frozen tier
  did not move (339 cases). The snapshot tier's listing records moved
  once, as the issue anticipated.
- **`bnrmr -f block` works from an arbitrary CWD after install**: it
  works from any CWD even without an install (built in), and `-f slim` /
  `-f big` work from `/` after `scripts/install.sh`. CI checks this
  (`Install smoke`), and the golden suite stages its own install
  (`path-install-*`, `list-fonts-install*`).
- **The release artifact contains the fonts**: the tarball, which the
  release job unpacks and checks.
- **Path traversal still rejected on every entry**: `font_name_ok`
  runs before any directory is consulted (`t_fontpath_name_ok`), and
  `BNRMR_FONTS` is refused if it holds a control byte
  (`t_fontpath_env_ok`, golden `path-env-control-byte`).

## Not done here

On AGNOS, `/bin/bnrmr` maps to `/share/bannermanor/fonts`. Staging fonts
there is a change to agnos's `scripts/burn/stage-tools.sh`, not to this
repository. Until agnos makes it, AGNOS has the built-in block and
whatever `BNRMR_FONTS` names.
