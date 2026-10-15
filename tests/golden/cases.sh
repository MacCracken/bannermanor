# tests/golden/cases.sh — the golden suite's case list. Sourced by
# scripts/golden.sh, which defines `g`:
#
#   g <tier> <id> [pty=RxC] [cwd=DIR] [env=NAME=VAL]... [norm=version] -- <args>
#
# Tiers (see scripts/golden.sh): frozen = valid renders, whose bytes v1.0
# froze; error = invalid invocations, whose exit codes are frozen and whose
# streams ADR 0002 rules on; snapshot = --version / --help / --list-fonts,
# which move on purpose. Ids are unique and stable: a record is keyed by its
# id in review diffs, so rename one only on purpose.
#
# Adding a case changes its tier's .golden file — run
# `sh scripts/golden.sh --update` and commit both. POSIX sh only (CI runs
# this under dash): no $'...', no arrays, no `local`.

# ── Inputs ───────────────────────────────────────────────────────────────────

# Printable ASCII, 0x20..0x7E, as one argument.
PRINT="$(i=32; while [ $i -le 126 ]; do printf "\\$(printf '%03o' $i)"; i=$((i + 1)); done)"
PUNCT=' !"#$%&()*+,-./:;<=>?@[\]^_`{|}~'"'"
CTL="$(printf 'A\033[31mB\001C\177D')"          # ESC, SOH, DEL: blank cells
CAFE="$(printf 'Caf\303\251')"                   # UTF-8: two blank cells for one char
A512="$(printf '%0512d' 0 | tr 0 A)"
A511="$(printf '%0511d' 0 | tr 0 A)"
A1024="$(printf '%01024d' 0 | tr 0 A)"
A1025="$(printf '%01025d' 0 | tr 0 A)"
N64="$(printf '%064d' 0 | tr 0 n)"
N65="$(printf '%065d' 0 | tr 0 n)"
W200=""; _i=0; while [ $_i -lt 200 ]; do W200="$W200 x"; _i=$((_i + 1)); done
W255=""; _i=0; while [ $_i -lt 255 ]; do W255="$W255 x"; _i=$((_i + 1)); done
W256=""; _i=0; while [ $_i -lt 256 ]; do W256="$W256 x"; _i=$((_i + 1)); done
MIXED=tests/golden/cwd/mixed
EMPTY=tests/golden/cwd/empty
ENVF=tests/golden/cwd/envfonts
ESCDIR="$(printf 'a\033b')"                      # a BNRMR_FONTS value with an ESC in it

# ── frozen: default font ─────────────────────────────────────────────────────
g frozen default-agnos -- AGNOS
g frozen default-lower-folds -- "hello world"
g frozen default-mixed-case -- "Welcome home"
g frozen default-printable -- "$PRINT"
g frozen default-punct -- "$PUNCT"
g frozen default-digits -- 0123456789
g frozen default-two-args -- HELLO WORLD
g frozen default-space-only -- " "
g frozen default-control-bytes -- "$CTL"
g frozen default-non-ascii -- "$CAFE"
g frozen default-leading-dash -- -- -HI
g frozen default-dashdash-version -- -- --version
g frozen default-lone-dash -- - HI
g frozen default-flags-after-text -- HI --font slim
g frozen default-repeat-flag-last-wins -- --font slim --font big HI

# ── frozen: the three in-tree fonts ──────────────────────────────────────────
g frozen block-printable -- -f block "$PRINT"
g frozen block-agnos-equals-embedded -- --font block AGNOS
g frozen slim-printable -- --font slim "$PRINT"
g frozen slim-agnos -- --font slim AGNOS
g frozen slim-lower -- --font=slim welcome
g frozen big-printable -- --font=big "$PRINT"
g frozen big-agnos -- -f big AGNOS
g frozen big-lower -- --font big welcome

