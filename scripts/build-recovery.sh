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
CANONICAL_FINAL2_SHA="261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a"
CANONICAL_FINAL2_TAR_SHA="51e9a33e27d9d0b2849192d1c7acf88e62958a7fd4fc6121dc658b1c1649c48b"

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

# Resolve inputs to canonical absolute paths
BASE_IMG="$(cd "$(dirname "$BASE_IMG")" && pwd)/$(basename "$BASE_IMG")"
MAGISK_APK="$(cd "$(dirname "$MAGISK_APK")" && pwd)/$(basename "$MAGISK_APK")"
if [[ -f "$MAGISKBOOT" ]]; then
    MAGISKBOOT="$(cd "$(dirname "$MAGISKBOOT")" && pwd)/$(basename "$MAGISKBOOT")"
elif command -v "$MAGISKBOOT" >/dev/null 2>&1; then
    MAGISKBOOT="$(command -v "$MAGISKBOOT")"
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# 1. Strict verification of base image
BASE_SHA=$(sha256sum "$BASE_IMG" | awk '{print $1}')
if [[ "$BASE_SHA" != "$EXPECTED_BASE_SHA" ]]; then
    echo "[-] ERROR: Provided image SHA256 ($BASE_SHA) does not match"
    echo "    proven canonical base image ($EXPECTED_BASE_SHA)!"
    echo "    Refusing to build from an unverified baseline."
    exit 1
fi
echo "[+] Base recovery image hash verified: $BASE_SHA"

# 2. Strict verification of lpmode helper
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

# 3. Clean workspace to prevent cross-build pollution or extract errors
WORK_DIR="$OUTPUT_DIR/work"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

# 4. Strict extraction and verification of BusyBox
echo "[*] Extracting static BusyBox from $MAGISK_APK..."
BUSYBOX_TMP="$WORK_DIR/busybox_extracted"
if ! unzip -p "$MAGISK_APK" "lib/arm64-v8a/libbusybox.so" > "$BUSYBOX_TMP"; then
    echo "[-] Failed to extract lib/arm64-v8a/libbusybox.so from $MAGISK_APK"
    exit 1
fi

BUSYBOX_SHA=$(sha256sum "$BUSYBOX_TMP" | awk '{print $1}')
if [[ "$BUSYBOX_SHA" != "$EXPECTED_BUSYBOX_SHA" ]]; then
    echo "[-] ERROR: Extracted BusyBox SHA256 ($BUSYBOX_SHA) does not match"
    echo "    proven Magisk v30.7 hash ($EXPECTED_BUSYBOX_SHA)!"
    echo "    Refusing to build with an unverified BusyBox binary."
    exit 1
fi
echo "[+] BusyBox hash verified: $BUSYBOX_SHA"

# 5. Unpack baseline recovery
echo "[*] Unpacking $BASE_IMG using $MAGISKBOOT..."
cp "$BASE_IMG" "$WORK_DIR/recovery.img"
(cd "$WORK_DIR" && "$MAGISKBOOT" unpack recovery.img)

mkdir -p "$WORK_DIR/ramdisk_root"
(cd "$WORK_DIR/ramdisk_root" && "$MAGISKBOOT" cpio ../ramdisk.cpio extract)

# 6. Apply binary patches
echo "[*] Applying binary patches..."
python3 "$SCRIPT_DIR/patch-recovery.py" "$WORK_DIR/ramdisk_root"

# 7. Apply init.rc patch
echo "[*] Applying init.rc patch..."
patch -p1 -d "$WORK_DIR/ramdisk_root" < "$REPO_ROOT/patches/init.rc.patch"

# 8. Install userland compatibility files
echo "[*] Installing userland compatibility files..."
# /sbin/sh -> /system/bin/sh
mkdir -p "$WORK_DIR/ramdisk_root/sbin"
chmod 0755 "$WORK_DIR/ramdisk_root/sbin"
ln -sf /system/bin/sh "$WORK_DIR/ramdisk_root/sbin/sh"

