# BannerManor — Roadmap

> Forward-only. Shipped milestones live in [`../../CHANGELOG.md`](../../CHANGELOG.md);
> this file is the sequencing of what's still ahead — what ships next,
> in what order, against what dependency gates. State lives in
> [`state.md`](state.md).

**Currently shipped**: v0.2.0 (M1 + M2 — first render path + CYML font
format). See CHANGELOG for the details.

**Next**: M3 — broaden the default font set.

## v1.0 criteria

The BannerManor v1.0 contract: figlet feature parity for the
non-color path, plus optional color via darshana. Stable CYML font
format. Frozen CLI flag surface.

- [x] Render pipeline + 1 KB input cap (M1, v0.2.0)
- [x] CYML font format schema documented and frozen (M2, v0.2.0)
- [ ] CLI flag surface frozen — `--font`, `--width`, `--align`,
      `--pad`, `--color`, `--list-fonts`, `--help`, `--version`
- [ ] `fonts/` ships 3–5 opinionated defaults with full ASCII
      coverage
- [ ] Optional .flf read path for legacy figlet fonts
- [ ] Test coverage: every flag + every default font + malformed-
      font-file path; 100+ assertions (current: 1334)
- [ ] Benchmarks captured in `docs/benchmarks.md` for render
      throughput on a representative banner
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] Security audit pass (`docs/audit/YYYY-MM-DD-audit.md`) — input
      length cap, font-file bounds, output buffer sizing

## Milestones

Milestone numbers preserve the historical sequence (M1 / M2 shipped
in v0.2.0; see CHANGELOG). Versions are targets, not commitments —
ship-when-ready.

### M3 — Ship default font set (v0.3.0)

Curate 3–5 opinionated fonts that look good. Resist scope creep.

- `fonts/block.cyml`, `fonts/slim.cyml`, `fonts/big.cyml`,
  `fonts/script.cyml` (final list determined during M3 work)
- Each font: full ASCII coverage, attribution in font header
- `bnrmr --list-fonts` prints available fonts + preview line
- Guide: `docs/guides/fonts.md` — authoring a new CYML font
- **Dep gate**: M2 (CYML loader + schema, shipped in v0.2.0)
- **Acceptance**: every shipped font renders "AGNOS" cleanly.

### M4 — Layout flags (v0.4.0)

- `--align left|center|right` — banner alignment within terminal width
- `--width N` — wrap or truncate at N columns (0 = unlimited)
- `--pad N` — N rows of vertical padding above + below
- Tests: every flag combo
- **Dep gate**: stdlib `lib/args.cyr` + terminal-width detection
- **Acceptance**: `bnrmr --align center --width 80 "hi"` centers
  in 80 cols.

### M5 — Color via darshana (v0.5.0)

- `--color <name>` — ANSI-256 colorize the banner via darshana primitives
- `--color rainbow` — per-row color cycle
- Auto-detect TTY; suppress colors when stdout isn't a terminal
- **Dep gate**: darshana ≥ 0.3.0 in `[deps.darshana]`
- **Acceptance**: `bnrmr --color cyan "AGNOS"` renders colored on
  TTY, plain on pipe.

### M6 — Legacy .flf read path (v0.6.0)

Optional figlet-font-format adapter for users with existing
figlet font libraries.

- `bnrmr --font path/to/standard.flf "hello"` — parse and render
- Read-only — no .flf write path, no .flf authoring docs
- Bounded parsing (refuse files > 1 MB; refuse malformed headers)
- Tests on a small set of public-domain figlet fonts
- **Dep gate**: M3 — the CYML path is the canonical format; .flf is the adapter
- **Acceptance**: a standard `.flf` font renders identically to
  the canonical figlet `figlet` binary on the same input.

### M7 — Harden + dogfood (v0.9.0; gap before v1.0 is intentional)

- BannerManor used in the maintainer's MOTD for one release cycle
- All real-world bugs / font-rendering surprises filed in
  `docs/development/issues/` and resolved
- P(-1) hardening pass complete — security audit doc filed
- 3-point benchmark trend in `docs/benchmarks.md`

### M8 — v1.0.0

- CLI flags frozen, font format frozen, default font set finalized
- CHANGELOG `Breaking` section for the freeze (no signature
  changes — the freeze is the contract change)
- v1.0.0 cut

## Out of scope (for v1.0)

The list keeps future contributors from adding to v1.0 by accident.

- **GUI / TUI preview mode** — never. CLI only.
- **Animation / scrolling banners** — out of scope; single-shot render.
- **Image embedding (kitty / sixel)** — out of scope; ASCII characters only.
- **Network / fetch-font-from-URL** — never. Fonts are local files.
- **Unicode / multi-byte support** — out of scope for v1.0; ASCII
  only. Unicode is a v2.0 question with serious font-coverage
  implications.
- **Daemon / cache** — every render is fresh. No persistent state.

## Cross-references

- [`state.md`](state.md) — live status (available fonts, sizes)
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history
