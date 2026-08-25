#!/bin/sh
# doc-pin-check — every LIVE version or pin quoted in the docs must agree with
# the file that OWNS that number.
#
# Usage: sh scripts/doc-pin-check.sh
# Exit 0 if every live mention matches its source of truth; 1 (listing each
# offender) otherwise.
#
# ── WHY THIS EXISTS ──────────────────────────────────────────────────────────
# At the 1.1.3 bump, README.md and docs/guides/getting-started.md both still
# quoted `cyrius = "6.0.1"` — the pin they were written against at 0.3.0, carried
# unchanged through the 1.1.0, 1.1.1 and 1.1.2 releases. docs/development/
# roadmap.md still announced v1.0.0 as the shipped version. Four numbers, three
# releases, nobody noticed: that is a PROCESS failure, not four typos, and the
# only reason it surfaced at all is that someone happened to read the guide.
#
# Nothing else in the tree can catch it. The build does not read prose; the test
# suite renders banners; `cyrius lint` lints Cyrius. release.yml's "Verify
# version" step (:22) ties the git TAG to VERSION — a real gate, but it stops at
# the repo root and says nothing about the seven other places a number is spelled
# out. So a doc pin can rot for as long as it likes and every gate stays green.
#
# ── SOURCES OF TRUTH (the only files allowed to state these numbers) ─────────
#   VERSION                        project version   — CLAUDE.md says so outright
#   cyrius.cyml [package].cyrius   toolchain pin     — what CI installs
#   cyrius.cyml [deps.darshana]    darshana pin      — the `tag =` line
# Everything the docs say is a COPY, and a copy is what drifts.
#
# ── LIVE vs HISTORICAL, WHICH IS THE WHOLE DIFFICULTY ────────────────────────
# ⭐ Most version numbers in this repo are SUPPOSED to be stale. CHANGELOG.md is
# a per-release record; state.md's `**N.N.N** — <date>.` paragraphs are the same
# record in summary form; docs/benchmarks.md stamps each measurement point with
# the `**Toolchain**:` it was taken under (points 1–3 correctly still read 6.0.1
# — rewriting them would falsify the benchmark); docs/development/issues/archive/
# describes bugs as they were when filed. A gate that flagged those would be
# worse than no gate: it would train the maintainer to "fix" true history into
# a lie, and then to ignore the gate.
#
# So this scans a NARROW file set (see LIVE_SET) with NARROW patterns (see the
# scan_rule calls), and recognises a live claim by its SHAPE, not by proximity to
# a version-looking string:
#   · `cyrius = "X.Y.Z"`   — the manifest line quoted verbatim in prose. The
#                            historical form in state.md is `cyrius pin
#                            `A → B`` — an arrow, no `=`, never matched.
#   · `- **Cyrius pin**: `X.Y.Z``  — state.md's ## Toolchain bullet, anchored to
#                            the line start so the prose paragraphs cannot match.
#   · `darshana = X.Y.Z`   — state.md's dep bullet. Historical form is again
#                            `darshana pin `A → B``, and `darshana 0.3.5's ...`
#                            at :111 is provenance — neither has an `=`.
#   · `**X.Y.Z**` at line start, NOT followed by an em dash — README's ## Status
#                            line. The em-dash form IS the dated record, and is
#                            the single discriminator that keeps state.md's whole
#                            version log out of scope.
#   · `"bnrmr X.Y.Z"`      — src/main.cyr's `--version` literal, the one live
#                            mention that is code rather than prose.
# Bare version numbers in running prose are deliberately NOT matched. state.md
# alone carries `added at 1.1.3`, `(pinned, 1.1.3)`, `against 0.8.0`, `the 0.7.0
# audit` — provenance every one, and a pattern loose enough to catch a real stale
# quote among them would fire on all of them.
#
# ── VACUITY FLOOR ────────────────────────────────────────────────────────────
# A pattern-matching gate fails the same way it passes — silently, by matching
# nothing. Reword one sentence in README.md and the toolchain pattern stops
# firing there; the gate still exits 0, having checked one fewer thing than it
# did yesterday, and reports nothing. That is exactly the drift it exists to stop,
# reintroduced one level up.
# So COVERAGE is asserted, not assumed: the table below names which kind of claim
# each file must yield, a file that yields none is a FAILURE, and every claim
# found is PRINTED on success. A run that lists 5 mentions where it listed 6 is
# reporting that its own patterns broke — not that the tree is clean.

