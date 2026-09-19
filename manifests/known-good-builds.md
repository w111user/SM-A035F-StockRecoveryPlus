# Known Good Builds & Lineage Manifest

Device: Samsung Galaxy A03 (`SM-A035F`)  
Chipset: Unisoc UMS9230-AB  
Recovery boot image OS version: 11.0.0  
Recovery boot image patch level: 2025-08  

---

## Provenance & Development Lineage

```
Upstream Samsung Stock Recovery (pure stock, no fastbootd)
  │
  ▼
Earliest Fastbootd-Only Project Baseline (No working ADB)
  │  • Release: https://github.com/w111user/Patch-Recovery/releases/tag/25625329948
  │  • Asset: fastbootd-recovery.tar.md5
  │  • Asset SHA256: a5294ab70c209fd0cc10abc294f4a867d6cc25cb02b984fd097d935c3c7e7101
  │  • Working fastbootd service, but ADB was non-functional
  │
  ▼  [ADB Enablement: scripts/enable-adb-user.sh (ro.adb.secure=1 -> 0)]
  │
Working ADB User-Shell Milestone / Base [Current Reproducible Build Input]
  │  • Source: recover.tar (SHA256: eabb15415804aef5e2034c08e627456c115911abbab057fd85b7486c46594b2c)
  │  • recovery.img SHA256: 8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce
  │  • Working fastbootd + working ADB daemon (unpatched stock user shell, enforcing init)
  │
  ▼  [Milestone 1: root_global_permissive]
  │  • adbd privilege-retention patches (uid=0, gid=0, full caps)
  │  • init permissive patch (0xeb4c0) + init.rc early-init setenforce 0
  │
  ▼  [Milestone 2: root_permissive_unsigned_updates]
  │  • recovery sig bypass (0x3f6bc: b #0x3f750)
  │
  ▼  [Milestone 3: root_permissive_multiformat]
  │  • recovery metadata fallback (0x3d494: tbz w0, #0, 0x3d7fc -> SetUpNonAbUpdatePackage)
  │
  ▼  [Milestone 4: root_permissive_multiformat_userland]
  │  • /sbin/sh -> /system/bin/sh symlink
  │  • Static BusyBox (/sbin/busybox) + unzip, awk, hexdump applets
  │  • /system/bin/blkid -> /system/bin/toybox
  │  (SHA256: 1a24c8bf6be2695fd5946967d6be3f160310df9de1c80753ed458e7f0f815d21)
  │
  ▼  [Milestone 5 & 6: root_permissive_multiformat_lpmapped_final2]
     • Dynamic partition mapper /system/bin/lpmode (AArch64 PIE)
     • Idempotent wrapper /system/bin/lpmode-run with uevent poll loop
     • init.rc post-fs exec hook under u:r:recovery:s0 domain
     • Magisk v30.7 sideload verified successfully (exit status 0)
     (SHA256: 261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a)
     (Odin TAR: 51e9a33e27d9d0b2849192d1c7acf88e62958a7fd4fc6121dc658b1c1649c48b)
```

---

## Historical Origin vs. Reproducible Build Input

1. **Historical Project Origin**:
   - **File**: `fastbootd-recovery.tar.md5`
   - **Repository**: `w111user/Patch-Recovery` (Release `25625329948`)
   - **URL**: `https://github.com/w111user/Patch-Recovery/releases/download/25625329948/fastbootd-recovery.tar.md5`
   - **SHA256**: `a5294ab70c209fd0cc10abc294f4a867d6cc25cb02b984fd097d935c3c7e7101`
   - **Status**: Earliest functional fastbootd port, but did not have working ADB.

2. **Current Reproducible Build Input (Working ADB User-Shell Milestone)**:
   - **File**: `recovery.img` (extracted from `recover.tar`)
   - **SHA256**: `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`
   - **Container**: `recover.tar` (SHA256: `eabb15415804aef5e2034c08e627456c115911abbab057fd85b7486c46594b2c`)
   - **File Size**: `67,108,864` bytes (64 MB)
   - **Header Version**: `2`
   - **Kernel Size**: `23,717,904` bytes | **Ramdisk Size**: `11,319,676` bytes
   - **Recovery Boot Image OS Version**: `11.0.0`
   - **Recovery Boot Image Patch Level**: `2025-08`
   - **Name**: `SRPUH31A009` | **Cmdline**: `console=ttyS1,115200n8`
   - **Note**: The current build scripts take this image as input. Re-creating the step from the fastbootd-only image to this working ADB image is not yet scripted.
