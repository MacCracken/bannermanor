# Issues

Defects and deferred work with a written-up reproducer, kept in-tree so they
version with the code. Open issues live here. Closed ones move to
[`archive/`](archive/).

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits.
  **Numbers are never reused or renumbered**, including when an issue is
  archived, abandoned or found to be a duplicate. A number named anywhere
  (a CHANGELOG entry, an audit, the roadmap, a code comment) must keep
  meaning the same thing.
- **Take the next number** after the highest one used anywhere, open or
  archived. Do not cite a number before its file exists. The 1.1.4 audit
  cited issue numbers ahead of filing, then the files were numbered
  differently, and five citations ended up wrong. Its errata blocks record
  the corrections.
- **Header fields**: `Reported` (date, and the finding ID if it came from
  an audit), `Version` (where it was observed), `Reporter`, `Status`,
  `Severity`. Then `Observation`, then whatever the fix needs: why it
  matters, why it is gated, the shape of the fix, `Acceptance`.
- **Status lifecycle**: **open** (optionally "gated on …" or "scheduled
  for …"), then **fixed in X.Y.Z** or **closed — won't fix** (with the
  reason), then move the file to `archive/`. An issue fixed by a toolchain
  or dependency bump rather than by a bnrmr change says so in its status.
- **Archive, don't delete.** The file is the record of what was wrong and
  how it was established.

## Register

The live register, with each issue's target release, is the
[roadmap](../roadmap.md#issue-register).
