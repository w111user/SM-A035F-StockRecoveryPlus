#!/usr/bin/env python3
"""
patch-recovery.py — Applies binary patches defined in patches/offsets.json
"""
import os
import sys
import json

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OFFSETS_FILE = os.path.join(SCRIPT_DIR, "..", "patches", "offsets.json")

def apply_patches(ramdisk_dir):
    with open(OFFSETS_FILE, "r") as f:
        data = json.load(f)

    for target, patches in data.get("binary_patches", {}).items():
        file_path = os.path.join(ramdisk_dir, target)
        if not os.path.isfile(file_path):
            print(f"[-] Target binary not found: {file_path}")
            sys.exit(1)

        with open(file_path, "r+b") as bf:
            for patch in patches:
                offset = int(patch["offset"], 16)
                orig_bytes = bytes.fromhex(patch["original_bytes"])
                patched_bytes = bytes.fromhex(patch["patched_bytes"])

                bf.seek(offset)
                current = bf.read(len(orig_bytes))
                if current == patched_bytes:
                    print(f"  [=] Already patched: {target} @ {patch['offset']}")
                elif current == orig_bytes:
                    bf.seek(offset)
                    bf.write(patched_bytes)
                    print(f"  [+] Applied patch: {target} @ {patch['offset']} ({patch.get('description')})")
                else:
                    print(f"  [-] Unexpected bytes at {target} @ {patch['offset']}: {current.hex()} (expected {orig_bytes.hex()})")
                    sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path_to_unpacked_ramdisk>")
        sys.exit(1)
    apply_patches(sys.argv[1])
