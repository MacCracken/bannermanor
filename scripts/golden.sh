#!/bin/sh
# golden — the committed byte-for-byte check of bnrmr's frozen output contract.
#
# Usage:
#   sh scripts/golden.sh             check build/bnrmr against tests/golden/*.golden
#   sh scripts/golden.sh --update    rewrite tests/golden/*.golden from build/bnrmr
#
#   BNRMR=path/to/bnrmr              check another binary (default: build/bnrmr)
#   BNRMR_RUNNER=qemu-aarch64        prefix every invocation (cross-arch runs)
#
# Exit 0 when every case matches; 1 (with a diff) otherwise.
#
# ── WHY THIS EXISTS ──────────────────────────────────────────────────────────
# v1.0 froze rendered output bytes. Until 1.4.1 nothing checked that: the
# 79-invocation golden diff cited by 1.1.3 / 1.1.4, and 1.2.0's 224-invocation
# matrix, were real when they ran, but they lived in shell history. Nothing
# re-ran them. This is that matrix, committed, so CI re-runs it on every push.
#
# ── THREE TIERS, ONE FILE EACH ───────────────────────────────────────────────
#   frozen    valid invocations that render a banner: stdout, stderr and the
#             exit code. These bytes cannot change in 1.x (CHANGELOG 1.0.0).
#             Includes the pty leg, because stdout_is_tty gates color and the
#             default truncation width, and a pipe capture only ever records
#             the suppression path.
#   error     invalid invocations. The exit code is contract; the diagnostic
#             stream and text are what ADR 0002 rules on (issue 0016). When
#             that moves, this tier is re-baselined on purpose and the diff
#             reviewed line by line.
#   snapshot  --version, --help, bare bnrmr, --list-fonts. These move on
#             purpose (a help-text edit, a new font). The --version record is
#             normalized to `bnrmr @VERSION@` and checked against VERSION, so
#             a version bump does not churn this file and a literal that
#             drifts from VERSION still fails.
# The tier says how a change is REVIEWED. All three are checked every run.
#
# ── LIVE INPUTS, PINNED ──────────────────────────────────────────────────────
# bnrmr reads its CWD (fonts/ and --list-fonts), $COLUMNS (frame width) and
# the terminal size of fd 1. Every case runs under `env -i` with only PATH
# and LC_ALL=C, from a stated CWD (the repo root unless the case says
# otherwise), with stdin on /dev/null. A case that wants COLUMNS sets it.
# Pipe cases put fd 1 on a file. Pty cases run through script(1) on a fresh
# pty with the window size set by stty and output post-processing off
# (-opost), so the bytes arrive exactly as bnrmr wrote them. On a pty, stdout
# and stderr share the terminal, so a pty record has one merged stream.
#
# ── RECORD FORMAT ────────────────────────────────────────────────────────────
#   ### <case id>
#   args: [<arg>] [<arg>] ...          each argument, escaped as below
#   env: NAME=VAL ...                  only if the case sets any
#   cwd: <dir>                         only if not the repo root
#   pty: <rows>x<cols>                 only for pty cases
#   exit: <n>
#   stdout: <bytes> bytes, cksum <crc> (or `pty:` for the merged pty stream)
#   | <line>$                          GNU `sed -n 'l 0'`: C escapes, octal
#   ...                                for every other byte >= 0x80 or < 0x20,
#   stderr: <bytes> bytes, cksum <crc> a `$` at each line end (so trailing
#                                      spaces are visible)
# The length and CRC make the record exact even where the escaped view is
# not: `l` cannot show whether the last line ended in a newline.
#
# ── NOT A GATE THAT LIES ─────────────────────────────────────────────────────
# `cyrius fuzz` reported green for releases while running a no-op stub (issue
# 0010), and the old golden diff was cited as a gate with nothing re-running
# it. So: a missing script(1) is a FAILURE, not a skipped pty leg; a tier
# with no records is a failure; the run asserts that every case it was given
# produced a record; and the summary prints how many cases each tier and the
# pty leg checked.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

die() {
    echo "golden: FAILED — $1" >&2
    shift
    for _l in "$@"; do echo "  $_l" >&2; done
    exit 1
}

MODE=check
case "${1:-}" in
    "")       ;;
    --update) MODE=update ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)        die "unknown argument '$1' (try --update)" ;;
esac

