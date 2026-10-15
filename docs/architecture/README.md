# Architecture notes

Non-obvious constraints, quirks, and invariants that a reader cannot derive from the code alone. Numbered chronologically — never renumber.

Not decisions (those live in [`../adr/`](../adr/)) and not guides (those live in [`../guides/`](../guides/)). An item here describes *how the world is*, not *what we chose* or *how to do something*.

## Items

| # | Note | In short |
|---|---|---|
| [001](001-no-raw-syscall-numbers.md) | No raw syscall numbers in `src/` | The stdout writes were portable by a three-way coincidence; the font readers used the same pattern and were broken on AGNOS for four releases. |
| [002](002-cyrius-restores-lib-from-the-lock.md) | `cyrius build` / `bench` restore `lib/` from the lock | Swapping a file in `lib/` to A/B a dependency silently measures the locked version twice. |
| [003](003-aarch64-size-moves-in-64k-steps.md) | The aarch64 binary's size moves in 64 KiB steps | Its data segment starts on a 64 KiB file boundary, so 1.5.0's +66 KB was 6.4 KB of code and 63 KB of padding. |

Add the next as `004-kebab-case-title.md`.
