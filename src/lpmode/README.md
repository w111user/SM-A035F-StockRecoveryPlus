# lpmode

`lpmode` is a standalone AArch64 PIE helper designed for Android recovery environments on dynamic partition devices (tested on Samsung Galaxy A03 SM-A035F).

## Purpose
Stock Samsung recovery does not initialize device-mapper logical partition nodes (`/dev/block/mapper/*`) during normal recovery boot because Samsung OTA update packages are handled via its own internal engine or payload assertions. Consequently, flashable ZIPs (such as Magisk installer scripts) cannot find `/system`, `/vendor`, or `/system_ext`.

`lpmode` invokes Samsung's existing Bionic library function:
```cpp
android::fs_mgr::CreateLogicalPartitions("/dev/block/by-name/super")
```
Exported symbol:
`_ZN7android6fs_mgr23CreateLogicalPartitionsERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE`

## Requirements
- Target: AArch64 (ARM64)
- ELF Type: `ET_DYN` (Position-Independent Executable / PIE). Android 5.0+ Bionic dynamic linkers reject `ET_EXEC`.
- Dynamic Linker (PT_INTERP): `/system/bin/linker64`
- Dynamic Libraries:
  - `libfs_mgr.so` (`CreateLogicalPartitions`)
  - `libc++.so` (`std::string::__init`, `std::string::~string`)
  - `libc.so` (`access`, `write`, `_exit`)

## Building
```bash
./build.sh /path/to/extracted_recovery_ramdisk/system/lib64
```
Proven SHA256 of stripped binary:
`20cd4d0014b920f5b799bd4ab03d93838886ecdcfff4e186a5b038070b4f0ae2`
