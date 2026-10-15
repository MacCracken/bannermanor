# BannerManor — Roadmap

> Forward-only. Shipped work lives in [`../../CHANGELOG.md`](../../CHANGELOG.md);
> this file is the sequencing of what's still ahead — what ships next,
> in what order, against what dependency gates. State lives in
> [`state.md`](state.md), which owns the current version; this file
> names *target* versions for planned work, and shipped versions only as
> provenance.

**Milestones**: M1–M8 closed at the v1.0.0 freeze. The freeze locked the
CLI flag surface, the CYML font format (schema 1), the default font set
(block / slim / big), and the `.flf` adapter contract. Everything below
is post-freeze work, and the freeze is what shapes it.

**Next**: 1.5.0 — *Diagnostics, failure honesty, and the malformed-input
rulings*. **Unblocked**: its gate was
[ADR 0002](../adr/0002-freeze-scope-error-paths-and-malformed-input.md),
accepted as written on 2026-10-15.

## What the freeze permits

Every item here is classified against the 1.0.0 freeze sentence:

> No flags added, no flags removed, no exit-code or stdout-byte changes
> **for any valid invocation**.

[ADR 0002](../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
(**Accepted** 2026-10-15) defines "valid invocation" and rules on the three
readings that were never written down:

1. **Error-path output is not frozen**, but exit codes are. Diagnostics
   may move to stderr in a minor.
2. **Exit 0 after a failed write is a defect**, not frozen behavior.
3. **A structurally malformed font is not protected.** Metadata rules
   (`name` against the stem) are 2.0. bnrmr's own limits (the `.flf`
   envelope) may widen.

Those rulings are what make all of 1.5.0 below 1.x work. The golden
suite (`scripts/golden.sh`) is the mechanical side of every ruling. Its `frozen` tier must never move in 1.x; its
`error` tier moves only under ruling 1, re-baselined deliberately, record
by record.

