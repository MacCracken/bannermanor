# BannerManor — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

## v1.0 criteria

The BannerManor v1.0 contract: figlet feature parity for the
non-color path, plus optional color via darshana. Stable CYML font
format. Frozen CLI flag surface.

- [ ] CLI flag surface frozen — `--font`, `--width`, `--align`,
      `--pad`, `--color`, `--list-fonts`, `--help`, `--version`
- [ ] CYML font format schema documented and frozen
- [ ] `fonts/` ships 3–5 opinionated defaults with full ASCII
      coverage
- [ ] Optional .flf read path for legacy figlet fonts
- [ ] Test coverage: every flag + every default font + malformed-
      font-file path; 100+ assertions
- [ ] Benchmarks captured in `docs/benchmarks.md` for render
      throughput on a representative banner
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] Security audit pass (`docs/audit/YYYY-MM-DD-audit.md`) — input
      length cap, font-file bounds, output buffer sizing

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-05-19

- `cyrius init` scaffold landed
- `./build/bnrmr` prints scaffold version and exits
- Doc-tree per [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)

### M1 — First render: hardcoded block-letter font (v0.2.0)

Prove the render pipeline end-to-end with a single in-source font.

- One hardcoded block-letter font, ASCII A–Z + 0–9 + space
- `bnrmr "hello"` produces correctly-rendered output to stdout
- Input length cap (1 KB)
- Tests: every character of the font + bounds case
- **Dep gate**: stdlib only
- **Acceptance**: `bnrmr "AGNOS"` renders cleanly.

### M2 — CYML font format spec + parser (v0.3.0)

Extract the hardcoded font into the planned CYML schema.

- ADR: `docs/adr/0001-cyml-font-format.md` — schema + rationale vs .flf
- `fonts/block.cyml` — extracted from M1's hardcoded font
- Loader reads `fonts/<name>.cyml`; `--font block` is the default
- Tests: parse happy path + malformed schema + missing character
- **Dep gate**: stdlib `lib/cyml.cyr`
- **Acceptance**: `bnrmr --font block "hello"` produces the same
  output as M1.

### M3 — Ship default font set (v0.4.0)

Curate 3–5 opinionated fonts that look good. Resist scope creep.

- `fonts/block.cyml`, `fonts/slim.cyml`, `fonts/big.cyml`,
  `fonts/script.cyml` (final list determined during M3 work)
- Each font: full ASCII coverage, attribution in font header
- `bnrmr --list-fonts` prints available fonts + preview line
- Guide: `docs/guides/fonts.md` — authoring a new CYML font
- **Dep gate**: M2
- **Acceptance**: every shipped font renders "AGNOS" cleanly.

### M4 — Layout flags (v0.5.0)

- `--align left|center|right` — banner alignment within terminal width
- `--width N` — wrap or truncate at N columns (0 = unlimited)
- `--pad N` — N rows of vertical padding above + below
- Tests: every flag combo
- **Dep gate**: stdlib `lib/args.cyr` + terminal-width detection
- **Acceptance**: `bnrmr --align center --width 80 "hi"` centers
  in 80 cols.

### M5 — Color via darshana (v0.6.0)

- `--color <name>` — ANSI-256 colorize the banner via darshana primitives
- `--color rainbow` — per-row color cycle
- Auto-detect TTY; suppress colors when stdout isn't a terminal
- **Dep gate**: darshana ≥ 0.3.0 in `[deps.darshana]`
- **Acceptance**: `bnrmr --color cyan "AGNOS"` renders colored on
  TTY, plain on pipe.

### M6 — Legacy .flf read path (v0.7.0)

Optional figlet-font-format adapter for users with existing
figlet font libraries.

- `bnrmr --font path/to/standard.flf "hello"` — parse and render
- Read-only — no .flf write path, no .flf authoring docs
- Bounded parsing (refuse files > 1 MB; refuse malformed headers)
- Tests on a small set of public-domain figlet fonts
- **Dep gate**: M3 — the CYML path is the canonical format; .flf is the adapter
- **Acceptance**: a standard `.flf` font renders identically to
  the canonical figlet `figlet` binary on the same input.

### M7 — Harden + dogfood (v0.9.0)

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
