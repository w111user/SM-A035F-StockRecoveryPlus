#!/usr/bin/env python3
"""
verify-recovery.py — Verifies binary patches and compatibility files
"""
import os
import sys
import json

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OFFSETS_FILE = os.path.join(SCRIPT_DIR, "..", "patches", "offsets.json")

def verify(ramdisk_dir):
    with open(OFFSETS_FILE, "r") as f:
        data = json.load(f)

    all_ok = True
    print(f"[*] Verifying binary patches in {ramdisk_dir}...")
    for target, patches in data.get("binary_patches", {}).items():
        file_path = os.path.join(ramdisk_dir, target)
        if not os.path.isfile(file_path):
            print(f"[-] File missing: {file_path}")
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

    print("\n[*] Verifying compatibility links and binaries...")
    compat_entries = data.get("compatibility_entries", [])
    for entry in compat_entries:
        path = os.path.join(ramdisk_dir, entry["path"])
        if os.path.exists(path) or os.path.islink(path):
            print(f"  [+] OK {entry['path']}")
        else:
            print(f"  [-] MISSING {entry['path']}")
            all_ok = False

    return all_ok

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path_to_unpacked_ramdisk>")
        sys.exit(1)
    success = verify(sys.argv[1])
    sys.exit(0 if success else 1)
