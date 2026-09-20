#!/usr/bin/env python3
"""
verify-recovery.py — Verifies binary patches, security properties, compatibility files,
and complete boot image structure against the canonical final2 milestone.
"""
import os
import sys
import json
import struct
import hashlib
import stat

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OFFSETS_FILE = os.path.join(SCRIPT_DIR, "..", "patches", "offsets.json")

# Proven hashes for canonical final2 components
EXPECTED_KERNEL_SHA = "648a657d373508e6f47b3d4dd5a8ebbc29f5756fb26ea771bf8758c5c5016968"
EXPECTED_DTB_SHA = "b66c3f3e68c4d03af0959dac5ef52b486559aa1d2d2e979574f648759a884af2"
EXPECTED_DTBO_SHA = "09672a385330b51fd75b231dfef8075d4b7c9bd0115d0270119da8493da9f72c"
EXPECTED_FINAL2_IMG_SHA = "261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a"
EXPECTED_FINAL2_RAMDISK_SHA = "1550ee14937a8828fc312d70e027606d8071802f05503848cc6b4367f2bcb91c"

# File-level payload expectations
EXPECTED_FILE_HASHES = {
    "system/bin/recovery": "a5b12b4b409467aca3331e4c5291433fca681433f00a1b707798df3da51bfb2d",
    "system/bin/adbd": "cc93ca4dc1236cbf853e054c4a89cc154a48232da52a38ef7200644b03be2efc",
    "system/bin/init": "cb75e37177d15ac6ea375c14662bf833b655a1108801c49027b9e58d3c427223",
    "system/bin/lpmode": "20cd4d0014b920f5b799bd4ab03d93838886ecdcfff4e186a5b038070b4f0ae2",
    "system/bin/lpmode-run": "d1e555a3385c3ce14fee20b1bb51c75ed057e54ace29171ce1567044bfc3e20f",
    "sbin/busybox": "4d60ab3f5a59ebb2ca863f2f514e6924401b581e9b64f602665c008177626651",
    "prop.default": "e0aa0250395edccb43b24aed40412c8e42ecb5dcbe57ee484bed9e7ee3d4ea56",
    "sepolicy": "09b8796b9e81fc7f7a0bd01c90a969a5edd416d50d6e14357473f31fdba8d027",
    "system/etc/init/hw/init.rc": "3745e890d5cd626bb936714160f6c6bc8c8b149c9092eee36760b377518a4f43"
}

EXPECTED_SYMLINKS = {
    "sbin/sh": "/system/bin/sh",
    "sbin/unzip": "/sbin/busybox",
    "sbin/awk": "/sbin/busybox",
    "sbin/hexdump": "/sbin/busybox",
    "system/bin/blkid": "/system/bin/toybox",
    "default.prop": "prop.default"
}

EXPECTED_MODES = {
    "sbin": 0o755,
    "sbin/busybox": 0o755,
    "system/bin/lpmode": 0o755,
    "system/bin/lpmode-run": 0o755
}

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def verify_ramdisk(ramdisk_dir):
    with open(OFFSETS_FILE, "r") as f:
        data = json.load(f)

    all_ok = True

    # 1. Binary patches
    print(f"[*] Verifying binary patches in {ramdisk_dir}...")
    for target, patches in data.get("binary_patches", {}).items():
        file_path = os.path.join(ramdisk_dir, target)
        if not os.path.isfile(file_path):
            print(f"  [-] File missing: {file_path}")
            all_ok = False
            continue

        with open(file_path, "rb") as bf:
            for patch in patches:
                offset = int(patch["offset"], 16)
                expected = bytes.fromhex(patch["patched_bytes"])
                bf.seek(offset)
                actual = bf.read(len(expected))
                desc = patch.get("description", "")
                if actual == expected:
                    print(f"  [+] OK {target} @ {patch['offset']} ({desc})")
                else:
                    print(f"  [-] MISMATCH {target} @ {patch['offset']}: got {actual.hex()}, expected {expected.hex()}")
                    all_ok = False

    # 2. Security property ro.adb.secure=0
    print("\n[*] Verifying ro.adb.secure=0 in prop.default...")
    prop_path = os.path.join(ramdisk_dir, "prop.default")
    if os.path.isfile(prop_path):
        with open(prop_path, "rb") as fp:
            prop_content = fp.read()
        if b"ro.adb.secure=0" in prop_content and b"ro.adb.secure=1" not in prop_content:
            print("  [+] OK ro.adb.secure=0 verified")
        else:
            print("  [-] MISMATCH: ro.adb.secure=0 not found or ro.adb.secure=1 still present")
            all_ok = False
    else:
        print("  [-] prop.default missing")
        all_ok = False

    # 3. Verify init.rc hook
    print("\n[*] Verifying init.rc post-fs lpmode hook...")
    initrc_path = os.path.join(ramdisk_dir, "system", "etc", "init", "hw", "init.rc")
    if os.path.isfile(initrc_path):
        with open(initrc_path, "r", errors="ignore") as fp:
            initrc_content = fp.read()
        if "exec u:r:recovery:s0 root root -- /system/bin/lpmode-run" in initrc_content:
            print("  [+] OK lpmode-run hook verified in init.rc")
        else:
            print("  [-] MISMATCH: lpmode-run hook missing in init.rc")
            all_ok = False
    else:
        print("  [-] init.rc missing")
        all_ok = False

    # 4. Verify symlinks and targets
    print("\n[*] Verifying compatibility symlink targets...")
    for rel_path, expected_target in EXPECTED_SYMLINKS.items():
        full_path = os.path.join(ramdisk_dir, rel_path)
        if not os.path.islink(full_path):
            print(f"  [-] NOT A SYMLINK: {rel_path}")
            all_ok = False
            continue
        actual_target = os.readlink(full_path)
        if actual_target == expected_target:
            print(f"  [+] OK {rel_path} -> {actual_target}")
        else:
            print(f"  [-] SYMLINK MISMATCH {rel_path}: got '{actual_target}', expected '{expected_target}'")
            all_ok = False

    # 5. Verify file permissions/modes
    print("\n[*] Verifying file permissions/modes...")
    for rel_path, expected_mode in EXPECTED_MODES.items():
        full_path = os.path.join(ramdisk_dir, rel_path)
        if not os.path.exists(full_path) and not os.path.islink(full_path):
            print(f"  [-] MISSING: {rel_path}")
            all_ok = False
            continue
        st = os.lstat(full_path)
        actual_mode = st.st_mode & 0o777
        if actual_mode == expected_mode:
            print(f"  [+] OK {rel_path} (mode {oct(actual_mode)})")
        else:
            print(f"  [-] MODE MISMATCH {rel_path}: got {oct(actual_mode)}, expected {oct(expected_mode)}")
            all_ok = False

    # 6. Verify file payload hashes
    print("\n[*] Verifying important payload file hashes...")
    for rel_path, exp_sha in EXPECTED_FILE_HASHES.items():
        full_path = os.path.join(ramdisk_dir, rel_path)
        if not os.path.isfile(full_path):
            print(f"  [-] MISSING file: {rel_path}")
            all_ok = False
            continue
        actual_sha = sha256_file(full_path)
        if actual_sha == exp_sha:
            print(f"  [+] OK {rel_path} ({actual_sha[:16]}...)")
        else:
            print(f"  [-] HASH MISMATCH {rel_path}: got {actual_sha}, expected {exp_sha}")
            all_ok = False

    return all_ok

