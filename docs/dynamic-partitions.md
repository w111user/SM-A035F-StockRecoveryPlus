# Dynamic Partition Mapping (`lpmode`)

## Problem
In Android 10+ devices utilizing `super.img` (dynamic partitions), partitions such as `system`, `vendor`, and `system_ext` reside as logical extents within the physical `super` partition (`/dev/block/by-name/super`).

Stock Samsung recovery does not construct device-mapper tables for these partitions on boot because its OTA updater uses internal direct payload engines. Custom installers like Magisk search for `/dev/block/mapper/system` or `/dev/block/by-name/system` to mount root partitions, failing immediately with `! Cannot mount /system` if mapper devices are absent.

## Solution
Rather than porting custom recovery frameworks (TWRP/OrangeFox), `lpmode` dynamically links against Samsung's existing `/system/lib64/libfs_mgr.so` to invoke:
```cpp
android::fs_mgr::CreateLogicalPartitions("/dev/block/by-name/super")
```

The kernel device-mapper responds by instantiating:
- `/dev/block/mapper/system` -> `/dev/block/dm-0`
- `/dev/block/mapper/system_ext` -> `/dev/block/dm-1`
- `/dev/block/mapper/vendor` -> `/dev/block/dm-2`

## Idempotent Init Integration
Executed at `on post-fs` under SELinux label `u:r:recovery:s0`:
- If nodes already exist, `lpmode-run` exits immediately.
- If not, it executes `lpmode` and polls for uevent node creation up to 1 second before continuing.
