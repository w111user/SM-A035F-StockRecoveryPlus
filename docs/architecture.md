# Architecture Overview

This project builds upon a **working ADB user-shell milestone recovery** (which itself originated from an **earliest fastbootd-only recovery base**), adding multi-format package support, unrestricted signature bypass, and dynamic partition mapping while maintaining the fastbootd service, stock recovery UI, and root ADB shell.

```
Samsung Stock Recovery Upstream
  │
  ▼
Earliest Fastbootd-Only Project Baseline (No working ADB)
  │  • Release: https://github.com/w111user/Patch-Recovery/releases/tag/25625329948
  │  • Asset SHA256: a5294ab70c209fd0cc10abc294f4a867d6cc25cb02b984fd097d935c3c7e7101
  │
  ▼  [ADB Enablement: scripts/enable-adb-user.sh]
  │
Working ADB User-Shell Milestone / Base [Current Reproducible Build Input]
  │  • Source: recover.tar (SHA256: eabb15415804aef5e2034c08e627456c115911abbab057fd85b7486c46594b2c)
  │  • recovery.img SHA256: 8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce
  │
  ├── system/bin/init (patched: global permissive)
  │     ├── parses init.rc
  │     └── triggers post-fs
  │           └── exec u:r:recovery:s0 root root -- /system/bin/lpmode-run
  │                 ├── checks /dev/block/mapper/system
  │                 └── runs /system/bin/lpmode (calls libfs_mgr CreateLogicalPartitions)
  │                       └── creates /dev/block/mapper/{system, system_ext, vendor}
  │
  ├── system/bin/adbd (patched: uid=0, gid=0, full caps)
  │     └── provides unrestricted root ADB shell
  │
  ├── system/bin/fastbootd (preserved from base image)
  │     └── provides fastbootd mode functionality
  │
  └── system/bin/recovery (patched)
        ├── Signature Verification Bypass (0x3f6bc)
        │     └── allows unsigned ZIPs & OTAs from ADB and SD card
        │
        └── Metadata Fallback Bypass (0x3d494)
              └── routes non-metadata packages to SetUpNonAbUpdatePackage()
                    ├── extracts META-INF/com/google/android/update-binary to /tmp
                    ├── executes with args: /tmp/update-binary 3 <status_fd> <zip>
                    └── resolves shebang #!/sbin/sh via /sbin/sh -> /system/bin/sh
```
