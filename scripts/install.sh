#!/bin/sh
# install.sh — install bnrmr, its fonts and its man page under a prefix.
#
# Usage:
#   cyrius build src/main.cyr build/bnrmr
#   sh scripts/install.sh [PREFIX]          default PREFIX: /usr/local
#   DESTDIR=/tmp/stage sh scripts/install.sh /usr      (packaging)
#
# Lays out:
#   PREFIX/bin/bnrmr
#   PREFIX/share/bannermanor/fonts/*.cyml
#   PREFIX/share/man/man1/bnrmr.1
#
# That layout is what bnrmr's font search path expects (ADR 0003): an
# executable at PREFIX/bin/bnrmr looks for fonts in
# PREFIX/share/bannermanor/fonts, so `bnrmr -f slim` works from any
# directory with no configuration, whatever PREFIX is. The release
# tarball is this script run with an empty prefix into a staging
# directory, so an unpacked tarball works the same way.
#
# Installs only what is in the tree; it does not build. It refuses to
# install a binary whose --version disagrees with VERSION, so a stale
# build/bnrmr cannot be installed by mistake.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "install.sh: $*" >&2; exit 1; }

PREFIX="${1:-${PREFIX:-/usr/local}}"
DESTDIR="${DESTDIR:-}"
BIN="${BNRMR:-build/bnrmr}"

[ -x "$BIN" ] || die "no executable at $BIN — run: cyrius build src/main.cyr build/bnrmr"
want="bnrmr $(tr -d '[:space:]' < VERSION)"
# A cross-built binary cannot run here; BNRMR_NO_RUN=1 skips the check.
if [ "${BNRMR_NO_RUN:-0}" != 1 ]; then
    got="$("$BIN" --version)" || die "$BIN --version failed"
    [ "$got" = "$want" ] || die "$BIN says '$got', VERSION says '$want' — rebuild first"
fi
ls fonts/*.cyml > /dev/null 2>&1 || die "no fonts/*.cyml in $ROOT"
[ -f man/bnrmr.1 ] || die "no man/bnrmr.1 in $ROOT"

D="$DESTDIR$PREFIX"
mkdir -p "$D/bin" "$D/share/bannermanor/fonts" "$D/share/man/man1"
cp "$BIN" "$D/bin/bnrmr"
chmod 0755 "$D/bin/bnrmr"
for f in fonts/*.cyml; do
    cp "$f" "$D/share/bannermanor/fonts/"
    chmod 0644 "$D/share/bannermanor/fonts/$(basename "$f")"
done
cp man/bnrmr.1 "$D/share/man/man1/bnrmr.1"
chmod 0644 "$D/share/man/man1/bnrmr.1"

echo "install.sh: installed $want under $D"
echo "    $D/bin/bnrmr"
echo "    $D/share/bannermanor/fonts/ ($(ls fonts/*.cyml | wc -l | tr -d ' ') fonts)"
echo "    $D/share/man/man1/bnrmr.1"
