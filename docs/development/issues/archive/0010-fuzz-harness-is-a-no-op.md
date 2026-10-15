# Issue 0010 — the fuzz harness verifies nothing and reports green

**Reported**: 2026-08-25
**Version**: 1.1.4 (deferred-work sweep)
**Reporter**: maintainer
**Status**: **fixed in 1.4.1** (2026-10-15)
**Severity**: process / false assurance

## Observation

`tests/bannermanor.fcyr` in full:

```
fn fuzz_main(data, len) {
    if (len == 0) { return 0; }
    return 0;
}
fn main() {
    alloc_init();
    fuzz_main("test", 4);
    println("fuzz: ok");
    return 0;
}
```

It `include`s nothing from `src/`, calls no parser, and returns 0
unconditionally. `cyrius fuzz` therefore prints `1 passed, 0 failed`
regardless of the state of the font parsers.

## Why it matters

`cyrius fuzz` green was cited as release evidence in the shipped 1.1.3
and 1.1.4 CHANGELOG entries. Those citations have been struck. A gate
that cannot fail is worse than no gate: it consumes the attention a real
one would have earned.

The 0.7.0 audit already carried "write a fuzzer" as future work, and the
2026-08-25 audit carried it forward again. Both times it was recorded as
a discovery tool. Scope it honestly instead: a **regression gate** over
the malformed inputs already known to matter.

## What it should do

Drive the three real entry points with mutated input:
`font_load_file`, `flf_load_file`, `font_header_load`.

Seed corpus is already in the tree — `tests/fixtures/` has 12 files
covering bad schema, wrong row count, bad body byte, truncated `.flf`,
bad magic, CRLF endmarks, ESC in glyph rows, C1 hardblank. Mutate those
rather than starting from random bytes.

Properties to assert, none of which need a crash oracle:
- no invocation writes a control byte to stdout (the F-001/F-011 class)
- every rejection returns 0 and exits 1; no partial render
- no read outside the declared buffer bounds
- termination — no input causes an unbounded loop

## Acceptance

- `cyrius fuzz` fails when a deliberately-broken parser is introduced.
- The harness is wired into CI alongside the other gates.
- CHANGELOG may cite it again only once the above holds.

## Fix (shipped 1.4.1)

`tests/bannermanor.fcyr` is now a real harness. Each font reader was
split at 1.4.1 into a read (`_slurp`) and a parse half (`_font_parse`,
`_font_header_parse`, `_flf_parse`), so the harness drives the parsers
directly, in memory:

- **Seeds**: every non-empty fixture in `tests/fixtures/` (22 of 24), the three
  in-tree fonts and `modular.flf`. That is 26 seeds; the two empty
  fixtures are covered by a direct empty-input run.
- **Mutants**: 1,000 per seed, each one to four edits (overwrite, an
  "interesting" byte, insert, delete, truncate, duplicate a span, swap a
  digit run for a boundary number such as 64/65 or 1024/1025). A fixed
  xorshift seed makes every run identical.
- **Every mutant through all three parsers**: 78,003 parses per run, in
  about 2 s.
- **Oracles**: geometry within schema 1 or the `.flf` envelope; a
  charmap that points at real glyphs; no control byte in any `.flf`
  glyph row (F-001); only `' '` and `'#'` in a CYML row; header strings
  NUL-terminated within their buffers and free of control bytes (F-011).
  Every mutant is placed so it ends exactly at a `PROT_NONE` page, so a
  read one byte past the input faults.
- **Self-checks**: the oracle must flag a deliberately bad font before
  the run counts, and at least 5% of mutants must load, so that the font
  checks actually run. A typical run loads about 4,600 fonts and 5,600 headers.

## Acceptance

- "`cyrius fuzz` fails when a deliberately-broken parser is introduced":
  **verified three ways**. With the C1 arm of the `.flf` scrub removed,
  it reports `.flf row carries a control byte (F-001)`, naming the seed
  and iteration. With `_flf_eol` reading one byte past the input
  (`i <= len`), the guard page faults and the harness fails. With the
  F-011 scrub dropped from header strings, it reports `header string
  carries a control byte (F-011)`.
- Wired into CI: **yes**, the `Fuzz` step in `.github/workflows/ci.yml`.
- "CHANGELOG may cite it again only once the above holds": it holds from
  1.4.1.

## Still not a discovery tool

It found nothing new at 1.4.1, as expected for a regression gate. Its job
is to fail loudly when one of the properties above regresses. Each of
those properties was learned the hard way, by an audit, not by fuzzing.