def verify_boot_image(img_path):
    print(f"\n[*] Verifying boot image structure: {img_path}...")
    if not os.path.isfile(img_path):
        print(f"  [-] Boot image missing: {img_path}")
        return False

    with open(img_path, "rb") as fp:
        raw_img = fp.read()

    all_ok = True
    img_sha = hashlib.sha256(raw_img).hexdigest()
    print(f"  recovery.img SHA256: {img_sha}")
    if img_sha == EXPECTED_FINAL2_IMG_SHA:
        print("  [+] MATCHES canonical final2 recovery.img SHA256!")
    else:
        print(f"  [-] MISMATCH with canonical final2 SHA256 ({EXPECTED_FINAL2_IMG_SHA})")
        all_ok = False

    # Header parsing
    hdr = raw_img[:2048]
    magic = hdr[:8]
    if magic != b"ANDROID!":
        print(f"  [-] Invalid Android boot header magic: {magic}")
        return False

    header_version = struct.unpack("<I", hdr[0x28:0x2c])[0]
    kernel_sz = struct.unpack("<I", hdr[0x08:0x0c])[0]
    ramdisk_sz = struct.unpack("<I", hdr[0x10:0x14])[0]
    dtbo_sz = struct.unpack("<I", hdr[0x660:0x664])[0]
    dtbo_offset = struct.unpack("<Q", hdr[0x664:0x66c])[0]
    dtb_sz = struct.unpack("<I", hdr[0x670:0x674])[0]

    print(f"  Header version:      {header_version}")
    print(f"  Kernel size:         {kernel_sz} bytes")
    print(f"  Ramdisk size (gz):   {ramdisk_sz} bytes")
    print(f"  Recovery DTBO size:  {dtbo_sz} bytes @ offset {hex(dtbo_offset)}")
    print(f"  DTB size:            {dtb_sz} bytes")

    # Segment hash checks
    kernel_data = raw_img[2048:2048+kernel_sz]
    kernel_sha = hashlib.sha256(kernel_data).hexdigest()
    if kernel_sha == EXPECTED_KERNEL_SHA:
        print(f"  [+] Kernel SHA256 verified ({kernel_sha[:16]}...)")
    else:
        print(f"  [-] Kernel SHA256 mismatch: {kernel_sha}")
        all_ok = False

    dtbo_data = raw_img[dtbo_offset:dtbo_offset+dtbo_sz]
    dtbo_sha = hashlib.sha256(dtbo_data).hexdigest()
    if dtbo_sha == EXPECTED_DTBO_SHA:
        print(f"  [+] Recovery DTBO SHA256 verified ({dtbo_sha[:16]}...)")
    else:
        print(f"  [-] Recovery DTBO SHA256 mismatch: {dtbo_sha}")
        all_ok = False

    dtb_offset = dtbo_offset + ((dtbo_sz + 2047) // 2048 * 2048)
    dtb_data = raw_img[dtb_offset:dtb_offset+dtb_sz]
    dtb_sha = hashlib.sha256(dtb_data).hexdigest()
    if dtb_sha == EXPECTED_DTB_SHA:
        print(f"  [+] DTB SHA256 verified ({dtb_sha[:16]}...)")
    else:
        print(f"  [-] DTB SHA256 mismatch: {dtb_sha}")
        all_ok = False

    return all_ok

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path_to_unpacked_ramdisk> [path_to_recovery.img]")
        sys.exit(1)

    ramdisk_dir = sys.argv[1]
    ok_ramdisk = verify_ramdisk(ramdisk_dir)

    ok_boot = True
    if len(sys.argv) >= 3:
        ok_boot = verify_boot_image(sys.argv[2])

    sys.exit(0 if (ok_ramdisk and ok_boot) else 1)

if __name__ == "__main__":
    main()
