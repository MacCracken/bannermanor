# 0002 — What the v1.0 freeze covers: error paths, failed writes, malformed input

**Status**: Accepted
**Date**: 2026-10-15 (proposed and accepted the same day, as written)

> Accepted by the maintainer on 2026-10-15, with no changes to the
> proposal. That unblocks the items it gated, all now scheduled for
> roadmap 1.5.0: diagnostics on stderr (issue 0016), checked writes
> (issue 0009), the CYML body-consumption fix (issue 0008), and the `.flf`
> geometry ceilings. Accepting it decides what 1.x may change. It does not
> make any of those changes; each lands with its own CHANGELOG entry and,
> where it moves bytes, a deliberate golden re-baseline.

## Context

The 1.0.0 CHANGELOG froze bnrmr's contract in one sentence:

> No flags added, no flags removed, no exit-code or stdout-byte changes
> **for any valid invocation**.

It also froze CYML schema 1 (ADR 0001), the default font set ("presence is
additive, never subtractive"), and the `.flf` adapter contract ("bug fixes
… are non-breaking; the documented limitations in CHANGELOG 0.6.0 are
intentional and stay").

"Valid invocation" was never defined. Three readings matter, because six
roadmap items depend on them and each can be read either way.

1. **Error-path output.** Every diagnostic goes to fd 1: about twenty
   `println` sites in `src/main.cyr`, and `2>/dev/null` hides none of
   them. `bnrmr --font typo "$HOST" > /etc/motd` writes the error into the
   MOTD (issue 0016). Is the stdout of an *invalid* invocation frozen?
   1.1.4 already changed `--help` stdout bytes in a patch release, noting
   that "no test asserts them". That is a precedent for treating help and
   diagnostic text as correctable, but not a ruling.
2. **Error-path exit codes.** `bnrmr "hi" > /dev/full` exits 0 having
   written nothing (issue 0009). Is that exit status frozen behavior or a
   defect?
3. **Already-malformed input.** Tightening a parser rejects files that
   load today. A CYML glyph body with surplus rows loads, and the surplus
   is silently ignored (issue 0008). Does the freeze protect a font that
   violates the format's own documented rules? The converse question is
   whether bnrmr may *admit* input it rejects today only by its own limit,
   such as `.flf` fonts wider than 64 columns, which the FIGfont spec
   allows.

Since 1.4.1 the contract has a mechanical check: `scripts/golden.sh` runs
285 invocations in three tiers. **frozen** holds valid renders, **error**
holds invalid invocations, and **snapshot** holds `--version`, `--help` and
`--list-fonts`. Each ruling below says what may move in which tier.

## Decision

**An invocation is valid when it exits 0, its output is fully written, and
its inputs conform to the contracts documented at v1.0: the CLI flag
surface, CYML schema 1 as ADR 0001 states it, and the `.flf` adapter
contract.** The freeze protects valid invocations. Everything else is
correctable in a 1.x minor under the rules below. No exception is needed
for the shipped fonts: they are covered by the golden frozen tier, and
nothing here may move one of their bytes.

### Ruling 1 — diagnostic output is not frozen

The bytes an invocation writes when it exits nonzero, on either stream,
are not part of the freeze. That covers the error line and the usage block
printed after it. They may change in a 1.x **minor**, under `Changed`,
with the golden **error** tier re-baselined in the same commit and the
diff reviewed record by record.

- Moving diagnostics to fd 2 (issue 0016) is permitted.
- `--help` and `--version` *on request* are successful invocations whose
  output is documentation, not banner bytes. That is the **snapshot**
  tier: correctable in any release and recorded in the CHANGELOG, as
  1.1.4 did. They stay on stdout. Moving a requested `--help` to stderr
  would break `bnrmr --help | less`.
- The usage block printed after an error follows the error to fd 2.
- What stays frozen on an error path is the **exit code**: an invocation
  that exits 1 today keeps exiting 1 (see ruling 2).

### Ruling 2 — exit codes: success is frozen, a failed write is a defect

- **Exit 0 on a valid invocation is frozen.** No 1.x release may make a
  valid invocation fail. This is why `--color=` keeps meaning "no color"
  (A-06), and why a sub-glyph `--width` keeps rendering blank rows (A-05):
  both are valid today.
- **Exit 1 on an invalid invocation is frozen, with one exception.** A
  change may make a failing invocation succeed only when it is
  additive and does not widen the CLI surface. The freeze's own example is
  a new font: "presence is additive". Admitting more fonts qualifies. New
  flags, new spellings of a flag value (`--color brightred`), and looser
  value grammar (`--width +5`) do not: they widen a frozen surface, so
  they wait for 2.0.
- **Exit 0 when the output was not written is a defect, not frozen.** An
  invocation whose bytes never reached fd 1 is not valid by the
  definition above. Making it exit nonzero (issue 0009) is a `Fixed`
  entry in a 1.x minor. The proposed code is 1, the same as every other
  failure. A retried partial write that completes is a success and is
  unchanged.

### Ruling 3 — malformed input is not protected; bnrmr's own limits may widen

- **A font that breaks a structural rule of its format is not
  protected.** Structural means a rule that decides which bytes are
  glyphs: geometry, row and column counts, the body byte set, `char`. A
  structural violation means bnrmr cannot know what the author meant, so
  today's render is a guess, not a contract. Enforcing a structural rule
  already documented in ADR 0001 (issue 0008: exactly `height` rows) or in
  the FIGfont v2 spec is a `Changed` entry in a 1.x minor, provided the
  golden frozen tier is byte-identical and every in-tree font still loads.
- **A metadata rule is not structural.** A font whose glyphs render
  unambiguously, but whose `name` differs from its file stem or which has
  no `name`, renders correctly. Rejecting it would make a valid invocation
  fail, which ruling 2 forbids. Enforcing `name` against the stem stays in
  "Beyond 1.x" (accepted risk A-11). ADR 0001's "must match the file stem"
  is a convention, and the 1.4.1 documentation pass says so.
- **Admitting input rejected only by a bnrmr limit is additive.** A `.flf`
  font wider than bnrmr's 64-column envelope is valid FIGfont. Raising
  that ceiling makes failing invocations succeed and moves no byte of any
  font that loads today. The roadmap's corpus measurement found 973 of 973
  loading fonts byte-identical with the ceiling widened. Permitted in a
  1.x minor. The CYML schema-1 caps (`width <= 64`, `height <= 32`,
  `gap <= 16`) are not "bnrmr limits" in this sense: they are part of
  schema 1, and they stay.

## Consequences

**Positive.**
- Issue 0016 (stderr), issue 0009 (checked writes), issue 0008 (body
  consumption) and the `.flf` ceilings each get a definite answer and a
  release they can land in. None is a 2.0 question.
- Every 1.x change gets a test it must pass: "does this make a valid
  invocation fail, or move one of its bytes?" The golden tiers make the
  test mechanical.
- The `name`-versus-stem contradiction in the 1.1.4 audit, which classed
  the change `Breaking` and scheduled it for a minor, is resolved: it is
  2.0.

**Negative.**
- Scripts that parse bnrmr's error text from stdout will break when issue
  0016 lands. bnrmr has no known consumer that does this. The documented
  consumers redirect stdout and check `$?`, which ruling 1 protects.
- "Structural" versus "metadata" is a judgment call that each future
  tightening has to make explicitly.
- Exit-code semantics now depend on I/O success. A caller writing to a
  device that reports errors on `close` but not on `write` will still see
  0.

**Neutral.**
- The golden error tier is expected to churn once, when issue 0016 lands,
  and rarely after that.
- The cmdit migration (roadmap) inherits ruling 1: its parse-error text
  may differ, but its exit codes may not.

## Alternatives considered

**Freeze everything bnrmr writes, error paths included.** This is the
literal reading of "stdout bytes", ignoring "valid". Rejected: it would
freeze the MOTD-corruption defect (issue 0016) for the rest of 1.x, and
1.1.4 has already broken it once without objection.

**Rule each case as it comes up.** Rejected: that is the status quo, and
the cost of it is six roadmap items parked with no release to land in.

**Treat every documented rule as structural, including `name`.** This
would allow stem enforcement in a minor. Rejected because ruling 2 forbids
failing a valid invocation, and a font whose glyphs render correctly is
valid, whatever its metadata says.

**Make failed writes exit with a distinct code (e.g. 74, `EX_IOERR`).**
More informative, but every other failure exits 1, and no caller is known
to distinguish codes. Left open for issue 0009's implementation; this ADR
requires only "nonzero".