# /sbin/busybox and applet symlinks (pointing to /sbin/busybox)
cp "$BUSYBOX_TMP" "$WORK_DIR/ramdisk_root/sbin/busybox"
chmod 0755 "$WORK_DIR/ramdisk_root/sbin/busybox"
(cd "$WORK_DIR/ramdisk_root/sbin" && ln -sf /sbin/busybox unzip && ln -sf /sbin/busybox awk && ln -sf /sbin/busybox hexdump)

# /system/bin/blkid -> /system/bin/toybox
ln -sf /system/bin/toybox "$WORK_DIR/ramdisk_root/system/bin/blkid"

# Add lpmode and lpmode-run
cp "$LPMODE_BIN" "$WORK_DIR/ramdisk_root/system/bin/lpmode"
chmod 0755 "$WORK_DIR/ramdisk_root/system/bin/lpmode"

cp "$SCRIPT_DIR/lpmode-run" "$WORK_DIR/ramdisk_root/system/bin/lpmode-run"
chmod 0755 "$WORK_DIR/ramdisk_root/system/bin/lpmode-run"

# 9. Verify all modifications
echo "[*] Verifying all modifications..."
python3 "$SCRIPT_DIR/verify-recovery.py" "$WORK_DIR/ramdisk_root"

# 10. Deterministic CPIO packing and recovery repacking
echo "[*] Repacking ramdisk.cpio deterministically..."
python3 "$SCRIPT_DIR/pack-cpio.py" "$WORK_DIR/ramdisk_root" "$WORK_DIR/ramdisk.cpio"

echo "[*] Repacking recovery.img with magiskboot..."
(cd "$WORK_DIR" && "$MAGISKBOOT" repack recovery.img "$OUTPUT_DIR/recovery.img")

echo "[*] Creating canonical Odin TAR package..."
chmod 0644 "$OUTPUT_DIR/recovery.img"
PRE_TAR_IMG_SHA=$(sha256sum "$OUTPUT_DIR/recovery.img" | awk '{print $1}')

python3 "$SCRIPT_DIR/pack-tar.py" "$OUTPUT_DIR/recovery.img" "$OUTPUT_DIR/recovery_patched.tar"

OUTPUT_IMG_SHA=$(sha256sum "$OUTPUT_DIR/recovery.img" | awk '{print $1}')
OUTPUT_TAR_SHA=$(sha256sum "$OUTPUT_DIR/recovery_patched.tar" | awk '{print $1}')

if [[ "$PRE_TAR_IMG_SHA" != "$OUTPUT_IMG_SHA" ]]; then
    echo "[-] ERROR: recovery.img was modified during TAR packaging!"
    exit 1
fi

# Strict fail-fast assertions on final output artifacts
if [[ "$OUTPUT_IMG_SHA" != "$CANONICAL_FINAL2_SHA" ]]; then
    echo "[-] ERROR: recovery.img SHA256 mismatch!"
    echo "    Got:      $OUTPUT_IMG_SHA"
    echo "    Expected: $CANONICAL_FINAL2_SHA"
    exit 1
fi

if [[ "$OUTPUT_TAR_SHA" != "$CANONICAL_FINAL2_TAR_SHA" ]]; then
    echo "[-] ERROR: recovery_patched.tar SHA256 mismatch!"
    echo "    Got:      $OUTPUT_TAR_SHA"
    echo "    Expected: $CANONICAL_FINAL2_TAR_SHA"
    exit 1
fi

echo ""
echo "======================================================================"
echo "  BUILD COMPLETED SUCCESSFULLY"
echo "======================================================================"
echo "  recovery.img:         $OUTPUT_DIR/recovery.img"
echo "  recovery.img SHA256:  $OUTPUT_IMG_SHA"
echo "  Odin TAR:             $OUTPUT_DIR/recovery_patched.tar"
echo "  Odin TAR SHA256:      $OUTPUT_TAR_SHA"
echo ""
echo "  [+] REPRODUCIBILITY STATUS: 100% BIT-FOR-BIT IDENTICAL WITH CANONICAL FINAL2!"
echo "      Matches canonical recovery.img SHA256: $CANONICAL_FINAL2_SHA"
echo "      Matches canonical Odin TAR     SHA256: $CANONICAL_FINAL2_TAR_SHA"
echo "======================================================================"
