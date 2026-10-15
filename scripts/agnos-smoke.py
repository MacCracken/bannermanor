#!/usr/bin/env python3
# agnos-smoke.py — run bnrmr on a real AGNOS kernel in QEMU and check what
# only AGNOS can show (1.7.0).
#
# Usage:
#   cyrius build --agnos src/main.cyr build/bnrmr-agnos
#   cyrius build src/main.cyr build/bnrmr          (the host reference)
#   python3 scripts/agnos-smoke.py
#
# Manual, not CI: it needs an agnos kernel and rootfs built from the agnos
# repo, gnoboot's BOOTX64.EFI, OVMF, qemu-system-x86_64, parted, sgdisk,
# mtools and mkfs.ext2. Paths, all overridable:
#   AGNOS_KERNEL   ../agnos/build/agnos         (agnos >= 1.57.13 for fd_kind)
#   AGNOS_ROOTFS   ../agnos/build/rootfs        (needs bin/agnsh, bin/wc)
#   GNOBOOT_EFI    ../gnoboot/build/BOOTX64.EFI
#   BNRMR_AGNOS    build/bnrmr-agnos            (the binary under test)
#   BNRMR_HOST     build/bnrmr                  (renders the expected bytes)
#   BNRMR_EXPECT_VERSION   VERSION's contents   (for an older binary)
#
# It boots agnos with the rootfs plus this bnrmr at /bin/bnrmr and the
# in-tree fonts at /share/bannermanor/fonts (the layout scripts/install.sh
# gives an empty prefix), types commands at agnsh over QEMU's monitor, and
# reads the console back from the serial log. Nothing outside a temporary
# directory is written.
#
# What is checked, and why it needs AGNOS:
#   version      the binary runs at all (four releases shipped once with
#                every --font dying on AGNOS: architecture note 001)
#   console      --color on the console writes SGR (fd_kind(1) == CONSOLE)
#   file         --color into a `>` redirect writes plain bytes
#   pipe         --color into a `|` pipeline writes plain bytes
#   file width   a banner wider than the console is not cut when redirected
#   fonts        -f slim finds /share/bannermanor/fonts through argv[0]
#                (and loads it: fl_alloc's mmap, the bayan CYML sublib)
#   flf          a figlet font by path, through the .flf adapter
#   list         --list-fonts names the install directory
#   error        a missing font is reported (the stderr route) and the
#                shell gets its prompt back
# file / pipe / width / fonts / flf are measured with `wc -c` on AGNOS
# against the host binary's byte count for the same command, so they do
# not depend on how the console renders escapes.
#
# A FAIL is a result, not a broken harness. Run it against the 1.6.0
# binary to see the checks that 1.7.0 changed go red (console, width).

import os, re, shutil, socket, subprocess, sys, tempfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIB = os.path.dirname(ROOT)

def env(name, default):
    v = os.environ.get(name, "")
    return v if v else default

KERNEL = env("AGNOS_KERNEL", os.path.join(SIB, "agnos/build/agnos"))
ROOTFS = env("AGNOS_ROOTFS", os.path.join(SIB, "agnos/build/rootfs"))
GNOBOOT = env("GNOBOOT_EFI", os.path.join(SIB, "gnoboot/build/BOOTX64.EFI"))
BNRMR = env("BNRMR_AGNOS", os.path.join(ROOT, "build/bnrmr-agnos"))
HOST = env("BNRMR_HOST", os.path.join(ROOT, "build/bnrmr"))
with open(os.path.join(ROOT, "VERSION")) as f:
    WANT_VER = env("BNRMR_EXPECT_VERSION", f.read().strip())

def die(msg):
    print("agnos-smoke: " + msg, file=sys.stderr)
    sys.exit(2)

for p in (KERNEL, os.path.join(ROOTFS, "bin/agnsh"), os.path.join(ROOTFS, "bin/wc"),
          GNOBOOT, BNRMR, HOST):
    if not os.path.lexists(p):
        die("missing " + p)
for tool in ("qemu-system-x86_64", "parted", "sgdisk", "mformat", "mcopy", "mkfs.ext2"):
    if shutil.which(tool) is None:
        die("missing tool " + tool)

OVMF_CODE = OVMF_VARS = None
for c in ("/usr/share/edk2/x64/OVMF_CODE.4m.fd", "/usr/share/edk2/x64/OVMF_CODE.fd",
          "/usr/share/OVMF/OVMF_CODE.fd", "/usr/share/OVMF/OVMF_CODE_4M.fd"):
    if os.path.exists(c): OVMF_CODE = c; break
for c in ("/usr/share/edk2/x64/OVMF_VARS.4m.fd", "/usr/share/edk2/x64/OVMF_VARS.fd",
          "/usr/share/OVMF/OVMF_VARS.fd", "/usr/share/OVMF/OVMF_VARS_4M.fd"):
    if os.path.exists(c): OVMF_VARS = c; break
