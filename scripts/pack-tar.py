#!/usr/bin/env python3
"""
pack-tar.py — Deterministic raw TAR packer for Samsung Odin recovery packages

Reproduces the exact historical canonical Odin TAR container:
  Archive SHA256: 51e9a33e27d9d0b2849192d1c7acf88e62958a7fd4fc6121dc658b1c1649c48b
from canonical recovery.img:
  Payload SHA256: 261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a
"""

import sys
import os

CANONICAL_MTIME_OCT = b"15253427242\x00"  # 1789800098 decimal (2026-09-19 06:41:38 UTC)
CANONICAL_UID_OCT   = b"0001750\x00"      # 1000 decimal
CANONICAL_GID_OCT   = b"0001750\x00"      # 1000 decimal
CANONICAL_MODE_OCT  = b"0000644\x00"      # rw-r--r--
CANONICAL_UNAME     = b"w11user"
CANONICAL_GNAME     = b"w11user"
CANONICAL_MAGIC     = b"ustar  \x00"      # GNU tar format magic

def pack_tar(img_path, tar_path):
    if not os.path.isfile(img_path):
        raise FileNotFoundError(f"Input image not found: {img_path}")

    file_size = os.path.getsize(img_path)

    # 1. Construct 512-byte header block
    hdr = bytearray(512)

    # name [0:100]
    entry_name = b"recovery.img"
    hdr[0:len(entry_name)] = entry_name

    # mode [100:108]
    hdr[100:108] = CANONICAL_MODE_OCT

    # uid [108:116]
    hdr[108:116] = CANONICAL_UID_OCT

    # gid [116:124]
    hdr[116:124] = CANONICAL_GID_OCT

    # size [124:136] - 11 octal digits + null
    size_oct = f"{file_size:011o}".encode("ascii") + b"\x00"
    hdr[124:136] = size_oct

    # mtime [136:148]
    hdr[136:148] = CANONICAL_MTIME_OCT

    # typeflag [156:157] - regular file
    hdr[156:157] = b"0"

    # magic [257:265] - GNU tar magic
    hdr[257:265] = CANONICAL_MAGIC

    # uname [265:297]
    hdr[265:265 + len(CANONICAL_UNAME)] = CANONICAL_UNAME

    # gname [297:329]
    hdr[297:297 + len(CANONICAL_GNAME)] = CANONICAL_GNAME

    # Calculate checksum: 8 spaces in chksum field during calculation
    hdr[148:156] = b"        "
    chksum = sum(hdr)
    # Checksum format in GNU tar: 6 octal digits + null + space
    chksum_bytes = f"{chksum:06o}".encode("ascii") + b"\x00 "
    hdr[148:156] = chksum_bytes

    # 2. Write archive
    total_blocks = 1  # header block
    with open(tar_path, "wb") as out_f, open(img_path, "rb") as in_f:
        out_f.write(hdr)
        while True:
            chunk = in_f.read(65536)
            if not chunk:
                break
            out_f.write(chunk)

        # Align payload to 512-byte block boundary
        rem = file_size % 512
        if rem != 0:
            pad = 512 - rem
            out_f.write(b"\x00" * pad)
            total_blocks += (file_size + pad) // 512
        else:
            total_blocks += file_size // 512

        # Blocking factor: GNU tar default is 20 blocks (10,240 bytes).
        # Standard end-of-archive consists of at least two 512-byte zero blocks,
        # padded up to the 20-block record boundary.
        blocks_needed = 2
        while (total_blocks + blocks_needed) % 20 != 0:
            blocks_needed += 1

        out_f.write(b"\x00" * (blocks_needed * 512))

    print(f"Successfully packed deterministic Odin TAR: {tar_path}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input_recovery.img> <output_recovery.tar>")
        sys.exit(1)

    pack_tar(sys.argv[1], sys.argv[2])
