# BannerManor — Roadmap

> Forward-only. Shipped milestones live in [`../../CHANGELOG.md`](../../CHANGELOG.md);
> this file is the sequencing of what's still ahead — what ships next,
> in what order, against what dependency gates. State lives in
> [`state.md`](state.md).

**Currently shipped**: v0.8.0 — M1–M6 (render pipeline, CYML font
format, default font set, layout flags, color, legacy `.flf` read
adapter) plus the M7 security audit pass and its v1.0 defense-in-depth
follow-ups (F-002 parser overflow caps + F-008 `ws_col` clamp). See
CHANGELOG for the per-release details.

**Next**: finish M7 — maintainer-MOTD dogfooding (in-flight) and the
3-point benchmark trend (points 1 + 2 captured).

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
- [x] Optional .flf read path for legacy figlet fonts (shipped v0.6.0 —
      uniform-width fit, no smushing; renders ASCII 32..126 from any
      figlet font that fits the 64-col / 32-row geometry envelope)
- [ ] Benchmarks captured in `docs/benchmarks.md` for render
      throughput on a representative banner (M7) — points 1 + 2 of 3
      captured (0.7.0 baseline, 0.8.0 post-F-002/F-008 no-regression);
      point 3 lands at 0.9.0
- [ ] Maintainer dogfood: BannerManor used in the maintainer's MOTD
      for one release cycle, real-world bugs filed in
      `docs/development/issues/` and resolved (M7)
- [x] Security audit pass (shipped v0.7.0 — `docs/audit/2026-05-20-audit.md`,
      10 findings, F-001 control-byte injection in `.flf` glyph rows fixed
      same-release)
- [ ] CHANGELOG complete from v0.1.0 onward (currently yes; keep so)

## Milestones

Milestone numbers preserve the historical sequence (M1 / M2 shipped
in v0.2.0; M3 in v0.3.0; M4 in v0.4.0; M5 in v0.5.0; M6 in v0.6.0 —
see CHANGELOG). Versions are targets, not commitments — ship-when-ready.

### M7 — Harden + dogfood (v0.9.0; gap before v1.0 is intentional)

- [x] P(-1) hardening pass complete — security audit doc filed at
      [`docs/audit/2026-05-20-audit.md`](../audit/2026-05-20-audit.md)
      (shipped v0.7.0; F-001 control-byte injection fix included)
- [ ] BannerManor used in the maintainer's MOTD for one release cycle
- [ ] All real-world bugs / font-rendering surprises filed in
      `docs/development/issues/` and resolved
- [ ] 3-point benchmark trend in `docs/benchmarks.md` — points 1 + 2
      of 3 captured; point 3 lands at 0.9.0

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