# ── frozen: the .flf adapter ─────────────────────────────────────────────────
g frozen flf-tiny-printable -- --font tests/fixtures/tiny.flf "$PRINT"
g frozen flf-tiny-hello -- --font tests/fixtures/tiny.flf HELLO
g frozen flf-dotslash -- --font ./tests/fixtures/tiny.flf HI
g frozen flf-crlf-printable -- --font tests/fixtures/flf_crlf.flf "$PRINT"
g frozen flf-esc-glyph-scrubbed -- --font tests/fixtures/flf_esc_glyph.flf "A B"
g frozen flf-c1-hardblank -- --font tests/fixtures/flf_c1_hardblank.flf "$PRINT"
g frozen flf-modular -- --font modular.flf BNRMR
g frozen flf-modular-printable -- --font modular.flf "$PRINT"
g frozen flf-modular-lower -- --font modular.flf bnrmr

# ── frozen: fonts from another CWD ───────────────────────────────────────────
g frozen cwd-tiny cwd=$MIXED -- --font tiny HI
g frozen cwd-noname-renders cwd=$MIXED -- --font noname HI
g frozen cwd-stem-mismatch-loads-by-stem cwd=$MIXED -- --font stem_mismatch HI
g frozen cwd-longname-renders cwd=$MIXED -- --font longname HI
g frozen cwd-longdesc-renders cwd=$MIXED -- --font longdesc HI
g frozen cwd-ctl-header-renders cwd=$MIXED -- --font ctl_header "A A"
g frozen cwd-default-font-anywhere cwd=$EMPTY -- AGNOS

# ── frozen: the font search path (ADR 0003, 1.6.0) ───────────────────────────
# block is built in, so -f block works with no fonts/ anywhere.
g frozen path-block-builtin-anywhere cwd=$EMPTY -- --font block HI
g frozen path-block-builtin-equals-embedded cwd=$EMPTY -- -f block AGNOS
# $BNRMR_FONTS comes first, and shadows ./fonts.
g frozen path-env-shadows-cwd env=BNRMR_FONTS=$ENVF -- --font block HI
g frozen path-env-adds-a-dir env=BNRMR_FONTS=$MIXED/fonts -- --font tiny HI
g frozen path-env-falls-through-to-cwd env=BNRMR_FONTS=$ENVF -- --font slim HI
g frozen path-env-missing-dir-is-a-miss env=BNRMR_FONTS=no/such/dir -- --font slim HI
g frozen path-env-empty-is-unset env=BNRMR_FONTS= -- --font slim HI
# An install: <prefix>/bin/bnrmr finds <prefix>/share/bannermanor/fonts.
g frozen path-install-slim install cwd=$EMPTY -- --font slim HI
g frozen path-install-big install cwd=$EMPTY -- -f big AGNOS
g frozen path-install-cwd-first install cwd=$MIXED -- --font tiny HI
g frozen path-install-env-first install cwd=$EMPTY env=BNRMR_FONTS=../envfonts -- --font block HI
g frozen path-install-pty install pty=24x80 cwd=$EMPTY -- --font big --color rainbow HI

# ── frozen: --align (pipe: no terminal width, so COLUMNS or 80) ──────────────
g frozen align-left -- --align left HI
g frozen align-L -- --align L HI
g frozen align-center -- --align center HI
g frozen align-centre -- --align centre HI
g frozen align-C -- --align C HI
g frozen align-right -- --align right HI
g frozen align-R -- --align R HI
g frozen align-equals-form -- --align=center HI
g frozen align-center-columns-100 env=COLUMNS=100 -- --align center HI
g frozen align-right-columns-40 env=COLUMNS=40 -- --align right HI
g frozen align-right-columns-5000-clamped env=COLUMNS=5000 -- --align right A
g frozen align-right-columns-junk env=COLUMNS=abc -- --align right HI
g frozen align-right-columns-0 env=COLUMNS=0 -- --align right HI
g frozen align-right-columns-past-int-cap env=COLUMNS=1048577 -- --align right HI
g frozen align-left-ignores-columns env=COLUMNS=20 -- HELLOWORLD
g frozen align-center-wider-than-frame -- --align center "THE QUICK BROWN FOX"
g frozen align-right-slim -- --font slim --align right HI
g frozen align-center-flf -- --font tests/fixtures/tiny.flf --align center HELLO