set -u

# ONE level up: this script lives in scripts/.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

TMPD="$(mktemp -d)" || { echo "doc-pin-check: FAILED — mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$TMPD"' EXIT INT TERM

fail() {
    echo "doc-pin-check: FAILED — $1" >&2
    shift
    for _l in "$@"; do echo "  $_l" >&2; done
    exit 1
}

# Version-shaped: X.Y.Z with an optional pre-release/build tail.
is_version() {
    printf '%s\n' "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9._-]*$'
}

# ── 1. Read the sources of truth ─────────────────────────────────────────────

VERSION="$(head -1 VERSION 2>/dev/null | tr -d '[:space:]')"
is_version "$VERSION" || fail "VERSION does not hold a version: '$VERSION'" \
    "release.yml's 'Verify version' step compares the git tag against this file;" \
    "if it cannot be read, nothing downstream has a project version to check."

# Deliberately the EXACT expression ci.yml:34 and release.yml:42 use to decide
# which toolchain to install, so this gate and CI can never disagree about what
# "the pin" is. Not grep -oP: neither workflow needs a PCRE-capable grep and this
# must not be the thing that introduces the requirement.
CYRIUS_PIN="$(grep 'cyrius *= *"' cyrius.cyml 2>/dev/null | head -1 | sed 's/.*"\(.*\)"/\1/')"
# That sed is a SUBSTITUTION, not a match: handed a malformed line it cannot
# rewrite (an unterminated quote, say) it passes the WHOLE LINE through unchanged,
# and the garbage would then be compared against three correct doc mentions and
# reported as all three docs being wrong. Shape-assert so the manifest is named
# as the culprit instead — CI has the same flaw and would try to fetch
# cyrius-<garbage>-x86_64-linux.tar.gz.
is_version "$CYRIUS_PIN" || fail "the toolchain pin is not version-shaped: '$CYRIUS_PIN'" \
    "cyrius.cyml [package].cyrius is malformed or missing. Expected exactly:" \
    "    cyrius = \"X.Y.Z\"" \
    "CI extracts it with this same expression and would install that string."

# Section-scoped so a future [deps.<other>] with its own `tag =` cannot be read
# as darshana's. The range ends at the next line starting with '[' (or EOF —
# [deps.darshana] is last today); the inner filter skips the comment block above
# the tag, which itself names old pins.
DARSHANA_PIN="$(sed -n '/^\[deps\.darshana\]/,/^\[/{ /^[[:space:]]*tag[[:space:]]*=/p; }' cyrius.cyml 2>/dev/null \
    | head -1 | sed 's/.*"\(.*\)"/\1/')"
is_version "$DARSHANA_PIN" || fail "the darshana pin is not version-shaped: '$DARSHANA_PIN'" \
    "cyrius.cyml [deps.darshana] is malformed or missing its tag. Expected:" \
    "    tag = \"X.Y.Z\""

# ── 2. The live file set ─────────────────────────────────────────────────────
# Narrow ON PURPOSE — see LIVE vs HISTORICAL above. docs/guides/ is a glob so a
# new guide is gated the day it is written; the other three are named because
# they are the only files outside guides/ that carry a live number.
#
# NOT scanned, and each for a stated reason:
#   CHANGELOG.md                       per-release record; every entry is history
#   docs/benchmarks.md                 `**Toolchain**:` stamps the pin a point was
#                                      measured under; rewriting it falsifies data
#   docs/development/issues/archive/   bugs as filed, closed, frozen
#   docs/adr/                          decisions as made (0001 is amended in place
#                                      with the body preserved as the record)
#   docs/development/roadmap.md        names TARGET versions (1.2.0, 1.3.0, ...)
#                                      and deliberately never the shipped one —
#                                      state.md owns that. Do NOT add it to
#                                      LIVE_SET: rule (d) is an equality test
#                                      against VERSION, and a target version is
#                                      defined by not equalling it, so every
#                                      heading here would read as drift.
: > "$TMPD/live"
for f in README.md docs/guides/*.md docs/development/state.md src/main.cyr; do
    [ -f "$f" ] && printf '%s\n' "$f" >> "$TMPD/live"
done

# ── 3. Coverage table — which file must yield which kind of claim ────────────
# This is the vacuity floor. Restructuring a doc so it no longer states a pin is
# a legitimate change; making that change means editing THIS TABLE in the same
# commit, which is the point — the removal becomes a decision instead of a
# silently narrowed gate.
REQUIRED="README.md:toolchain
README.md:version
docs/guides/getting-started.md:toolchain
docs/development/state.md:toolchain
docs/development/state.md:darshana
src/main.cyr:version"

# ── 4. Scan ──────────────────────────────────────────────────────────────────
# scan_rule <kind> <grep ERE> <sed extractor> [exclude ERE]
# Every loop reads its list from a REDIRECT, not a pipe: a piped `while read`
# runs in a subshell and discards what it accumulates. Not `for f in $LIST`
# either — that leans on unquoted word splitting, which zsh does not do by
# default, so the same script would report a different verdict under `zsh` than
# under CI's dash.
: > "$TMPD/claims"
scan_rule() {
    _kind="$1"; _re="$2"; _ext="$3"; _excl="${4:-}"
    while IFS= read -r _f; do
        [ -n "$_f" ] || continue
        if [ -n "$_excl" ]; then
            grep -nE "$_re" "$_f" 2>/dev/null | grep -vE "$_excl" > "$TMPD/hits" || true
        else
            grep -nE "$_re" "$_f" 2>/dev/null > "$TMPD/hits" || true
        fi
        while IFS= read -r _hit; do
            [ -n "$_hit" ] || continue
            _no="${_hit%%:*}"
            _txt="${_hit#*:}"
            _val="$(printf '%s\n' "$_txt" | sed "$_ext")"
            # sed passes a line it cannot rewrite straight through, so a failed
            # extraction arrives as the entire source line rather than as an
            # error. Catch it here and name the file:line — a garbage "found"
            # value would otherwise be reported as doc drift.
            if ! is_version "$_val"; then
                printf '    %s:%s  (%s) — matched but no version could be extracted\n' \
                    "$_f" "$_no" "$_kind" >> "$TMPD/unreadable"
                continue
            fi
            printf '%s|%s|%s|%s\n' "$_kind" "$_f" "$_no" "$_val" >> "$TMPD/claims"
        done < "$TMPD/hits"
    done < "$TMPD/live"
}
: > "$TMPD/unreadable"

# (a) the manifest line quoted in prose: Toolchain pin: `cyrius = "6.5.35"`
scan_rule toolchain \
    'cyrius[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+' \
    's/.*cyrius[[:space:]]*=[[:space:]]*"\([0-9][^"]*\)".*/\1/'

# (b) state.md ## Toolchain bullet: - **Cyrius pin**: `6.5.35`
scan_rule toolchain \
    '^-[[:space:]]*\*\*Cyrius pin\*\*:' \
    's/^-[[:space:]]*\*\*Cyrius pin\*\*:[^`]*`\([0-9][^`]*\)`.*/\1/'

# (c) state.md dep bullet: - `darshana = 1.0.0` (pinned, 1.1.3)
scan_rule darshana \
    'darshana[[:space:]]*=[[:space:]]*"?[0-9]+\.[0-9]+\.[0-9]+' \
    's/.*darshana[[:space:]]*=[[:space:]]*"*\([0-9][0-9A-Za-z._-]*\).*/\1/'

# (d) README ## Status: **1.1.3**. Stable. ...
#     The exclusion is load-bearing: `**N.N.N** — <date>` is state.md's dated
#     record (13 of them today) and MUST stay stale. That em dash is the only
#     thing separating the two shapes.
scan_rule version \
    '^\*\*[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9._-]*\*\*' \
    's/^\*\*\([0-9][0-9A-Za-z._-]*\)\*\*.*/\1/' \
    '^[0-9]+:\*\*[0-9][0-9A-Za-z._-]*\*\*[[:space:]]*—'

# (e) src/main.cyr's --version literal: println("bnrmr 1.1.3");
scan_rule version \
    '"bnrmr [0-9]+\.[0-9]+\.[0-9]+' \
    's/.*"bnrmr \([0-9][0-9A-Za-z._-]*\)".*/\1/'

if [ -s "$TMPD/unreadable" ]; then
    echo "doc-pin-check: FAILED — a pattern matched a line it could not read a version out of" >&2
    cat "$TMPD/unreadable" >&2
    echo "  The line's shape changed under the pattern in scripts/doc-pin-check.sh." >&2
    echo "  Fix the line or the pattern — do not leave it half-matching." >&2
    exit 1
fi

sort -u "$TMPD/claims" -o "$TMPD/claims" 2>/dev/null || true

# ── 5. Coverage floor ────────────────────────────────────────────────────────
: > "$TMPD/uncovered"
while IFS= read -r _req; do
    [ -n "$_req" ] || continue
    _rf="${_req%%:*}"; _rk="${_req##*:}"
    if [ ! -f "$_rf" ]; then
        printf '    %s — required file is missing from the worktree (expected a %s mention)\n' \
            "$_rf" "$_rk" >> "$TMPD/uncovered"
    elif ! grep -q "^$_rk|$_rf|" "$TMPD/claims"; then
        printf '    %s — no live %s mention found\n' "$_rf" "$_rk" >> "$TMPD/uncovered"
    fi
done <<REQ
$REQUIRED
REQ

if [ -s "$TMPD/uncovered" ]; then
    echo "doc-pin-check: FAILED — the gate found nothing to check where it must find something" >&2
    cat "$TMPD/uncovered" >&2
    echo "" >&2
    echo "  This is NOT a report that the tree is clean — it is the gate reporting that" >&2
    echo "  it went blind. Either the doc was reworded out from under the pattern (fix" >&2
    echo "  the pattern), or it genuinely no longer states that pin (drop the line from" >&2
    echo "  REQUIRED in this script, in the same commit, deliberately)." >&2
    exit 1
fi

# ── 6. Compare ───────────────────────────────────────────────────────────────
: > "$TMPD/drift"
N=0
while IFS='|' read -r kind file lineno value; do
    [ -n "${kind:-}" ] || continue
    N=$((N + 1))
    case "$kind" in
        toolchain) want="$CYRIUS_PIN";   src="cyrius.cyml [package].cyrius" ;;
        darshana)  want="$DARSHANA_PIN"; src="cyrius.cyml [deps.darshana].tag" ;;
        version)   want="$VERSION";      src="VERSION" ;;
        *) fail "internal: unknown claim kind '$kind'" ;;
    esac
    if [ "$value" != "$want" ]; then
        printf '    %s:%s\n        says %-12s  %s says %s\n' \
            "$file" "$lineno" "$value" "$src" "$want" >> "$TMPD/drift"
    fi
