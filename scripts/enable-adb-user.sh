#!/usr/bin/env bash
# enable-adb-user.sh — Transform historical fastbootd-only recovery to working non-root ADB user-shell recovery
#
# Provenance Note:
# Input:  Historical fastbootd-only recovery.img (SHA256: 461a0344e6d7018fe0b1ee76e526458ce1aa9f66f2aaabf8f592e980bc4e4e77)
# Output: Working ADB user-shell milestone recovery.img (SHA256: 8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce)
#
# IMPORTANT:
# This script enables an unprivileged user shell (uid=2000, gid=2000) by disabling
# ADB host RSA authentication enforcement (ro.adb.secure=0).
# It does NOT patch adbd or init, and does NOT provide root privileges.
set -euo pipefail

EXPECTED_INPUT_SHA="461a0344e6d7018fe0b1ee76e526458ce1aa9f66f2aaabf8f592e980bc4e4e77"
EXPECTED_OUTPUT_SHA="8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce"

INPUT_IMG="${1:-}"
MAGISKBOOT="${2:-}"
OUTPUT_DIR="${3:-./dist}"

if [[ -z "$INPUT_IMG" || -z "$MAGISKBOOT" ]]; then
    echo "Usage: $0 <path_to_fastbootd_only_recovery.img> <path_to_magiskboot> [output_dir]"
    echo ""
    echo "Arguments:"
    echo "  1. Path to historical fastbootd-only recovery image"
    echo "     (Expected SHA256: $EXPECTED_INPUT_SHA)"
    echo "  2. Path to magiskboot binary"
    echo "  3. Output directory (default: ./dist)"
    exit 1
fi

if [[ ! -f "$INPUT_IMG" ]]; then
    echo "[-] ERROR: Input recovery image not found: $INPUT_IMG"
    exit 1
fi

if [[ ! -x "$MAGISKBOOT" ]]; then
    echo "[-] ERROR: magiskboot binary not found or not executable: $MAGISKBOOT"
    exit 1
fi

echo "[*] Verifying input recovery image SHA256..."
ACTUAL_INPUT_SHA=$(sha256sum "$INPUT_IMG" | awk '{print $1}')
if [[ "$ACTUAL_INPUT_SHA" != "$EXPECTED_INPUT_SHA" ]]; then
    echo "[-] ERROR: Input image SHA256 mismatch!"
    echo "    Expected: $EXPECTED_INPUT_SHA"
    echo "    Got:      $ACTUAL_INPUT_SHA"
    echo "    This script only transforms the verified historical fastbootd-only recovery image."
    exit 1
fi
echo "[+] Input image verified: $ACTUAL_INPUT_SHA"

# Create secure temporary work directory
WORK_DIR=$(mktemp -d -t enable_adb_user_XXXXXX)
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "[*] Unpacking recovery image..."
cp "$INPUT_IMG" "$WORK_DIR/recovery.img"
(cd "$WORK_DIR" && "$MAGISKBOOT" unpack recovery.img > /dev/null)

if [[ ! -f "$WORK_DIR/ramdisk.cpio" ]]; then
    echo "[-] ERROR: Failed to unpack ramdisk.cpio from recovery image"
    exit 1
fi

echo "[*] Extracting prop.default from ramdisk..."
(cd "$WORK_DIR" && "$MAGISKBOOT" cpio ramdisk.cpio "extract prop.default prop.default.before" > /dev/null)

if [[ ! -f "$WORK_DIR/prop.default.before" ]]; then
    echo "[-] ERROR: prop.default not found in ramdisk"
    exit 1
fi

echo "[*] Verifying ro.adb.secure=1 in prop.default..."
if ! grep -q "^ro.adb.secure=1$" "$WORK_DIR/prop.default.before"; then
    echo "[-] ERROR: Expected 'ro.adb.secure=1' not found in prop.default"
    exit 1
fi

