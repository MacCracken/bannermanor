# 003 — The aarch64 binary's size moves in 64 KiB steps

**Fact**: the size of `build/bnrmr-aarch64` says little about how much code
changed. Its data segment starts at a file offset that is a multiple of
64 KiB, so whatever lies between the end of the code and the next 64 KiB
boundary is zero padding. When the code grows past a boundary, the file
grows by up to 64 KiB at once.

## Why it is not obvious

The x86_64 and AGNOS binaries align the same way to 4 KiB, so their sizes
track code growth to within a page. At 1.5.0 the three moved like this:

| target | 1.4.2 | 1.5.0 | change |
|---|---|---|---|
| x86_64 | 292,008 | 296,552 | +4,544 |
| AGNOS | 304,088 | 308,624 | +4,536 |
| aarch64 | 341,064 | 407,048 | **+65,984** |

The 1.5.0 notes recorded the aarch64 jump as "out of line … not yet
investigated." The program headers explain it (`readelf -l -W`):

```
1.4.2  LOAD 0x000000 … filesz 0x04eb00  R E  align 0x10000
       LOAD 0x050000 … filesz 0x0032e8  RW   align 0x10000
1.5.0  LOAD 0x000000 … filesz 0x050428  R E  align 0x10000
       LOAD 0x060000 … filesz 0x0034a8  RW   align 0x10000
```

The code segment grew 6,440 bytes (0x4eb00 → 0x50428), about what x86_64
grew. That carried it past 0x50000, so the data segment moved from file
offset 0x50000 to 0x60000, behind 64,472 bytes of padding. At 1.8.0 the
code ends at 0x54578 and the padding is 47,752 bytes: 12% of the file.

## Where it comes from

cyrius's aarch64 ELF writer (`src/backend/aarch64/fixup.cyr`, the W^X
layout since v6.3.12) uses `p_align` 0x10000. It rounds the data
segment's **file offset** up to 64 KiB and gives it a 2 MiB-aligned
virtual address.

The padding is the price of segment-level W^X. Arm64 Linux runs with 4,
16 or 64 KiB pages, and the loader maps whole pages. Only a 64 KiB gap in
the file guarantees that no page holds both code mapped executable and
data mapped writable, on every one of them.

A linker that does not separate code from data avoids the padding: it
keeps the file offset unpadded and picks a congruent virtual address.
But that puts the first data bytes in the last executable page, which is
what W^X exists to prevent. So this is a cyrius layout trade-off, not a
bnrmr defect.

The padding costs disk and download bytes only; it is never mapped. A
one-line program is 65,888 bytes on aarch64, 4,448 on x86_64, and 520 on
aarch64 with `CYRIUS_WX=0`. Filed with cyrius at 1.8.1
(`docs/development/issues/2026-10-15-aarch64-wx-layout-pads-every-binary-to-64k.md`
there). That issue asks for the cost to be documented, and lays out a
narrower 16 KiB padding as an option with its W^X trade-off on 64 KiB-page
kernels.

## How to keep it in mind

- Judge aarch64 code growth by the code segment's `filesz`, not the file
  size: `readelf -l -W build/bnrmr-aarch64 | grep LOAD`.
- Expect the next step when the code segment passes 0x60000 (393,216
  bytes); it was 0x54578 (345,464) at 1.8.0.