# ── frozen: --width ──────────────────────────────────────────────────────────
g frozen width-0 -- --width 0 AGNOS
g frozen width-1-sub-glyph -- --width 1 AGNOS
g frozen width-4-sub-glyph -- --width 4 AGNOS
g frozen width-5 -- --width 5 AGNOS
g frozen width-10 -- --width 10 AGNOS
g frozen width-11 -- --width 11 AGNOS
g frozen width-short-17 -- -w 17 AGNOS
g frozen width-20-center -- --width 20 --align center AGNOSTIC
g frozen width-20-right -- --width 20 --align right AGNOSTIC
g frozen width-equals-23 -- --width=23 AGNOSTIC
g frozen width-4096 -- --width 4096 AGNOS
g frozen width-4096-right -- --width 4096 --align right A
g frozen width-leading-zeros -- --width 007 AGNOS
g frozen width-minus-zero -- --width -0 AGNOS
g frozen width-minus-double-zero -- --width -00 AGNOS
g frozen width-slim-17 -- -f slim -w 17 AGNOS
g frozen width-big-15 -- -f big -w 15 AGNOS
g frozen width-flf-30 -- --font modular.flf --width 30 BNRMR
g frozen width-beats-columns env=COLUMNS=20 -- --width 40 --align right HI
g frozen width-sub-glyph-pad-color -- --width 1 --pad 1 --color red HI

# ── frozen: --pad ────────────────────────────────────────────────────────────
g frozen pad-0 -- --pad 0 HI
g frozen pad-1 -- --pad 1 HI
g frozen pad-2 -- --pad 2 HI
g frozen pad-64 -- --pad 64 HI
g frozen pad-equals-3 -- --pad=3 HI
g frozen pad-leading-zeros -- --pad 007 HI
g frozen pad-minus-zero -- --pad -0 HI

# ── frozen: --color on a pipe (suppressed: plain bytes) ──────────────────────
g frozen color-pipe-red -- --color red HI
g frozen color-pipe-bright-underscore -- --color bright_red HI
g frozen color-pipe-bright-dash -- --color bright-red HI
g frozen color-pipe-rainbow -- --color rainbow HI
g frozen color-pipe-black -- --color black HI
g frozen color-pipe-empty-equals -- --color= HI
g frozen color-pipe-empty-arg -- --color "" HI

# ── frozen: combinations ─────────────────────────────────────────────────────
g frozen combo-center-width-pad-color -- --align center --width 40 --pad 1 --color cyan WELCOME
g frozen combo-big-right-rainbow -- --font big --align right --width 60 --pad 2 --color rainbow HI
g frozen combo-flf-center-pad -- --font tests/fixtures/tiny.flf --align center --pad 1 HELLO

# ── frozen: positionals and the 1 KB cap ─────────────────────────────────────
# shellcheck disable=SC2086
g frozen positionals-200-past-128 -- $W200
# shellcheck disable=SC2086
g frozen positionals-255-at-argc-cap -- $W255
g frozen input-1024-one-arg -- --width 11 "$A1024"
g frozen input-1024-joined -- --width 11 "$A512" "$A511"

# ── frozen: parser grammar, pinned before the cmdit swap (1.4.2) ─────────────
# Recorded against the stdlib flags parser; the cmdit build must match.
g frozen parse-repeat-width-last-wins -- --width 5 --width 23 AGNOSTIC
g frozen parse-repeat-align-last-wins -- --align right --align left HI
g frozen parse-repeat-pad-mixed-forms -- --pad=1 --pad 2 HI
g frozen parse-dashdash-then-dashdash -- -- -- HI
g frozen parse-dashdash-alone-then-dashdash -- -- --
g frozen parse-flag-after-dashdash-is-text -- --color red -- --color HI
g frozen parse-text-then-dashdash -- HI -- --pad 3

