# Issue 0010 — the fuzz harness verifies nothing and reports green

**Reported**: 2026-08-25
**Version**: 1.1.4 (deferred-work sweep)
**Reporter**: maintainer
**Status**: **open**
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