Settled regardless of the ADR, and **not** 1.x work under any reading:
new flags (the freeze calls them "an SCHEMA-MAJOR question, not a
minor"), new spellings or a looser grammar for a flag value, rendered
banner bytes for inputs that render correctly today, and CYML schema 1.
See [Beyond 1.x](#beyond-1x).

One thing the freeze explicitly permits: *"Additional fonts can ship in
1.x without breaking the contract (presence is additive, never
subtractive)."*

## Planned releases

Versions are targets, not commitments — ship-when-ready. Sequencing is
by dependency, then by value.

### 1.5.0 — Diagnostics, failure honesty, and the malformed-input rulings

**Unblocked** by ADR 0002 (Accepted 2026-10-15). Each item below cites
the ruling that permits it; quote that ruling in its CHANGELOG entry.

- **Diagnostics to fd 2** ([issue 0016](issues/0016-diagnostics-go-to-stdout.md),
  ruling 1). `bnrmr --font typo "$HOSTNAME" > /etc/motd` currently writes
  the error into the MOTD, and `banner=$(bnrmr ...)` captures it as the
  banner. Every named consumer is exactly this shape. It is not a simple
  swap: `print_usage()` is called from five sites on both sides of the
  divide. A requested `--help` stays on stdout; the usage block printed
  after an error follows the error to stderr. `cmd_list_fonts`'
  informational lines are exit-0 and stay on stdout. In the same change,
  add the `bright-<name>` alias to the `--color` error text so it agrees
  with `--help`. Then the `error` tier moves once. Since 1.4.2 the parser
  is cmdit, whose `cmdit_print_error` already writes stderr and names the
  offending token (`unknown flag: --bogus`). Adopting it changes the
  wording as well as the stream, which ruling 1 permits; decide it here,
  in the same re-baseline, rather than in a later one.
- **Check write returns** ([issue 0009](issues/0009-write-return-never-checked.md),
  ruling 2). A retry-on-partial loop and errno classification, not a bare
  nonzero check. Exit nonzero when the banner did not reach fd 1:
  `bnrmr hi > /dev/full` exits 0 today.
- **One write per row** — issue 0005's Option 2 (Option 1 shipped in
  1.4.1). Adopt darshana's `_buf` SGR composers and assemble each row,
  color included, in one buffer. That collapses the emit sites in
  `render_layout` to one, so the checked write above is a single site.
  Size the buffer from the 1 KB input cap, not `WIDTH_CAP`: the worst case
  is 8,191 bytes, which exceeds `PIPE_BUF`.
- **Reject surplus CYML body rows** ([issue 0008](issues/0008-cyml-body-not-fully-consumed.md),
  ruling 3). One line in `_font_decode_body`. `t_cyml_entry_rules` pins
  today's behavior and flips with the fix.
- **Raise the `.flf` geometry ceilings** (ruling 3, additive). Measured
  over the 1052-font reference corpus: 973 load, and all 79 rejections are
  geometry or size. A scratch build with the ceilings widened rendered
  all 973 loading fonts byte-identically. Raise only `src/flf.cyr`'s
  `FLF_MAX_WIDTH` / `FLF_MAX_HEIGHT`. **Never** `src/font.cyr`'s
  `MAX_WIDTH` / `MAX_HEIGHT`: those are schema 1. Since 1.4.1 the two
  sets are separate constants, with a comment saying so. Mind that
  `FLF_MAX_WIDTH` is also the scratch stride per glyph row
  (`95 × height × FLF_MAX_WIDTH`), so a much larger envelope wants the
  scratch sized from the observed width, not the cap. Update `t_flf_header_gates`.

**Gate (mechanical)**: the frozen tier is byte-identical. The error tier
is re-baselined deliberately, and its diff reviewed line by line.

### 1.6.0 — Fonts findable, listing honest

The largest genuinely 1.x-eligible user-facing gap. All the listing items
ship together so the output moves once.

- **A font search path, plus packaging** ([issue 0015](issues/0015-fonts-not-findable-when-installed.md)).
  An installed `bnrmr` finds no fonts. Even `-f block` fails, while bare
  `bnrmr` renders the same font from its embedded copy. And `release.yml`
  publishes `build/*` without `fonts/`, so slim and big do not exist for
  anyone who downloads a release. That matters now: agnos stages
  `/bin/bnrmr` into its rootfs. Search `./fonts` first, so no lookup that
  succeeds today changes. An env var is a new untrusted input and gets
  validated like `--font`, with `build_font_path`'s byte rules applied to
  every search-path entry. *The asymmetry behind this*: the legacy `.flf`
  branch accepts an absolute path anywhere, so it is more deployable than
  the first-party format.
- **`--list-fonts` stops advertising names `--font` refuses.** Print the
  stem, or add a fallback name scan (byte-neutral, and it turns exit 1s
  into exit 0s, which ADR 0002 ruling 2 permits). Restrict the walk to
  depth 1, by enumerating with `lib/fs.cyr`'s `dir_list`: today it
  recurses to depth 64 while `build_font_path` rejects `/`, so a nested
  font lists under a name no spelling can load (golden:
  `cyml-nested-unreachable`).
- Show an over-long description truncated instead of dropping it, and
  size the name column from the widest name instead of a fixed 10.
- Ship `bnrmr.1`, now that there is an install path to put it in.

**Gate**: ADR 0002 does not rule directly on whether a shipped default
font that fails outside a checkout is a defect. Ruling 2's additive
exception (a failing invocation may start succeeding when the change adds
no CLI surface) is the likely basis, since a search path adds a place to
look, not a flag. Record that reading explicitly when 1.6.0 starts, or
amend the ADR. The rendered-banner tier is untouched; `snapshot` moves
once.

### 1.7.0 — AGNOS parity

CLAUDE.md's Goal is *"Own ASCII-banner rendering for AGNOS userland."*
`--color` is a silent no-op there. The console-geometry half closed in
1.2.0 ([issue 0018](issues/archive/0018-agnos-console-width-never-queried.md)).

- **Color on AGNOS — blocked on agnos.** The console renders SGR (agnos
  1.43.1), but `stdout_is_tty` still returns 0 there, because nothing on
  AGNOS can say whether fd 1 *is* the console. darshana's AGNOS
  `tty_isatty` answers 1 whenever the console is up, a redirected fd 1
  included, and darshana has filed the per-fd query with agnos. When
  agnos ships it and darshana's peer becomes per-fd, delete the stub and
  derive the verdict from the probe, as on Linux.
- **The ADR for the probe rule**: route through a target-bridged wrapper
  where one exists and answers the question asked; gate inline where it
  does not. The width probe is the first case, the color stub the second.
- **aarch64 at runtime in CI.** The cross-build step catches compile
  breakage only. The suite and the golden matrix both pass under qemu
  locally (`cyrius test --aarch64`, and `BNRMR_RUNNER=qemu-aarch64
  sh scripts/golden.sh`), but nothing gates them. Two steps once a runner
  has qemu-user.
- **AGNOS runtime verification** of what 1.4.1 compiled but could not
  run: the `file_write` route, freelist's 2 MB-granular `mmap`, and the
  bayan sublib.

**Gate**: the color probe must return 0 when stdout is not the console,
or `bnrmr --color red X > file` writes escape bytes into the file. Ruled
out: letting `$COLUMNS` or the console-global `tty_isatty` drive the TTY
decision, which would emit SGR into a pipe. The width probe is the
deliberate exception: on AGNOS a redirected stdout gets the console
geometry (plain text, no escapes), as recorded in issue 0018.

### 1.8.0 — The fourth font

Lowest-priority scheduled release. No consumer has asked for it; it
earns its place on recorded intent alone, stated in three places.

No in-tree font contains a single lowercase glyph, so `bnrmr "Welcome
home"` shouts. The gap in the default set is **case, not size**: block
5×5, slim 4×5 and big 7×7 already span small, medium and large.
CHANGELOG 0.3.0 made the uppercase fold a *fallback* specifically to "let
future taller fonts ship distinct lowercase"; `fonts.md` says fonts of
height ≥ 7 "should ship both cases"; `fonts/big.cyml` records why big is
not that font. The mechanism shipped; the font never did.

Height ≥ 8 (seven rows leave no descender row). About 95 glyphs, no
renderer change: `font_glyph_index` already prefers a registered glyph
over the fold. That takes the set to four and uses up the discretionary
half of CLAUDE.md's 3–5 budget. More fonts after this would be the
menagerie.

## Beyond 1.x

Contract-breaking or unrequested. Each entry states why it cannot be 1.x.

- **Variable-width `.flf` glyph storage.** Every glyph is padded to the
  corpus-wide max, so an `I` advances as far as an `M`: a wrong
  inter-glyph advance mid-word, not just trailing whitespace. Measured
  across 752 fonts, bnrmr renders a median **1.74×** wider than figlet.
  Decomposed, uniform width accounts for 1.64× against smushing's 1.09×,
  which makes it the dominant parity gap. *Cannot be 1.x*: it moves
  rendered bytes for every width-variant `.flf`, and CHANGELOG 1.0.0
  names "uniform-width fit" as frozen. The CYML half is separately
  schema 2. The parity target is `figlet -W`, not figlet.
- **`.flf` smushing / kerning.** 42% of corpus fonts declare a layout
  figlet applies. *Cannot be 1.x* by either route: unconditional
  smushing moves bytes, and a `--layout` opt-in is a flag addition.
  Blocked on variable widths, on preserving hardblank identity into
  `Font*`, and on rewriting layout's closed-form width math into
  per-pair accumulation.
- **Non-ASCII coverage** — the whole Unicode question: the skipped
  German and code-tagged `.flf` glyphs, the 128-byte charmap (which, not
  `MAX_GLYPHS`, is what caps a font at 128 entries), and the per-byte
  blank cells (`bnrmr "Café"` renders five cells for four characters;
  golden `default-non-ascii`). *Cannot be 1.x*: it is schema 2 for CYML,
  and it moves bytes for every input ≥ 0x80. ADR 0001's amendment
  usefully shrank it, since no parser work is a prerequisite. The real
  gate is an unmade decision about what encoding argv text is in.
- **Reading stdin.** `echo hi | bnrmr` prints help where `echo hi |
  figlet` renders. *Cannot be 1.x*: that is a valid invocation exiting 0
  today. Also blocked on AGNOS, where there is no isatty, so an unguarded
  fd-0 read would hang bare `bnrmr` on the keyboard forever.
- **A force-color override / `--color-when`.** A new flag is a major.
  The env-var half moves TTY bytes and does not deliver the use case on
  its own.
- **`--color=` accepting an empty value**, where the other four
  value-taking flags reject it (A-06). It is one line, and one
  deliberately inverted golden record (`color-pipe-empty-equals`). But it
  changes the exit code *and* output bytes of an invocation that renders
  correctly today.
- **Sub-glyph `--width` emitting nothing** instead of blank rows (A-05).
- **Enforcing CYML `name` against the filename stem** (A-11). It flips
  `--font` from 0 to 1 for third-party fonts that render correctly. ADR
  0002 ruling 3 (Accepted) settles the audit's old contradiction, which
  classed the change `Breaking` and scheduled it for a minor: it is
  metadata, so it waits for 2.0.
- **A `[lib]` distlib surface.** Not a contract question, but a Project
  Identity change ("Type: Binary") that would create a second frozen
  surface. Unrequested: agnoshi has shipped hand-rolled box art through
  six releases, and both its builds can already spawn bnrmr. Blocked on a
  real request; do not build on spec.

## Issue register

Open, with a written-up reproducer and acceptance criteria:

| # | Title | Scheduled |
|---|---|---|
| [0006](issues/0006-bayan-cyml-parse-regression.md) | bayan 1.5.2 made `font_load_file` ~45% slower | unscheduled; upstream (bayan). The 1.4.1 sublib did not recover it |
| [0008](issues/0008-cyml-body-not-fully-consumed.md) | A CYML glyph body is never required to be fully consumed | 1.5.0, unblocked (ADR 0002 ruling 3) |
| [0009](issues/0009-write-return-never-checked.md) | No `write(2)` return value is checked anywhere | 1.5.0, unblocked (ADR 0002 ruling 2) |
| [0015](issues/0015-fonts-not-findable-when-installed.md) | An installed `bnrmr` cannot find any font | 1.6.0 |
| [0016](issues/0016-diagnostics-go-to-stdout.md) | Every diagnostic goes to stdout, corrupting redirected output | 1.5.0, unblocked (ADR 0002 ruling 1) |

Archived — all closed: [0001](issues/archive/0001-keystroke-interleave-during-render.md)
(deferred past v1.0, still open in principle),
[0002](issues/archive/0002-unbounded-pad-and-width.md),
[0003](issues/archive/0003-flf-crlf-endmarks-bleed.md),
[0004](issues/archive/0004-tty-wrap-on-narrow-terminal.md),
[0005](issues/archive/0005-write-per-cell-syscall-cost.md),
[0007](issues/archive/0007-positionals-past-128-dropped.md),
[0010](issues/archive/0010-fuzz-harness-is-a-no-op.md),
[0011](issues/archive/0011-list-fonts-hangs-on-fifo.md),
[0012](issues/archive/0012-dead-geometry-constants.md),
[0013](issues/archive/0013-full-bayan-bundle-linked.md),
[0014](issues/archive/0014-transient-read-buffers-never-freed.md),
[0017](issues/archive/0017-docs-precision-pass.md),
[0018](issues/archive/0018-agnos-console-width-never-queried.md),
[0019](issues/archive/0019-darshana-probes-hand-rolled.md).
The numbering rule is in [`issues/README.md`](issues/README.md); the next
issue is 0020.

## Out of scope

Two kinds, kept separate. The first are product decisions independent of
version; the second are deferred design questions.

**Permanent — not a version question:**

- **GUI / TUI preview mode** — never. CLI only.
- **Animation / scrolling banners** — single-shot render.
- **Image embedding (kitty / sixel)** — ASCII characters only.
- **Network / fetch-font-from-URL** — never. Fonts are local files.
- **Daemon / cache** — every render is fresh. No persistent state.
  Restated as a hard rule in CLAUDE.md: *one render per invocation*.

**Deferred to a 2.0 charter change**, not settled refusals — see
[Beyond 1.x](#beyond-1x) for the mechanics: Unicode / multi-byte support,
variable per-glyph `.flf` widths, and `.flf` smushing rules. A Unicode
font set would legitimately reopen the ASCII-only charter. The five
permanent entries above would not be reopened at any version.

## Closed record

Kept compact. Per-release detail is in
[`../../CHANGELOG.md`](../../CHANGELOG.md).

| Milestone | Shipped | What closed |
|---|---|---|
| M1 / M2 | 0.2.0 | Render pipeline, 1 KB input cap, CYML schema 1 documented |
| M3 | 0.3.0 | `fonts/` default set — block, slim, big — full printable-ASCII coverage |
| M4 | 0.4.0 | `--align`, `--width`, `--pad` |
| M5 | 0.5.0 | Color via darshana; TTY auto-suppression |
| M6 | 0.6.0 | `.flf` read path — uniform-width fit, no smushing, ASCII 32..126 |
| M7 | 0.9.0 | Security audit ([2026-05-20](../audit/2026-05-20-audit.md), 10 findings, F-001 fixed same release); defense-in-depth follow-ups at 0.8.0; maintainer-MOTD dogfood (issues 0001–0003); benchmark trend established |
| M8 | 1.0.0 | The freeze: CLI flags, CYML schema 1, default font set, `.flf` adapter contract. Issue 0002's `--pad` ≤ 64 / `--width` ≤ 4096 caps as its one documented `Breaking`. Issue 0004 found and fixed in the same release |

Milestone numbers preserve the historical sequence and are not reused.
Post-freeze releases carry no milestone:

- **1.0.1 through 1.2.0**: dependency, toolchain, AGNOS and hardening
  work. 1.1.4's P(-1) pass is recorded in
  [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md).
- **1.4.1**: the whole post-1.2.0 plan in one release. That covered
  proving the contract (the golden suite committed and gated, the CI
  gates, the issue register reconciled, ADR 0002 proposed and accepted)
  and the documentation precision pass. It also shipped chunked writes,
  the CYML-only bayan and freed read buffers, plus tests, fixtures, a
  real fuzz harness and the dead constants wired in.
- **1.4.2**: CLI parsing moved from the stdlib's `flags` to cmdit 1.4.0.
  The roadmap had carried this as demand-gated; it was waiting on cmdit
  1.3.1 (positionals past 128, `--bool=value`) and on a golden suite to
  prove it. The suite gained 33 grammar cases first, and all 318 records
  are byte-identical across the swap.

Two entries in the pre-1.0 criteria list have since moved. They are
corrected here rather than left to imply otherwise:

- The benchmark trend now runs to seven points. Point 4 records a ~45%
  `font_load_file` regression from the 1.1.3 dependency fold
  ([`issues/0006`](issues/0006-bayan-cyml-parse-regression.md)), and a
  second security audit shipped at 1.1.4.
- "CHANGELOG complete from 0.1.0 onward" was carried as an unchecked
  acceptance criterion. It is a standing maintenance rule, not a
  milestone, and belongs to CLAUDE.md's Work Loop.

## Cross-references

- [`state.md`](state.md) — live status: current version, fonts, module
  inventory, consumers
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history
- [`issues/`](issues/) — open deferrals; [`issues/archive/`](issues/archive/)
  for closed ones
- [`../audit/`](../audit/) — audit reports and the accepted-risk register
  (A-01..A-12), which bounds what is even a candidate
- [`../adr/`](../adr/) — decisions; [ADR 0002](../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
  (Accepted) is what every 1.x contract question is checked against
- [`../architecture/`](../architecture/) — invariants the code does not
  state (no raw syscall numbers; `lib/` restored from the lock)
- [`../benchmarks.md`](../benchmarks.md) — the trend, and the
  measurement-methodology trap recorded with it
- `scripts/golden.sh` / `tests/golden/` — the frozen-output contract
