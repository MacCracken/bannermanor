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

## Shape vs figlet

- Font format probably **CYML** (or .figlet-compatible read path with
  a native CYML extension).
- Color / layout primitives shared with `darshini` via `darshana`
  (TTY/ANSI/cursor) when needed.
- Ships with a few opinionated default fonts; user-installable extras.

## Status

Pre-1.0 scaffold (0.1.0). No font system, no rendering, no input
parsing yet.

## Build

```sh
cyrius deps                              # resolve stdlib
cyrius build src/main.cyr build/bnrmr    # compile (output: bnrmr)
./build/bnrmr                             # prints scaffold version line
cyrius test                               # run tests/*.tcyr
```

## License

GPL-3.0-only
