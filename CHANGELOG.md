# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.8.1] — 2026-10-15 (measurement debts)

No code change: every target builds to the bytes 1.8.0 did, apart from the
version string. This release settles numbers the project quoted but had
not measured.

### Changed

- **Issue 0006 is diagnosed and filed with bayan.** bayan 1.5.1 made the
  `[[entries]]` scan two-pass, to drop a 256-entry cap that truncated
  silently. Each pass calls `_cyml_is_entries` once per input byte, so
  `bayan_cyml_parse` makes twice the calls it made before. That is the
  whole ~45% B2 regression.
  - **The evidence.** A parser-only A/B: five scratch builds, same
    compiler, stdlib and input, only the parser varied.
  - **The result.** One pass gives back bayan 1.0.1's time. Looking for
    markers only at line starts, with 1.5.1's two-pass design kept, takes
    the parse to 0.33–0.43× of today's.
  - **The filing.** It is with bayan as
    `docs/development/issues/2026-10-15-cyml-parse-scans-every-byte-twice.md`,
    with a repro that proves the proposed fix parses exactly as 1.5.14
    does on 12 documents (exit 0) and prints the timings.
  - **What is left.** 0006 stays open until bnrmr moves `[deps.bayan]` to
    a release that carries the fix (roadmap 1.8.2).
- **`docs/benchmarks.md`** now gives that root cause where it said "not
  diagnosed".
- **The roadmap.** 1.8.1 is done. 1.8.2, adopting the bayan fix, is added
  and gated on that bayan release.

### Added

- **Architecture note 003: the aarch64 binary's size moves in 64 KiB
  steps.** It explains 1.5.0's "out of line, not investigated" jump
  (341,064 → 407,048 bytes). The code segment grew 6,440 bytes, as on the
  other targets. That carried it past a 64 KiB boundary, and cyrius's
  aarch64 ELF writer starts the data segment at a 64 KiB-aligned file
  offset, so 64,472 bytes of padding appeared. At 1.8.0 the padding is
  47,752 bytes, 12% of the file. It is never mapped, and the cause is in
  cyrius's layout (`src/backend/aarch64/fixup.cyr`), not in bnrmr.

### Notes

- **Method.** The A/B parsers were bayan 1.0.1's and 1.5.14's, plus three
  1.5.14 variants: one pass with a growing array; two passes driven by
  newlines; one pass driven by newlines. Each was built with cyrius 6.7.11
  against bnrmr's vendored stdlib, and timed on `block`, `slim`, `big` and
  `clean` (2,000 parses, 9 interleaved rounds).
  - All five agree on every font. The four 1.5.14-based ones also agree on
    1.5.1's leading-newline and 300-entry cases, which 1.0.1 gets wrong.
  - The host load average was 7–11 throughout, so the issue quotes the
    fastest round and ratios, not absolute times. The scan work is also
    given as exact call counts from the input bytes, which load cannot
    move.
- **Verification**: build for x86_64, `--agnos` and `--aarch64` (sizes
  unchanged: 309,488 / 325,768 / 407,696), lint clean, `cyrius test` 3268
  on x86_64 and on aarch64 under qemu, golden 346/346 on both, `cyrius
  fuzz` 81,003 parses with 0 violations, coverage 100%, `cyrius deps
  --locked`, `scripts/doc-pin-check.sh`, `groff -ww`.

## [1.8.0] — 2026-10-15 (the fourth font)

`bnrmr --font clean "Welcome home"` renders lowercase. **No byte of any
invocation that worked under 1.7.0 changes**, apart from the listing's
new row: the golden frozen and error tiers are byte-identical, on x86_64
and on aarch64 under qemu. The freeze permits this outright: *"Additional
fonts can ship in 1.x without breaking the contract."*

### Added

- **`fonts/clean.cyml` — 7×8, gap 1, full printable ASCII (32..126) as 95
  glyphs, uppercase and lowercase.** The first in-tree font whose
  lowercase is its own: `font_glyph_index` uses the registered glyph and
  skips the uppercase fold, as it has since 0.3.0. Row 7 is the
  descender row (`g j p q y , ; _`).
  - **Source**: Dale Schumacher's X11 bitmap font Clean, medium, 8 pixels
    (`clR7x8.bdf`, `$XConsortium: clR7x8.bdf,v 1.2 94/04/11`), as
    converted to `clr7x8.flf` by John Cowan's `bdf2flf` in the figlet font
    collection (cmatsuoka/figlet-fonts, `bdffonts/clr7x8.flf`, SHA-256
    `b2379dbd1d7f3eeacd6f0186c78de0e6a79a5104619d61e3a8664108f8d97e4c`).
  - **Transcribed, not redrawn.** Each 8-column `.flf` cell is 7 columns
    of glyph plus a column that is blank in every glyph; that column is
    `gap = 1`, so the spacing is the original's. Rendering printable
    ASCII through `--font clean` and through the `.flf` adapter on the
    source gives the same lines, apart from trailing blanks. That
    comparison was shown to fail on a one-pixel change.
  - **License**: HPND (`license = "HPND"`), compatible with
    GPL-3.0-only. Its terms require the copyright and permission notice
    in every copy, so the file's header comment carries it verbatim; the
    file is what `scripts/install.sh` and the release tarball ship.
  - **Name**: `clean`, the font's family name. Like `block`, `slim` and
    `big`, it is what `--font` takes, and it is frozen from here on.
- **Golden suite: 7 frozen cases** (346 in all, 114 on a pty):
  `clean-printable`, `clean-mixed-case`, `clean-descenders`,
  `clean-width-20`, `clean-center-40`, `clean-pty-red`, and
  `path-install-clean` (an installed copy found from an empty directory).
- **Tests** (suite 3150 → 3268): `t_load_clean_cyml` (geometry, all 95
  glyphs, 26 lowercase letters that are not the fold, descenders on row
  7 and not on `a` or `x`, the header loader, and the HPND notice in the
  file), and `t_man_page` now checks the man page names `clean`.
- **Fuzz**: `fonts/clean.cyml` is the 27th seed (81,003 parses, 0
  violations).
- **`docs/guides/fonts.md`: "Importing a font from a catalog"**, the
  rules an imported font has to meet (two-tone, one fixed cell, a
  GPL-compatible license with its notice where required, the provenance
  chain with a checksum) and how to prove the transcription.

### Changed

- **`--list-fonts` lists `clean`** (snapshot tier). The 7 listing
  records each gained exactly that row; nothing else in them moved,
  which was checked record by record.
- **The man page, README and getting-started guide** name the fourth
  font, and the man page gains a `--font clean "Welcome home"` example.
- **The roadmap looks forward only.** Shipped work and the closed-issue
  list are gone (they are in this file and `issues/archive/`). What can
  be 1.x is pinned: 1.8.1 measurement debts (the benchmark baseline,
  issue 0006, the aarch64 size jump), 1.9.0 AGNOS follow-through, 1.10.0
  byte-identical groundwork for 2.0, and 1.11.0 a library surface, only
  on request. Everything that breaks the freeze is under "Deferred to
  2.0", with the reason and any 1.x groundwork. Out of scope and the
  cross-references are kept.

### Notes

- **How the font was chosen.** 377 of the 1,052 fonts in the figlet
  collections are drawn only in `#`, at least 7 rows tall, with 20 or
  more distinct lowercase glyphs. The `clr` bitmaps are fixed-width as
  drawn, have true lowercase with descenders and a permissive license.
  figlet's `banner` draws lowercase as small capitals, is proportional,
  and states no license. `clr7x8` sits between `slim` (4 columns) and
  `big` (7) at 7 columns, one row taller for the descenders.
- **Binary sizes are unchanged** (x86_64 309,488, AGNOS 325,768, aarch64
  407,696 bytes): a font is data, not code.
- **Verification**:
  - build clean for x86_64, `--agnos` and `--aarch64`, and
    `cyrius lint --strict --strict-deferrals` clean;
  - `cyrius test` 3268 passed on x86_64 and on aarch64 under qemu;
  - golden 346/346 on both;
  - `cyrius fuzz` 81,003 parses, 0 violations; `cyrius coverage --min 100`,
    `cyrius deps --locked`, `scripts/doc-pin-check.sh`, `groff -ww`;
  - `scripts/install.sh` into a scratch prefix, then `--font clean` from
    `/`.

## [1.7.0] — 2026-10-15 (AGNOS parity)

`--color` works on the AGNOS console. A redirected or piped banner on AGNOS
now has the bytes it has on Linux. The decision is
[ADR 0004](docs/adr/0004-terminal-probes-ask-about-fd-1.md); it needs
agnos's new `fd_kind` syscall, which cyrius 6.7.11 is the first release to
wrap, so the toolchain moves too. **No Linux byte changes**: the golden
suite is byte-identical, 339/339, on x86_64 and on aarch64 under qemu.
It was also checked on AGNOS before release, with a new QEMU harness,
`scripts/agnos-smoke.py`, on agnos 1.57.14.

### Changed

- **AGNOS: the terminal probes ask about fd 1** (ADR 0004). darshana's
  AGNOS `tty_winsize` reports the console's grid whatever fd 1 is, so
  bnrmr now asks it only when `sys_fd_kind(1) == FDK_CONSOLE`
  (`_winsize_describes_stdout`, `src/layout.cyr`). Color is derived from
  the width probe again, on both targets (`stdout_is_tty`), so the two
  cannot disagree (F-020).
  - **`--color` on the AGNOS console writes SGR.** Through 1.6.0
    `stdout_is_tty` returned 0 on AGNOS, so `--color` did nothing there.
  - **AGNOS output change: a redirected or piped banner is no longer cut
    to the console's width.** Through 1.6.0, `bnrmr TEXT > file` with a
    banner wider than the console (128 columns under QEMU) was cut at a
    glyph boundary (issue 0018 recorded it as deliberate, because nothing
    could tell a file from the console). It is now whole, as the man page
    has always said: "output to a pipe or file is not" cut. Linux bytes
    do not move.
  - Not terminals on AGNOS: a file (agnsh's `>`), a pipe (agnsh's `|`),
    the channel a terminal emulator hands its child (`FDK_CHAN`: its size
    is not the console's), and fd 1 on a kernel older than 1.57.13, where
    the syscall does not exist. darshana's planned per-fd `tty_isatty`
    draws the same line, so routing through it later changes no byte.
- **cyrius 6.7.9 → 6.7.11.** `lib/` re-vendored from the manifest (34
  files). Four stdlib files changed: `alloc` (comments only), `str`
  (additions bnrmr does not call), `fs` (the FIFO fix below) and the
  AGNOS syscall table (`sys_fd_kind`). `cyrius.lock` regenerated from
  empty, so the superseded bayan row did not linger.
  - `[deps.bayan]` 1.5.13 → 1.5.14, the bayan the 6.7.11 stdlib bundles.
    Its CYML sublib differs from 1.5.13 only in the version comment.
  - darshana 1.3.0 and cmdit 1.4.0 are unchanged. cmdit pins 6.7.9 and
    has no later tag.
  - The 6.7.10 and 6.7.11 migration notes were read against bnrmr's
    source: bnrmr uses none of the struct, tuple or generic forms they
    tighten, and the new lint rules (overruns, write lengths) report
    nothing.
- **`--color` in the man page** says that on AGNOS only the console
  counts as a terminal, for color and for the width cut.

### Fixed

- **`--list-fonts` hung when a search directory was a FIFO**
  (`mkfifo fonts`; [issue 0020](docs/development/issues/archive/0020-list-fonts-hangs-when-fonts-is-a-fifo.md)).
  The stdlib's directory listing opened it `O_RDONLY` and blocked until a
  writer came. cyrius 6.7.11 opens with `O_DIRECTORY`, so the listing
  gets `ENOTDIR` at once and reports `./fonts (unreadable: ./fonts)`.
  Found in the 6.7.11 migration notes, then confirmed against the 1.5.0
  and 1.6.0 binaries (each killed by `timeout` after 3 s). Issue 0011
  had closed the hang on a FIFO *inside* `fonts/`, not on `fonts`
  itself. `--font NAME` was never affected: it `stat`s the joined path,
  which fails on a FIFO.

### Added

- **`scripts/agnos-smoke.py`** boots agnos in QEMU with this `bnrmr` at
  `/bin/bnrmr` and the fonts at `/share/bannermanor/fonts`, types at
  agnsh over the QEMU monitor, and reads the console back from the serial
  log. Nine checks:
  - the binary runs (`--version`);
  - `--color` writes SGR on the console;
  - `--color` writes plain bytes into a file and into a pipe;
  - a banner wider than the console is whole in a file;
  - `-f slim` is found through `argv[0]`;
  - a `.flf` font by path renders;
  - `--list-fonts` names the install directory;
  - a missing font is reported on stderr.

  File, pipe, width and font results are byte counts from agnos's own
  `wc -c`, compared with the host binary's output for the same command,
  so they do not depend on how the console draws escapes. It is manual,
  not CI: it needs the agnos tree's kernel and rootfs, gnoboot, OVMF and
  qemu-system-x86_64.
- **ADR 0004**, the probe rule: route through a target-bridged wrapper
  when one answers the question; gate inline, with a stdlib `sys_*`
  wrapper and a comment naming its replacement, where none does.
- **CI: `aarch64 at runtime (qemu-user)`.** It installs qemu-user and
  runs the suite (`cyrius test --aarch64`) and the golden matrix
  (`BNRMR_RUNNER=qemu-aarch64`) on the cross-built binary. Both were run
  by hand before releases, but nothing gated them.
- **Tests** (suite 3146 → 3150):
  - `t_list_dir_fifo` (the hang above). It was shown to hang on a tree
    pinned back to 6.7.9; the 300 s test deadline turns that into a
    failure.
  - An assertion that the new gate stays open on Linux. Shut, it would
    take width and color from every Linux terminal.

  Reference coverage stays 100%.

### Notes

- **Run on AGNOS** (agnos 1.57.14 in QEMU, `-machine q35`):
  - **1.7.0: 9/9.**
  - **Control, the 1.6.0 binary:** it failed exactly the two checks this
    release changes, on the then seven-check harness: no SGR on the
    console, and a 40-glyph banner redirected to a file came out at 630
    bytes (cut at 125 columns) instead of 1,200. The other five passed.
  - **Mutant**, the gate forced open on AGNOS (the console-wide answer):
    `--color` wrote 105 bytes into the file and into the pipe, where
    plain is 60, and the wide banner in a file was cut to 630 bytes
    again (4/7). So the file, pipe and width checks can fail.
- **What that run verifies**, which 1.4.1–1.6.0 compiled for AGNOS but
  never ran:
  - the `file_write` route;
  - `fl_alloc`'s `mmap` and the bayan CYML sublib (`-f slim`);
  - the `.flf` adapter;
  - cmdit's argv path (`--color`, `-f`, `--list-fonts`, `--version`);
  - the stderr route.

  agnsh passes the absolute `/bin/bnrmr` as `argv[0]`, so 1.6.0's install
  directory works on AGNOS. **Not verified**: a failed write on AGNOS,
  since there is no full device to point fd 1 at.
- **Fonts on AGNOS**: agnos's `stage-tools.sh` now stages
  `fonts/*.cyml` at `/share/bannermanor/fonts` beside `/bin/bnrmr` (an
  agnos change, after its 1.57.14; through 1.57.14 it staged the binary
  only). Fonts at that path are found and load (above).
- **The kernel** was agnos `main` at 7b50feff (1.57.14), built in a
  scratch clone with agnos's own pin (cyrius 6.6.20). The tools (agnsh,
  `wc`) came from agnos's staged `build/rootfs`.
