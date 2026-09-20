#!/usr/bin/env python3
"""
pack-cpio.py — Deterministic CPIO archive packer for Android recovery ramdisk

Generates bit-for-bit reproducible CPIO (newc) archives identical to the
internal format used by magiskboot cpio:
- Alphabetically sorted entry order
- Inode sequence starting at 300000 (0x493e0)
- Zeroed timestamps (mtime = 0)
- Root ownership (uid = 0, gid = 0)
- Single link count (nlink = 1)
- 4-byte aligned entries without unnecessary trailing block padding
- Standard TRAILER!!! marker with mode 0755
"""

import os
import sys

def collect_entries(root_dir):
    entries = []
    
    def scan(current_dir, rel_prefix):
        with os.scandir(current_dir) as it:
            items = list(it)
            items.sort(key=lambda e: e.name)
            
            for item in items:
                rel_path = os.path.join(rel_prefix, item.name) if rel_prefix else item.name
                
                # Check symlink first to prevent descending into symlinks to dirs
                if item.is_symlink():
                    target = os.readlink(item.path)
                    mode = 0o120777
                    entries.append((rel_path, mode, target.encode('latin1')))
                elif item.is_dir():
                    st = item.stat(follow_symlinks=False)
                    mode = 0o40000 | (st.st_mode & 0o777)
                    entries.append((rel_path, mode, b''))
                    scan(item.path, rel_path)
                else:
                    st = item.stat(follow_symlinks=False)
                    mode = 0o100000 | (st.st_mode & 0o777)
                    with open(item.path, 'rb') as fp:
                        content = fp.read()
                    entries.append((rel_path, mode, content))
                    
    scan(root_dir, "")
    entries.sort(key=lambda x: x[0])
    entries.append(('TRAILER!!!', 0o755, b''))
    return entries

def pack_to_cpio(entries, out_path):
    out = bytearray()
    for idx, (name, mode, content) in enumerate(entries):
        name_bytes = name.encode('latin1') + b'\x00'
        namesize = len(name_bytes)
        filesize = len(content)
        ino = 300000 + idx
        uid = 0
        gid = 0
        nlink = 1
        mtime = 0
        devmajor = 0
        devminor = 0
        rdevmajor = 0
        rdevminor = 0
        check = 0
        
        hdr = (
            f"070701{ino:08x}{mode:08x}{uid:08x}{gid:08x}{nlink:08x}"
            f"{mtime:08x}{filesize:08x}{devmajor:08x}{devminor:08x}"
            f"{rdevmajor:08x}{rdevminor:08x}{namesize:08x}{check:08x}"
        ).encode('ascii')
        
        out.extend(hdr)
        out.extend(name_bytes)
        while len(out) % 4 != 0:
            out.append(0)
        out.extend(content)
        while len(out) % 4 != 0:
            out.append(0)
            
    with open(out_path, 'wb') as fp:
        fp.write(out)
    return len(entries)

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <ramdisk_root_dir> <output_cpio_path>", file=sys.stderr)
        sys.exit(1)
        
    root_dir = sys.argv[1]
    out_path = sys.argv[2]
    
    if not os.path.isdir(root_dir):
        print(f"Error: Not a directory: {root_dir}", file=sys.stderr)
        sys.exit(1)
        
    entries = collect_entries(root_dir)
    pack_to_cpio(entries, out_path)
    print(f"Successfully packed {len(entries)} entries into {out_path}")

if __name__ == "__main__":
    main()
