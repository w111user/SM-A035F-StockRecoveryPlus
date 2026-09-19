# Magisk Sideload Flow & Compatibility Userland

## Pipeline Execution
When a user runs `adb sideload Magisk-v30.7.zip`:

1. `adbd` (sideload service) receives ZIP into `/sideload/package.zip`.
2. Recovery package verification runs; signature check is bypassed.
3. Metadata inspection fails (no Android OTA metadata); bypass routes execution to `SetUpNonAbUpdatePackage()`.
4. `META-INF/com/google/android/update-binary` is extracted to `/tmp/update-binary` and executed.
5. Shebang interpreter `#!/sbin/sh` executes via `/sbin/sh -> /system/bin/sh`.
6. Update binary extracts its embedded BusyBox and updater scripts.
7. Magisk's `find_block()` discovers `/dev/block/mapper/system` created by `lpmode`.
8. Partitions are mounted read-only, boot image is patched, partitions unmounted.
9. Recovery UI displays success status: `Install from ADB completed with status 0`.

## Userland Compatibility Setup
- `/sbin/sh` -> `/system/bin/sh`
- `/system/bin/blkid` -> `/system/bin/toybox`
- Extracted static BusyBox from Magisk v30.7 placed at `/sbin/busybox` with symlinks:
  - `/sbin/unzip`
  - `/sbin/awk`
  - `/sbin/hexdump`
