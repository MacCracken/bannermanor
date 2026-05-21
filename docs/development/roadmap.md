# BannerManor — Roadmap

> Forward-only. Shipped milestones live in [`../../CHANGELOG.md`](../../CHANGELOG.md);
> this file is the sequencing of what's still ahead — what ships next,
> in what order, against what dependency gates. State lives in
> [`state.md`](state.md).

**Currently shipped**: **v1.0.0** — M1–M8 complete. v1.0 ships with
the CLI flag surface, CYML font format (schema 1), default font set
(block / slim / big), and `.flf` adapter contract all frozen.
Issue 0002's `--pad ≤ 64` / `--width ≤ 4096` caps landed at 1.0.0 as
the freeze's one documented `Breaking`. See CHANGELOG for per-release
details.

**Next**: Post-v1.0 — no committed milestones. Future work (e.g.
variable per-glyph `.flf` widths, Unicode/v2.0) would be scoped into
a "Beyond v1.0" section as it firms up.

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
- [x] CLI flag surface frozen at v1.0.0 — `--font` (`-f`),
      `--width` (`-w`), `--align`, `--pad`, `--color`,
      `--list-fonts`, `--help` (`-h`), `--version`. (M8 — shipped v1.0.0)
- [x] Optional .flf read path for legacy figlet fonts (shipped v0.6.0 —
      uniform-width fit, no smushing; renders ASCII 32..126 from any
      figlet font that fits the 64-col / 32-row geometry envelope)
- [x] Benchmarks captured in `docs/benchmarks.md` for render
      throughput on a representative banner (M7) — three points
      captured (0.7.0 baseline, 0.8.0 post-F-002/F-008 no-regression,
      0.9.0 post-issue-0003 flat). Trend item closed at v0.9.0.
- [x] Maintainer dogfood: BannerManor used in the maintainer's MOTD
      for one release cycle, real-world bugs filed in
      `docs/development/issues/` (0001 / 0002 / 0003) and resolved
      (0003 fixed in 0.9.0; 0001 deferred past v1.0 per
      cost/benefit; 0002 deferred to M8 as the freeze's one
      documented `Breaking`). (M7 — closed at v0.9.0)
- [x] Security audit pass (shipped v0.7.0 — `docs/audit/2026-05-20-audit.md`,
      10 findings, F-001 control-byte injection in `.flf` glyph rows fixed
      same-release)
- [ ] CHANGELOG complete from v0.1.0 onward (currently yes; keep so)

## Milestones

Milestone numbers preserve the historical sequence (M1 / M2 shipped
in v0.2.0; M3 in v0.3.0; M4 in v0.4.0; M5 in v0.5.0; M6 in v0.6.0 —
see CHANGELOG). Versions are targets, not commitments — ship-when-ready.

### M7 — Harden + dogfood (closed at v0.9.0; gap before v1.0 is intentional)

- [x] P(-1) hardening pass complete — security audit doc filed at
      [`docs/audit/2026-05-20-audit.md`](../audit/2026-05-20-audit.md)
      (shipped v0.7.0; F-001 control-byte injection fix included)
- [x] BannerManor used in the maintainer's MOTD for one release
      cycle (0.7.0 → 0.9.0)
- [x] All real-world bugs / font-rendering surprises filed in
      `docs/development/issues/` and resolved — issue 0001
      (keystroke interleave, deferred past v1.0 with rationale),
      issue 0002 (unbounded `--pad`/`--width`, deferred to M8
      freeze with rationale), issue 0003 (CRLF `.flf` endmark
      bleed, fixed in v0.9.0)
- [x] 3-point benchmark trend in `docs/benchmarks.md` complete —
      points 1 (0.7.0), 2 (0.8.0), 3 (0.9.0) captured; flat-or-faster
      across the trend

### M8 — v1.0.0 (shipped 2026-05-20)

- [x] CLI flags frozen, CYML font format frozen (schema 1), default
      font set finalized (block / slim / big), `.flf` adapter
      contract frozen
- [x] CHANGELOG `Breaking` section for the freeze: `--pad` cap at 64,
      `--width` cap at 4096 (issue 0002's resolution). No signature
      changes; the freeze itself is the contract change.
- [x] v1.0.0 cut

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
