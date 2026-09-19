#!/usr/bin/env bash
# build-recovery.sh — Assemble patched recovery with userland compatibility
#
# Provenance Note:
# This build workflow is validated against the project's pre-existing
# FASTBOOTD-ENABLED SM-A035F base recovery image (SHA256: 8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce).
#
# Rebuilding directly from a pure, untouched upstream Samsung stock recovery
# (which lacks initial fastbootd support) has NOT been reproduced and is
# UNSUPPORTED by this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BASE_IMG="${1:-}"
MAGISKBOOT="${2:-magiskboot}"
MAGISK_APK="${3:-}"
OUTPUT_DIR="${4:-$REPO_ROOT/dist}"

EXPECTED_BASE_SHA="8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce"
EXPECTED_BUSYBOX_SHA="4d60ab3f5a59ebb2ca863f2f514e6924401b581e9b64f602665c008177626651"
EXPECTED_LPMODE_SHA="20cd4d0014b920f5b799bd4ab03d93838886ecdcfff4e186a5b038070b4f0ae2"

if [[ -z "$BASE_IMG" || ! -f "$BASE_IMG" || -z "$MAGISK_APK" || ! -f "$MAGISK_APK" ]]; then
    echo "Usage: $0 <path_to_fastbootd_base_recovery.img> <path_to_magiskboot> <path_to_Magisk-v30.7.apk> [output_dir]"
    echo ""
    echo "Arguments:"
    echo "  1. Base recovery image (Expected SHA256: $EXPECTED_BASE_SHA)"
    echo "  2. Path to magiskboot binary"
    echo "  3. Path to official Magisk v30.7 APK (for static BusyBox extraction)"
    echo "  4. Output directory (default: ./dist)"
    exit 1
fi

BASE_SHA=$(sha256sum "$BASE_IMG" | awk '{print $1}')
if [[ "$BASE_SHA" != "$EXPECTED_BASE_SHA" ]]; then
    echo "[!] WARNING: Provided image SHA256 ($BASE_SHA) does not match"
    echo "    the proven fastbootd-enabled base image ($EXPECTED_BASE_SHA)!"
    echo "    Proceeding with unverified base may fail patch verification."
    read -rp "    Continue anyway? (y/N) " confirm
    if [[ "$confirm" != [yY] ]]; then
        echo "Aborted."
        exit 1
    fi
fi

LPMODE_BIN="$REPO_ROOT/src/lpmode/lpmode_stripped"
if [[ ! -f "$LPMODE_BIN" ]]; then
    echo "[-] ERROR: Precompiled helper not found: $LPMODE_BIN"
    echo "    Please compile it first by running:"
    echo "    ./src/lpmode/build.sh <path_to_extracted_system_lib64>"
    exit 1
fi

LPMODE_SHA=$(sha256sum "$LPMODE_BIN" | awk '{print $1}')
if [[ "$LPMODE_SHA" != "$EXPECTED_LPMODE_SHA" ]]; then
    echo "[-] ERROR: lpmode SHA256 mismatch"
    echo "    Got:      $LPMODE_SHA"
    echo "    Expected: $EXPECTED_LPMODE_SHA"
    echo "    Refusing to claim reproducibility with an unverified helper."
    exit 1
fi

echo "[+] lpmode hash verified: $LPMODE_SHA"

mkdir -p "$OUTPUT_DIR/work"
WORK_DIR="$OUTPUT_DIR/work"

echo "[*] Extracting static BusyBox from $MAGISK_APK..."
BUSYBOX_TMP="$WORK_DIR/busybox_extracted"
if ! unzip -p "$MAGISK_APK" "lib/arm64-v8a/libbusybox.so" > "$BUSYBOX_TMP"; then
    echo "[-] Failed to extract lib/arm64-v8a/libbusybox.so from $MAGISK_APK"
    exit 1
fi

BUSYBOX_SHA=$(sha256sum "$BUSYBOX_TMP" | awk '{print $1}')
if [[ "$BUSYBOX_SHA" != "$EXPECTED_BUSYBOX_SHA" ]]; then
    echo "[!] WARNING: Extracted BusyBox SHA256 ($BUSYBOX_SHA) does not match"
    echo "    proven Magisk v30.7 hash ($EXPECTED_BUSYBOX_SHA)!"
    echo "    This build cannot be certified as reproducing the proven final2 environment."
else
    echo "[+] BusyBox hash verified: $BUSYBOX_SHA"
fi

echo "[*] Unpacking $BASE_IMG using $MAGISKBOOT..."
cp "$BASE_IMG" "$WORK_DIR/recovery.img"
(cd "$WORK_DIR" && "$MAGISKBOOT" unpack recovery.img)

mkdir -p "$WORK_DIR/ramdisk_root"
(cd "$WORK_DIR/ramdisk_root" && "$MAGISKBOOT" cpio ../ramdisk.cpio extract)

echo "[*] Applying binary patches..."
python3 "$SCRIPT_DIR/patch-recovery.py" "$WORK_DIR/ramdisk_root"

echo "[*] Applying init.rc patch..."
patch -p1 -d "$WORK_DIR/ramdisk_root" < "$REPO_ROOT/patches/init.rc.patch"

echo "[*] Installing userland compatibility files..."
# 1. /sbin/sh -> /system/bin/sh
mkdir -p "$WORK_DIR/ramdisk_root/sbin"
ln -sf /system/bin/sh "$WORK_DIR/ramdisk_root/sbin/sh"

# 2. /sbin/busybox and applet symlinks
cp "$BUSYBOX_TMP" "$WORK_DIR/ramdisk_root/sbin/busybox"
chmod 0755 "$WORK_DIR/ramdisk_root/sbin/busybox"
(cd "$WORK_DIR/ramdisk_root/sbin" && ln -sf busybox unzip && ln -sf busybox awk && ln -sf busybox hexdump)

# 3. /system/bin/blkid -> /system/bin/toybox
ln -sf /system/bin/toybox "$WORK_DIR/ramdisk_root/system/bin/blkid"

# 4. Add lpmode and lpmode-run
cp "$LPMODE_BIN" "$WORK_DIR/ramdisk_root/system/bin/lpmode"
chmod 0755 "$WORK_DIR/ramdisk_root/system/bin/lpmode"

cp "$SCRIPT_DIR/lpmode-run" "$WORK_DIR/ramdisk_root/system/bin/lpmode-run"
chmod 0755 "$WORK_DIR/ramdisk_root/system/bin/lpmode-run"

echo "[*] Verifying all modifications..."
python3 "$SCRIPT_DIR/verify-recovery.py" "$WORK_DIR/ramdisk_root"

echo "[*] Repacking ramdisk.cpio and recovery.img..."
(cd "$WORK_DIR/ramdisk_root" && find . | cpio -H newc -o > ../ramdisk.cpio)
(cd "$WORK_DIR" && "$MAGISKBOOT" repack recovery.img "$OUTPUT_DIR/recovery.img")

echo "[*] Creating Odin TAR package..."
(cd "$OUTPUT_DIR" && tar -cf recovery_patched.tar recovery.img)

echo "[*] Build complete: $OUTPUT_DIR/recovery.img and $OUTPUT_DIR/recovery_patched.tar"
sha256sum "$OUTPUT_DIR/recovery.img" "$OUTPUT_DIR/recovery_patched.tar"