done < "$TMPD/claims"

if [ -s "$TMPD/drift" ]; then
    echo "doc-pin-check: FAILED — documented pins disagree with their source of truth"
    echo ""
    cat "$TMPD/drift"
    echo ""
    echo "  Every number above is a COPY. Fix the copy, never the source — and fix it in"
    echo "  the SAME commit as the bump, which is the step that was missed at 1.1.0,"
    echo "  1.1.1 and 1.1.2 and left README.md and docs/guides/getting-started.md quoting"
    echo "  cyrius 6.0.1 for three releases."
    echo "  Current sources of truth:"
    echo "      VERSION                        $VERSION"
    echo "      cyrius.cyml [package].cyrius   $CYRIUS_PIN"
    echo "      cyrius.cyml [deps.darshana]    $DARSHANA_PIN"
    exit 1
fi

# ── 7. Report what was actually checked ──────────────────────────────────────
LIVE_N="$(grep -c . "$TMPD/live" || true)"
echo "doc-pin-check: OK — $N live mentions across $LIVE_N scanned files agree with the sources of truth"
echo "    VERSION                        $VERSION"
echo "    cyrius.cyml [package].cyrius   $CYRIUS_PIN"
echo "    cyrius.cyml [deps.darshana]    $DARSHANA_PIN"
echo "  checked:"
while IFS='|' read -r kind file lineno value; do
    [ -n "${kind:-}" ] || continue
    printf '    %-40s %-10s %s\n' "$file:$lineno" "$kind" "$value"
done < "$TMPD/claims"
exit 0
