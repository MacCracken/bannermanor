# BannerManor — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (current version,
> module line counts, supported backends, test counts, dep-gap status,
> consumers) lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

## Project Identity

**BannerManor** (binary: `bnrmr`) — *heraldic welcome ceremony at the gate of your digital manor*. figlet-equivalent ASCII-art banner generator for MOTDs, script intros, and splash text.

- **Type**: Binary
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)
- **Shared crates registry**: [shared-crates.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/shared-crates.md)

## Goal

Own ASCII-banner rendering for AGNOS userland. CYML-defined fonts, optional color via darshana, opinionated defaults that ship in-tree. Fourth member of the terminal-aesthetics set (commandress / darshini / hapi / **BannerManor** / iam). The mechanical lane is figlet-equivalent; the soul-lane is the heraldic banner unfurling at the manor gate when the user arrives.

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, available fonts, command surface, in-flight work,
> consumers, dep gaps. Refreshed every release.

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Project was scaffolded with `cyrius init bannermanor` (the directory is lowercase per convention; the human-facing name is BannerManor). Binary output is `bnrmr` (vowel-dropped per the `commandress` → `cmdrs` compression pattern). **Do not manually create project structure** — use the tools.

## Quick Start

```sh
cyrius deps                              # resolve stdlib + sibling deps
cyrius build src/main.cyr build/bnrmr   # compile (binary: bnrmr)
./build/bnrmr                             # prints scaffold version line
cyrius test                               # run tests/*.tcyr
```

## Key Principles

- **CYML-first font format.** Fonts live as `<name>.cyml` files in `fonts/`. .flf compatibility is a read-only adapter for legacy fonts; new fonts target the CYML schema.
- **Opinionated defaults, not endless options.** Ship 3–5 fonts in-tree that look good. Resist the figlet-style font menagerie. Quality over quantity.
- **Color is opt-in via darshana, never inline ANSI.** If a user wants color, they pass `--color`; we route through `darshana` ANSI primitives. No raw ANSI escape codes in the codebase.
- **One render per invocation.** No daemon, no cache, no preview server. The CLI takes text + flags + font, writes bytes, exits.
- **Self-contained.** A user can `bnrmr "hello"` with zero config files; the in-tree default font handles it.

## Rules (Hard Constraints)

- **Read the genesis repo's CLAUDE.md first** — [agnosticos/CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
- **Do not commit or push** — the user handles all git operations
- **Never use `gh` CLI** — use `curl` to the GitHub API only
- Do not skip tests before claiming changes work
- Do not use `sys_system()` or `exec_*` — bnrmr writes bytes, nothing else
- Do not trust external data (text input, font files) without validation — input length cap, font-file format check
- Do not modify `lib/` files (vendored stdlib / dep symlinks managed by `cyrius deps`)
- Do not emit raw ANSI escape codes inline — always route via darshana
- Do not embed font data as huge inline string tables in source — fonts are data files
- Do not hardcode toolchain versions in CI YAML — `cyrius = "X.Y.Z"` in `cyrius.cyml` is the source of truth

## Process

### P(-1): Hardening (before v0.2.0 first feature cut, and before v1.0)

1. **Cleanliness** — `cyrius build` clean, `cyrius lint` clean, tests pass
2. **Benchmark baseline** — `cyrius bench` for render hot path
3. **Internal review** — input bounds, font-parser validation, output buffer sizing
4. **External research** — figlet font format spec; existing CYML font conventions
5. **Security audit** — input length, font-file bounds. File findings in `docs/audit/YYYY-MM-DD-audit.md`
6. **Documentation audit** — font format ADR, default-fonts guide, examples

### Work Loop (continuous)

1. **Work phase** — new font, render flag, bug fix
2. **Build check** — `cyrius build src/main.cyr build/bnrmr`
3. **Test additions** — happy path + malformed-input path
4. **Internal review** — bounds, buffer sizing
5. **Documentation** — CHANGELOG, state.md, font docs if a new font landed
6. **Version sync** — `VERSION`, `cyrius.cyml`, CHANGELOG header in sync before tag

### Task Sizing

- **Low/Medium effort**: batch — multiple flags / font tweaks per cycle
- **Large effort**: small bites — font format work, .flf read path
- **If unsure**: treat it as large

## Cyrius Conventions

- All struct fields are 8 bytes (`i64`), accessed via `load64`/`store64` with offset
- Heap allocation via `fl_alloc()`/`fl_free()` for individual-lifetime data
- Bump allocation via `alloc()` for long-lived data
- Enum values for constants — don't consume `gvar_toks` slots
- `break` in while loops with `var` declarations is unreliable — use flag + `continue`
- See [cyrius CLAUDE.md](https://github.com/MacCracken/cyrius/blob/main/CLAUDE.md) for the full convention set

## Docs

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — Non-obvious constraints
- [`docs/guides/`](docs/guides/) — Task-oriented how-tos (including font authoring)
- [`docs/examples/`](docs/examples/) — Runnable examples
- [`docs/development/state.md`](docs/development/state.md) — Live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — Milestones through v1.0
- `fonts/` — In-tree default fonts (CYML)

Full doc-tree convention: [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md).

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/). Font format changes are `Breaking` until v1.0. New fonts go under `Added` with their character coverage noted. CLI flag changes that alter exit codes or output bytes are `Breaking`.