# ── frozen: pty leg ──────────────────────────────────────────────────────────
# Twelve renders at each of seven window sizes. 0 columns is "not a terminal"
# (F-020): no SGR, no truncation. Columns clamp at 4096 (F-008).
for _sz in 24x80 24x40 24x11 24x1 24x0 0x0 50x5000; do
    g frozen "pty-$_sz-agnos" pty=$_sz -- AGNOS
    g frozen "pty-$_sz-red" pty=$_sz -- --color red AGNOS
    g frozen "pty-$_sz-rainbow-big" pty=$_sz -- --color rainbow --font big AGNOS
    g frozen "pty-$_sz-center" pty=$_sz -- --align center HI
    g frozen "pty-$_sz-right-cyan" pty=$_sz -- --align right --color cyan HI
    g frozen "pty-$_sz-width-20-center" pty=$_sz -- --width 20 --align center AGNOSTIC
    g frozen "pty-$_sz-pad-green" pty=$_sz -- --pad 1 --color green HI
    g frozen "pty-$_sz-slim-mixed" pty=$_sz -- --font slim "Welcome home"
    g frozen "pty-$_sz-flf-yellow" pty=$_sz -- --font tests/fixtures/tiny.flf --color yellow HELLO
    g frozen "pty-$_sz-centre-pad-2" pty=$_sz -- --align centre --pad 2 X
    g frozen "pty-$_sz-long-text" pty=$_sz -- "THE QUICK BROWN FOX"
    g frozen "pty-$_sz-explicit-width-right" pty=$_sz -- --width 4096 --align right --color blue A
done
# Every --color spelling on a real terminal.
for _c in rainbow black red green yellow blue magenta cyan white; do
    g frozen "pty-color-$_c" pty=24x80 -- --color "$_c" HI
done
for _c in black red green yellow blue magenta cyan white; do
    g frozen "pty-color-bright_$_c" pty=24x80 -- --color "bright_$_c" HI
    g frozen "pty-color-bright-$_c" pty=24x80 -- --color "bright-$_c" HI
done
g frozen pty-color-empty pty=24x80 -- --color= HI
# COLUMNS is read only when the terminal reports no width.
g frozen pty-24x80-ignores-columns pty=24x80 env=COLUMNS=40 -- --align right HI
g frozen pty-24x0-uses-columns pty=24x0 env=COLUMNS=40 -- --align right HI

# ── error ────────────────────────────────────────────────────────────────────
g error font-missing -- --font typo HI
g error font-slash -- --font ../fonts/block HI
g error font-dot -- --font a.b HI
g error font-backslash -- --font 'a\b' HI
g error font-control-byte -- --font "$(printf 'a\033b')" HI
g error font-name-65 -- --font "$N65" HI
g error font-name-64-missing -- --font "$N64" HI
g error font-empty-arg -- --font "" HI
g error font-empty-equals -- --font= HI
g error font-bare-flf-suffix -- --font .flf HI
g error flf-missing -- --font nope.flf HI
g error flf-bad-magic -- --font tests/fixtures/flf_bad_magic.flf HI
g error flf-bad-height -- --font tests/fixtures/flf_bad_height.flf HI
g error flf-truncated -- --font tests/fixtures/flf_truncated.flf HI
g error flf-space-hardblank -- --font tests/fixtures/flf_space_hardblank.flf HI
g error flf-directory cwd=$MIXED -- --font dir.flf HI
g error cyml-bad-schema cwd=$MIXED -- --font bad_schema HI
g error cyml-bad-body-byte cwd=$MIXED -- --font bad_body_byte HI
g error cyml-wrong-row-count cwd=$MIXED -- --font wrong_row_count HI
g error cyml-zero-entries cwd=$MIXED -- --font zero_entries HI
g error cyml-width-0 cwd=$MIXED -- --font width0 HI
g error cyml-listed-name-not-stem cwd=$MIXED -- --font other HI
g error cyml-nested-unreachable cwd=$MIXED -- --font pack/nested HI
g error cyml-not-found-anywhere cwd=$EMPTY -- --font slim HI
g error path-malformed-first-match-wins install cwd=$MIXED -- --font bad_schema HI
g error path-not-found-names-dirs install cwd=$EMPTY -- --font nosuch HI
g error path-env-not-found env=BNRMR_FONTS=$ENVF cwd=$EMPTY -- --font slim HI
g error path-env-control-byte env=BNRMR_FONTS=$ESCDIR -- --font slim HI
g error align-unknown -- --align x HI
g error align-uppercase-word -- --align LEFT HI
g error align-empty -- --align "" HI
g error width-alpha -- --width abc HI
g error width-empty -- --width "" HI
g error width-negative -- --width -5 HI
g error width-4097 -- --width 4097 HI
g error width-past-int-cap -- --width 1048577 HI
g error width-u64-wrap -- --width 18446744073709551620 HI
g error width-plus-sign -- --width +5 HI
g error width-leading-space -- --width " 5" HI
g error pad-65 -- --pad 65 HI
g error pad-negative -- --pad -1 HI
g error pad-alpha -- --pad x HI
g error pad-u64-wrap -- --pad 18446744073709551617 HI
g error color-unknown -- --color purple HI
g error color-no-separator -- --color brightred HI
g error color-uppercase -- --color CYAN HI
g error color-two-words -- --color "bright red" HI
g error parse-unknown-long -- --bogus HI
g error parse-unknown-short -- -x HI
g error parse-wrong-case -- --Font slim HI
g error parse-triple-dash -- ---font slim HI
g error parse-missing-value -- --font
g error parse-missing-value-after-text -- HI --width
g error parse-bundled -- -hf HI
g error parse-short-equals -- -w=11 AG
g error parse-bool-with-value -- --list-fonts=0
g error parse-help-with-value -- --help=1
g error parse-capital-v-is-not-version -- -V
g error parse-capital-v-with-text -- -V HI
g error parse-version-with-value -- --version=1
g error parse-error-beats-help -- --help --bogus
g error parse-error-beats-help-after -- --bogus --help
g error parse-error-beats-version -- --version --bogus
g error parse-bundled-same-letter -- -hh
g error parse-attached-short-value -- -w5 AGNOS
g error parse-short-equals-font -- -f=slim HI
g error parse-no-british-spelling -- --colour red HI
g error parse-no-prefix-match-value -- --col red HI
g error parse-no-prefix-match-help -- --he
g error parse-no-prefix-match-bool -- --list
g error parse-empty-long-name -- --=x HI
g error parse-short-missing-value -- -w
g error parse-uppercase-long -- --WIDTH 5 HI
g error parse-value-is-flag-shaped -- --font --list-fonts HI
g error parse-short-value-is-flag-shaped -- -f -h HI
g error order-align-before-width -- --align x --width abc HI
g error order-width-before-font -- --font typo --width abc HI
# shellcheck disable=SC2086
g error positionals-256-too-many -- $W256
g error input-1025-one-arg -- "$A1025"
g error input-1025-joined -- "$A512" "$A512"

