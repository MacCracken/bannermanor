#!/bin/sh
# flf-corpus.sh — render every .flf font in a figlet font corpus with two
# bnrmr binaries and compare what they write (1.10.0).
#
# Usage:
#   sh scripts/flf-corpus.sh OLD_BNRMR NEW_BNRMR DIR...
#
# Manual, not CI: the corpus is not in this repo. The reference corpus is
# cmatsuoka/figlet-fonts and xero/figlet-fonts, 1,052 .flf files between
# them (git clone --depth 1 each). 1.5.0 checked its envelope change
# against it by hand; this script is that check, kept.
#
# Each font gets three invocations, and each is compared on stdout, stderr
# and exit status:
#   all     every printable ASCII byte, natural width
#   right   "Hello, World" in --width 100 --align right: the truncation
#           and alignment arithmetic
#   center  every printable ASCII byte in --width 500 --align center
# A font that fails to load is compared too: both binaries must refuse it
# the same way.
#
# Prints a line for each font that differs, then a summary. Exit 0 if
# every font is identical, 1 if any differs, 2 on a usage error.

if [ $# -lt 3 ]; then
    echo "usage: sh scripts/flf-corpus.sh OLD_BNRMR NEW_BNRMR DIR..." >&2
    exit 2
fi
OLD=$1
NEW=$2
shift 2
for b in "$OLD" "$NEW"; do
    if [ ! -x "$b" ]; then echo "flf-corpus: not executable: $b" >&2; exit 2; fi
done
for d in "$@"; do
    if [ ! -d "$d" ]; then echo "flf-corpus: not a directory: $d" >&2; exit 2; fi
done

T=$(mktemp -d "${TMPDIR:-/tmp}/flf-corpus.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT INT TERM

ALL=$(awk 'BEGIN { for (i = 32; i < 127; i++) printf "%c", i }')

find "$@" -type f -name '*.flf' | LC_ALL=C sort > "$T/list"

# run BIN TAG FONT ARGS... : stdout, stderr and status into $T/TAG.*
run() {
    bin=$1; tag=$2; font=$3
    shift 3
    "$bin" --font "$font" "$@" > "$T/$tag.out" 2> "$T/$tag.err"
    echo $? > "$T/$tag.rc"
}

# same TAG : 0 if the old and new runs of TAG match on all three
same() {
    cmp -s "$T/old-$1.out" "$T/new-$1.out" &&
        cmp -s "$T/old-$1.err" "$T/new-$1.err" &&
        cmp -s "$T/old-$1.rc" "$T/new-$1.rc"
}

fonts=0
loaded=0
identical=0
differ=0
while IFS= read -r font; do
    fonts=$((fonts + 1))
    for side in old new; do
        bin=$OLD
        [ "$side" = new ] && bin=$NEW
        run "$bin" "$side-all" "$font" -- "$ALL"
        run "$bin" "$side-right" "$font" --width 100 --align right -- "Hello, World"
        run "$bin" "$side-center" "$font" --width 500 --align center -- "$ALL"
    done
    [ "$(cat "$T/new-all.rc")" = 0 ] && loaded=$((loaded + 1))
    bad=""
    for tag in all right center; do
        same "$tag" || bad="$bad $tag"
    done
    if [ -z "$bad" ]; then
        identical=$((identical + 1))
    else
        differ=$((differ + 1))
        echo "DIFFER $font:$bad"
    fi
done < "$T/list"

echo "flf-corpus: $fonts fonts ($loaded load), $identical identical, $differ differ"
[ "$differ" -eq 0 ] || exit 1
exit 0
