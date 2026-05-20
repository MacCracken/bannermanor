# BannerManor — Roadmap

> Forward-only. Shipped milestones live in [`../../CHANGELOG.md`](../../CHANGELOG.md);
> this file is the sequencing of what's still ahead — what ships next,
> in what order, against what dependency gates. State lives in
> [`state.md`](state.md).

**Currently shipped**: v0.5.0 — M1–M5 (render pipeline, CYML font
format, default font set, layout flags, color). See CHANGELOG for
the per-release details.

**Next**: M6 — legacy `.flf` read adapter.

## v1.0 criteria

The BannerManor v1.0 contract: figlet feature parity for the
non-color path, plus optional color via darshana. Stable CYML font
format. Frozen CLI flag surface.

- [x] Render pipeline + 1 KB input cap (shipped v0.2.0)
- [x] CYML font format schema documented and frozen (shipped v0.2.0)
- [x] `fonts/` ships 3+ opinionated defaults with full printable-ASCII
      coverage (shipped v0.3.0 — block, slim, big)
- [x] CLI layout flags: `--align`, `--width`, `--pad` (shipped v0.4.0)
- [x] Color via darshana: `--color NAME`, `--color rainbow`, TTY
      auto-suppression (shipped v0.5.0)
- [ ] CLI flag surface frozen — current set is `--font`, `--width`,
      `--align`, `--pad`, `--color`, `--list-fonts`, `--help`,
      `--version` (plus `-f`/`-w`/`-h` short forms). M8 freeze.
- [ ] Optional .flf read path for legacy figlet fonts (M6)
- [ ] Benchmarks captured in `docs/benchmarks.md` for render
      throughput on a representative banner (M7)
- [ ] Maintainer dogfood: BannerManor used in the maintainer's MOTD
      for one release cycle, real-world bugs filed in
      `docs/development/issues/` and resolved (M7)
- [ ] Security audit pass (`docs/audit/YYYY-MM-DD-audit.md`) — input
      length cap, font-file bounds, output buffer sizing (M7)
- [ ] CHANGELOG complete from v0.1.0 onward (currently yes; keep so)

## Milestones

Milestone numbers preserve the historical sequence (M1 / M2 shipped
in v0.2.0; M3 in v0.3.0; M4 in v0.4.0; M5 in v0.5.0 — see CHANGELOG).
Versions are targets, not commitments — ship-when-ready.

### M6 — Legacy .flf read path (v0.6.0)

Optional figlet-font-format adapter for users with existing
figlet font libraries.

- `bnrmr --font path/to/standard.flf "hello"` — parse and render
- Read-only — no .flf write path, no .flf authoring docs
- Bounded parsing (refuse files > 1 MB; refuse malformed headers)
- Tests on a small set of public-domain figlet fonts
- **Dep gate**: none beyond what's already shipped — the CYML loader
  + Font struct from M2 are the model; .flf is a parallel input path
  that produces the same `Font*`.
- **Acceptance**: a standard `.flf` font renders identically to
  the canonical figlet `figlet` binary on the same input.

### M7 — Harden + dogfood (v0.9.0; gap before v1.0 is intentional)

- BannerManor used in the maintainer's MOTD for one release cycle
- All real-world bugs / font-rendering surprises filed in
  `docs/development/issues/` and resolved
- P(-1) hardening pass complete — security audit doc filed at
  `docs/audit/YYYY-MM-DD-audit.md`
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

- [`state.md`](state.md) — live status (current version, available fonts, sizes)
- [`../../CHANGELOG.md`](../../CHANGELOG.md) — release history (shipped milestones)
