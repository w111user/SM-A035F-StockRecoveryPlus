# Architecture Overview

This project builds upon an existing **fastbootd-enabled Samsung Galaxy A03 recovery base**, adding multi-format package support, unrestricted signature bypass, and dynamic partition mapping while maintaining the fastbootd service, stock recovery UI, and root ADB shell.

```
Samsung Stock Recovery Upstream
  │
  ▼
Pre-Existing Fastbootd-Enabled SM-A035F Recovery Base
  │  (SHA256: 8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce)
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
