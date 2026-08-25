# BannerManor

`figlet`-equivalent ASCII-art banner generator for MOTDs, script
intros, splash text — in
[Cyrius](https://github.com/MacCracken/cyrius). Binary: **`bnrmr`**
(vowel-dropped per the `commandress` → `cmdrs` compression pattern).

## The frame

*Banner* (heraldic flag, welcome announcement, MOTD) + *Manor* (the
lord's estate, the home one returns to) = the heraldic welcome
ceremony at the entrance to your digital home. The MOTD as the banner
unfurled at the manor gate when the lord arrives. Every login = arriving
back at your manor with your banner being raised.

The mechanical lane is *what BannerManor does* (figlet-equivalent);
the manor-gate framing is *what BannerManor is*.

## Positioning

Fourth member of the terminal-aesthetics set:

- [`commandress`](https://github.com/MacCracken/commandress) (`cmdrs`) — prompt rendering
- [`darshini`](https://github.com/MacCracken/darshini) — file listing display
- [`hapi`](https://github.com/MacCracken/hapi) — dotfile / symlink management
- **`BannerManor`** (`bnrmr`) — ASCII banner generation
- [`iam`](https://github.com/MacCracken/iam) — system info / login MOTD

## Status

**1.1.4**. Stable. CLI flag surface, CYML font format (schema 1),
default font set, and `.flf` adapter contract are all frozen at their
v1.0.0 shape — see the v1.0.0 [`Breaking`](CHANGELOG.md) section for
what locked.

## Quick usage

```sh
bnrmr "AGNOS"                          # default font (block), full width
bnrmr --font slim "HELLO"              # narrower font from the default set
bnrmr --font big "1.0"                 # chunky 7×7 banner
bnrmr --align center --color cyan "WELCOME"
bnrmr --font ./modular.flf "BNRMR"     # legacy .flf path
bnrmr --list-fonts                     # what's available
```

The banner clamps to the terminal width by default; piped output
(`bnrmr ... | cat`) emits the full untruncated banner.

## v1.0 contract

The frozen surface:

- **CLI flags**: `--font` (`-f`), `--width` (`-w`), `--align`,
  `--pad`, `--color`, `--list-fonts`, `--help` (`-h`), `--version`.
- **Default font set** (in-tree): `block` (5×5), `slim` (4×5),
  `big` (7×7) — all with full printable-ASCII coverage and
  lowercase-folds-to-uppercase behavior.
- **CYML font format**, schema 1 — see
  [`docs/adr/0001-cyml-font-format.md`](docs/adr/0001-cyml-font-format.md).
  Authoring walkthrough at [`docs/guides/fonts.md`](docs/guides/fonts.md).
- **Legacy `.flf` read path** — `--font path.flf` loads any figlet
  font that fits the 64-col × 32-row envelope. Uniform-width fit,
  no smushing, ASCII 32..126, 1 MB file cap.
- **Color via [darshana](https://github.com/MacCracken/darshana)** —
  16 ANSI named colors + `rainbow`. Auto-suppressed on pipes.

## Build

```sh
cyrius deps                            # resolve stdlib + darshana
cyrius build src/main.cyr build/bnrmr  # compile (binary: bnrmr)
cyrius test                            # 2775 assertions
cyrius bench tests/bannermanor.bcyr    # render hot-path CPU bench
```

Toolchain pin: `cyrius = "6.5.35"` in `cyrius.cyml` is the source of
truth.

## Docs

- [`CHANGELOG.md`](CHANGELOG.md) — per-release history
- [`docs/guides/`](docs/guides/) — getting started, font authoring
- [`docs/adr/`](docs/adr/) — design decisions (why X over Y)
- [`docs/development/state.md`](docs/development/state.md) — live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — what ships next, and why
- [`docs/benchmarks.md`](docs/benchmarks.md) — render-path CPU trend
- [`docs/audit/`](docs/audit/) — security audit reports

## License

GPL-3.0-only