- **Corrected the [1.4.1] notes**, which said "cyrius 6.7.12 is out".
  It was not: 6.7.12 is still in progress. 6.7.11 is the newest release
  and is what 1.7.0 pins.
- **Sizes**: x86_64 305,384 → 309,488 bytes, all of it the toolchain
  (the bump alone builds the same size); AGNOS 317,448 → 325,768.
- **Verification**:
  - build clean for x86_64, `--agnos` and `--aarch64`, and
    `cyrius lint --strict --strict-deferrals` clean;
  - `cyrius test` 3150 passed on x86_64 and on aarch64 under qemu;
  - golden 339/339 byte-identical on both, with the bump alone and with
    the release;
  - `cyrius fuzz` clean, `cyrius coverage --min 100`,
    `cyrius deps --locked`, `scripts/doc-pin-check.sh`, `groff -ww`;
  - `scripts/agnos-smoke.py` as above.

## [1.6.0] — 2026-10-15 (fonts findable, listing honest)

An installed `bnrmr` finds its fonts, the release ships them, and
`--list-fonts` lists exactly what `--font` can load. Decisions are in
[ADR 0003](docs/adr/0003-font-search-path.md). **No rendered byte of any
invocation that succeeded under 1.5.0 changes**: the golden frozen tier is
byte-identical, on x86_64 and on aarch64 under qemu.

### Changed — behavior, each permitted by ADR 0002

- **`--font NAME` searches a path** ([issue 0015](docs/development/issues/archive/0015-fonts-not-findable-when-installed.md)). The first `NAME.cyml` found is the font, in this order:
  1. the directory in `$BNRMR_FONTS`, if set and not empty;
  2. `./fonts`;
  3. `<prefix>/share/bannermanor/fonts`, when the running executable is `<prefix>/bin/bnrmr`. The executable is found through `/proc/self/exe`, or from `argv[0]` when that is absolute (AGNOS);
  4. for `block` only, the built-in copy.

  With `BNRMR_FONTS` unset, `./fonts` comes first among the implicit entries, so every lookup that worked under 1.5.0 resolves to the same file (ruling 2: failing invocations may start succeeding, and no flag was added). A first match that fails to load is an error, never a fall-through to another font of the same name.
  - Through 1.5.0 only `fonts/NAME.cyml` relative to the current directory was tried. An installed `bnrmr` found no fonts, and `bnrmr -f block` failed outside a checkout while a bare `bnrmr` rendered the same font.
  - `BNRMR_FONTS` is validated like the `--font` value it extends: non-empty, under 1024 bytes, no control byte. A bad value is an error (`bnrmr: BNRMR_FONTS is not a usable directory path`, exit 1), but only when a font is looked up.
  - There is no hardcoded `/usr/share` entry. The bin-relative rule covers every prefix, and keeps the golden suite from depending on the host's installed state (ADR 0003).
- **Font errors say which failure it was** (ruling 1). They replace `failed to load font (missing or malformed)`, which covered both:
  - `bnrmr: font 'X' not found (searched: ./fonts (missing), …)`
  - `bnrmr: font 'X' is malformed: ./fonts/X.cyml`

  Paths are echoed with control bytes as `?`.
- **`--list-fonts` lists what `--font` finds** (snapshot tier; it moves once, here):
  - **Every directory on the search path, one level deep.** It used to recurse 64 levels, and a nested font listed under a name no spelling could load (accepted risk A-12, resolved).
  - **Each font by its file stem**, the spelling `--font` takes, not by its `name` field, which `--font` never reads (A-11, resolved). The first directory to define a stem wins, as in a lookup.
  - **Validated with the full loader.** A font with a broken glyph body is now reported malformed instead of listed clean. A font with no `name`, or an over-long one, now lists, since `name` is optional metadata. A file whose stem `--font` cannot spell is shown as skipped.
  - **The built-in block font is listed** when no `block.cyml` shadows it. So `(none found — try running from the project root)` is gone.
  - **Layout.** Rows are sorted by stem, and the name column is one past the widest stem, at least 10, so the default listing's rows are unchanged. A description over 255 bytes is shortened with `...` instead of dropped. The header reads `Available fonts (--font NAME):`, and the last line names the directories searched, marking missing ones.
- **`--help`** describes the search path under `--font`, says what `--list-fonts` now shows, and ends with a note on stderr and exit status, pointing at `bnrmr(1)`.

### Added

- **`man/bnrmr.1`**: flags, the font search path, the environment (`BNRMR_FONTS`, `COLUMNS`), exit status, examples. It formats under `groff -ww` with no warnings, which CI checks. `t_man_page` fails if a flag is missing from it. `scripts/doc-pin-check.sh` now also holds its `.TH` version line to `VERSION`, and was checked to fail when they differed.
- **`scripts/install.sh [PREFIX]`** (default `/usr/local`; honors `DESTDIR`) installs `bin/bnrmr`, `share/bannermanor/fonts/*.cyml` and `share/man/man1/bnrmr.1`. It refuses a binary whose `--version` disagrees with `VERSION`.
- **A release tarball**, `bnrmr-<version>-x86_64-linux.tar.gz`, with that layout plus README, LICENSE and CHANGELOG, and a `.sha256`. Before publishing, the release job unpacks it in a scratch directory and renders `big` from `/`. Through 1.5.0 the release published the binary alone, so `slim` and `big` existed for nobody who downloaded it. The bare binary is still published.
- **CI**: an `Install smoke` step (install to a scratch prefix, run `--font slim` from `/`) and a `Man page` step.
- **`src/fontpath.cyr`**, the search path, in pure functions the suite drives with synthetic inputs.
- **Golden suite: 21 new cases** (339 in all):
  - 12 frozen and 5 error search-path cases (`path-*`), including shadowing by `BNRMR_FONTS`, a missing directory, an empty value, an ESC in the value, and a malformed first match;
  - 4 snapshot listings.

  An `install` case option stages `<prefix>/bin/bnrmr` beside `<prefix>/share/bannermanor/fonts` and normalizes the prefix to `@PREFIX@`. The suite now refuses to run a binary that sits in a `bin/` directory, whose install directory would read the host's fonts. The record's `env:` line is escaped like its arguments.
- **Tests** (suite 3082 → 3146):
  - `t_fontpath_name_ok`, `t_fontpath_env_ok`, `t_fontpath_install_dir` (`/usr/local/bin`, `/bin` for AGNOS, an unpacked tarball, and `build/`, `sbin`, relative and root paths that must not count);
  - `t_fontpath_resolve`: order, shadowing, fall-through, and the built-in block from a directory with no fonts;
  - `t_cli_report_font_error`, `t_man_page`, and the listing test's new header and footer.

  Reference coverage stays 100% (50/50).

### Removed

- `build_font_path` (`src/cli.cyr`), replaced by `font_name_ok` and `font_path_join` (`src/fontpath.cyr`), which keep the same byte rules.

### Notes

- **The golden re-baseline**, checked by script against the 1.5.0 records:
  - **frozen**: 0 of 217 existing records changed; 12 added.
  - **error**: 10 changed, every one only the font diagnostic (8 `not found` / `is malformed` lines and two flag-shaped names); 1 removed (`cyml-no-fonts-dir`, `--font block` with no fonts dir, which now succeeds and is frozen case `path-block-builtin-anywhere`); 5 added.
  - **snapshot**: 6 changed, the listing format only; 5 added.
  - **Help text**: a second pass re-baselined it; 26 error and 15 snapshot records differ only by the new help lines.
- **Verification**:
  - build clean for x86_64, `--agnos` and `--aarch64`, and `cyrius lint --strict --strict-deferrals` clean;
  - `cyrius test` 3146 passed on x86_64 and on aarch64 under qemu;
  - golden 339/339 on both, the staged-install cases included (qemu resolves `/proc/self/exe` to the guest binary);
  - `cyrius fuzz` clean, `cyrius coverage --min 100`, `cyrius deps --locked`, `scripts/doc-pin-check.sh`, `groff -ww`;
  - `scripts/install.sh` into a scratch prefix and with `DESTDIR`, and the release packaging run end to end locally.
- **AGNOS**: `/bin/bnrmr` maps to `/share/bannermanor/fonts`, if `argv[0]` is absolute. agnos stages the binary only, so until its `stage-tools.sh` stages fonts there, AGNOS has the built-in block and `BNRMR_FONTS`. That change belongs to agnos (roadmap 1.7.0). None of this has run on AGNOS.

## [1.5.0] — 2026-10-15 (diagnostics on stderr, honest exit codes, one write per row, the malformed-input rulings)

Everything [ADR 0002](docs/adr/0002-freeze-scope-error-paths-and-malformed-input.md)
unblocked. **Rendered banners are unchanged**: the golden suite's frozen
tier (217 renders, 112 on a pty) and its snapshot tier (`--help`,
`--version`, `--list-fonts`) are byte-identical to 1.4.2, on x86_64 and on
aarch64 under qemu. The error tier was re-baselined once, deliberately,
and checked record by record (below).

### Changed — behavior, each permitted by ADR 0002

CLAUDE.md classes any change to exit codes or output bytes as `Breaking`.
ADR 0002 (Accepted) defines what the v1.0 freeze covers, and rules that
none of these four break it. They are listed together, under the ruling
that permits each one, so nobody has to find them.

- **Diagnostics go to stderr** ([issue 0016](docs/development/issues/archive/0016-diagnostics-go-to-stdout.md), ruling 1). Every error message moves from fd 1 to fd 2, and every exit code is unchanged. `bnrmr --font typo "$HOST" > /etc/motd` leaves the file empty, and `banner=$(bnrmr …)` no longer captures an error as the banner.
  - The usage block that follows a parse error goes to stderr too.
  - `--help`, a bare `bnrmr` and an empty text, all exit 0, still print usage on stdout.
  - `--list-fonts` stays on stdout, including its `(none found …)` and `(malformed — skipped)` lines.
- **Parse errors name what was typed.** `bnrmr: unknown flag: --bogus`, `bnrmr: --font: missing value`, `bnrmr: --list-fonts=0: this flag takes no value`, and `bnrmr: -HI: bundled short flags are not supported (write -x -y; put -- before text that starts with -)`. That last one is the error someone hits for `bnrmr -HI`, which used to name a cause unrelated to what they meant. The token is echoed with control bytes (C0, DEL and C1) shown as `?`, and cut at 64 bytes.
  - This settles the question the roadmap left for this change. cmdit's own `cmdit_print_error` was **not** adopted: its echo escapes C0 and DEL but not C1, which bnrmr's control-byte rule covers (F-001), and its bundled-flag text does not mention `--`.
  - Through 1.4.2 these said only `bnrmr: unknown flag` and similar, with no token. bnrmr's own value diagnostics (`--align`, `--width`, `--pad`, `--color`, the font loaders, `input too long`) keep their wording.
- **`--color`'s error lists `bright-<name>`**, so it agrees with `--help` (from issue 0017).
- **A failed write exits 1** ([issue 0009](docs/development/issues/archive/0009-write-return-never-checked.md), ruling 2). Every stdout byte goes through one checked writer, `_emit`: banner rows, `--help`, `--version`, and `--list-fonts`, whose numbers no longer go through the stdlib's unchecked `fmt_int`.
  - Short writes are continued. `EINTR` is retried at once; `EAGAIN`, from a non-blocking stdout, is retried after a 1 ms pause; both are bounded.
  - Anything else stops output, and bnrmr exits 1 with `bnrmr: write error: <reason>` on stderr. ENOSPC, EBADF, EIO, EFBIG and EDQUOT are named.
  - Through 1.4.2, `bnrmr hi > /dev/full` exited 0 having written nothing, and so did a closed stdout. Both now exit 1.