# ── Tools ────────────────────────────────────────────────────────────────────
# `sed -n 'l 0'` (no line wrapping) is GNU. The escaped view is what a reviewer
# reads in a re-baseline diff, so a sed that wraps or escapes differently would
# rewrite every record. Refuse rather than produce a file that will not match.
sed --version 2>/dev/null | head -1 | grep -q 'GNU sed' \
    || die "GNU sed is required (the record format uses \`sed -n 'l 0'\`)"
command -v script >/dev/null 2>&1 \
    || die "script(1) is not installed — the pty leg cannot run" \
        "It is util-linux's script. Install it; do not skip the pty leg: it is" \
        "the only part of this suite that sees --color bytes and TTY truncation."
command -v stty >/dev/null 2>&1 || die "stty is not installed — the pty leg cannot set a window size"
command -v cksum >/dev/null 2>&1 || die "cksum is not installed"

VERSION="$(head -1 VERSION 2>/dev/null | tr -d '[:space:]')"
[ -n "$VERSION" ] || die "VERSION is empty or missing"

BNRMR="${BNRMR:-build/bnrmr}"
case "$BNRMR" in /*) ;; *) BNRMR="$ROOT/$BNRMR" ;; esac
[ -x "$BNRMR" ] || die "no executable at $BNRMR" \
    "Build it first:  cyrius build src/main.cyr build/bnrmr"
BNRMR_RUNNER="${BNRMR_RUNNER:-}"

T="$(mktemp -d)" || die "mktemp -d failed"
trap 'rm -rf "$T"' EXIT INT TERM
OUT="$T/out"
mkdir -p "$OUT"
for _tier in frozen error snapshot; do : > "$OUT/$_tier.golden"; done

NL='
'
N_CASES=0
N_PTY=0

# Single-quote a word for the shell script(1) runs.
q() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# One argument, escaped the way stream bodies are, without the line-end `$`.
escarg() {
    printf '%s' "$1" | LC_ALL=C sed -n 'l 0' | sed 's/\$$//'
}

stream() {  # <label> <file>
    _n="$(wc -c < "$2" | tr -d ' ')"
    _ck="$(cksum < "$2" | cut -d' ' -f1)"
    printf '%s: %s bytes, cksum %s\n' "$1" "$_n" "$_ck"
    if [ "$_n" -gt 0 ]; then
        LC_ALL=C sed -n 'l 0' "$2" | sed 's/^/| /'
    fi
}

# g <tier> <id> [pty=RxC] [cwd=DIR] [env=NAME=VAL]... [norm=version] -- <bnrmr args>
g() {
    _tier="$1"; _id="$2"; shift 2
    case "$_tier" in frozen|error|snapshot) ;; *) die "case $_id: unknown tier '$_tier'" ;; esac
    _pty=""; _cwd="."; _env=""; _norm=""
    while [ $# -gt 0 ] && [ "$1" != "--" ]; do
        case "$1" in
            pty=*)  _pty="${1#pty=}" ;;
            cwd=*)  _cwd="${1#cwd=}" ;;
            env=*)  _env="$_env ${1#env=}" ;;
            norm=version) _norm=version ;;
            *) die "case $_id: unknown option '$1'" ;;
        esac
        shift
    done
    [ "${1:-}" = "--" ] || die "case $_id: missing '--' before the bnrmr arguments"
    shift
    [ -d "$_cwd" ] || die "case $_id: cwd '$_cwd' does not exist"
    for _a in "$@"; do
        case "$_a" in *"$NL"*) die "case $_id: an argument contains a newline (the record format cannot show it)" ;; esac
    done

    if [ -z "$_pty" ]; then
        # $_env and $BNRMR_RUNNER are split on purpose: NAME=VAL words, and a
        # runner such as `qemu-aarch64`.
        # shellcheck disable=SC2086
        ( cd "$_cwd" && exec env -i PATH="$PATH" LC_ALL=C $_env $BNRMR_RUNNER "$BNRMR" "$@" ) \
            < /dev/null > "$T/o" 2> "$T/e"
        _rc=$?
    else
        _rows="${_pty%x*}"; _cols="${_pty#*x}"
        _cmd="stty rows $_rows cols $_cols -opost && exec env -i PATH=$(q "$PATH") LC_ALL=C$_env $BNRMR_RUNNER $(q "$BNRMR")"
        for _a in "$@"; do _cmd="$_cmd $(q "$_a")"; done
        ( cd "$_cwd" && SHELL=/bin/sh exec script -qec "$_cmd" /dev/null ) \
            < /dev/null > "$T/o" 2> "$T/e"
        _rc=$?
        # script(1) has nothing of its own to say on a clean run; bnrmr's
        # stderr went to the pty with its stdout. Anything here is the
        # harness, not bnrmr, and would otherwise be recorded as output.
        [ -s "$T/e" ] && die "case $_id: script(1) wrote to stderr:" "$(cat "$T/e")"
        N_PTY=$((N_PTY + 1))
    fi

    if [ "$_norm" = version ]; then
        _vre="$(printf '%s' "$VERSION" | sed 's/[.]/\\./g')"
        grep -q "^bnrmr $_vre\$" "$T/o" \
            || die "case $_id: --version does not print 'bnrmr $VERSION' (VERSION)" "got: $(head -1 "$T/o")"
        sed "s/^bnrmr $_vre\$/bnrmr @VERSION@/" "$T/o" > "$T/o2" && mv "$T/o2" "$T/o"
    fi

    {
        printf '### %s\n' "$_id"
        printf 'args:'
        for _a in "$@"; do printf ' [%s]' "$(escarg "$_a")"; done
        printf '\n'
        [ -n "$_env" ] && printf 'env:%s\n' "$_env"
        [ "$_cwd" != "." ] && printf 'cwd: %s\n' "$_cwd"
        [ -n "$_pty" ] && printf 'pty: %s\n' "$_pty"
        printf 'exit: %s\n' "$_rc"
        if [ -z "$_pty" ]; then
            stream stdout "$T/o"
            stream stderr "$T/e"
        else
            stream pty "$T/o"
        fi
        printf '\n'
    } >> "$OUT/$_tier.golden"
    N_CASES=$((N_CASES + 1))
}

# shellcheck source=../tests/golden/cases.sh
. "$ROOT/tests/golden/cases.sh"

# ── Coverage floor ───────────────────────────────────────────────────────────
N_REC=0
for _tier in frozen error snapshot; do
    _c="$(grep -c '^### ' "$OUT/$_tier.golden")"
    [ "$_c" -gt 0 ] || die "tier '$_tier' produced no records — tests/golden/cases.sh lost its cases"
    N_REC=$((N_REC + _c))
done
[ "$N_REC" -eq "$N_CASES" ] || die "$N_CASES cases ran but $N_REC records were written"
[ "$N_PTY" -gt 0 ] || die "the pty leg ran no cases"

count() { grep -c '^### ' "$1"; }

if [ "$MODE" = update ]; then
    for _tier in frozen error snapshot; do
        cp "$OUT/$_tier.golden" "tests/golden/$_tier.golden"
    done
    echo "golden: UPDATED tests/golden/{frozen,error,snapshot}.golden from $BNRMR"
    for _tier in frozen error snapshot; do
        printf '    %-9s %4s cases\n' "$_tier" "$(count "$OUT/$_tier.golden")"
    done
    echo "  Review the diff before committing: every changed frozen record is a"
    echo "  contract change (CHANGELOG 1.0.0); an error record is ADR 0002's call."
    exit 0
fi

FAIL=0
for _tier in frozen error snapshot; do
    _want="tests/golden/$_tier.golden"
    [ -f "$_want" ] || die "$_want is missing — run with --update to create it"
    if ! cmp -s "$_want" "$OUT/$_tier.golden"; then
        FAIL=1
        echo "golden: tier '$_tier' differs from $_want" >&2
        diff -u "$_want" "$OUT/$_tier.golden" | head -n 200 >&2
        echo "" >&2
    fi
done

if [ "$FAIL" -ne 0 ]; then
    echo "golden: FAILED — output no longer matches the committed records (diff above)" >&2
    echo "  frozen: a rendered byte moved — a v1.0 contract break unless the" >&2
    echo "          input already rendered wrong. error / snapshot: re-baseline with" >&2
    echo "          --update only if the change is intended, and say so in CHANGELOG." >&2
    exit 1
fi

echo "golden: OK — $N_CASES cases byte-identical ($BNRMR_RUNNER${BNRMR_RUNNER:+ }$BNRMR)"
for _tier in frozen error snapshot; do
    printf '    %-9s %4s cases\n' "$_tier" "$(count "$OUT/$_tier.golden")"
done
printf '    %-9s %4s cases (of the above, on a pty)\n' "pty" "$N_PTY"
exit 0