# ── snapshot ─────────────────────────────────────────────────────────────────
g snapshot bare --
g snapshot help -- --help
g snapshot help-short -- -h
g snapshot help-short-with-text -- -h HI
g snapshot help-beats-version -- --version --help
g snapshot help-beats-bad-align -- --help --align x
g snapshot version norm=version -- --version
g snapshot version-with-text norm=version -- --version HI
g snapshot empty-text -- ""
g snapshot font-without-text -- -f block
g snapshot flags-without-text -- --align center --pad 2
g snapshot color-equals-alone -- --color=
g snapshot list-fonts -- --list-fonts
g snapshot list-fonts-with-text -- --list-fonts HI
g snapshot list-fonts-beats-bad-align -- --list-fonts --align x
g snapshot list-fonts-empty-cwd cwd=$EMPTY -- --list-fonts
g snapshot list-fonts-mixed-cwd cwd=$MIXED -- --list-fonts
g snapshot help-repeated-short -- -h -h
g snapshot help-repeated-long -- --help --help
g snapshot list-fonts-repeated -- --list-fonts --list-fonts
g snapshot version-repeated norm=version -- --version --version
g snapshot dashdash-alone -- --
g snapshot help-beats-list-fonts -- --list-fonts --help
g snapshot help-beats-list-fonts-before -- --help --list-fonts
g snapshot version-beats-list-fonts norm=version -- --version --list-fonts
g snapshot list-fonts-install install cwd=$EMPTY -- --list-fonts
g snapshot list-fonts-install-under-checkout install -- --list-fonts
g snapshot list-fonts-env env=BNRMR_FONTS=$ENVF -- --list-fonts
g snapshot list-fonts-env-missing env=BNRMR_FONTS=no/such/dir cwd=$EMPTY -- --list-fonts
g snapshot list-fonts-bad-env env=BNRMR_FONTS=$ESCDIR -- --list-fonts
