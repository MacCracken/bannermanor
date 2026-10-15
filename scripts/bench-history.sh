#!/bin/sh
# bench-history — append one `cyrius bench` run to docs/benchmarks/history.csv.
#
# Usage:
#   cyrius bench tests/bannermanor.bcyr | sh scripts/bench-history.sh
#
# Env overrides (for back-filling a saved run):
#   BENCH_HISTORY_CSV   destination (default docs/benchmarks/history.csv)
#   BENCH_DATE          date column  (default: today, UTC)
#   BENCH_VERSION       version column (default: VERSION)
#   BENCH_HOST          host column  (default: uname -n)
#
# Reads result rows of the shape lib/bench.cyr prints, a grammar several
# consumers parse:
#   <name>: <avg><unit> avg (min=<min><unit> max=<max><unit>) [<iters> iters]
# and writes one CSV row per result:
#   date,version,cyrius,host,timer_floor_ns,name,avg_ns,iters
# Values are normalized to nanoseconds, fractions kept (lib/bench.cyr
# prints "87.359us"). min and max are not stored: for a batched row they
# equal the average by construction (docs/benchmarks.md, Methodology).
# The `[timer floor ...]` line is not a result. Its value goes in every
# row's timer_floor_ns column, because the floor moves between boots and
# a row near it means nothing without it.
#
# ── WHY IT REFUSES AN EMPTY RUN ──────────────────────────────────────────────
# A recorder fails the same way it passes: by silently matching nothing.
# commandress's copy of this script dropped every row with a fractional
# average for four releases (its 1.1.4 notes), because a bare [0-9]+
# matched the "2" of "2.835us" and then found no unit. So the parse here
# allows fractions, and a run that yields no rows, or fewer than the
# subjects tests/bannermanor.bcyr declares, is an ERROR, not "0 rows
# appended".

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

CSV="${BENCH_HISTORY_CSV:-docs/benchmarks/history.csv}"
DATE="${BENCH_DATE:-$(date -u +%Y-%m-%d)}"
VERSION="${BENCH_VERSION:-$(head -1 VERSION 2>/dev/null | tr -d '[:space:]')}"
HOST="${BENCH_HOST:-$(uname -n)}"
CYRIUS="$(grep 'cyrius *= *"' cyrius.cyml 2>/dev/null | head -1 | sed 's/.*"\(.*\)"/\1/')"
# B0..B4: _calibration, B1, B2, B3, three B4 rows.
EXPECT=7

die() { echo "bench-history: FAILED — $*" >&2; exit 1; }

[ -n "$VERSION" ] || die "no version (VERSION is empty and BENCH_VERSION is unset)"

T="$(mktemp)" || die "mktemp failed"
trap 'rm -f "$T"' EXIT INT TERM
cat > "$T"

# "<n><unit>" -> integer nanoseconds (rounded).
to_ns() {
    printf '%s\n' "$1" | awk '{
        v = $0; u = v; sub(/[a-z]+$/, "", v); sub(/^[0-9.]+/, "", u)
        m = 0
        if (u == "ns") m = 1; else if (u == "us") m = 1000; else if (u == "ms") m = 1000000; else if (u == "s") m = 1000000000
        if (m == 0 || v == "") { print "BAD"; exit }
        printf "%d\n", v * m + 0.5
    }'
}

FLOOR="$(sed -n 's/.*\[timer floor \([0-9.]*[a-z]*\) per clock read.*/\1/p' "$T" | head -1)"
FLOOR_NS=""
[ -n "$FLOOR" ] && FLOOR_NS="$(to_ns "$FLOOR")"
[ "$FLOOR_NS" != "BAD" ] || die "could not read the timer floor '$FLOOR'"

ROWS="$(mktemp)" || die "mktemp failed"
trap 'rm -f "$T" "$ROWS"' EXIT INT TERM
: > "$ROWS"
N=0
while IFS= read -r line; do
    # A result row: indented "<name>: <number><unit> avg (".
    printf '%s\n' "$line" | grep -qE '^[[:space:]]*[^[:space:]][^:]*: [0-9]+(\.[0-9]+)?(ns|us|ms|s) avg \(' || continue
    name="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*([^:]+):.*/\1/' | sed 's/,/;/g')"
    avg="$(printf '%s\n' "$line" | sed -E 's/.*: ([0-9.]+(ns|us|ms|s)) avg.*/\1/')"
    iters="$(printf '%s\n' "$line" | sed -nE 's/.*\[([0-9]+) iters\].*/\1/p')"
    avg_ns="$(to_ns "$avg")"
    [ "$avg_ns" != "BAD" ] || die "row '$name': could not read the average '$avg'"
    [ -n "$iters" ] || die "row '$name': no iteration count"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$DATE" "$VERSION" "$CYRIUS" "$HOST" "$FLOOR_NS" "$name" "$avg_ns" "$iters" >> "$ROWS"
    N=$((N + 1))
done < "$T"

[ "$N" -gt 0 ] || die "no result rows in the input — was it the output of \`cyrius bench\`?"
[ "$N" -ge "$EXPECT" ] || die "$N result rows, expected $EXPECT — a subject was dropped or no longer parses"

mkdir -p "$(dirname "$CSV")"
[ -f "$CSV" ] || echo "date,version,cyrius,host,timer_floor_ns,name,avg_ns,iters" > "$CSV"
cat "$ROWS" >> "$CSV"
echo "bench-history: appended $N rows to $CSV (date=$DATE version=$VERSION cyrius=$CYRIUS host=$HOST)"
cat "$ROWS" | sed 's/^/    /'
