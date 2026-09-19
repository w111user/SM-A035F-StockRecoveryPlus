# Runtime Validation & Test Proofs

The modifications were verified on a live Samsung Galaxy A03 (`SM-A035F`):

## 1. SELinux & Root ADB Proof
```text
# id
uid=0(root) gid=0(root) groups=0(root) context=u:r:su:s0

# getenforce
Permissive
```

## 2. Init Post-FS Execution
```text
processing action (post-fs)
exec u:r:recovery:s0 root root -- /system/bin/lpmode-run
lpmode: CreateLogicalPartitions OK
... exited with status 0
```

## 3. Dynamic Partition Nodes
```text
# ls -l /dev/block/mapper/
lrwxrwxrwx 1 root root 15 2026-09-19 13:30 system -> /dev/block/dm-0
lrwxrwxrwx 1 root root 15 2026-09-19 13:30 system_ext -> /dev/block/dm-1
lrwxrwxrwx 1 root root 15 2026-09-19 13:30 vendor -> /dev/block/dm-2
```

## 4. Magisk v30.7 Sideload Log
```text
Magisk 30.7 Installer
- Mounting partitions
- Device is system-as-root
- Current boot slot: 
- Boot image: /dev/block/mmcblk0p39
...
- Patching ramdisk
- Repacking boot image
- Unmounting partitions
- Done
Install from ADB completed with status 0
```
