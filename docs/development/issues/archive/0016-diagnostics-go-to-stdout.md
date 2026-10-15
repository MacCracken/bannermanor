# Issue 0016 — every diagnostic is written to stdout, never stderr

**Reported**: 2026-08-25
**Version**: 1.1.4 (deferred-work sweep)
**Reporter**: maintainer
**Status**: **fixed in 1.5.0** (2026-10-15), under [ADR 0002](../../../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
ruling (1).
**Severity**: correctness — corrupts the project's primary use case

## Observation

Every error message in `src/main.cyr` goes through `println`, which
writes to fd 1. Nothing in `src/` ever writes to fd 2:

```
$ bnrmr --font typo "HI" 2>/dev/null
bnrmr: failed to load font (missing or malformed)     # survives 2>/dev/null
$ bnrmr --font typo "HI" 2>&1 >/dev/null
                                                       # stderr is empty
```

## Why it matters

BannerManor's stated purpose is MOTDs and script intros — which means
its output is *redirected*, routinely:

```
bnrmr --font "$FONT" "$HOSTNAME" > /etc/motd
banner=$(bnrmr --font "$FONT" "$TITLE")
```

With a typo in `$FONT`, the first writes `bnrmr: failed to load font
(missing or malformed)` into `/etc/motd`, and the second captures the
error text as the banner. The usage block behaves the same way — a bare
`bnrmr` or a bad flag dumps the whole help text into the target file.

Exit codes are correct throughout; only the stream is wrong. A caller
checking `$?` is fine. A caller redirecting stdout — which is every
caller in the documented use case — is not.

## Why it was gated

Moving ~20 messages from fd 1 to fd 2 changes the stdout bytes of an
invalid invocation. Whether the v1.0 freeze covers *invalid* invocations
was one of three unsettled readings of the freeze sentence.
[ADR 0002](../../../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
ruling (1), accepted 2026-10-15, settles it: diagnostic output is not
frozen, exit codes are. The move is a `Changed` entry in a 1.x minor,
with the golden `error` tier re-baselined in the same commit and its diff
reviewed record by record. The precedent agreed: 1.1.4 had already
changed `--help` stdout bytes inside a patch release.

## Scope when unblocked

- Route all diagnostics to fd 2. Keep exit codes exactly as they are.
- Add the `bright-<name>` dash alias to the `--color` error text, so it
  agrees with `--help` (moved here from issue 0017 at 1.4.1). It is an
  error-path byte change too, so the error tier moves once, not twice.
- Decide `--help`'s stream separately: `--help` on *request* is a
  success and conventionally goes to stdout; the usage block printed
  after an *error* should follow the error to stderr.
- The golden suite already captures stdout and stderr separately
  (`scripts/golden.sh`, since 1.4.1), so the move shows up as a diff of
  the `error` tier, record by record.

## Acceptance

- `bnrmr --font typo "X" > out` leaves `out` empty; the message is on fd 2.
- Every exit code unchanged, verified against the golden suite.
- Rendered banner bytes on valid invocations unchanged.

## Fix (shipped 1.5.0)

Every diagnostic goes to fd 2, through `_err_line` (`src/layout.cyr`).
Exit codes did not change. That covers the parse errors, `too many
arguments`, every flag-value error, every font-load error, `input too
long`, and the new `write error` / `out of memory`.

- **The usage block follows the error.** After a parse error it goes to
  stderr (`print_usage_err`). On request (`--help`), and for a bare
  `bnrmr` or an empty text (both exit 0), it stays on stdout. A help that
  was asked for is output, not a diagnostic.
- **`--list-fonts` stays on stdout**, including `(none found …)` and
  `(malformed — skipped)`: it exits 0, and the listing is its output.
- **Parse errors name what was typed.** This was the open question the
  roadmap left for this change. cmdit's `cmdit_print_error` already did
  it, but bnrmr composes its own line (`report_parse_error`) for two
  reasons. cmdit's echo escapes C0 and DEL but not C1 (0x80–0x9F), which
  bnrmr's control-byte rule covers, and its bundled-flag message says
  nothing about `--`, which is exactly what someone who typed `bnrmr -HI`
  needs. The echo shows control bytes as `?` and is cut at 64 bytes.
  ```
  bnrmr: unknown flag: --bogus
  bnrmr: --font: missing value
  bnrmr: -HI: bundled short flags are not supported (write -x -y; put -- before text that starts with -)
  bnrmr: --list-fonts=0: this flag takes no value
  ```
- **The `--color` error lists `bright-<name>`** (moved here from issue
  0017), so it agrees with `--help`.

The golden `error` tier was re-baselined once, in the same change, and
checked record by record by a script rather than by eye. All 76 records
keep their exit code and have empty stdout. 46 moved their text to
stderr verbatim, 26 parse errors reworded only their first line, and 4
`--color` errors gained `bright-<name>`. The frozen and snapshot tiers
did not move.

```
$ bnrmr --font typo "$HOSTNAME" > /etc/motd; echo $?
bnrmr: failed to load font (missing or malformed)
1
$ wc -c < /etc/motd
0
```
