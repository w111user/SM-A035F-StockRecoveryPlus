#!/usr/bin/env bash
# build.sh — Build lpmode as an Android AArch64 PIE binary
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBDIR="${1:-}"

if [[ -z "$LIBDIR" || ! -d "$LIBDIR" ]]; then
    echo "Usage: $0 <path_to_samsung_system_lib64>"
    echo "Example: $0 /path/to/ramdisk/system/lib64"
    exit 1
fi

echo "==> Assembling lpmode.s for aarch64-linux-android..."
clang-21 --target=aarch64-linux-android31 \
    -x assembler -c "$SCRIPT_DIR/lpmode.s" -o "$SCRIPT_DIR/lpmode.o"

echo "==> Linking PIE executable (ET_DYN)..."
ld.lld \
    -m aarch64linux \
    -pie \
    -z now \
    -z relro \
    -dynamic-linker /system/bin/linker64 \
    -L "$LIBDIR" \
    -l:libfs_mgr.so \
    -l:libc++.so \
    -l:libc.so \
    -e _start \
    --no-undefined \
    "$SCRIPT_DIR/lpmode.o" -o "$SCRIPT_DIR/lpmode"

echo "==> Stripping binary..."
llvm-strip-21 "$SCRIPT_DIR/lpmode" -o "$SCRIPT_DIR/lpmode_stripped" 2>/dev/null || \
    llvm-strip "$SCRIPT_DIR/lpmode" -o "$SCRIPT_DIR/lpmode_stripped"

echo "==> Done. Output: $SCRIPT_DIR/lpmode_stripped"
sha256sum "$SCRIPT_DIR/lpmode_stripped"
