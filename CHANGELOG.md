# Changelog

## Milestone 6 — Dynamic Partition Mapper & Verified Magisk Sideload (`final2`)
- Resolved SELinux domain transition failure by executing `/system/bin/lpmode-run` in `u:r:recovery:s0`.
- Introduced `/system/bin/lpmode-run` wrapper with uevent polling loop to eliminate device node creation race condition.
- Verified Magisk v30.7 sideload successfully mounts `/dev/block/mapper/system` and exits with status 0.

## Milestone 5 — Standalone Dynamic Partition Mapper (`lpmode`)
- Authored standalone AArch64 PIE helper `lpmode` calling `android::fs_mgr::CreateLogicalPartitions("/dev/block/by-name/super")`.
- Dynamic linkage against existing Bionic `/system/lib64/libfs_mgr.so`, `/system/lib64/libc++.so`, and `/system/lib64/libc.so`.
- Linked as `ET_DYN` position-independent executable satisfying Android 5.0+ linker requirements.

## Milestone 4 — Userland Compatibility Layer
- Added `/sbin/sh -> /system/bin/sh` symlink to resolve legacy shebang interpreters.
- Injected static BusyBox (`/sbin/busybox`) with `/sbin/unzip`, `/sbin/awk`, `/sbin/hexdump`.
- Linked `/system/bin/blkid -> /system/bin/toybox` for filesystem UUID probing.

## Milestone 3 — Multi-Format Package Support
- Patched `system/bin/recovery` at `0x3d494` (`40 1b 00 36`) to bypass `GetMetadata()` abort and branch into `SetUpNonAbUpdatePackage()`.

## Milestone 2 — Unsigned Package Acceptance
- Patched `system/bin/recovery` at `0x3f6bc` (`25 00 00 14`) to bypass OTA signature verification for both ADB sideload and SD-card updates.

## Milestone 1 — Root ADB & Global Permissive
- Patched `system/bin/adbd` to bypass privilege-drop routines, retaining `uid=0`, `gid=0`, and full Linux capabilities.
- Patched `system/bin/init` at `0xeb4c0` (`e0 03 1f 2a`) to enforce global SELinux Permissive mode.

## Historical Baseline 2 — Working ADB User-Shell Milestone
- Source archive: `recover.tar` (SHA256: `eabb15415804aef5e2034c08e627456c115911abbab057fd85b7486c46594b2c`)
- Extracted `recovery.img` (SHA256: `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`)
- Functional fastbootd + functional unprivileged user ADB daemon.
- Serves as the **current reproducible build input** for `build-recovery.sh`.

## Historical Baseline 1 — Earliest Fastbootd-Only Project Baseline
- GitHub release asset: `https://github.com/w111user/Patch-Recovery/releases/tag/25625329948` (`fastbootd-recovery.tar.md5`)
- Asset SHA256: `a5294ab70c209fd0cc10abc294f4a867d6cc25cb02b984fd097d935c3c7e7101`
- Earliest functional fastbootd port on SM-A035F (ADB non-functional).
