# BannerManor — Roadmap

> Forward-only. Shipped milestones live in [`../../CHANGELOG.md`](../../CHANGELOG.md);
> this file is the sequencing of what's still ahead — what ships next,
> in what order, against what dependency gates. State lives in
> [`state.md`](state.md), which owns the current version; this file
> names *target* versions only, and deliberately never the shipped one.

**Milestones**: M1–M8 closed at the v1.0.0 freeze. The freeze locked the
CLI flag surface, the CYML font format (schema 1), the default font set
(block / slim / big), and the `.flf` adapter contract. Everything below
is post-freeze work, and the freeze is what shapes it.

**Next**: 1.2.0 — *Prove the contract*. See [Planned releases](#planned-releases).

## What the freeze permits

Every item on this roadmap was classified against one sentence in
[`../../CHANGELOG.md`](../../CHANGELOG.md)'s 1.0.0 entry:

> No flags added, no flags removed, no exit-code or stdout-byte changes
> **for any valid invocation**.

Three readings of that sentence are load-bearing and none of them is
written down. **1.2.0 files an ADR settling all three**, because six
later items are gated on the answers:

1. **Error-path output.** Every diagnostic today goes to fd 1
   (`src/main.cyr`, ~20 `println` sites — verified: `2>/dev/null`
   suppresses nothing). Is stdout on an *invalid* invocation inside the
   freeze? 1.1.4 already shipped a `--help` stdout-byte change inside a
   patch release, recording that "no test asserts them" — a precedent
   for diagnostic and help text being corrigible in 1.x.
2. **Error-path exit codes.** `bnrmr "hi" > /dev/full` exits 0 having
   written nothing. Is exit 0 on a failed write a frozen behavior or a
   defect?
3. **Already-malformed inputs.** Tightening a parser rejects files that
   load today. Does the freeze protect a font that violates the format's
   own documented rules?

Until that ADR exists, anything touching those three surfaces is parked.
Three things are settled regardless, and are **not** 1.x work under any
reading: new flags (the freeze calls them "an SCHEMA-MAJOR question, not
a minor"), rendered banner bytes for inputs that render correctly today,
and CYML schema 1. See [Beyond 1.x](#beyond-1x).

One thing the freeze explicitly permits: *"Additional fonts can ship in
1.x without breaking the contract (presence is additive, never
subtractive)."*

## Planned releases

Versions are targets, not commitments — ship-when-ready. Sequencing is
by dependency, then by value. 1.2.0 and 1.2.1 gate everything below them.

### 1.2.0 — Prove the contract

v1.0 froze rendered output bytes and **nothing checks that contract**.
The 79-invocation golden diff cited across the 1.1.4 CHANGELOG,
[`state.md`](state.md) and
[`issues/0005`](issues/0005-write-per-cell-syscall-cost.md) exists only in
whatever shell history produced the release. CI runs five steps and gates
none of the claims the release notes make.

- Commit the golden suite as a script plus fixtures, wired into CI.
  Two tiers: **frozen** (rendered banner bytes, error stderr, exit codes)
  and **snapshot** (`--version`, `--help`, `--list-fonts`, which move
  deliberately). Needs a pty leg — `stdout_is_tty` gates color, so a pipe
  capture records only the suppression path and the darshana half of the
  output surface has never been verified at all. Pin `COLUMNS` and CWD,
  which are live inputs.
- CI gates that are unblocked today, verified: `cyrius lint` on all eight
  `src/*.cyr`, `cyrius build --agnos`, `cyrius build --aarch64`,
  `cyrius coverage --min`, and a smoke run of the built binary. The
  pinned toolchain cross-builds both targets in-process from a plain
  x86_64 install — no second runner, no qemu, ~2 lines of YAML each.
- Reconcile the issue register. All five `DEFERRED` rows in
  [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md)'s
  findings table cite an issue number that is wrong or nonexistent; that
  audit contradicts itself five lines later. File 0007–0017 and add an
  errata block rather than silently rewriting a dated record.
- ADR 0002 — the three freeze rulings above.
- Update `scripts/doc-pin-check.sh`'s roadmap exclusion comment in the
  same commit: it asserts this file holds no version, which this rewrite
  falsifies. Do **not** add it to `LIVE_SET` — rule (d) is an equality
  test against `VERSION`, and a *target* version is defined by not
  equalling it.
- Fix the three inbound pointers that contradict this file's own header
  (`README.md`, [`state.md`](state.md), `CLAUDE.md` all describe the
  roadmap as the shipped-milestone log).

**Gate**: golden suite green and byte-identical to the shipped binary;
lint clean; agnos and aarch64 builds clean; coverage floor set; ADR 0002
merged. No `src/` behavior change — zero contract exposure by construction.

### 1.2.1 — Documentation precision (patch)

One editorial pass, no code. Batched per CLAUDE.md Task Sizing, and the
highest value-per-effort work in the backlog: four of these would cause a
font author to write a font that behaves differently than documented.

- [`../guides/fonts.md`](../guides/fonts.md) and
  [`../adr/0001-cyml-font-format.md`](../adr/0001-cyml-font-format.md) —
  seven verified defects. `name` documented as required and stem-matching
  when neither is enforced on the render path; one validation list for two
  loaders with different gates; the zero-entry and >256-entry rejections
  omitted; geometry rejection stated as "any < 0" when `width == 0` also
  rejects; the entry cap published as 256 when the 128-byte charmap makes
  128 the ceiling; the size gate stated as "exceeds 64 KB" when a file of
  *exactly* 64 KB is refused (`>= 65536`).
- `src/color.cyr:44-45` documents a `brightX` spelling that does not parse
  and exits 1; the `--color` error text omits the dash alias `--help`
  gained in 1.1.4, so the two surfaces now disagree.
- `src/layout.cyr:174-177` and `state.md` still promise "a clean no
  output" for a sub-glyph `--width`; it emits `height` blank rows,
  SGR-wrapped on a TTY.
- Add the `--` escape to `--help`. It works; the error a user actually
  hits names "bundled short flags", a cause unrelated to what they typed.
- Restate F-004's *never call `cyml_expand_value` from a font loader* in
  ADR 0001. It holds in code across two audits but lives only in audit
  prose — and it is the constraint any loader extension would breach first.
- CHANGELOG and [`state.md`](state.md) repairs: 1.1.3's retracted
  bench-flat claim needs a superseded pointer (it is reachable by a
  documented deep link that bypasses the retraction); [1.1.4] has
  duplicate `### Fixed` / `### Notes` headings from an unmerged fold, with
  conflicting suite counts; `state.md` carries a live **Unreleased** entry
  for shipped work, an out-of-order version log, a three-point benchmark
  claim against five points recording a 45% regression, and a `_None yet._`
  consumers line that is wrong — agora embeds bnrmr-rendered MOTD art with
  the provenance in its source, and anuenue documents the pipeline.
- The first two entries in the empty [`../architecture/`](../architecture/):
  why the write syscall number is portable across all three targets for
  three independent reasons (and why the font readers were the
  counterexample that shipped broken for four releases); and that
  `cyrius bench`/`build` restore any `lib/` file whose hash misses
  `cyrius.lock` — `--no-deps` included — so a lib-swap A/B compares the
  library against itself. That trap carried a wrong published conclusion
  through a full release.
- `issues/README.md`: the numbering rule the ADR directory has and this
  one does not.

**Gate**: doc-pin-check green; golden suite byte-identical, which is the
mechanical proof nothing here touched behavior.

### 1.3.0 — One write per row

No observable behavior change. Buffering moves syscall boundaries, not
bytes or their order.

- [`issues/0005`](issues/0005-write-per-cell-syscall-cost.md) Option 1 —
  chunked writes from a static space buffer. The option the issue itself
  calls "probably the right one": it removes the entire measured
  width-scaling term with zero SGR-ordering risk, because the darshana
  call sites do not move. Honest payoff: ~2% at natural width, 6–8x on
  wide or centered renders.
- Route all 19 `syscall(1, 1, ...)` sites through `lib/io.cyr`, matching
  the precedent 1.1.3 set for the font readers. A-10 records 17; 1.1.4's
  own `_write_scrubbed` added two, which is the argument for doing it —
  the pattern is still spreading.
- The deferred **B4** write-path bench subject, a `_calibration` subject,
  `scripts/bench-history.sh` (the convention `lib/bench.cyr` already
  names), and a committed baseline. B4 must redirect fd 1 around the timed
  region or 28 KB of banner interleaves with the report.
- Free the transient read buffers (`fl_alloc`/`fl_free`, the convention
  CLAUDE.md names and `src/` never uses). Scoped to `--list-fonts`, the
  only path where the per-font cost scales. Not via `alloc_reset`, which
  invalidates the vector the loop is still iterating.
- Vendor bayan's CYML-only sublib and drop `bayan` from `[deps].stdlib`.
  Measured **520,720 → 175,320 bytes**, byte-identical output, full suite
  passing, both cross-builds clean. Not blocked upstream — the sublib
  ships in the pinned dist. Does *not* recover
  [`issues/0006`](issues/0006-bayan-cyml-parse-regression.md)'s parse
  regression (measured flat), so the two are not one item.

**Gate**: golden suite byte-identical on both tiers including the pty leg;
B4 shows `--width 4096` within noise of natural width.

### 1.3.1 — Tests, fixtures and dead code (patch)

No behavior change, or already-broken inputs only. Batched.

- The cheap parser fixtures that are entirely absent: over-wide /
  over-tall / over-gap CYML, >256-entry, duplicate-`char`,
  out-of-range-`char`, >1024-comment `.flf`, over-long `name`. Plus repair
  `t_reader_dir_path`, whose documented coverage no longer exists because
  1.1.4's `S_IFREG` gate now rejects a directory before `file_open`.
- Extract the six pure CLI helpers into `src/cli.cyr` so they can be
  tested. `src/main.cyr` has **zero** test coverage today — including
  `build_font_path`, the only containment on the CYML branch — and it
  cannot be included by the harness, because its bare top-level
  `_agnos_entry();` runs at include time and exits the test process.
  The extraction must be a pure move: `_parse_count_flag`'s `-0`→0 and
  `007`→7 cases are exit-code contract.
- Make the fuzz harness drive real parsers. It is a 16-line stub with no
  `include` of `src/` that nonetheless makes `cyrius fuzz` report green —
  a signal cited as release evidence in two shipped CHANGELOG blocks.
  A regression gate, not a discovery tool: the audit's own 7,000 ad-hoc
  iterations found zero crashes.
- Wire in or delete the dead geometry constants. Not mechanical — the
  literal `32` means three different things in `src/flf.cyr`, and one
  substitution would change rendered bytes.
- Extract one `_slurp(path, cap, out_len)` from the three verbatim copies
  of the reader block. 1.1.4's guard had to be pasted three times.
- Raise the `.flf` geometry ceilings. Measured over the 1052-font
  reference corpus: 973 load, and all 79 rejections are geometry or size.
  A scratch build with the ceilings widened produced byte-identical output
  for all 973 currently-loading fonts. **Do not touch `src/font.cyr`'s
  `MAX_WIDTH`/`MAX_HEIGHT`** — those are the frozen schema-1 caps, and
  `flf.cyr`'s stale "match font.cyr" comment is exactly what would mislead
  an implementer into changing both.
- Delete `src/test.cyr` (the manifest's declared test entry, an empty
  `return 0` untouched since scaffold) and the raw exit syscall number in
  all three harnesses — `SYS_EXIT` is 93 on aarch64 and 0 on AGNOS,
  unlike the write number A-10 correctly accepted.

**Gate**: ADR 0002 must have ruled on already-malformed inputs before the
`.flf` ceilings and the CYML body-consumption fix land.

### 1.4.0 — Diagnostics and failure honesty

Gated on ADR 0002 ruling (1) and (2). If either goes the other way, the
affected items move to [Beyond 1.x](#beyond-1x) and only the buffered
emit path ships.

- Route diagnostics to fd 2.
  `bnrmr --font typo "$HOSTNAME" > /etc/motd` currently writes the error
  text into the MOTD, and `banner=$(bnrmr ...)` captures it as the banner.
  Every named future consumer is exactly this shape. Not a swap:
  `print_usage()` is called from five sites on both sides of the divide,
  and `cmd_list_fonts`' informational lines are exit-0 and must stay.
- Check write returns. Needs a retry-on-partial loop and errno
  classification, not a bare nonzero check.
- Adopt darshana's `_buf` SGR composers and finish
  [`issues/0005`](issues/0005-write-per-cell-syscall-cost.md) Option 2 —
  one write per row, which is what collapses the emit sites to one and
  makes the checked write a single site instead of nineteen. Size the
  buffer from the 1 KB input cap, not `WIDTH_CAP`: worst case is 8,191
  bytes, which exceeds `PIPE_BUF`.

**Gate**: frozen tier byte-identical; error tier re-baselined deliberately,
diff reviewed line by line.

### 1.5.0 — Fonts findable, listing honest

The largest genuinely 1.x-eligible user-facing gap. All five listing items
ship together so the output moves once, not five times.

- A font search path, plus packaging. An installed `bnrmr` finds no fonts
  — even `-f block` fails while bare `bnrmr` renders from the embedded
  font — and `release.yml` publishes `build/*` without `fonts/` at all, so
  slim and big do not exist on disk for anyone who downloads a release.
  Two of three advertised default fonts are inert outside a git checkout
  while README and `--help` advertise them. Search `./fonts` first so no
  currently-succeeding lookup changes. An env var is a new untrusted input
  surface and gets validated like `--font`.
  *Note the asymmetry driving this*: the legacy `.flf` branch accepts an
  absolute path anywhere, so it is more deployable than the first-party
  format.
- Make `--list-fonts` stop advertising names `--font` refuses — print the
  stem, or add a fallback name scan (byte-neutral, turns exit-1s into
  exit-0s). Restrict the walk to depth 1: it recurses to 64 while
  `build_font_path` rejects `/`, so a nested font lists under a colliding
  name and loads by no spelling.
- Fix the FIFO hang. `lib/fs.cyr` already exports `dir_list`, which opens
  only the directory — no `lib/` edit, and not blocked upstream.
- Truncate an over-cap description instead of dropping it silently; size
  the name column from the widest name instead of a hardcoded 10.
- Ship `bnrmr.1`, now that an install path exists to put it.

**Gate**: ADR 0002 must cover whether a shipped default font failing
outside a checkout is a defect. Rendered-banner tier untouched.

### 1.6.0 — AGNOS parity

CLAUDE.md's Goal is *"Own ASCII-banner rendering for AGNOS userland."*
`--color` is currently a silent no-op there and issue 0004's narrow-console
truncation never engages.

- Wire real console geometry and TTY detection into the two
  `#ifdef CYRIUS_TARGET_AGNOS` hard-returns. **The premise they were
  written on is dead**: AGNOS syscall #60 returns the live framebuffer
  console grid, and AGNOS 1.43.1 shipped a CSI parser handling SGR, so
  both "not queryable from userland yet" and "doesn't interpret ANSI" are
  now false. darshana's agnos-bridged `tty_winsize`/`tty_isatty` are
  already vendored here and inside its frozen v1.0 API — this is deleting
  two stubs and calling two already-linked functions.
- The ADR recording the resulting rule: route through a target-bridged
  wrapper where one exists, gate inline only where none does. The
  "extract later only if needed" trigger has fired.
- An aarch64 runtime check under qemu. The 1.2.0 gate catches compile
  breakage only; the `st_mode`-offset reasoning is validated by the
  vendored lib, not by compiling.

**Gate**: the new probe must return 0 when stdout is not the console, or
`bnrmr --align center X | cat` stops matching the M1 byte-identity
contract. Ruled out: letting `$COLUMNS` drive the TTY decision, which
would emit SGR into a pipe.

### 1.7.0 — The fourth font

Lowest-priority scheduled release. No consumer, no request — it earns its
place on recorded intent alone, and the intent is on three surfaces.

No in-tree font contains a single lowercase glyph, so `bnrmr "Welcome
home"` shouts. The gap in the default set is **case, not size**: block
5×5 / slim 4×5 / big 7×7 already span small/medium/large. CHANGELOG 0.3.0
made the uppercase fold a *fallback* specifically to "let future taller
fonts ship distinct lowercase"; `fonts.md` says fonts of height ≥ 7
"should ship both cases"; `fonts/big.cyml` records why big is not that
font. The mechanism shipped; the font never did.

Height ≥ 8 (seven rows leaves no descender row). ~95 glyphs, no renderer
change — `font_glyph_index` already prefers a registered glyph over the
fold. This takes the set to four and closes the discretionary half of
CLAUDE.md's 3–5 budget. After this, more fonts are the menagerie.

## Beyond 1.x

Contract-breaking or unrequested. Each entry states why it cannot be 1.x.

- **Variable-width `.flf` glyph storage.** Every glyph is padded to the
  corpus-wide max, so an `I` advances as far as an `M` — a wrong
  inter-glyph advance mid-word, not merely trailing whitespace. Measured
  across 752 fonts, bnrmr renders a median **1.74×** wider than figlet;
  decomposed, uniform width accounts for 1.64× against smushing's 1.09×,
  making this the dominant parity gap. *Cannot be 1.x*: moves rendered
  bytes for every width-variant `.flf`, and CHANGELOG 1.0.0 names
  "uniform-width fit" as frozen. The CYML half is separately schema 2.
  The parity target is `figlet -W`, not figlet.
- **`.flf` smushing / kerning.** 42% of corpus fonts declare a layout
  figlet applies. *Cannot be 1.x* on both routes: unconditional smushing
  moves bytes, and a `--layout` opt-in is a flag addition. Blocked on
  variable widths, on preserving hardblank identity into `Font*`, and on
  rewriting layout's closed-form width math into per-pair accumulation.
- **Non-ASCII coverage** — the whole Unicode question, including the
  skipped German/code-tagged `.flf` glyphs, the 128-byte charmap, and the
  per-byte blank cells (`bnrmr "Café"` renders five cells for four
  characters). *Cannot be 1.x*: schema 2 for CYML, and moving bytes for
  every input ≥ 0x80. ADR 0001's amendment usefully shrank it — no parser
  work is a prerequisite — but the real gate is an unmade decision about
  what encoding argv text is in. Eight sites across three files.
- **Reading stdin.** `echo hi | bnrmr` prints help where `echo hi |
  figlet` renders. *Cannot be 1.x*: that is a valid invocation exiting 0
  today. Also blocked on AGNOS, where there is no isatty and an unguarded
  fd-0 read would hang bare `bnrmr` on the keyboard forever.
- **A force-color override / `--color-when`.** New flag = major. The
  env-var half moves TTY bytes and does not deliver the use case alone.
- **`--color=` accepting an empty value** where the other four
  value-taking flags reject it. One line, and one deliberately-inverted
  test. Exit-code *and* output-byte change on an invocation that renders
  correctly today.
- **Sub-glyph `--width` emitting nothing** instead of blank rows.
- **Enforcing CYML `name` against the filename stem.** Flips `--font`
  from 0 to 1 for third-party fonts that render correctly. The audit
  classes it `Breaking` *and* targets it at 1.2.0; resolving that
  contradiction toward 2.0 is the most consequential call in the backlog,
  because the same reasoning governs the two entries above.
- **A `[lib]` distlib surface.** Not a contract question — a Project
  Identity change ("Type: Binary") that creates a second frozen surface.
  Unrequested: agnoshi has shipped hand-rolled box art through six
  releases, and both its builds can already spawn bnrmr. Blocked on a real
  request; do not build on spec.

## Issue register

Filed, with a written-up reproducer and acceptance criteria:

| # | Title | Scheduled |
|---|---|---|
| [0005](issues/0005-write-per-cell-syscall-cost.md) | One `write(2)` per glyph cell and per pad space — 8x cost at `--width 4096` | 1.3.0 |
| [0006](issues/0006-bayan-cyml-parse-regression.md) | bayan 1.5.2 made `font_load_file` ~45% slower | 1.3.0 (investigate) |
| [0010](issues/0010-fuzz-harness-is-a-no-op.md) | The fuzz harness verifies nothing and reports green | 1.3.1 |
| [0015](issues/0015-fonts-not-findable-when-installed.md) | An installed `bnrmr` cannot find any font | 1.5.0 |
| [0016](issues/0016-diagnostics-go-to-stdout.md) | Every diagnostic goes to stdout, corrupting redirected output | 1.4.0 (gated on ADR 0002) |
| [0017](issues/0017-docs-precision-pass.md) | Documentation precision pass deferred from the 1.1.4 audit | 1.2.1 |

Named in the release plan above but **not yet written up** — 1.2.0 files
them, and until it does they are described only here and in
[`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md):
0007 (positionals past the 128th silently discarded), 0008 (CYML body
never required to be fully consumed), 0009 (no `write(2)` return value
checked anywhere), 0011 (`--list-fonts` hangs on a FIFO under `fonts/`),
0012 (dead geometry-limit constants), 0013 (full bayan bundle linked for
nine CYML symbols — 66% of the binary), 0014 (transient read buffers
never freed).

Archived: [0001](issues/archive/0001-keystroke-interleave-during-render.md)
(deferred past v1.0, still open in principle),
[0002](issues/archive/0002-unbounded-pad-and-width.md),
[0003](issues/archive/0003-flf-crlf-endmarks-bleed.md),
[0004](issues/archive/0004-tty-wrap-on-narrow-terminal.md) — all closed.

## Out of scope

Two kinds, kept separate — the first are product decisions independent of
version, the second are deferred design questions.

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
font set would legitimately reopen the ASCII-only charter; the five
entries above it would not be reopened at any version.

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
Post-freeze releases 1.0.1 through 1.1.4 were dependency, toolchain,
AGNOS and hardening work carrying no milestone; 1.1.4's P(-1) pass is
recorded in [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md).

Two entries in the pre-1.0 criteria list have since moved and are
corrected here rather than left to imply otherwise: the benchmark trend
now runs to five points, and Point 4 records a ~45% `font_load_file`
regression from the 1.1.3 dependency fold (see
[`issues/0006`](issues/0006-bayan-cyml-parse-regression.md)); and a second
security audit shipped at 1.1.4. "CHANGELOG complete from 0.1.0 onward"
was carried as an unchecked acceptance criterion — it is a standing
maintenance rule, not a milestone, and belongs to CLAUDE.md's Work Loop.

## Cross-references

- [`state.md`](state.md) — live status: current version, fonts, module
  inventory, in-flight work
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history
- [`issues/`](issues/) — open deferrals; [`issues/archive/`](issues/archive/)
  for closed ones
- [`../audit/`](../audit/) — audit reports and the accepted-risk register
  (A-01..A-12), which bounds what is even a candidate
- [`../benchmarks.md`](../benchmarks.md) — the trend, and the
  measurement-methodology trap recorded with it
- [`../adr/`](../adr/) — decisions