- **A CYML glyph body with surplus rows is rejected** ([issue 0008](docs/development/issues/archive/0008-cyml-body-not-fully-consumed.md), ruling 3). Only newlines may follow the last of the `height` rows. Through 1.4.2 the surplus was read past and ignored. A font that relied on that now fails `--font` (exit 1), and still lists under `--list-fonts`, which reads no bodies. No in-tree font is affected.
- **The `.flf` envelope is 128 columns × 64 rows**, up from 64 × 32 (ruling 3: admitting input rejected only by bnrmr's own limit is additive). Measured over the 1,052-font reference corpus (cmatsuoka/figlet-fonts + xero/figlet-fonts), rendering all of printable ASCII with each font against 1.4.2:
  - all 973 fonts that loaded before are **byte-identical**;
  - **73 more load**: the Obanner family, up to 125 × 63, and five fonts 70–77 columns wide;
  - 6 stay rejected: five CJK fonts over the 1 MB cap, which the 1.0.0 adapter contract names and which stays, and one malformed 23 MB file.

  Only `FlfLimits` moved; CYML schema 1 stays 64 × 32 × 16.

### Changed

- **One write per banner row** ([issue 0005](docs/development/issues/archive/0005-write-per-cell-syscall-cost.md), Option 2). Each row is composed in one buffer and written once: the left pad, the color through darshana's `tty_sgr_buf`, the glyph rows and gaps, `tty_sgr_reset_buf`, the newline. `tty_sgr` was always `tty_sgr_buf` plus a write, so the colored bytes are the same, and the golden pty leg confirms it. `bnrmr AGNOS` makes 5 `write(2)` calls, down from 50.
  - In process (B4), interleaved against 1.4.2 over three rounds: natural width 21–22 → 3.4–4.3 µs; `--width 4096 --align center` 22–23.5 → 5.6–7.2 µs. `--width 4096 --align right A` is about 1 µs slower, 6.1–6.6 → 7.3–9.2 µs, because its 4 KB pad is now copied into the row. That row was already the cheapest of the three, and all three remain within a small factor of each other. The host was loaded (load average 14–22), so only these ratios are claimed, not a benchmark point.
  - Rows are copied eight bytes at a time (`_bulk_copy`): the stdlib's `memcpy` / `memset` move one byte per iteration, and a first cut using them made the wide rows slower than 1.4.2.
- **`cyrius.cyml [deps.darshana]`**: bnrmr now consumes `tty_sgr_buf`, `tty_sgr_reset_buf` and `tty_dec_buf`, all in darshana's frozen v1.0 surface.
- **`src/main.cyr`**: `main()` is a wrapper that turns any failed stdout write into exit 1; the body moved to `_run()`. The `--version` literal is now `bnrmr 1.5.0`.

### Added

- Tests (suite 3061 → 3082):
  - `t_emit_checked`: fd 1 on `/dev/full`; the failure is recorded, later writes are skipped, and `render_layout` returns -4. Also a 200 KB write to `/dev/null`.
  - `t_write_error_text`, and `t_line_writers` (the stdout / stderr line writers, and `print_usage_err`).
  - `t_cli_report_parse_error`, rewritten for stderr: the token named, ESC and C1 shown as `?`, an 80-byte token cut at 64.
  - Surplus and trailing-newline bodies, in memory.
  - The 128 / 129 and 64 / 65 `.flf` boundaries. The over-wide fixture became `tests/fixtures/flf_wide_129.flf`, because 65 columns now loads.
- Reference coverage stays 100% (40/40).

### Notes

- **The error-tier re-baseline, checked by script, not by eye.** All 76 error records keep their exit code and now have empty stdout. 46 moved their text to stderr verbatim; 26 parse errors changed only their first line (the token, listed in the review); 4 `--color` errors gained `bright-<name>`. Nothing else moved.
- **Fuzz**: the oracle bounds `.flf` geometry by the adapter's envelope, not schema 1's; its self-test now includes a 129-column `.flf`. 0 violations in 78,003 parses. Fewer mutants load than before (3,461 against 4,630), because surplus-row bodies are rejected; the 5% floor still holds.
- **Verification**:
  - `cyrius build` clean for x86_64, `--agnos` and `--aarch64`;
  - `cyrius lint --strict --strict-deferrals` clean;
  - `cyrius test` 3082 passed on x86_64 and on aarch64 under qemu;
  - golden 318/318 on both;
  - `cyrius fuzz` clean, `cyrius coverage --min 100`, `cyrius deps --locked`, `scripts/doc-pin-check.sh`;
  - the corpus comparison above.
- **Not runtime-verified on AGNOS**: the checked-write path there. A failed AGNOS write returns -1, which `_emit` treats as a failure (AGNOS defines no `EINTR` / `EAGAIN`, so bnrmr names the Linux values itself).
- **Binary** 292,008 → 296,552 bytes (x86_64), 304,088 → 308,624 (AGNOS), 341,064 → 407,048 (aarch64). The aarch64 jump is out of line with the other two and not yet investigated; the build is clean, and the suite and golden pass on it under qemu.

## [1.4.2] — 2026-10-15 (CLI parsing on cmdit)

The command-line parser moves from the stdlib's table parser
(`lib/flags.cyr`) to [cmdit](https://github.com/MacCracken/cmdit), the
same getopt-long core productized as a distlib. **No output byte
changes on any path the golden suite covers.** Before the swap, the
suite gained 33 parser-grammar cases recorded against the 1.4.1 parser,
and all 318 records are byte-identical across it, on x86_64 and on
aarch64 under qemu.

### Changed

- **CLI parsing on cmdit 1.4.0.** New `[deps.cmdit]` (tag 1.4.0, `dist/cmdit.cyr`); `flags` leaves `[deps].stdlib`; `lib/` is regenerated from the manifest (`flags.cyr` out, `cmdit.cyr` in) and `cyrius deps --locked` passes. The roadmap had carried this as demand-gated, waiting on cmdit 1.3.1 to stop dropping positionals past the 128th and to reject `--bool=value`, and on a golden suite to prove the swap byte-identical. 1.4.1 provided the suite.
  - The flag table moved from `main()` into `src/cli.cyr` as `cli_flags()`, so tests parse synthetic argv with it (`cmdit_parse_argv`).
  - `cmdit_argv` replaced bnrmr's own `build_argv_array` and its fixed 256-slot stack array; the `> 256` argument guard stays.
  - cmdit's auto `-V` is dropped (`cmdit_version_short(fs, 0)`): bnrmr never had `-V`, and the freeze adds no flags. A mutant that keeps it fails the golden error tier.
  - Deliberately **not** handed to cmdit: help (`print_usage` stays; `cmdit_help` writes stderr), the `--version` literal (`scripts/doc-pin-check.sh` reads it), and every value check. `--width` / `--pad` stay strings for `_parse_count_flag`, `--align` stays `parse_align` (`cmdit_enum` would reject during the parse, ahead of `--help` and `--list-fonts`), and `--color` stays `parse_color`.
  - The parse-error lines are the stdlib parser's wording, byte for byte, now in `report_parse_error()` (`src/cli.cyr`). Codes 0..4 are the same in both parsers; everything past them is `argument parse error`, as before.
- **One error path changes its message**, permitted by ADR 0002 ruling 1 and with the same exit code: a command line too long for the stdlib's 2 MiB `/proc/self/cmdline` read. cmdit refuses it (`CMDIT_ERR_ARGV`), so bnrmr now prints `argument parse error` and the usage block, exit 1. Before, it parsed whatever survived the truncation and failed on that, typically `input too long (max 1024 bytes)`, also exit 1. Reaching it takes a raised `ulimit -s`; checked by hand with 17 arguments of 131,000 bytes.
- **Binary size** 244,184 → 292,008 bytes (x86_64), 260,352 → 304,088 (AGNOS), 338,296 → 341,064 (aarch64). The whole cmdit bundle links, shell-completion generators included; cyrius's DCE does not strip unreachable code.
- **`src/main.cyr`** — `--version` literal bumped to `bnrmr 1.4.2`.

### Added

- **33 golden cases pinning the flag grammar** (`parse-*`, `help-*`, `version-*`, `list-fonts-*`, `dashdash-alone`), recorded against the 1.4.1 parser before the swap: `-V` is not version; errors beat `--help` in either order; no prefix matching (`--col`, `--he`, `--list`); bundled and attached short forms (`-hh`, `-w5`, `-f=slim`); flag-shaped values taken as values (`--font --list-fonts`); repeats (last wins); `--` in every position; and help / version / `--list-fonts` precedence. Golden: 285 → 318 cases (217 frozen, 76 error, 25 snapshot).
- **Tests** (suite 3006 → 3061): `t_cli_flags` drives the table on synthetic argv (values, absent flags, repeats, `--`, help over version, `-V`, the error codes, flag-shaped values); `t_cli_report_parse_error` captures every message through a pipe; `t_cli_argv` reads the real process argv. Reference coverage stays 100% (37/37).

### Notes

- **Verification**: build clean for x86_64, `--agnos` and `--aarch64`; `cyrius lint --strict --strict-deferrals` clean; `cyrius test` 3061 passed on x86_64 and on aarch64 under qemu; golden 318/318 on both; `cyrius fuzz` 0 violations; `cyrius coverage --min 100`; `cyrius deps --locked`; `scripts/doc-pin-check.sh` green.
- **Not measured**: speed. The host load average was 12–15 throughout, and a 500-run wall-clock comparison against 1.4.1 swung from 648 to 1,069 µs between consecutive runs. The parse is a negligible share of an invocation either way.
- **Not runtime-verified on AGNOS**: cmdit's AGNOS argv path (`argv(i)` over the pointer table). It compiles, and it is the same `lib/args` call 1.4.1 made directly.

## [1.4.1] — 2026-10-15 (the contract checked in CI, one write per run, CYML-only bayan, a real fuzz gate)

This release lands the roadmap's planned 1.3.0 (*prove the contract*),
1.3.1 (*documentation precision*), 1.4.0 (*one write per row*, Option 1)
and 1.4.1 (*tests, fixtures and dead code*) together, numbered 1.4.1. No
1.3.x or 1.4.0 was tagged. Items the roadmap gated on ADR 0002 are not in
it. ADR 0002 was proposed and accepted within this release, which
unblocks them for 1.5.0 (under Notes).

**No rendered banner byte changes.** The release commits the golden
matrix that 1.1.3, 1.1.4 and 1.2.0 ran from shell history: 285
invocations, 112 of them on a pty. Its frozen tier is byte-identical to
the 1.2.0 binary on x86_64, and on aarch64 under qemu. The one stdout
change on purpose: `--help` gains a line for the `--` terminator. The
same usage block follows a flag-parse error, so 20 records changed, by
exactly those two lines.

### Added

- **The golden suite, committed and gated** — `scripts/golden.sh` and `tests/golden/`. 285 invocations in three tiers, one file each:
  - **frozen**: 210 valid renders, every byte of stdout and stderr plus the exit code. Every font, the `.flf` path and its malformed fixtures, every alignment / width / pad / color spelling, `COLUMNS` at 0, junk, 5000 and past the int cap, flags after text, repeated flags, `--`, 200 and 255 positionals, the 1 KB cap from both sides. Of these, 112 run on a pty through script(1) at seven window sizes (24×80, 24×40, 24×11, 24×1, 24×0, 0×0, 50×5000), plus every `--color` spelling. `stdout_is_tty` gates color and the default truncation width, so a pipe capture alone only ever recorded the suppression path.
  - **error**: 58 invalid invocations. The exit codes are contract; the text is what ADR 0002 rules on.
  - **snapshot**: 17 records of `--help`, `--version` and `--list-fonts` (from the repo root, from a directory with no `fonts/`, and from a fixture tree of malformed, nameless, nested, over-long and control-byte fonts). The `--version` record is checked against `VERSION`, then normalized, so a version bump doesn't churn it.
  - Every invocation runs under `env -i` with a pinned CWD and stdin on `/dev/null`. A missing script(1) fails the suite rather than skipping the pty leg, and so does an empty tier. `--update` re-baselines.
  - Verified red: a one-byte change to a block glyph fails the frozen tier, and so does swapping one color in the rainbow cycle (pty leg). Verified green: on x86_64, on the aarch64 build under qemu-aarch64, and under `bash --posix`.
- **CI gates** (`.github/workflows/ci.yml`), in addition to the pin check, build and tests:
  - `cyrius deps --locked`
  - `cyrius lint --strict --strict-deferrals` over `src/` and the three harnesses
  - `--agnos` and `--aarch64` cross-builds
  - a smoke step that checks the binary's `--version` against `VERSION`
  - the golden suite and the fuzz harness
  - `cyrius coverage --min 100`

  Each one was checked to fail when it should before it was wired in.
- **The fuzz harness verifies something** ([issue 0010](docs/development/issues/archive/0010-fuzz-harness-is-a-no-op.md)). `tests/bannermanor.fcyr` was a 16-line stub that always passed. It now mutates 26 seeds 1,000 times each (every non-empty fixture, the three fonts, `modular.flf`) and pushes each mutant through all three parsers: 78,003 parses in about 2 s. It checks:
  - geometry within the format's limits, and a charmap that points at real glyphs;
  - glyph rows without control bytes (F-001), and header strings that are NUL-terminated and scrubbed (F-011);
  - with a `PROT_NONE` page right after every input, so an over-read faults.

  It checks its own oracle before trusting it, and requires that a real share of mutants load. Verified red three ways: the `.flf` C1 scrub removed, a one-byte over-read in `_flf_eol`, and the header scrub removed.
- **`src/cli.cyr`**: everything in the CLI except `main()`, moved out of `src/main.cyr` so the suite can include it. That file ends in a bare `_agnos_entry();`, which exits the process at include time. The move was pure: golden identical, binary size identical. For the first time, tests cover `build_font_path`, the only containment on the CYML `--font` branch.
- **Suite 2828 → 3006** (+178):
  - the CLI helpers, including `_parse_count_flag`'s exit-code sentinels (`-0`, `007`, `+5`, u64 wrap) and the 1 KB join from both sides;
  - `_write_scrubbed` (F-012) and `_print_padded`, captured through a pipe;
  - a check that `--help` names every registered flag and `--`;
  - `cmd_list_fonts` and `build_argv_array`;
  - `resolve_frame` on a pty, and the font constructors;
  - the size gates at 65,535 / 65,536 bytes (CYML, in memory and through a real file) and 1,048,575 / 1,048,576 (`.flf`);
  - every schema-1 geometry limit from both sides, zero entries, the 128-entry ceiling (chars 0–127 all load; a 129th repeats), 257 entries;
  - the `.flf` envelope (64 / 65 columns, 32 / 33 rows, 1024 / 1025 comment lines);
  - empty files, and a FIFO made at run time (all three readers return at once).

  `t_reader_dir_path` is re-documented: since 1.1.4 it tests the `S_IFREG` gate, not the read-error path its comment described.
- **12 fixtures** in `tests/fixtures/` for the cases the 1.1.4 audit found missing: width 0 and 65, height 33, gap 17, a duplicate `char`, a non-ASCII `char`, a 64-byte `name`, surplus body rows (issue 0008, pinned as today's behavior), empty `.cyml` and `.flf`, 1025 comment lines, 65-column `.flf` rows.
- **Write-path benchmarks**: B0 `_calibration` (the harness floor), and three B4 `render_layout` rows with fd 1 on `/dev/null`. `scripts/bench-history.sh` records a `cyrius bench` run into `docs/benchmarks/history.csv`, and fails if it parses fewer rows than the bench declares. See `docs/benchmarks.md` Point 7.
- **[ADR 0002](docs/adr/0002-freeze-scope-error-paths-and-malformed-input.md), Accepted**: what the v1.0 freeze covers. Proposed and accepted as written on 2026-10-15.
  1. Diagnostics are not frozen; exit codes are.
  2. Exit 0 after a failed write is a defect.
  3. Structurally malformed fonts are not protected; metadata rules (`name` against the stem) are 2.0; bnrmr's own limits may widen.
- **Issue register reconciled.**
  - 0007, 0008, 0009, 0011, 0012, 0013 and 0014 are filed; the 1.1.4 audit had named them without files.
  - 0007 and 0011 turned out already fixed by 1.2.0's toolchain and are archived (see Notes).
  - The audit gains a second dated errata block mapping every deferral to its issue.
  - `docs/development/issues/README.md` states the numbering rule: never reuse, never cite a number before its file exists.
- **`docs/architecture/`**: its first two notes. 001: why `src/` uses no raw syscall numbers, and the AGNOS reader bug that shipped for four releases. 002: `cyrius build` / `bench` silently restore `lib/` from the lock (re-verified at 6.7.9), and how to A/B a dependency correctly.

### Changed

- **Pads, gaps and `--pad` lines are written in runs, not a byte at a time** ([issue 0005](docs/development/issues/archive/0005-write-per-cell-syscall-cost.md), Option 1). Same bytes in the same order; darshana's SGR writes did not move. `write(2)` calls, against 1.2.0:

  | invocation | calls before | calls after |
  |---|---|---|
  | `--width 4096 --align right A` | 20,465 | 15 |
  | `--width 4096 --align center AGNOS` | 10,215 | 55 |
  | `--pad 64 --font big HI` | 156 | 30 |
  | `--list-fonts` | 55 | 40 |

  Whole-process wall time for the wide renders is down from 4.2 ms (centered) and 7.7 ms (right) to ~0.56 ms. That is within noise of a natural-width render, which is 562 µs, down from ~570.
- **Every stdout write in `src/` goes through `lib/io.cyr`'s `file_write`**, via `_emit` in `src/layout.cyr`. That replaces 19 raw `syscall(1, 1, …)` sites (accepted risk A-10), which were correct on all three targets only by coincidence (architecture note 001). The `--list-fonts` printers now use the same chunked runs.
- **bayan: the CYML-only sublib instead of the full bundle** ([issue 0013](docs/development/issues/archive/0013-full-bayan-bundle-linked.md)).
  - New `[deps.bayan]` pins `dist/bayan-cyml.cyr` at tag 1.5.13, the bayan the cyrius 6.7.9 stdlib bundles, so the parser code is byte-identical. `bayan` leaves `[deps].stdlib`.
  - The nine calls are renamed to the canonical `bayan_cyml_*`; the unprefixed names were deprecated shims.
  - Binary size: **597,040 → 244,184 bytes** (x86_64), 609,104 → 260,352 (AGNOS), 756,672 → 338,296 (aarch64).
- **The font readers share one `_slurp`, and free their buffers** ([issue 0014](docs/development/issues/archive/0014-transient-read-buffers-never-freed.md)). The three copies of the read loop are now one function. Each reader splits into a read and a parse (`_font_parse`, `_font_header_parse`, `_flf_parse`), and frees the read buffer after the parse (`fl_alloc` / `fl_free`, first use in `src/`). `--list-fonts` no longer grows with the number of fonts: peak RSS for 200 fonts went from 16.7 MB to 13.3 MB, the same as for 3. `[deps].stdlib` gains `freelist` and `mmap`.
- **Named limits wired in** ([issue 0012](docs/development/issues/archive/0012-dead-geometry-constants.md)).
  - Five enums of limits and struct offsets were declared and never used. They now replace the literals, the three different meanings of `32` in `src/flf.cyr` kept apart.
  - New `MAX_GAP` and `CHARMAP_SIZE`. `MAX_INPUT` moved to where the cap is enforced.
  - `flf.cyr`'s "match font.cyr" comment, which would have tied the `.flf` envelope to schema 1, now says why they differ.
  - Codegen-neutral: an enum constant compiles to the same instruction as its literal.
- **`src/test.cyr` deleted.** It was an empty `return 0` from the scaffold that bare `cyrius test` counted as a passing suite. `[build].test` now names `tests/bannermanor.tcyr`. The test and bench harnesses exit through `SYS_EXIT`, not a raw 60, which is `exit` on x86_64 only.
- **`--help`** lists `--` ("end of flags: everything after it is TEXT, even a word starting with '-'"). This changes `--help` stdout bytes, as 1.1.4's help edit did, and also the usage block after a parse error. These are golden snapshot and error records; under ADR 0002 ruling 1 it is documentation, not a frozen byte.
- **`src/main.cyr`** — `--version` literal bumped to `bnrmr 1.4.1`.

### Documentation

- **`docs/guides/fonts.md`** ([issue 0017](docs/development/issues/archive/0017-docs-precision-pass.md)) — two validation lists, one per loader, and where they disagree. `name` documented as a listing requirement and a stem convention, not a render-path check. The exact size gate (65,535 bytes loads, 65,536 does not), zero geometry as out of range, the zero-entry rejection, and 128 (not 256) as the binding entry limit.
- **ADR 0001** — a 1.4.1 amendment with the same facts. It also writes down F-004's rule, until now only in audit prose: a font loader never calls `bayan_cyml_expand_value`.
- **Source comments** — `src/color.cyr` no longer claims a separator-less `brightX` (it exits 1). `src/layout.cyr` no longer promises "no output" for a sub-glyph `--width` (it writes blank rows).
- **CHANGELOG repairs** — [1.1.3]'s retracted "benchmarks are flat" bullet now opens with a superseded pointer, since a deep link reached it without the retraction. [1.1.4]'s fold seams are closed, and its two suite counts reconciled.
- **`docs/development/state.md`** rewritten. The stale **Unreleased** paragraph (shipped in 1.1.4) is gone, the version log is in order, and the benchmark line counts the real points. The consumers line names agora (embeds `bnrmr "AGORA"` art), anuenue (documents the `bnrmr | anuenue` pipeline), agnos (stages `/bin/bnrmr`) and agnoshi (its launch example), instead of `_None yet._`.
- **Pointers** — README, `docs/guides/getting-started.md`, `CLAUDE.md` (the roadmap pointer no longer says "1.2.x onward") and `scripts/doc-pin-check.sh` (the roadmap-exclusion comment, and the darshana scoping comment, now that `[deps.bayan]` follows that section).
- **`docs/development/roadmap.md`** — cleared of everything this release completed. Every remaining item is retargeted, and the issue register is current.

### Notes

- **Verification.**
  - `cyrius build` clean for x86_64, `--agnos` and `--aarch64`.
  - `cyrius lint --strict --strict-deferrals` 0 warnings on all of `src/` and the three harnesses.
  - `cyrius test` 3006 passed, 0 failed, on x86_64 and on aarch64 (`cyrius test --aarch64`, qemu).
  - Golden 285/285 on x86_64 and on the aarch64 build under qemu-aarch64.
  - `cyrius fuzz` 78,003 parses, 0 violations.
  - `cyrius coverage --min 100` (36/36 public functions, was 25/36).
  - `cyrius deps --locked` green, and `scripts/doc-pin-check.sh` green.
- **Correction to [1.2.0]: one output change shipped unrecorded** ([issue 0007](docs/development/issues/archive/0007-positionals-past-128-dropped.md)). Through 1.1.5 the stdlib flag parser silently dropped positionals past the 128th: `bnrmr` with 200 one-word arguments rendered 128 and exited 0. 1.2.0's `lib/` re-vendor brought a parser that grows instead, so all 200 render. That is a fix, but 1.2.0's "golden matrix byte-identical to 1.1.5" claim was true only because the matrix had no case past 128. It has one now (`positionals-200-past-128`).
- **Also fixed by 1.2.0's toolchain, unnoticed**: `--list-fonts` no longer hangs on a FIFO under `fonts/` ([issue 0011](docs/development/issues/archive/0011-list-fonts-hangs-on-fifo.md); accepted risk A-08). cyrius 6.6.10's `is_dir` asks `stat(2)` instead of `open(2)`.
- **Unblocked by ADR 0002, not in this release**: diagnostics to stderr, plus the `--color` error text's missing `bright-<name>` (issue 0016); checked writes (issue 0009); rejecting surplus CYML body rows (issue 0008); raising the `.flf` geometry ceilings. The ADR was accepted after this release's code was done, so these wait for roadmap 1.5.0. Each changes behavior on purpose and gets its own entry.
- **Natural-width renders cost ~0.9 µs more in process** (B4: 18.0 against 17.1 µs). That is the price of the extra call layers through the `file_write` wrapper on each of its 50 writes. It does not show at the process level, where the smaller binary more than pays for it (562 against ~570 µs per invocation).
- **B2 (`font_load_file`) did not move.** The sublib is the same parser code; [issue 0006](docs/development/issues/0006-bayan-cyml-parse-regression.md)'s ~45% bayan regression remains, as expected.
- **Not runtime-verified on AGNOS** (no AGNOS target here): the `file_write` route, freelist's AGNOS `mmap` (2 MB-granular there) and the sublib. All three compile through their AGNOS branches, which the stdlib's other AGNOS consumers already use.
- **Toolchain unchanged at 6.7.9**, darshana at 1.3.0. Moving to a newer cyrius is a separate change, with the bump checklist. (Corrected at 1.7.0: this line said "cyrius 6.7.12 is out", which was false. 6.7.12 was in progress, and a locally installed build of it was mistaken for a release.)

## [1.2.0] — 2026-10-12 (cyrius 6.7.9, darshana 1.3.0, stdout probes through darshana)

The cyrius 6.7 language minor, darshana's 1.3.0 surface, and the two terminal
probes `src/layout.cyr` hand-rolled since 0.4.0 / 0.5.0 moved onto darshana. **On
Linux no rendered byte changes**: a 224-invocation golden matrix — 112 piped
(every font, the `.flf` path and its malformed fixtures, every alignment, width,
pad and color spelling, every error path) and 112 on a pty (twelve renders at
each of seven window sizes including 0×0 and 50×5000, plus every `--color`
spelling at 24×80) — is byte-identical to 1.1.5 on x86_64, and on aarch64 under
qemu, except the `--version` literal. **On AGNOS the output changes, on
purpose**: banners now size to the real console (issue 0018, under Fixed).

### Changed

- **cyrius toolchain pin `6.6.2` → `6.7.9`** (the 6.7 language minor; 6.7.9 is the latest published release). **No source repair was needed.** Built under 6.7.9 before any other change, bnrmr compiled with zero errors and zero warnings on x86_64, `--agnos` and `--aarch64`, passed its full suite (2775) on x86_64 and on aarch64 under qemu, and rendered the golden matrix byte-identically to the 6.6.2 build. Because a clean compile cannot rule out a value that silently changed, the source was also swept for the silent-change hazards cyrius's `docs/development/ecosystem-migration.md` lists for 6.6.3–6.7.9, and none reaches it: no `!` operator (6.7.3 — bnrmr spells only `!=`), no typed pointer (so neither 6.7.8's narrow `*p` nor 6.7.9's pointer-step rules apply), no unary `-` / `~` on a constant (6.7.9 — negatives are written `0 - N` throughout), no compound assignment (6.7.5 / 6.7.6), no identifier spelled `const` / `true` / `false` / `do` / `dyn` / `trait`. No 6.7 language feature was adopted.
- **`lib/` re-vendored from the manifest**: `rm -rf lib/ && cyrius deps`, **109 files → 32**. Thirty are the same modules at the 6.7.9 snapshot (28 changed; `args_macos` and `args_win` are byte-identical); `alloc_cx.cyr` and `poison.cyr` are new (6.7.9's `alloc.cyr` includes both); 79 are gone — `tls*`, `yukti`, `vani`, `unicode/`, `thread*` and the rest of the full snapshot `cyrius lib sync --full` left at 1.1.3, none of which bnrmr's include graph reaches. The 1.1.5 build's `./lib/ shadows version-pinned … 11 bundled lib(s) differ` warning is gone with them. `[deps].stdlib` is unchanged. `bayan` (the CYML parser) moves `1.5.5` → `1.5.13` with the snapshot; the nine `cyml_*` wrappers the font loader calls have identical signatures, and the CYML load path is byte-stable (the loaded-equals-embedded test, every fixture, and the matrix's `--font` / `--list-fonts` cases).
- **`cyrius.lock` regenerated** for the new pin and tag — from empty, because `cyrius deps --lock` after the tag move kept the superseded `darshana … 1.0.0` commit row beside the new `1.3.0` one (6.7.9 behavior; reported to the owner). `cyrius deps --locked` passes: `lib/` and the lock are exactly what the tags resolve.
- **darshana pin `1.0.0` → `1.3.0`.** 1.3.0's bundle declares private constants with `const`, which cyrius gained in 6.7.2, so it cannot be consumed under the old pin — reproduced: the 6.6.2 compiler stops at `error:lib/darshana.cyr:315:7: expected '=', got identifier '_TTY_RAW'`. That is why the toolchain moved first. The bump itself needed no code change: everything bnrmr already consumed (`tty_sgr`, `tty_sgr_reset`, the 16 `TTY_FG_*`) is frozen and emits identical bytes — the matrix's pty leg renders every `--color` spelling.
  Evaluated against bnrmr and **deliberately not adopted**: `tty_sanitize_buf` in `TTY_SANITIZE_LATIN1` mode neutralizes exactly bnrmr's byte set (C0, DEL, raw 0x80–0x9F — it was modeled on bnrmr's rule) but replaces with `?` where bnrmr writes a space, which would move frozen `.flf` glyph-row bytes; darshana's ADR 0004 records that the space was not reproduced, so bnrmr keeps its own loop, and a new test pins the two byte sets equal. `tty_winsize_or` treats a 0-row terminal as size-unknown, where bnrmr reads columns only. The `_buf` SGR composers belong with issue 0005's one-write-per-row work, still scheduled. `TTY_BG_*`, 256-color and truecolor have no flag to serve, and a new flag is a major.
- **The stdout width and TTY probes go through darshana** ([issue 0019](docs/development/issues/archive/0019-darshana-probes-hand-rolled.md)). `term_width_ioctl` and `stdout_is_tty` each issued their own `TIOCGWINSZ` ioctl and each carried an AGNOS stub. Now one call, `tty_winsize(1, …)`, feeds a pure `_usable_cols(rc, cols)` that keeps both existing rules — a 0-column terminal is not a terminal (F-020) and columns clamp at `WS_COL_CAP` (F-008) — and on Linux `stdout_is_tty` is `term_width_ioctl() > 0`, so the two probes cannot disagree. `tty_isatty(1)` was not used because it answers 1 for a 0-column pty. `src/` no longer issues an ioctl of its own.
- **`LayoutLimits` no longer re-declares `TIOCGWINSZ`** (nor the two winsize offsets). The enum's `TIOCGWINSZ = 0x5413` sat in the same compilation unit as darshana's public `var TIOCGWINSZ = 0x5413`, after it. It was silent only because the values agree: cyrius resolves a duplicate to its LAST definition, so a differing value would have redirected darshana's own `tty_winsize` too, with only a `duplicate symbol … conflicting value` warning (verified on a minimal program under 6.7.9).
- **`src/main.cyr`** — `--version` literal bumped to `bnrmr 1.2.0`.
- **`cyrius.cyml [deps.darshana]`** — the comment now lists what bnrmr consumes and what it deliberately does not.

### Fixed

- **AGNOS: the console width was never queried** ([issue 0018](docs/development/issues/archive/0018-agnos-console-width-never-queried.md)). The AGNOS arm of `term_width_ioctl` hard-returned 0 on the premise that the console size "isn't queryable from userland yet". It is — agnos's `winsize` syscall #60, wrapped by darshana's AGNOS `tty_winsize`, already linked into every AGNOS `bnrmr`. So on AGNOS issue 0004's narrow-terminal truncation never engaged (a banner wider than the console wrapped into itself), `--align center|right` aligned inside `$COLUMNS` or 80 columns, and the F-008 clamp never ran. Routing through darshana gives AGNOS the console grid.
  **Output-byte change on AGNOS, deliberate.** With no `--width`, an AGNOS banner now truncates at the console width on a glyph boundary, and center/right alignment uses the console width; `$COLUMNS` is read only when the framebuffer console is down. **This includes redirected and piped stdout**: agnos has no per-fd terminal query and darshana's AGNOS `tty_winsize` ignores the fd, so `bnrmr X | cat` and `bnrmr X > file` on AGNOS take the console's geometry, where Linux leaves piped output untruncated. The bytes stay plain text. Linux is unaffected.
  **Not changed: `--color` on AGNOS stays off.** `stdout_is_tty`'s AGNOS arm still returns 0, but its comment's premise — that the console "doesn't interpret ANSI escapes" — was also false (agnos 1.43.1 parses SGR). The real reason is the per-fd gap: darshana's AGNOS `tty_isatty` answers 1 whenever the console is up, redirected fd 1 included, so following it would write SGR into `bnrmr --color red X > /etc/motd`. The width and the color decision diverge on AGNOS on purpose — a wrong width costs plain-text line length, a wrong TTY verdict puts escape bytes in a file. Color there waits for an agnos fd-kind query (filed with agnos by darshana); the roadmap's AGNOS-parity release keeps that item.

### Added

- **The first tests of either stdout probe** — suite **2775 → 2828** (+53). The suite's own stdout is whatever the runner gave it, so nothing could assert on the probes before; the new Linux tests point fd 1 at a descriptor they control, call the probe or the renderer, and restore fd 1 before asserting:
  - `t_usable_cols` (7) — the pure width rule: 0 columns, a failed query, the `WS_COL_CAP` clamp at 4096 / 4097 / 65535.
  - `t_probes_non_tty` (8) — fd 1 on `/dev/null` and on a pipe: width 0, not a TTY.
  - `t_probes_pty` (28) — fd 1 on a pty slave at 24×80, 0×80, 0×0, 24×0, 24×1, 50×5000 and 24×4096: the width and the TTY verdict for each.
  - `t_render_pty_vs_pipe` (7) — `render_layout` on the pty against the same render on a pipe, byte for byte: `--color red` and `--color rainbow` wrap each plain row in `ESC[<code>m … ESC[0m` (the first check anywhere of darshana's SGR bytes on bnrmr's TTY path); a 0-column pty renders exactly the plain bytes; an 11-column pty truncates `AGNOS` to `AG`; `--align center` on an 80-column pty equals `--width 80 --align center` on a pipe.
  - `t_scrub_matches_darshana_latin1` (3) — over all 256 byte values, `_scrub_ctl` neutralizes exactly the bytes `tty_has_ctl(…, TTY_SANITIZE_LATIN1, 0)` flags (65 of them), and replaces with a space, not darshana's `?`.
  Each was checked by mutation and seen to fail: `stdout_is_tty` as a bare `tty_isatty(1)` (3 failures — the 0×0 / 24×0 rows and the 0-column render), `tty_winsize_or` semantics (2 — the 0×80 row), the clamp removed (3), and the pre-1.2.0 AGNOS hard-0 applied on Linux (13).
- **Issues [0018](docs/development/issues/archive/0018-agnos-console-width-never-queried.md) and [0019](docs/development/issues/archive/0019-darshana-probes-hand-rolled.md)**, filed from darshana's 2026-10-12 consumer survey and archived as fixed.
- **`docs/benchmarks.md` Point 6** — an A/B of the 1.1.5 tree at 6.6.2 against this one at 6.7.9, six runs each: B1 noise, B2 flat (90.6 vs 89.7 µs), B3 +4.5% (672 vs 642 ns per 100 calls — every new run above every old one; `fit_chars` did not change, so it is the toolchain).

### Documentation

- **`docs/development/roadmap.md`** — every planned release moved down one minor (Prove the contract is now 1.3.0, … the fourth font 1.8.0), since this release took the next minor; the issue register's targets and issues 0016 / 0017 moved with them. The darshana-survey block is closed out. The AGNOS-parity release (now 1.7.0) is rewritten: console geometry is done; color on AGNOS is blocked on agnos, with the gate restated for the color probe and the width decision recorded. A stale `src/layout.cyr` line reference is updated.
- **`README.md`** — the piped-output sentence and the color line now say what happens on AGNOS; pin and assertion count refreshed. **`docs/guides/getting-started.md`** — the same refresh, and `src/layout.cyr` is described as routing its probes through darshana.
- **`docs/development/state.md`** — 1.2.0 entry; the skipped 1.1.5 entry backfilled; Toolchain, Source, Tests, Dependencies and Next refreshed.
- **`src/font.cyr`** — `_scrub_ctl` says why it is not darshana's sanitizer.
- **`scripts/doc-pin-check.sh`** — the roadmap-exclusion comment's example target versions.

### Notes

- **Verification**: `cyrius build` clean (0 warnings) for x86_64, `--agnos` and `--aarch64`; `cyrius lint` 0 warnings on all 8 `src/*.cyr` and the 3 harnesses; `cyrius test tests/bannermanor.tcyr` **2828 passed, 0 failed** on x86_64 and under `cyrius test --aarch64`; `cyrius bench` and `cyrius fuzz` run (fuzz: 1 passed — still the no-op stub, issue 0010); `sh scripts/doc-pin-check.sh` green; `cyrius deps --locked` green; golden matrix as above.
- **The AGNOS change is not runtime-verified** — there is no AGNOS target here, and an `--agnos` binary cannot run on the Linux host past its first `winsize` call, because agnos syscall #60 is Linux `exit`. What is verified: the AGNOS build compiles the width probe through darshana's AGNOS arm, the rule over its answer (`_usable_cols`) is tested, and darshana tests its AGNOS decode.
- **The golden matrix is not committed.** It is a scratch harness, like the 79-invocation diff before it; committing a golden suite with a CI pty leg is the roadmap's next release.
- **`&` binds tighter than `!=` in cyrius**, in 6.6.2 and 6.7.9 alike — verified, because the three readers' `mode & 0xF000 != 0x8000` regular-file gate (1.1.4) depends on it and reads as a bug to anyone expecting C precedence.

## [1.1.5] - 2026-09-11

### Changed

- **Toolchain `6.5.35` → `6.6.2`.** No source change; the value form needed none.
  Build, tests, and any bench/fuzz/distlib target the repo ships re-verified at the new pin.


## [1.1.4] — 2026-08-25 (P(-1) hardening — security, bounds, `.flf` fidelity)

The P(-1) hardening pass. Ten repairs; **no rendered banner byte changes**.
The golden suite — 79 invocations across every font, alignment, color, the
`.flf` path and every error path — is byte-identical to 1.1.2 and 1.1.3 except
the `--version` literal. Full report:
[`docs/audit/2026-08-25-audit.md`](docs/audit/2026-08-25-audit.md).

### Security

- **`--list-fonts` printed font metadata straight to the terminal (F-011, HIGH).** `_font_get_str` (`src/font.cyr`) copied a CYML header value with `memcpy` and a scan that stopped only at `"` and `\n`; `cmd_list_fonts` then wrote `name` and `description` to fd 1 unfiltered. A font file could therefore inject live ANSI — verified end to end with `ESC[2J` (erase display), `ESC]0;…BEL` (OSC window-title set), `ESC]8;;…BEL` (OSC 8 hyperlink), `ESC[8m` (conceal) and bare CR, delivered intact through both a pipe and a real pty. This is the **metadata half of F-001**: the 0.7.0 audit closed the same CWE-150 vector for `.flf` glyph rows and scoped the fix there, correctly noting the CYML *body* accepts only `.`/`#` — and left the *header strings* as the one CYML→stdout path that bypasses the body decoder. Severity is higher than F-001's by the 0.7.0 audit's own calibration: F-001 required the user to name the malicious file (`--font evil.flf`), while this needs only `--list-fonts` in an untrusted directory, and `find_files` recurses, so `fonts/pack/deep/evil.cyml` lists too. Now scrubbed at the parser boundary via a shared `_scrub_ctl` predicate identical to `src/flf.cyr`'s: C0 (`0x00-0x1F`), DEL, C1 (`0x80-0x9F`) → space. The scrub is length-preserving, so column alignment is untouched, and folding NUL into the first arm also fixes a silent `strlen` truncation.
- **The malformed-font branch echoed the raw filesystem path (F-012, MEDIUM).** `src/main.cyr` wrote `str_data(path_str)` verbatim before `(malformed — skipped)`, so the bytes came from the filesystem: a font named `ev<ESC>[31mil.cyml` emitted live SGR. A **separate** defect from F-011, not a duplicate — this branch runs precisely because the parser rejected the file, so a parser-boundary scrub cannot reach it. Now written through the same predicate. Every other user-echo site was checked and is clean: all of `src/main.cyr`'s error messages are string literals and none interpolate the user's value or path.
- **`$COLUMNS` bypassed every width ceiling (F-013).** It was the only one of the three frame-width sources without a cap — `--width` is *rejected* above `WIDTH_CAP` and `TIOCGWINSZ` is *clamped* at `WS_COL_CAP` by the F-008 fix — leaving a 256× overshoot bounded only by `PARSER_INT_CAP`: `COLUMNS=1048576 bnrmr --align right A` emitted 5,242,885 bytes. Now clamped at `WS_COL_CAP`. This matters most on AGNOS, where `term_width_ioctl` hard-returns 0 and `$COLUMNS` is the *only* frame source, so `WS_COL_CAP` never executed there at all.

### Fixed

- **agnos: every font-file load exited the process instead of rendering.** The three font-file readers — `_flf_slurp` (`src/flf.cyr`), `font_load_file` and `font_header_load` (`src/font.cyr`) — issued raw `syscall(2, path, 0, 0)` / `syscall(0, fd, buf, n)` / `syscall(3, fd)` for open/read/close across 12 call sites, ungated by any `#ifdef CYRIUS_TARGET_AGNOS`. Those are x86_64-Linux numbers. On agnos the same three numbers are **different calls**: `2` is `SYS_GETPID`, `0` is `SYS_EXIT`, `3` is `SYS_SPAWN`. So `syscall(2, ...)` returned the process's own pid — a positive value — the `if (fd < 0)` guard never fired, and the read on the next line was `exit(pid)`. `bnrmr --font block`, `bnrmr --font NAME.flf` and `--list-fonts` all terminated silently on agnos rather than rendering or reporting an error; only the embedded default font (which reads no file) worked. AGNOS has been a supported build target since [1.1.0], so this shipped broken for four releases.

  All 12 sites now route through `lib/io.cyr`'s `file_open` / `file_read` / `file_close`. Those wrappers carry the per-target bridge: agnos's `sys_open` is `(name, namelen, ao_flags)`, not Linux's `(path, O_flags, mode)`, and its `AO_*` bits differ from `O_*` (`AO_CREAT` `0x100` vs `O_CREAT` `64`), so even a corrected syscall *number* passed Linux-shaped arguments would have landed the flags in `namelen` — a silent ABI miscompile with no `ud2`. Bridging once inside `io.cyr` is the same fix upstream `bayan` applied to its own `_toml_slurp` this cycle. On Linux the wrappers are pass-throughs to the identical `SYS_OPEN` (2) / `SYS_READ` (0) / `SYS_CLOSE` (3), so nothing about the Linux path moves.

- **`src/font.cyr` and `src/flf.cyr` now include `lib/io.cyr` themselves.** Both call the wrapper set directly, but neither declared it — the symbol resolved only because `src/layout.cyr` includes `io.cyr`, and it does so *after* its own `include "src/font.cyr"`. The modules now declare the dependency they use instead of inheriting it from a sibling's include order. Includes are deduplicated, so the emitted binary is unchanged (verified byte-for-byte with and without the two lines).

- **`--width` / `--pad` accepted i64 modular wraparound (F-015).** `lib/flags.cyr`'s integer parser accumulates `n*10+d` with no overflow guard, and bnrmr validated only the post-wrap residue, so `--pad 18446744073709551617` rendered with pad=1 and `--width 18446744073709551620` exited 0 — silently defeating the caps issue 0002 froze at v1.0. Both flags are now taken as strings and parsed through `parse_uint`, which carries the F-002 `PARSER_INT_CAP` guard. Every previously-accepted spelling is preserved with its exact exit code and message — verified by A/B against the 1.1.3 binary across 38 inputs: `-0`, `-00`, `007`, `4096`, `+5`, `" 5"`, `abc`, empty and the cap boundaries are all unchanged; only the four wraparound cases move, from silent success to the correct `max` message and exit 1.
- **`.flf` endmark detection ignored trailing whitespace (F-016).** figlet's `readfontchar()` trims trailing `ISSPACE` *first*, then takes the last remaining byte as the endmark. bnrmr trimmed only a single CR (the issue-0003 fix), so a row ending in a space or TAB latched `endmark = ' '` and the literal `@`/`#` bytes rendered as banner art. Now trims the full `{space, TAB, CR, VT, FF}` set. **Output-byte change, measured and bounded**: a 397-font differential (18 upstream figlet fonts + 376 archive fonts + every in-tree fixture + `modular.flf`) shows 8 differing glyph sets across exactly 7 fonts — **all 7 already misparse today**, and no font changes its load/reject status. `tiny.flf`, `flf_crlf.flf`, `flf_esc_glyph.flf` and `modular.flf` contain no trailing whitespace and are byte-identical.
- **`.flf` hardblank range was narrower than the spec (F-014).** The header rejected any hardblank outside 33..126; FIGfont v2 allows any byte except NUL, LF, CR and space, and explicitly recommends DEL. 17 of the 1052 fonts in the reference corpus were rejected on byte 5 alone — including `bubble`, `digital` and `term`, three of the 18 fonts shipped with figlet itself. Widening only *admits* fonts, so nothing that loaded before can change: the hardblank→space substitution runs *before* the F-001 control scrub, so a DEL or C1 hardblank still becomes a space and never reaches stdout (covered by a new regression test).
- **Font readers accepted non-regular files (F-017).** `--font /dev/zero.flf` read to the size cap, and a FIFO blocked the process indefinitely. All three readers now gate on `S_IFREG` via `xstat` + `STAT_MODE` (not a hardcoded offset — `st_mode` sits at 24 on x86_64-Linux and 16 on aarch64-Linux). A directory still returns 0, one syscall earlier.
- **`block_font_embed` discarded `font_set_char`'s failure return (F-018).** Unreachable on the current table — the seven character ranges are disjoint — but the table is hand-maintained, and a future edit colliding two entries would have dropped a glyph silently. `main.cyr` already handled the 0 return with `failed to build embedded font`; it is now wired up.
- **`lens_scratch` was allocated, written and never read (F-019).** Up to 24,320 bytes of dead bump allocation per `.flf` load, plus a failure path that could reject a valid font on an OOM for a buffer nothing used.
- **`term_width_ioctl` and `stdout_is_tty` disagreed about a zero-column TTY (F-020).** On a terminal reporting `ws_col == 0` (a pty before `TIOCSWINSZ`, some serial consoles) the width probe returned 0, silently disabling issue-0004's narrow-terminal truncation, while the TTY probe returned 1 and kept emitting SGR — exactly the wrapping-colored-banner case 0004 exists to prevent. Both now require `ws_col > 0`.

### Added

- **`t_reader_dir_path`** — a directory path pushed through all three readers. This is the one input that separates the two guards: the open **succeeds** (so the `fd < 0` early-out does not fire) and the read then fails `EISDIR`, which must land on the `total <= 0` return. The pre-existing missing-file tests only ever exercised `fd < 0`, leaving the `file_read` error passthrough uncovered. This test took the suite 2762 → 2765; the release as a whole ends at 2775 (Notes). *(1.4.1: the S_IFREG gate under Fixed now rejects a directory before the open, so this test no longer reaches the read; it pins the gate instead. The `total <= 0` return is covered by `t_reader_empty_file`.)*
- **`scripts/doc-pin-check.sh` + a `Documented pin consistency` CI step.** Fails the build when a version or pin quoted in the docs disagrees with the file that owns it. Three sources of truth: `VERSION` (project version), `cyrius.cyml [package].cyrius` (toolchain pin — read with the exact `grep`/`sed` expression the workflows use to decide what to install, so the gate and CI can never disagree about what "the pin" is), and `cyrius.cyml [deps.darshana]`'s `tag` (darshana pin, read section-scoped so a future `[deps.<other>]` cannot be mistaken for it). Scans `README.md`, `docs/guides/*.md`, `docs/development/state.md` and `src/main.cyr`'s `--version` literal — 6 live mentions today. Runs as the **first** step in `ci.yml`, ahead of the toolchain install, because it invokes no `cyrius` at all; `release.yml` calls that workflow as its CI Gate, so tag pushes are gated by it too. This closes the class of failure behind 1.1.3's "four-release pin drift in the docs": `README.md` and `docs/guides/getting-started.md` sat on `cyrius = "6.0.1"` through the 1.1.0, 1.1.1 and 1.1.2 releases with every existing gate green, because nothing in CI reads prose — the build does not, the suite renders banners, and `release.yml`'s "Verify version" step ties the git tag to `VERSION` and stops at the repo root.
  - **Live vs historical is decided by SHAPE, not by the number.** Most stale versions in this tree are *supposed* to be stale: `CHANGELOG.md` is a per-release record, `state.md`'s dated `**N.N.N** — <date>.` paragraphs are that record in summary form, `docs/benchmarks.md` stamps each measurement point with the `**Toolchain**:` it was taken under (points 1–3 still read `6.0.1`, and rewriting them would falsify the benchmark), and `docs/development/issues/archive/` describes bugs as filed. None of those are scanned. Within the live set only declarative forms match — `cyrius = "X.Y.Z"`, a line-leading ``- **Cyrius pin**: `X.Y.Z` ``, `darshana = X.Y.Z`, a line-leading `**X.Y.Z**` *not* followed by an em dash (that em dash is the whole discriminator between README's Status line and state.md's 13-entry version log), and `"bnrmr X.Y.Z"`. Bare versions in running prose are deliberately unmatched: `state.md` alone carries `added at 1.1.3`, `(pinned, 1.1.3)`, `against 0.8.0` and `the 0.7.0 audit`, every one of them provenance.
  - **The gate asserts its own coverage.** A pattern-matching check fails the way it passes — silently, by matching nothing — so a table names which kind of claim each file must yield, and a file that yields none is a failure with its own message ("the gate found nothing to check where it must find something"), not a pass. Every mention found is printed on success, so a run listing 5 where it listed 6 is reporting that its own patterns broke rather than that the tree is clean. A line that matches a pattern but yields no extractable version is likewise an error, not a skip: `sed` passes a line it cannot rewrite straight through, and that garbage would otherwise be reported as doc drift.
  - Verified green on the current tree and **red for each failure mode**: toolchain / darshana / project version bumped with the docs left behind, a single doc mention reverted to `6.0.1` (the original bug, reproduced), a new stale quote added to a guide that had none, README's Status line reworded out from under the pattern, and a malformed `[package].cyrius` — which names the manifest as the culprit instead of blaming three correct docs. Stable under `bash`, `zsh` and `bash --posix`, and in the `C`, `C.UTF-8` and `en_US.UTF-8` locales.

### Changed

- **`--help` text** — `--width` no longer claims a sub-glyph width renders "nothing" (it renders `height` blank rows); the `--color` list gains `black` and the accepted `bright-<name>` dash alias. This changes `--help` stdout bytes; no test asserts them.
- **`src/main.cyr`** — `--version` literal bumped to `bnrmr 1.1.4`.

### Documentation

- **`docs/benchmarks.md` Point 4's A/B was invalid and is corrected.** It concluded "the 1.1.3 dep bump is bench-flat" from a lib-swap A/B — but `cyrius bench` and `cyrius build` run dep resolution first and restore any `lib/` file whose hash does not match `cyrius.lock`, `--no-deps` included, so both rows compiled against the same bayan. Re-run correctly (by pointing `CYRIUS_HOME` at a snapshot carrying the version under test) the result reverses: **bayan 1.5.2 costs ~27 µs against 1.0.1's 59 µs — a ~45% regression in `font_load_file`, introduced by the 1.1.3 bump.** The 1.0.1 figure also sits within noise of Point 3's 58 µs on cyrius 6.0.1, retiring Point 4's other claim of gradual drift across 6.0.1 → 6.2.24: B2 was flat for three toolchain generations and then stepped once. Root cause inside bayan is not diagnosed; the CYML parse is 62-65% of B2 and is the only part worth profiling. Point 5 records 1.1.4 as flat.
- **`SECURITY.md`** — the claim that "fonts that include literal escapes in glyph data are rejected at parse time" was false twice over: `.flf` rows are *sanitized*, not rejected, and metadata was neither. Replaced with the three real mechanisms, stated separately because they differ. Also dropped "stdin" from the threat-surface sentence — bnrmr never reads fd 0.
- **`docs/adr/README.md`** said "_No ADRs yet_" while ADR 0001 has existed since 0.2.0, and instructed the next author to create a colliding `0001-`.
- **`docs/development/state.md`** — the live snapshot silently skipped releases 1.1.0 and 1.1.1; both are backfilled.
- **`tests/bannermanor.bcyr`** — the header asserted the write side is "bounded by terminal/pipe throughput, not bnrmr's code". It is bnrmr's code: 28,637 `write(2)` calls to emit 28,679 bytes.
- Assertion counts in `README.md` and `docs/guides/getting-started.md` refreshed (2762 → 2775).

### Notes

- **The agnos fix itself is not runtime-verified here** — there is no agnos target in this environment. It rests on the `#ifdef` bridge inside `lib/io.cyr`, which upstream `bayan` and the rest of the stdlib's file paths already depend on. What *is* verified is that the agnos build output changed (37 507 bytes differ against a build of the pre-fix source), confirming the readers now compile through the agnos branch rather than the raw numbers.
- **The remaining raw `syscall()` sites in `src/` are out of scope and already portable.** The stdout writes in `src/main.cyr` and `src/layout.cyr` use literal `syscall(1, 1, ...)`, and `SYS_WRITE` is `1` on both Linux and agnos, so they are correct on both by coincidence rather than by construction; the `SYS_EXIT` and `SYS_IOCTL` sites use named enum constants and the `ioctl` pair is already `#ifdef`-gated (1.1.0). Folding the writes into a named wrapper is worth doing but is not this fix.

- **Known, not fixed: the write path issues one `write(2)` per glyph cell and per pad space.** Render cost therefore scales with banner width — 0.67 ms at natural width against 5.49 ms at `--width 4096`, an 8× difference that is almost entirely syscall overhead. Fixing it means buffering, which must interleave correctly with darshana's own unbuffered SGR writes to keep output byte-identical; deferred rather than rushed into a hardening release.
- **Known, not fixed: `src/font.cyr` links the whole bayan bundle for 9 CYML symbols**, which is most of the 516 KB binary. The added code is unreachable and `CYRIUS_DCE=1` NOPs rather than strips it. Needs a narrower entry point from bayan.
- **Correction to this entry and to [1.1.3]: `cyrius fuzz` green was cited as release evidence and is not evidence of anything.** `tests/bannermanor.fcyr` is a 16-line stub that includes nothing from `src/`, calls no parser, and returns 0 unconditionally — so `cyrius fuzz` reports `1 passed, 0 failed` no matter what the font parsers do. Both citations are struck above. Filed as [`issue 0010`](docs/development/issues/0010-fuzz-harness-is-a-no-op.md) and scheduled in [`docs/development/roadmap.md`](docs/development/roadmap.md); until it exercises `font_load_file` / `flf_load_file` / `font_header_load`, no release should cite it.
- Verification: build clean, `cyrius lint` clean on all 8 sources (0 warnings, 0 untracked deferrals), 2775 tests, `scripts/doc-pin-check.sh` green, and `--agnos` / `--aarch64` cross-builds clean with the aarch64 binary rendering correctly under `qemu-aarch64`.

## [1.1.3] — 2026-08-25 (toolchain + dep refresh — cyrius 6.5.35, darshana 1.0.0)

### Changed

- **cyrius toolchain pin 6.2.24 → 6.5.35.** Re-synced the vendored stdlib snapshot into `lib/` with `cyrius lib sync --full` (108 files). `lib/agnosys.cyr` was retired from the core snapshot upstream (cyrius commit `3db51e6c`) and is pruned here — nothing in `src/`, `tests/` or the rest of `lib/` ever included it. Four modules are new to the snapshot: `async_macos.cyr`, `async_win.cyr`, `thread_macos.cyr`, `yantra.cyr`. No public symbol bannermanor consumes was removed or resignatured across the range.
- **`bayan` folded forward 1.0.1 → 1.5.2** (it absorbed `dtoa`, `pdf` and `yaml`). All nine CYML symbols the font loader rides on — `cyml_parse`, `cyml_trim`, `cyml_doc_header{,_len}`, `cyml_doc_entry{,_count}`, `cyml_entry_header{,_len}`, `cyml_entry_body{,_len}` — keep identical arity, so `src/font.cyr` is byte-stable. bayan also dropped its own fixed 256-entry scan (which silently truncated past 256) for a counted heap allocation; bnrmr's `count > 256` guard in `font_load_file` is now policy rather than an inherited limit. **No observable change** — verified by rendering the same fixtures through the 1.1.2 and 1.1.3 binaries: identical results at every entry count tested.
- **`cyrius.cyml [deps.darshana]` pin bumped 0.7.1 → 1.0.0** — darshana's v1.0 API freeze (its ADR 0003). All 18 symbols bannermanor consumes (`tty_sgr`, `tty_sgr_reset`, and the 16 `TTY_FG_*` constants) are inside the frozen surface, so they can no longer move without a major bump. `--color` output is byte-identical.
- **`[deps].stdlib` gained `atomic`, `fs` and `fnptr`** (13 → 16 modules). This closes a pre-existing declaration gap rather than tracking anything new: `src/main.cyr` has always included `lib/fs.cyr` directly, and `fs`/`alloc` pull `fnptr`/`atomic` transitively. Because `lib/` is vendored as a full snapshot the build never noticed, but a non-`--full` `cyrius lib sync` produced a `lib/` that could not compile. The declared subset now covers the whole reachable include graph.
- **`src/main.cyr`** — `--version` literal bumped to `bnrmr 1.1.3`.

### Fixed

- **CI would have hard-failed on the new pin.** cyrius 6.5.25 rewrote `_dep_find_stdlib_dir()`: branch (a) used to test `file_exists("src/main.cyr")`, which is true for essentially every cyrius project, so bannermanor's own vendored `./lib` was returned as "the stdlib" and the version-pinned branch never ran. It now tests `_dep_is_cyrius_source_repo()`, so a manifest with `[package].cyrius` set **requires** `~/.cyrius/versions/<pin>/lib` and exits 1 otherwise. Both workflows hand-rolled a flat `~/.cyrius/{bin,lib}` copy that never created that layout, so `cyrius deps`, `build` and `test` would all have failed with `error: cyrius.cyml pins version 6.5.35 but it is not installed at …`. `ci.yml` and `release.yml` now exec the `install.sh` that ships inside the release tarball, matching the 6.5.x siblings. Reproduced against a clean `HOME`, and the fix verified end-to-end in the same sandbox (`deps` → `build` → `test`, 2762 passing).
- **`ci.yml`'s Test-step comment was wrong on both of its claims.** It said bare `cyrius test` no longer auto-discovers `.tcyr` and that the `cyrius tests` subcommand postdates the pin; `cmd_tests` ships in both 6.2.24 and 6.5.35, and bare `cyrius test` discovers correctly at both. The explicit `.tcyr` path is kept — it is a deliberate choice, not a workaround — and the comment now says so.
- **Stale `lib/cyml.cyr` references in the font documentation.** That module has not shipped since the 6.2.x reorg. `src/font.cyr`'s `MAX_GLYPHS` rationale and its "Parse via" comment, `docs/guides/fonts.md`'s 256-entry note, and `docs/adr/0001-cyml-font-format.md` (amended in place, body preserved as the historical record) all pointed readers at a file that no longer exists.
- **Four-release pin drift in the docs.** `README.md` and `docs/guides/getting-started.md` still quoted `cyrius = "6.0.1"` — missed by the 1.1.0, 1.1.1 and 1.1.2 bumps. `docs/development/roadmap.md` still announced v1.0.0 as the shipped version; it now defers to `state.md` instead of duplicating a number that goes stale every release. `docs/development/state.md`'s claim that darshana is "resolved via `path = \"../darshana\"` for development" has been wrong since 2026-05-20 — the manifest has declared `git` + `tag` throughout.

### Notes

- **No API or behavior changes.** Build clean, `cyrius lint` clean (0 warnings, 0 untracked deferrals), full suite green (2762 tests). Cross-builds clean for both `--agnos` and `--aarch64`. Rendered output across all three fonts, both alignments, the `.flf` path, the `--color` path and every error path is **byte-identical to 1.1.2** except the `--version` literal.
- **Superseded at 1.1.4: this claim is wrong.** The A/B below swapped files in `lib/`, which `cyrius bench` silently restores from `cyrius.lock`, so both arms measured the same bayan. Re-measured correctly, bayan 1.5.2 made `font_load_file` ~45% slower. See [1.1.4] Documentation, `docs/benchmarks.md` Point 4, and [issue 0006](docs/development/issues/0006-bayan-cyml-parse-regression.md). The original text follows, unedited.
  **Benchmarks are flat for this release.** Holding the 6.5.35 compiler fixed and swapping only the vendored `lib/`, `font_load_file(block.cyml)` measures 87.4 / 86.6 / 87.6 µs pre-upgrade against 88.3 / 86.3 / 86.8 µs post-upgrade — bayan 1.5.2 parses no slower than 1.0.1 despite quadrupling in size. The suite *is* ~29 µs slower than the 0.9.0 baseline in `docs/benchmarks.md`, but that drift predates this bump and entered across 6.0.1 → 6.2.24, three toolchain generations that shipped without a bench point. Captured as Point 4 with the A/B table; bisecting it is filed as follow-up.
- **The binary roughly doubled: 237 192 → 516 528 bytes.** This is `bayan` 1.5.2 arriving with PDF, YAML and Grisu2 `dtoa` attached — `src/font.cyr` includes the whole bundle to reach `cyml_parse`. The added code is unreachable (`1122 unreachable fns, 336 820 bytes`) and `CYRIUS_DCE=1` NOPs rather than strips it, so the size is carried, not executed. Trimming it would need a narrower CYML-only entry point from bayan; filed as follow-up, not blocking.
- **Two `lib/bayan.cyr` compiler warnings are gone** — the `assigning non-pointer to typed pointer` pair at the old bundle's TOML paths was fixed upstream. The build is now warning-free.

## [1.1.2] — 2026-06-19 (toolchain + dep refresh — cyrius 6.2.24, cyml → bayan)

### Changed

- **cyrius toolchain pin 6.1.14 → 6.2.24.** Re-synced the vendored stdlib snapshot into `lib/` with `cyrius lib sync`. The 6.2.x stdlib reorg dropped several modules from the core snapshot (`base64`, `bigint`, `csv`, `json`, `linalg`, `matrix`, `toml`, `u128`, and `cyml`); the stale copies were pruned from `lib/`.
- **CYML parser moved out of the core stdlib into `bayan`.** `cyml.cyr` no longer ships in the cyrius snapshot as of 6.2.x — the `cyml_parse` / `cyml_doc_*` / `cyml_entry_*` surface bannermanor's font loader depends on now lives in `bayan`. Updated `[deps].stdlib` (`cyml` → `bayan`) and `src/font.cyr`'s `include "lib/cyml.cyr"` → `include "lib/bayan.cyr"`. The consumed symbols are unchanged, so the font loader is byte-stable.
- **`cyrius.cyml [deps.darshana]`** — pin bumped `0.5.3` → `0.7.1` to track the latest release. The `tty_sgr` / `tty_sgr_reset` / `TTY_FG_*` symbols bannermanor consumes remain present and byte-stable.
- **`src/main.cyr`** — `--version` literal bumped to `bnrmr 1.1.2`.

### Notes

- **No API or behavior changes.** Build clean, full suite green (2762 tests). The CYML font-load path (now via `bayan`) and the `--color` darshana path were smoke-checked.

## [1.1.1] — 2026-06-08 (agnos argv fix)

### Changed

- cyrius toolchain pin 6.0.56 → 6.1.14.

### Fixed

- **agnos: `bnrmr TEXT` printed help instead of rendering.** `argc()`/`argv()` returned 0/null because the `var r = main();` entry idiom runs `main` as a module-global initializer — *before* cyrius's init-stack capture — so the command-line args were never seen. `main` is now called from a bare top-level statement (`_agnos_entry();`), which runs after the capture, so native `argc`/`argv` resolve and `bnrmr agnos` renders. Root cause + reproducer filed as a cyrius issue (agnos argv init-rsp capture).

## [1.1.0] — 2026-06-06 (AGNOS as a build target — builds + renders on both Linux and agnos)

### Added

- **AGNOS platform support** (VERSION → 1.1.0; cyrius pin 6.0.1 → 6.0.56). `bnrmr` now builds under `cyrius build --agnos` and renders ASCII banners on AGNOS (MOTD / splash text in the agnsh environment, output via the agnos `write` syscall). The only Linux-ism was terminal-size detection (`ioctl`/`TIOCGWINSZ`), gated inline with `#ifdef CYRIUS_TARGET_AGNOS` in `src/layout.cyr`:
  - `term_width_ioctl` → returns 0 on agnos so callers fall back to the default banner width;
  - `stdout_is_tty` → returns 0 (non-TTY) on agnos, keeping auto-color off (the fb console renders glyphs literally and doesn't interpret ANSI).
  - **The real fb-console-size query (`ioctl`/`TIOCGWINSZ` equivalent) is deferred to the 1.43.x graphics work** — terminal geometry is a console/graphics concern, so it lands with that arc (alongside the GPU surface). Until then, the default width is correct for banners.
- Inline gating, no shared platform-abstraction layer (extract later only if needed). The Linux path is unchanged (verified: Linux build OK + renders correctly).

### Validated

- `cyrius build --agnos src/main.cyr` → **OK** (`bnrmr_agnos`, 169 KB; darshana color dep builds for agnos too). Linux build + render unaffected (`./bnrmr AGNOS` renders the banner).

## [1.0.1] — 2026-05-23 (darshana pin bump — ecosystem alignment)

### Changed

- **`cyrius.cyml [deps.darshana]`** — pin moved from `0.3.5` → `0.5.3` so every AGNOS consumer of darshana is on the same release. Triggered by agora's M2-B work landing the same alignment for the telnet-MOTD coloring path; consolidating the ecosystem on one darshana version means a single audit surface when darshana 1.0 freezes.
- **`src/main.cyr`** — `--version` literal bumped to `bnrmr 1.0.1`.

### Notes

- **No API or behavior changes.** The `tty_sgr` / `tty_sgr_reset` / `TTY_FG_*` symbols bannermanor consumes are byte-stable from darshana 0.3.5 through 0.5.3 — the 0.5.x additions are the `_buf` family (e.g. `tty_sgr_buf` for buffer-targeted SGR emission), which bannermanor doesn't use yet. Adopting the `_buf` variants for single-write piped-output rendering is a future bite, not blocking.
- v1.0 frozen surface (CLI flags, CYML font schema, default font set) unchanged. The "freeze is the contract change" framing from [1.0.0] still holds.

## [1.0.0] — 2026-05-20

**v1.0**. The CLI flag surface, the CYML font format, and the default
in-tree font set are frozen — no signature changes from 0.9.0 to 1.0.0
in any of the three. The freeze itself is the contract change.

What the freeze locks:

- **CLI flags**: `--font` (`-f`), `--width` (`-w`), `--align`, `--pad`,
  `--color`, `--list-fonts`, `--help` (`-h`), `--version`. No flags
  added, no flags removed, no exit-code or stdout-byte changes for
  any valid invocation. New flags after 1.0.0 are an SCHEMA-MAJOR
  question, not a minor.
- **CYML font format**: schema = 1 (see `docs/adr/0001-cyml-font-format.md`).
  Body convention (`.` background, `#` stroke), `[font]` header
  fields, per-glyph entries — frozen. Schema 2 is the next-major
  question.
- **Default font set**: `block`, `slim`, `big`. Frozen as the in-tree
  trio. Additional fonts can ship in 1.x without breaking the
  contract (presence is additive, never subtractive).
- **`.flf` adapter contract**: read-only, uniform-width fit, no
  smushing, ASCII 32..126, 1 MB cap, C0/C1/DEL scrub. Bug fixes (like
  0.9.0's CRLF handling) are non-breaking; the documented limitations
  in CHANGELOG 0.6.0 are intentional and stay.

Issue 0002's `--pad` / `--width` caps land here as the freeze's one
documented `Breaking`. Issue 0001 (keystroke interleave) stays
deferred — the cost/risk analysis in its filing is unchanged.

### Breaking
- **`--pad N` capped at 64**; values 65..PARSER_INT_CAP are rejected
  with `bnrmr: --pad max 64` and exit 1. Pre-1.0 these were accepted
  and produced unbounded blank lines around the banner.
- **`--width N` capped at 4096**; values 4097..PARSER_INT_CAP are
  rejected with `bnrmr: --width max 4096` and exit 1. Pre-1.0 these
  were accepted and produced unbounded line lengths. The cap matches
  `WS_COL_CAP` (the 0.8.0 F-008 terminal-cols clamp) by design —
  a `--width` larger than the largest column count any terminal will
  ever report is by definition unreasonable. Issue 0002 documents
  the rationale; this closes it.

### Fixed
- **Banner wraps into itself on narrow terminals (issue 0004).**
  `render_layout` previously only called `fit_chars` when `--width N`
  was set explicitly. With the default (`--width 0`), the banner was
  emitted at full width regardless of terminal size; the terminal's
  soft-wrap broke row alignment when the banner was wider than the
  TTY (caught dogfooding `bnrmr --font modular.flf "BANNERMANOR 1.0"`
  on a 129-col terminal: 15 glyphs × ~9 cols ≈ 135 cols, ~6 cols
  over). The renderer now resolves an effective truncation width
  from `term_width_ioctl()` when `--width` is unset; whole-glyph
  truncation rules are identical to `--width N`. **Piped output is
  byte-identical to pre-1.0**: `term_width_ioctl()` returns 0 when
  stdout isn't a TTY, `fit_chars(0, ...)` returns `len` unchanged, so
  `bnrmr ... | cat` still emits the full untruncated banner — the M1
  byte-identity contract is preserved. The
  `t_layout_render_layout_default_matches_render` test (which runs
  non-TTY) still passes for this reason. Found and fixed in 1.0.0.

### Added
- `src/layout.cyr` — `WIDTH_CAP = 4096` and `PAD_CAP = 64` in
  `LayoutLimits`. Kept as separate constants from `WS_COL_CAP`
  because the *reason* differs (CLI input rejection vs. ioctl
  output clamping), even though the numeric value happens to match.

### Changed
- `src/main.cyr` — `--width` and `--pad` validation grows an
  upper-bound check immediately after the existing
  non-negative check. Error message style matches the existing
  negative-rejection messages (`bnrmr: <flag> max N`, exit 1).
- `VERSION` and the `--version` string bumped to `1.0.0`.

### Closed (out of M7 / M8)
- Issue 0002 (`--pad` / `--width` unbounded) — fixed in this release.
- Issue 0001 (keystroke interleave) — formally deferred past 1.0.0.
  Documented in the issue file; revisit in a future minor if the
  cost/benefit shifts.
- Issue 0003 (CRLF `.flf` endmark bleed) — fixed in 0.9.0.

## [0.9.0] — 2026-05-20

Closes **M7**. Fixes the one real bug surfaced by the maintainer-MOTD
dogfood cycle (issue 0003 — CRLF-line `.flf` fonts bleed endmark bytes
into glyph rows), and captures the **third and final benchmark trend
point** so the v1.0 "3-point benchmark trend" criterion is satisfied.

Issue 0001 (keystroke interleave during render) was already deferred
past v1.0 in 0.7.0; issue 0002 (unbounded `--pad` / `--width`) stays
deferred to the M8 freeze pass where the cap becomes a documented
`Breaking` change. No remaining open M7 work; M8 is next and cuts v1.0.

### Fixed
- **Issue 0003 — CRLF-line `.flf` fonts bleed endmark bytes.** `src/flf.cyr`
  previously read the byte immediately preceding `\n` as the endmark
  character. For CRLF-terminated `.flf` files (common from Windows
  authoring tools like JavE — `modular.flf` in the repo top level was
  the dogfood reproducer), that byte was `\r`, so the real endmark
  (`#`, `@`, `$`, …) was left embedded in glyph row data — visible at
  render time as a literal column of endmark characters down the
  right edge of every glyph. The loader now trims a trailing `\r`
  from each line before endmark detection and the strip-trailing-
  endmark loop. Pure-LF `.flf` files are unaffected (the trim is a
  no-op when the trailing byte is not `\r`). `cursor` still advances
  past the original `\n` position so file traversal is unchanged.

### Added
- `tests/fixtures/flf_crlf.flf` — `tests/fixtures/tiny.flf` byte-for-byte
  with every `\n` re-encoded as `\r\n`. Reproduces the issue 0003
  vector in a 493-byte fixture.
- `tests/bannermanor.tcyr` — `t_flf_crlf_endmarks_stripped`: asserts
  the CRLF fixture loads, glyph rows do not contain the `@` endmark,
  and the CRLF and LF fixtures produce byte-identical glyph row 0
  across all 95 glyphs. 2762 assertions (up from 2754).
- `docs/benchmarks.md` — point 3 captured (block_font_embed 7 ns,
  font_load_file 58 µs, fit_chars ×100 = 572 ns). Flat against 0.8.0;
  the CRLF trim is in `.flf` parsing which the benchmark set doesn't
  exercise. M7's 3-point trend item is closed.

### Changed
- `VERSION` and the `--version` string bumped to `0.9.0`.

## [0.8.0] — 2026-05-20

Closes the **v1.0 defense-in-depth items** from the 0.7.0 audit. Both
were tagged "future work" in `docs/audit/2026-05-20-audit.md`; both
are now belt-and-suspenders against future regressions even though
the audit confirmed neither was reachable as a bug in 0.7.0.

Also captures **benchmark trend point 2 of 3** against the new
parsers and clamps. M7's MOTD dogfood is in-flight on archaemenid;
one cosmetic issue surfaced (0001, keystroke interleave) and was
deferred past v1.0; one observed-but-deferred issue (0002, unbounded
`--pad` / `--width`) was filed for the M8 freeze pass.

### Added
- `docs/development/issues/archive/0002-unbounded-pad-and-width.md` — filed
  from the pre-release ad-hoc stress sweep. `--pad 100000` produces
  200 005 newlines, `--width 1000000` produces a 500 KB line.
  No security impact (user-controlled); flagged for M8 freeze.
- `docs/benchmarks.md` — point 2 captured (block_font_embed 6 ns,
  font_load_file 58 µs, fit_chars 5.72 ns). No regression vs 0.7.0;
  deltas all within bench-frame noise floor.

### Changed
- **F-002 (defense in depth) — parser overflow caps.** `parse_uint`
  (`src/layout.cyr`), `_font_get_int` (`src/font.cyr`), and
  `_flf_take_int` (`src/flf.cyr`) now reject any value that exceeds
  the shared `PARSER_INT_CAP` (1 048 576) during accumulation,
  rather than risk silent i64 wrap. Downstream bounds were already
  tighter (`width ≤ 64`, `height ≤ 32`, etc.) — this guard is for
  a future relaxation that might widen those caps.
- **F-008 (defense in depth) — `ws_col` clamp.** `term_width_ioctl`
  (`src/layout.cyr`) clamps the TIOCGWINSZ-reported column count at
  `WS_COL_CAP` (4096). No current bnrmr code path sizes an
  allocation from cols, but a `resize -s 65535 65535` attack
  documented in the audit's external survey is now structurally
  defeated.

## [0.7.0] — 2026-05-20

Closes the **M7 security audit pass**. One concrete vulnerability
(F-001: `.flf` glyph rows could smuggle ANSI control bytes through to
stdout, CWE-150) is fixed in this release. The remainder of the audit
documents positive observations and defense-in-depth recommendations
for v1.0. See [`docs/audit/2026-05-20-audit.md`](docs/audit/2026-05-20-audit.md)
for the full report.

M7 is not closed by this release — the maintainer-MOTD dogfood cycle
and the 3-point benchmark trend (`docs/benchmarks.md`) remain.

### Security
- **F-001 (HIGH) — `.flf` glyph row control-byte injection.** The
  `.flf` loader (`src/flf.cyr`) previously copied glyph row bytes
  verbatim after hardblank→space substitution. A malicious `.flf`
  could embed an ESC (`0x1B`) or other C0/C1 control byte inside a
  glyph; `bnrmr --font evil.flf "X"` would emit real ANSI to the
  user's terminal — the same vector documented in the OpenAI Codex
  CLI RCE (CVE-2026-…) and the `gh run view --log` advisory. The
  per-byte copy now scrubs `0x00–0x1F`, `0x7F`, and `0x80–0x9F` to
  space after the hardblank substitution. CYML body bytes were
  already restricted to `'.'` and `'#'` and were never exposed.

### Added
- `docs/audit/2026-05-20-audit.md` — full 0.7.0 audit report:
  10 findings (1 HIGH/fixed, 3 LOW/accepted, 6 informational), threat
  model, external CVE survey, future-work tracking for v1.0
  defense-in-depth.
- `tests/fixtures/flf_esc_glyph.flf` — synthetic 1-row `.flf` whose
  space glyph carries a literal ESC byte; consumed by the new
  regression test.
- `tests/bannermanor.tcyr` — `t_flf_strips_control_bytes` (loaded ESC
  row reads back as space; non-control bytes preserved). 2754
  assertions (up from 2751).

### Changed
- `src/flf.cyr` — per-byte glyph copy now applies the control-byte
  scrub described under Security.

## [0.6.0] — 2026-05-20

Closes M6 — legacy `.flf` read adapter. Users with existing figlet
font libraries can now `bnrmr --font path/to/standard.flf "hello"`
and get a banner; CYML stays canonical.

### Added — M6 (legacy .flf read path)
- `bnrmr --font NAME.flf` — when the `--font` value ends in `.flf`,
  the value is taken as a literal filesystem path and dispatched to
  the new `flf_load_file` adapter. Other values continue through the
  CYML loader (`fonts/NAME.cyml`) with the existing path-segment
  sanitization untouched.
- `src/flf.cyr` — new module. `flf_load_file(path)` validates the
  `flf2a$` magic line, parses the 6 standard header ints
  (height / baseline / max-length / old-layout / comment-count), skips
  comment lines, decodes 95 glyph blocks (ASCII 32..126) with
  per-glyph endmark detection and hardblank → space substitution,
  then assembles a uniform-width `Font*` (gap=0, width = observed
  max across all glyphs). Same `Font*` shape as the CYML loader, so
  the renderer is unchanged.
- `tests/fixtures/tiny.flf` — synthetic 95-glyph fixture; exercises
  header parse, comment-skip with CL=0, endmark strip, hardblank
  substitution, geometry registration.
- `tests/fixtures/flf_bad_magic.flf` / `flf_bad_height.flf` /
  `flf_truncated.flf` — malformed fixtures consumed by the loader
  rejection tests.
- `tests/bannermanor.tcyr` — `t_load_tiny_flf` (geometry, charmap,
  hardblank assertions), `t_load_flf_missing`, and
  `t_load_flf_malformed` (three malformed fixtures → 0). 2751
  assertions (up from 2641).

### Notes — M6 (known limitations, intentional for v0.6)
- **Uniform-width fit.** Every glyph row is right-padded with spaces
  to the font's observed max width; gap = 0. Narrow glyphs (e.g.
  `.` `!` `,`) carry trailing whitespace, so output diverges from
  `figlet -W` for fonts with significant width variance. Variable
  per-glyph widths would require extending the Font* model and the
  renderer's per-row byte emission loop — pushed beyond v0.6.
- **No smushing or kerning.** The header's old-layout / full-layout
  fields are parsed and discarded; hardblanks render as spaces, which
  matches figlet's no-smushing mode. Smushing rules are out of scope
  for v1.0.
- **ASCII 32..126 only.** The 7 trailing "German" required chars
  (196 / 214 / 220 / 228 / 246 / 252 / 223) and any code-tagged
  glyphs after the standard block are *skipped*, not failed on. v1.0
  is ASCII-only per `roadmap.md` "Out of scope".
- **1 MB file cap.** Bounded read; oversized files are rejected.

### Changed — M6
- `src/main.cyr` — `--font` dispatch grows a `.flf` branch (delegates
  to `flf_load_file`); CYML branch unchanged. `print_usage` gains
  one line documenting the `.flf` form. Header comment block
  refreshed to list M5 + M6.
- `VERSION` and the `--version` string bumped to `0.6.0`.

## [0.5.0] — 2026-05-20

Closes M5 — color. `--color NAME` lands with the 16 ANSI named
foregrounds plus a `rainbow` per-row cycle. SGR primitives are
sourced from darshana 0.3.5 — no inline ANSI in bnrmr.

### Added — M5 (color via darshana)
- `bnrmr --color NAME` — colorize the banner. Accepts the 8 base ANSI
  colors (`black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`,
  `white`) and the 8 bright variants (`bright_red`, `bright-cyan`, …
  both underscore and dash forms accepted). Special value `rainbow`
  cycles a 6-color hue rotation per banner row.
- TTY auto-detection: SGR sequences are emitted only when stdout is
  attached to a TTY (probed via TIOCGWINSZ). Pipes / redirects
  receive plain bytes. Roadmap M5 acceptance: `bnrmr --color cyan
  "AGNOS"` renders colored on TTY, plain on `bnrmr ... | cat`.
- `src/color.cyr` — new module. `parse_color(name)` maps user strings
  to either an SGR code (30..37 / 90..97), `COLOR_NONE`, `COLOR_RAINBOW`,
  or `-3` (unknown — distinct from default). `rainbow_color_for_row(r)`
  returns the SGR code for row `r` modulo 6.
- `src/layout.cyr` — `stdout_is_tty()` helper. `render_layout` gained
  a 7th `color` param; per-row SGR-set/reset wrapping when color
  != `COLOR_NONE` and stdout is a TTY.
- `tests/bannermanor.tcyr` — coverage for `parse_color` (all 16 names
  in underscore + dash forms, special values, unknown names),
  `rainbow_color_for_row` (full 6-step cycle + wrap), and sentinel
  distinctness. 2641 assertions (up from 2608).

### Changed — M5
- `src/render.cyr` — `render()` shim passes `COLOR_NONE` through to
  `render_layout`'s new color parameter. Byte-identical behavior
  preserved.
- `cyrius.cyml` — `[deps.darshana]` resolves the sibling library.
  Currently pinned via `path = "../darshana"` for development; will
  flip to `git + tag = "0.3.5"` at release-cut time.
- `lib/darshana.cyr` — vendored from `darshana@0.3.5` via `cyrius
  deps`. Provides `tty_sgr`, `tty_sgr_reset`, and the 16
  `TTY_FG_*` SGR constants.
- `VERSION` and the `--version` string bumped to `0.5.0`.

## [0.4.0] — 2026-05-20

Closes M4 — layout flags. `--align`, `--width`, `--pad` land, CLI
parser migrated to `lib/flags.cyr` (getopt-long shape), terminal
width detection wired through ioctl + COLUMNS + 80-col fallback.

### Added — M4 (layout flags)
- `bnrmr --align V` — banner alignment within the frame. `V` is one
  of `left` (default), `center`, `right`. Short aliases `L`/`C`/`R`
  and `centre` are accepted. Frame width = `--width N` if given,
  else terminal width (TIOCGWINSZ on stdout), else `$COLUMNS`, else
  80 (documented fallback so `bnrmr --align center 'hi' | cat`
  still centers).
- `bnrmr --width N` (short: `-w N`) — truncate input at the glyph
  boundary so no banner row exceeds N columns. `--width 0` is the
  default and means unlimited. Truncation is always whole-glyph; a
  glyph is never half-rendered.
- `bnrmr --pad N` — N blank lines above and below the banner.
- `bnrmr -h` short alias for `--help`; `-f NAME` short alias for
  `--font NAME`.
- `src/layout.cyr` — new module. Exposes `term_width_ioctl()`,
  `term_width_env()`, `resolve_frame()`, `banner_width()`,
  `fit_chars()`, `align_pad()`, `parse_uint()`, and the
  `render_layout(font, text, len, width, align, pad)` orchestrator.
- `tests/bannermanor.tcyr` — coverage for layout math (`fit_chars`,
  `align_pad`, `banner_width`, `parse_uint`) and `render_layout`
  bounds. 2608 assertions (up from 2573).

### Changed — M4
- `src/main.cyr` — CLI arg parsing now goes through `lib/flags.cyr`
  (getopt-long-style: supports `--name value`, `--name=value`,
  short forms like `-f`, and `--` terminator). Replaces the previous
  hand-rolled `streq_lit` ladder. `--help` text rewritten to list
  the full M4 flag surface.
- `src/render.cyr` — `render(font, text, len)` is now a thin wrapper
  over `render_layout` with neutral options (`width=0`,
  `align=ALIGN_LEFT`, `pad=0`). Byte-for-byte identical to the
  pre-M4 output for callers that don't opt into layout flags
  (covered by the existing test suite).
- `cyrius.cyml` — `[deps].stdlib` adds `flags`.
- `VERSION` and the `--version` string bumped to `0.4.0`.

### Contract — M4
- If `--width N` is smaller than a single glyph (i.e. `N < font width`),
  bnrmr emits no banner. A clean "no output" is the documented
  behavior — preferred over partial-glyph rendering or silently
  overflowing the frame. Documented under `--width` in `--help`.

## [0.3.0] — 2026-05-20

Closes M3 — the default font set. Block expanded to full printable
ASCII; two new fonts (`slim`, `big`) shipped; `--list-fonts` and a
font-authoring guide land alongside. Toolchain pin caught up to
`cycc` 6.0.1.

### Added — M3
- `bnrmr --list-fonts` lists fonts in `./fonts`, alphabetically, with
  geometry (`WxH gap=N`) and description pulled from each font's `[font]`
  header. Malformed font files are surfaced as `(malformed — skipped)`
  rather than aborting the listing.
- `src/font.cyr` — `font_header_load(path)` lightweight loader. Parses
  only the `[font]` file header, validates schema + geometry, and
  returns a `FontHeader*` carrying width / height / gap / name /
  description. Skips glyph decode (cheaper than `font_load_file`).
- `src/font.cyr` — `_font_get_str()` TOML-style `key = "value"` parser
  used by the header loader. `_font_get_char()` now accepts `\"` and
  `\\` escapes so fonts can declare `char = "\""` and `char = "\\"`.
- `fonts/block.cyml` — 32 punctuation glyphs added: `! " # $ % & ' ( ) * + , - . / : ; < = > ? @ [ \ ] ^ _ \` { | } ~`.
  Glyph count goes from 37 to 69 (space + 0–9 + A–Z + printable
  punctuation). `bnrmr "Hello, World!"` now renders the punctuation
  inline instead of falling through to blank space glyphs.
- `fonts/slim.cyml` — second in-tree default font. 4×5, gap=1; one
  column narrower per glyph than block (~16% horizontal compression).
  Full printable ASCII coverage (69 glyphs), uppercase-only with
  fold-fallback for lowercase. Reachable via `bnrmr --font slim TEXT`
  and listed by `bnrmr --list-fonts`.
- `fonts/big.cyml` — third in-tree default font. 7×7, gap=1; chunky
  banner option, ~96% more cells per glyph than block. Full printable
  ASCII coverage (69 glyphs), uppercase-only with fold-fallback for
  lowercase. Closes the M3 default-font set at three (small / medium
  / large at distinct sizes).
- `src/font_block.cyr` — mirrors the new glyphs byte-for-byte; the
  M2 acceptance test now covers 69 glyphs × 5 rows. `_block_raw_row`
  was split into `_block_raw_row_lo` (idx 0–36) and `_block_raw_row_hi`
  (idx 37–68) to stay under cycc's 256-return-per-function limit.
- `docs/guides/fonts.md` — full font-authoring walkthrough (schema,
  body convention, validation gates, drop-in workflow, design tips).
- `tests/bannermanor.tcyr` — `font_header_load` happy path / missing
  file / bad-schema rejection; `t_glyph_punctuation` covering all 32
  new chars; `t_glyph_fold_is_fallback` pinning the fold-fallback
  semantics; `t_load_slim_cyml` and `t_load_big_cyml` each validating
  geometry and full printable-ASCII coverage on the new fonts. 2573
  assertions (up from 1334).

### Changed — M3
- `font_glyph_index` lowercase fold is now a **fallback**: a font that
  registers a lowercase glyph gets that glyph honored; only fonts
  with no lowercase entry (like `block.cyml`) fall through to the
  uppercase. Lets future taller fonts ship distinct lowercase without
  changing block's behavior.
- `cyrius.cyml` pin bumped from `6.0.0` to `6.0.1` — matches local
  cycc, silences toolchain-drift warning.
- `VERSION` and the `--version` string bumped to `0.3.0`.

## [0.2.0] — 2026-05-19

First post-scaffold release. Bundles milestones M1 (first render path)
and M2 (CYML font format) into one tag.

### Added — M2 (CYML font format)
- `docs/adr/0001-cyml-font-format.md` — schema decision: multi-entry
  CYML with `[font]` file header and per-glyph entries; `.` for
  background, `#` for stroke (avoids `lib/cyml.cyr` body trimming);
  rationale against `.flf` as canonical.
- `fonts/block.cyml` — first canonical CYML font, extracted from the
  embedded block font; same 37 glyphs (space, 0–9, A–Z).
- `src/font.cyr` — `Font` struct (width / height / gap / count /
  rows / charmap) + `font_load_file()` CYML loader. Validates file
  size (≤ 64 KB), schema (= 1), geometry bounds, body shape (height
  rows × width bytes, `.`/`#` only), and rejects duplicate `char`
  entries.
- `src/render.cyr` — renamed `render_block()` → `render(font, ...)`;
  same code path now serves both embedded and on-disk fonts.
- `src/main.cyr` — `--font NAME` resolves to `fonts/NAME.cyml` (path
  separator / `..` / control char rejected at the name level). Default
  (no flag) uses `block_font_embed()` so `bnrmr "hello"` still works
  with zero config.
- `tests/bannermanor.tcyr` — M2 coverage: loader happy path, missing
  file → 0, malformed fixtures (bad schema, bad body byte, wrong row
  count) → 0, and the M2 acceptance check: every char's glyph index
  and every glyph's rows are byte-identical between embedded and
  `fonts/block.cyml`. 1334 assertions.
- `tests/fixtures/{bad_schema,bad_body_byte,wrong_row_count}.cyml`
  — malformed-font fixtures.
- `cyml` and `result` added to `[deps].stdlib` in `cyrius.cyml`.

### Changed — M2
- `src/font_block.cyr` is now a `block_font_embed()` builder that
  returns a `Font*` instead of providing `block_glyph_index` /
  `block_row` directly. Embedded and on-disk fonts share one
  `Font*`-typed code path through the renderer.

### Added — M1 (first render path)
- `src/render.cyr` — first render pipeline: composes glyph rows into
  a banner on stdout, with a 1 KB input length cap.
- `src/font_block.cyr` — hardcoded 5×5 "block" font covering space,
  `0`–`9`, `A`–`Z`. Lowercase ASCII folds to uppercase; unsupported
  characters render as the space glyph (no error).
- `src/main.cyr` — argv concatenation + length-cap enforcement +
  render dispatch. Flags: `--version`, `--help`. With no args, prints
  usage.
- `tests/bannermanor.tcyr` — coverage for glyph index lookup, row
  shape invariant, renderer bounds.
- `args` added to `[deps].stdlib` in `cyrius.cyml`.

## [0.1.0]

### Added
- Initial project scaffold
