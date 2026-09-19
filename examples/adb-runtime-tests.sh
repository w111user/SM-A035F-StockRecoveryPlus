#!/usr/bin/env bash
# adb-runtime-tests.sh — Run validation tests via ADB while device is booted in recovery
set -euo pipefail

echo "=== 1. Checking ADB Device ==="
adb devices
adb wait-for-recovery

echo "=== 2. Checking Root & Identity ==="
adb shell "id"
# Expected: uid=0(root) gid=0(root) groups=0(root)...

echo "=== 3. Checking SELinux Status ==="
adb shell "getenforce"
# Expected: Permissive

echo "=== 4. Checking Dynamic Partition Mapper Nodes ==="
adb shell "ls -l /dev/block/mapper/"
# Expected:
# system -> /dev/block/dm-0
# system_ext -> /dev/block/dm-1
# vendor -> /dev/block/dm-2

echo "=== 5. Checking Compatibility Links ==="
adb shell "ls -l /sbin/sh /system/bin/blkid"

echo "=== 6. Checking Init Post-FS Execution in Dmesg/Logcat ==="
adb shell "dmesg | grep -i lpmode || true"

echo "=== All checks completed ==="
