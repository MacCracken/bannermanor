# BannerManor — Roadmap

> Forward-only. What ships next, in what order, against what gates.
> Shipped work is in [`../../CHANGELOG.md`](../../CHANGELOG.md); the
> current version and live state are in [`state.md`](state.md). This file
> names *target* versions only.

The v1.0.0 freeze locked the CLI flag surface, the CYML font format
(schema 1), the default font set and the `.flf` adapter contract. Every
item below is placed by what the freeze allows: 1.x when it fits, 2.0
when it cannot.

**Next**: 1.8.1 — *measurement debts*: the benchmark baseline, issue
0006, and the aarch64 binary size.

## The rules every item is checked against

The freeze sentence:

> No flags added, no flags removed, no exit-code or stdout-byte changes
> **for any valid invocation**.

[ADR 0002](../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
(Accepted) defines "valid invocation" and makes three rulings:

1. **Error-path output is not frozen**, but exit codes are.
2. **Exit 0 after a failed write is a defect**, not frozen behavior.
3. **A structurally malformed font is not protected.** Metadata rules
   (`name` against the stem) are 2.0. bnrmr's own limits may widen.

The golden suite (`scripts/golden.sh`) is the mechanical check. Its
`frozen` tier never moves in 1.x; its `error` tier moves only under
ruling 1, re-baselined record by record; its `snapshot` tier (help,
version, listing) moves only when a release says so.

Never 1.x under any reading: new flags (the freeze calls them "an
SCHEMA-MAJOR question, not a minor"), new spellings or a looser grammar
for a flag value, different bytes for an input that renders correctly
today, and CYML schema changes. Those are [Deferred to 2.0](#deferred-to-20).

Explicitly allowed: *"Additional fonts can ship in 1.x without breaking
the contract (presence is additive, never subtractive)."*

## Planned releases

Targets, not commitments: ship when ready. Releases are ordered by
dependency, then by value. A gated release whose gate is not met does not
hold up the next one; the two swap numbers, so versions stay in shipping
order.

### 1.8.1 — Measurement debts

Byte-identical. Three numbers the project quotes but has never measured
properly:

- **The benchmark baseline.** `scripts/bench-history.sh` has existed
  since 1.4.1, but `docs/benchmarks/history.csv` has never been recorded:
  each attempt met a loaded host, and the numbers were discarded. Record it on a quiet machine
  (`cyrius bench tests/bannermanor.bcyr | sh scripts/bench-history.sh`),
  and add the 1.4.1 → 1.8.0 points to `docs/benchmarks.md`.
- **Issue 0006, B2's ~45% regression.** Re-measure `font_load_file`
  against that baseline on bayan 1.5.14, and profile the CYML scan, which
  is 62–65% of B2 (`docs/benchmarks.md`). File the finding with bayan.
  The fix is upstream; bnrmr adopts it with a tag move.
- **The aarch64 binary.** It grew 341,064 → 407,048 bytes at 1.5.0 while
  x86_64 and AGNOS grew about 4.5 KB each. Not investigated (CHANGELOG
  1.5.0). Find out what the aarch64 backend emits for the 1.5.0 changes;
  fix it here if the cause is in bnrmr, file it with cyrius if it is not.

### 1.9.0 — AGNOS follow-through

Gated on agnos and darshana. Each item ships when its gate is met;
whatever is not ready moves to a later 1.9.x.

- **Route the AGNOS probe through darshana.** [ADR 0004](../adr/0004-terminal-probes-ask-about-fd-1.md)
  gates inline (`sys_fd_kind(1) == FDK_CONSOLE`) only because darshana's
  AGNOS `tty_isatty` does not ask about the fd yet. When a darshana
  release does, delete `_winsize_describes_stdout`'s AGNOS arm and call
  darshana. Byte-identical by construction, since both draw the line at
  the console; prove it with `scripts/agnos-smoke.py`. *Gate*: that
  darshana release.
- **Terminal-emulator windows on AGNOS.** A program in an AGNOS terminal
  emulator has an `FDK_CHAN` stdout, which bnrmr treats as not a
  terminal: no color, no width cut. That is right while the only size
  bnrmr can ask for is the console's. When agnos and darshana expose a
  per-fd window size for a channel, count it as a terminal. This is the
  same contract reading as 1.7.0: color and the width cut on a terminal,
  never in a pipe or file. *Gate*: the per-fd size.
- **A failed write on AGNOS.** 1.7.0's QEMU run verified every write path
  except failure, because nothing could make an AGNOS write fail on
  demand. Add that check to `scripts/agnos-smoke.py` once agnos offers a
  way (a full device, or a closed fd 1 from agnsh). *Gate*: that agnos
  facility.

### 1.10.0 — 2.0 groundwork, byte-identical

The two largest 2.0 items, variable-width `.flf` glyphs and smushing, are
mostly plumbing. Do the plumbing in 1.x, where the golden suite can prove
it changed nothing, so 2.0 becomes a render-policy change and not a
rewrite.

- **Keep each `.flf` glyph's own width, and the hardblank's identity,
  in `Font*`.** Today the loader pads every glyph to the font's maximum
  and folds hardblanks to spaces, so both facts are lost at load.
- **Make layout add up per-glyph advances**, instead of the closed-form
  `n * width + (n - 1) * gap`, while every glyph still advances by the
  padded width.
- **Proof**: the golden `frozen` tier unchanged, and the figlet corpus
  byte-identical before and after (1.5.0's envelope change checked 973
  fonts unchanged the same way).
- **The 2.0 charter, as an ADR (Proposed)**: which of the deferred items
  below 2.0 takes, and the decision Unicode is waiting on, namely what
  encoding argv text is in.

### 1.11.0 — Library surface (on request only)

A `[lib]` distlib so another Cyrius program can render a banner in
process. It is not a contract question, but it changes the Project
Identity ("Type: Binary") and creates a second frozen surface. No one has
asked: agnoshi has shipped hand-drawn box art through six releases, and
both its builds can already spawn `bnrmr`. *Gate*: a consumer's request.
Do not build it on spec. If none comes before the 2.0 charter is
accepted, the charter decides whether it stays here or moves to 2.0.

## Deferred to 2.0

Each of these breaks the freeze. Where a 1.x release prepares the
ground, it is named.

- **Variable-width `.flf` glyphs.** Every glyph is padded to the widest,
  so an `I` advances as far as an `M`: the spacing is wrong in mid-word,
  not just at the end. Across 752 fonts, bnrmr renders a median **1.74×**
  wider than figlet; uniform width accounts for 1.64× of that and missing
  smushing for 1.09×. *Why 2.0*: it moves rendered bytes for every
  variable-width `.flf`, and CHANGELOG 1.0.0 names "uniform-width fit" as
  frozen. The CYML half is schema 2. The parity target is `figlet -W`.
  *Groundwork*: 1.10.0.
- **`.flf` smushing and kerning.** 42% of corpus fonts declare a layout
  figlet applies. *Why 2.0*: applying it moves bytes, and an opt-in
  `--layout` is a new flag. It needs variable widths, hardblank identity
  and per-pair layout first. *Groundwork*: 1.10.0.
- **Non-ASCII text.** That covers the skipped German and code-tagged
  `.flf` glyphs, the 128-byte charmap (it, not `MAX_GLYPHS`, caps a font
  at 128 entries), and per-byte blank cells (`bnrmr "Café"` renders five
  cells for four characters; golden `default-non-ascii`). *Why 2.0*: it
  is CYML schema 2, and it moves bytes for every input byte ≥ 0x80. A
  Unicode font set would also reopen the ASCII-only charter. *Groundwork*:
  the argv-encoding decision in 1.10.0's charter ADR.
- **Reading stdin.** `echo hi | bnrmr` prints the usage text, exit 0,
  where figlet renders. *Why 2.0*: that is a valid invocation today.
  AGNOS no longer blocks it: since agnos 1.57.13 `fd_kind` tells a pipe
  from the console (bnrmr uses it since 1.7.0), so an fd-0 read need not
  hang on the keyboard.
- **Forcing color, and turning it off.** A `--color-when` flag is a new
  flag. An environment override (`CLICOLOR_FORCE`, `NO_COLOR`) changes
  bytes for invocations that are valid today, and forcing color without
  the flag does not deliver the use case on its own.
- **`--color=` with an empty value** (accepted risk A-06). The other four
  value-taking flags reject an empty value; `--color=` means "no color".
  The fix is one line plus one inverted golden record
  (`color-pipe-empty-equals`). *Why 2.0*: it turns an exit-0 invocation
  into an exit-1 one.
- **A sub-glyph `--width` printing nothing** instead of blank rows
  (A-05). *Why 2.0*: different bytes for every `--width` below one glyph,
  and every terminal narrower than one glyph.
- **CYML `name` checked against the filename stem** (A-11). *Why 2.0*:
  ADR 0002 ruling 3, metadata. It would turn `--font` from exit 0 to 1
  for third-party fonts that render today. Since 1.6.0 there is little to
  gain: `--list-fonts` shows the stem, and `name` is unused metadata.

## Out of scope

Product decisions, not version questions. None reopens at any version:

- **GUI / TUI preview mode.** CLI only.
- **Animation / scrolling banners.** Single-shot render.
- **Image embedding (kitty / sixel).** ASCII characters only.
- **Fetching fonts from a URL, or any network use.** Fonts are local files.
- **Daemon / cache.** Every render is fresh, with no persistent state.
  CLAUDE.md states it as a hard rule: *one render per invocation*.

The items above are refusals. [Deferred to 2.0](#deferred-to-20) holds the
ones that are only waiting on a major.

## Issue register

Open, with a written-up reproducer and acceptance criteria:

| # | Title | Target |
|---|---|---|
| [0006](issues/0006-bayan-cyml-parse-regression.md) | bayan 1.5.2 made `font_load_file` ~45% slower | 1.8.1: re-measure and profile, file with bayan; the fix is upstream |

Closed issues are in [`issues/archive/`](issues/archive/). The numbering
rule is in [`issues/README.md`](issues/README.md); the next issue is 0021.

## Cross-references

- [`state.md`](state.md) — live status: current version, fonts, module
  inventory, consumers
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history, M1–M8
  and every post-freeze release
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
- [`../guides/fonts.md`](../guides/fonts.md) — the font format and both
  loaders' validation, which a catalog font must pass
- `scripts/golden.sh` / `tests/golden/` — the frozen-output contract
- `scripts/agnos-smoke.py` — bnrmr on a real agnos kernel in QEMU
  (manual), the check for every AGNOS item above
