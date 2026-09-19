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
Pre-existing Fastbootd-Enabled SM-A035F Recovery Base
  (SHA256: 8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce)
  │  • Has fastbootd service in init.rc and /system/bin/fastbootd
  │  • Unpatched stock adbd, enforcing init, stock signature enforcement
  │
  ▼  [Milestone 1: root_global_permissive]
  │  • adbd 4-patch root (uid=0, gid=0, full caps)
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

## Baseline Recovery Image Metadata

The project starting image was extracted from `recover.tar`:
- **File**: `recovery.img`
- **SHA256**: `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`
- **File Size**: `67,108,864` bytes (64 MB)
- **Header Version**: `2`
- **Kernel Size**: `23,717,904` bytes
- **Ramdisk Size**: `11,319,676` bytes
- **Recov DTBO Size**: `494,126` bytes
- **DTB Size**: `179,505` bytes
- **Recovery Boot Image OS Version**: `11.0.0`
- **Recovery Boot Image Patch Level**: `2025-08`
- **Page Size**: `2048`
- **Name**: `SRPUH31A009`
- **Kernel Cmdline**: `console=ttyS1,115200n8`