echo "[*] Patching ro.adb.secure=1 -> ro.adb.secure=0 in ramdisk..."
# Exact byte patch: replace "ro.adb.secure=1" (hex: 726f2e6164622e7365637572653d31)
# with "ro.adb.secure=0" (hex: 726f2e6164622e7365637572653d30) directly in ramdisk.cpio.
# This in-place replacement preserves exact CPIO entry ordering, inode alignment, and metadata.
(cd "$WORK_DIR" && "$MAGISKBOOT" hexpatch ramdisk.cpio 726f2e6164622e7365637572653d31 726f2e6164622e7365637572653d30 > /dev/null)

echo "[*] Verifying patched property in ramdisk..."
(cd "$WORK_DIR" && "$MAGISKBOOT" cpio ramdisk.cpio "extract prop.default prop.default.after" > /dev/null)

if ! grep -q "^ro.adb.secure=0$" "$WORK_DIR/prop.default.after"; then
    echo "[-] ERROR: 'ro.adb.secure=0' not found after patching!"
    exit 1
fi

if grep -q "^ro.adb.secure=1$" "$WORK_DIR/prop.default.after"; then
    echo "[-] ERROR: 'ro.adb.secure=1' still present after patching!"
    exit 1
fi

echo "[+] Property verification passed: ro.adb.secure=1 -> ro.adb.secure=0"

echo "[*] Repacking recovery image with magiskboot..."
mkdir -p "$OUTPUT_DIR"
OUTPUT_IMG="$OUTPUT_DIR/recovery_fastbootd_adb_user.img"
(cd "$WORK_DIR" && "$MAGISKBOOT" repack recovery.img "$OUTPUT_IMG" > /dev/null)

if [[ ! -f "$OUTPUT_IMG" ]]; then
    echo "[-] ERROR: Failed to generate repacked recovery image"
    exit 1
fi

ACTUAL_OUTPUT_SHA=$(sha256sum "$OUTPUT_IMG" | awk '{print $1}')

echo "[*] Creating Odin TAR package..."
OUTPUT_TAR="$OUTPUT_DIR/recovery_fastbootd_adb_user.tar"
TAR_WORK_DIR="$WORK_DIR/tar_stage"
mkdir -p "$TAR_WORK_DIR"
cp "$OUTPUT_IMG" "$TAR_WORK_DIR/recovery.img"
(cd "$TAR_WORK_DIR" && tar -cf "$OUTPUT_TAR" recovery.img)
OUTPUT_TAR_SHA=$(sha256sum "$OUTPUT_TAR" | awk '{print $1}')

echo ""
echo "======================================================================"
echo "  HISTORICAL ADB ENABLEMENT STAGE COMPLETED"
echo "======================================================================"
echo "  Property change:   ro.adb.secure=1 -> ro.adb.secure=0"
echo "  Input SHA256:      $ACTUAL_INPUT_SHA"
echo "  Output SHA256:     $ACTUAL_OUTPUT_SHA"
echo "  Output image:      $OUTPUT_IMG"
echo "  Output Odin TAR:   $OUTPUT_TAR ($OUTPUT_TAR_SHA)"
echo ""
if [[ "$ACTUAL_OUTPUT_SHA" == "$EXPECTED_OUTPUT_SHA" ]]; then
    echo "  [+] REPRODUCIBILITY: Bit-identical to verified ADB milestone!"
    echo "      (Matches SHA256: $EXPECTED_OUTPUT_SHA)"
else
    echo "  [!] NOTICE: Output SHA256 differs from milestone reference ($EXPECTED_OUTPUT_SHA)."
fi
echo ""
echo "  NOTE: This image provides a WORKING NON-ROOT ADB SHELL (uid=2000)."
echo "  It does NOT grant root access. To add root privileges, SELinux permissive,"
echo "  and dynamic partition mapping, use this output as the input image for"
echo "  scripts/build-recovery.sh."
echo "======================================================================"
