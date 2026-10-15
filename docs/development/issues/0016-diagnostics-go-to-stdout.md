# Issue 0016 — every diagnostic is written to stdout, never stderr

**Reported**: 2026-08-25
**Version**: 1.1.4 (deferred-work sweep)
**Reporter**: maintainer
**Status**: **open**, unblocked. [ADR 0002](../../adr/0002-freeze-scope-error-paths-and-malformed-input.md) ruling (1), accepted
2026-10-15, permits the move. Scheduled for roadmap 1.5.0.
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
[ADR 0002](../../adr/0002-freeze-scope-error-paths-and-malformed-input.md)
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