if not OVMF_CODE or not OVMF_VARS:
    die("OVMF not found")

# The text for the width check: 40 glyphs of block is 239 columns, wider
# than any console agnos draws under QEMU.
WIDE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCD"

def host_len(args):
    # The plain bytes the host binary writes for `args` into a pipe, run
    # from the repo root so ./fonts holds the same fonts the image does.
    r = subprocess.run([HOST] + args, cwd=ROOT, stdout=subprocess.PIPE,
                       stderr=subprocess.DEVNULL, env={"PATH": "/usr/bin:/bin"})
    if r.returncode != 0:
        die("host bnrmr failed on " + " ".join(args))
    return len(r.stdout)

EXPECT = {
    "color": host_len(["--color", "red", "HI"]),
    "wide": host_len([WIDE]),
    "slim": host_len(["-f", "slim", "HI"]),
    "flf": host_len(["-f", "tests/fixtures/tiny.flf", "AGNOS"]),
}

WORK = tempfile.mkdtemp(prefix="bnrmr-agnos-")
SEED = os.path.join(WORK, "seed")
IMG = os.path.join(WORK, "disk.img")
SER = os.path.join(WORK, "serial.log")
# A UNIX socket path is at most 108 bytes, which a deep TMPDIR overruns:
# the monitor gets its own short directory.
QDIR = tempfile.mkdtemp(prefix="bnrmr-q-", dir=os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
MON = os.path.join(QDIR, "mon.sock")

def sh(cmd):
    r = subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if r.returncode != 0:
        die("image step failed: " + cmd + "\n" + r.stderr.decode("latin1")[:400])

subprocess.run(["cp", "-a", ROOTFS, SEED], check=True)
shutil.copyfile(BNRMR, os.path.join(SEED, "bin/bnrmr") + ".new")
os.replace(os.path.join(SEED, "bin/bnrmr") + ".new", os.path.join(SEED, "bin/bnrmr"))
os.chmod(os.path.join(SEED, "bin/bnrmr"), 0o755)
fdir = os.path.join(SEED, "share/bannermanor/fonts")
os.makedirs(fdir, exist_ok=True)
for name in sorted(os.listdir(os.path.join(ROOT, "fonts"))):
    if name.endswith(".cyml"):
        shutil.copyfile(os.path.join(ROOT, "fonts", name), os.path.join(fdir, name))
shutil.copyfile(os.path.join(ROOT, "tests/fixtures/tiny.flf"), os.path.join(SEED, "tiny.flf"))

PART_OFFSET = 33 * 1048576
PART_BLOCKS = (67 * 1048576) // 4096
FEATURES = "^resize_inode,^dir_index,^metadata_csum,^64bit,^uninit_bg"
sh(f"dd if=/dev/zero of={IMG} bs=1M count=128 status=none")
sh(f"parted -s {IMG} mklabel gpt mkpart ESP fat32 1MiB 33MiB set 1 esp on mkpart agnos-fs ext2 33MiB 100MiB")
sh(f"sgdisk -t 2:8300 {IMG}")
sh(f"mformat -i {IMG}@@1048576 -F")
sh(f"mmd -i {IMG}@@1048576 ::EFI ::EFI/BOOT ::boot")
sh(f"mcopy -i {IMG}@@1048576 {GNOBOOT} ::EFI/BOOT/BOOTX64.EFI")
sh(f"mcopy -i {IMG}@@1048576 {KERNEL} ::boot/agnos")
sh(f"mkfs.ext2 -F -q -L BNRMR-SMOKE -b 4096 -m 0 -O {FEATURES} -d {SEED} -E offset={PART_OFFSET} {IMG} {PART_BLOCKS}")
shutil.copyfile(OVMF_VARS, os.path.join(WORK, "vars.fd"))
open(SER, "w").close()

def p(*a): print(*a, flush=True)

qemu = subprocess.Popen([
    "qemu-system-x86_64", "-machine", "q35", "-m", "512M", "-cpu", "max",
    "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
    "-drive", f"if=pflash,format=raw,file={WORK}/vars.fd",
    "-drive", f"file={IMG},format=raw,if=none,id=disk0",
    "-device", "nvme,drive=disk0,serial=BNRMR-SMOKE",
    "-device", "qemu-xhci,id=xhci", "-device", "usb-kbd,bus=xhci.0",
    "-serial", f"file:{SER}", "-display", "none", "-no-reboot",
    "-monitor", f"unix:{MON},server,nowait",
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# HMP sendkey names for the bytes the commands use.
KEYS = {' ': 'spc', '\n': 'ret', '-': 'minus', '.': 'dot', '/': 'slash',
        '>': 'shift-dot', '|': 'shift-backslash', '_': 'shift-minus', '=': 'equal'}

results = []
rc = 1
try:
    s = None
    for _ in range(60):
        try:
            s = socket.socket(socket.AF_UNIX); s.connect(MON); break
        except OSError:
            s = None; time.sleep(0.2)
    if s is None: die("no QEMU monitor")
    s.settimeout(1.0)

    def drain():
        try:
            while True: s.recv(65536)
        except OSError: pass

    def ser():
        try:
            with open(SER, "rb") as f: return f.read().decode("latin1")
        except OSError: return ""

    def typ(text):
        for ch in text:
            key = KEYS.get(ch, ch)
            if ch.isupper(): key = "shift-" + ch.lower()
            s.sendall(("sendkey " + key + "\n").encode())
            time.sleep(0.10); drain()

    PROMPT = "[ASSIST]"

    def run(cmd, timeout=40):
        # Type cmd, wait for the prompt to come back, return what the
        # console printed after the echoed command line.
        mark = len(ser())
        typ(cmd + "\n")
        deadline = time.time() + timeout
        while time.time() < deadline:
            seg = ser()[mark:]
            at = seg.find(cmd)
            tail = seg[at + len(cmd):] if at >= 0 else ""
            if PROMPT in tail:
                return tail[:tail.find(PROMPT)]
            time.sleep(0.5)
        seg = ser()[mark:]
        at = seg.find(cmd)
        return seg[at + len(cmd):] if at >= 0 else seg

    def wc_bytes(cmd):
        out = run(cmd)
        m = re.search(r"(\d+)", out)
        return (int(m.group(1)) if m else None), out

    def check(name, ok, detail):
        results.append((name, ok))
        p(f"  {'PASS' if ok else 'FAIL'}  {name}: {detail}")

    booted = False
    for _ in range(480):
        if "agnoshi" in ser(): booted = True; break
        time.sleep(0.25)
    if not booted: die("agnsh never came up; serial log: " + SER)
    kver = re.search(r"AGNOS kernel v([0-9]+\.[0-9]+\.[0-9]+)", ser())
    p("agnos kernel:", kver.group(1) if kver else "(version not seen)")
    time.sleep(1.0)
    # The first key of a session is swallowed by the HID path (agnos's
    # harness README): absorb it with a bare Enter.
    typ("\n"); time.sleep(2.0)

    out = run("bnrmr --version")
    check("version", ("bnrmr " + WANT_VER) in out, repr(out.strip()[:60]))

    out = run("bnrmr --color red HI")
    check("console", "\x1b[31m" in out and "#" in out,
          "SGR seen" if "\x1b[31m" in out else "no SGR on the console: " + repr(out[:80]))

    run("bnrmr --color red HI > /c1")
    n, out = wc_bytes("wc -c /c1")
    check("file", n == EXPECT["color"], f"{n} bytes, plain is {EXPECT['color']}")

    n, out = wc_bytes("bnrmr --color red HI | wc -c")
    check("pipe", n == EXPECT["color"], f"{n} bytes, plain is {EXPECT['color']}")

    run("bnrmr " + WIDE + " > /w1")
    n, out = wc_bytes("wc -c /w1")
    check("file width", n == EXPECT["wide"], f"{n} bytes, uncut is {EXPECT['wide']}")

    run("bnrmr -f slim HI > /s1")
    n, out = wc_bytes("wc -c /s1")
    check("fonts", n == EXPECT["slim"], f"{n} bytes, slim HI is {EXPECT['slim']}")

    run("bnrmr -f /tiny.flf AGNOS > /t1")
    n, out = wc_bytes("wc -c /t1")
    check("flf", n == EXPECT["flf"], f"{n} bytes, tiny.flf AGNOS is {EXPECT['flf']}")

    out = run("bnrmr --list-fonts")
    ok = "slim" in out and "big" in out and "/share/bannermanor/fonts" in out
    tail = [l for l in out.splitlines() if "Searched" in l]
    check("list", ok, repr(tail[0].strip()[:120]) if tail else repr(out.strip()[:120]))

    out = run("bnrmr -f nosuch HI")
    check("error", "font 'nosuch' not found" in out, repr(out.strip()[:120]))

    p("serial log:", SER)
    rc = 0 if all(ok for _, ok in results) else 1
    p("agnos-smoke:", "PASS" if rc == 0 else "FAIL", f"({sum(ok for _, ok in results)}/{len(results)})")
    try: s.sendall(b"quit\n")
    except OSError: pass
finally:
    qemu.terminate()
    try: qemu.wait(timeout=3)
    except subprocess.TimeoutExpired: qemu.kill()
    shutil.rmtree(QDIR, ignore_errors=True)
sys.exit(rc)
