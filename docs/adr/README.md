# Architecture Decision Records

Decisions about bannermanor — what we chose, the context, and the consequences we accept. Use these when a future reader would reasonably ask *"why did we do it this way?"*

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. Never renumber.
- **One decision per ADR.** If a decision supersedes a prior one, add a new ADR and set the old one's status to `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use [`template.md`](template.md) as the starting point.

## ADR vs. architecture note vs. guide

| Kind | Lives in | Answers |
|---|---|---|
| ADR | `docs/adr/` | *Why did we choose X over Y?* |
| Architecture note | `docs/architecture/` | *What non-obvious constraint is true about the code?* |
| Guide | `docs/guides/` | *How do I do X?* |

## Index

| ADR | Decision | Status |
|-----|----------|--------|
| [0001](0001-cyml-font-format.md) | CYML as the in-tree font format, `.` for background, `.flf` as a read-only adapter | Accepted (amended 1.1.3, 1.1.4, 1.4.1) |
| [0002](0002-freeze-scope-error-paths-and-malformed-input.md) | What the v1.0 freeze covers: diagnostics are not frozen, a failed write is a defect, malformed input is not protected | Accepted (2026-10-15) |
| [0003](0003-font-search-path.md) | `--font NAME` searches `$BNRMR_FONTS`, `./fonts`, the install directory beside the executable, then the built-in block font; `--list-fonts` lists exactly what that finds | Accepted (2026-10-15) |
| [0004](0004-terminal-probes-ask-about-fd-1.md) | The width and color probes ask whether fd 1 is a terminal, through darshana where it answers that and through an inline `sys_fd_kind` gate on AGNOS until it does; only the console counts there | Accepted (2026-10-15) |
| [0005](0005-the-2-0-charter.md) | The 2.0 charter: variable-width glyphs, opt-in smushing, non-ASCII text, stdin and the A-05 / A-06 fixes go into 2.0; color forcing and the A-11 name check do not; argv text is UTF-8 | Proposed (2026-10-30) |

Add the next as `0006-kebab-case-title.md`. Never renumber an
existing ADR.
