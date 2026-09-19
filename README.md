# Multi-Format Patched Recovery for Samsung Galaxy A03 (SM-A035F)

A patchset, userland compatibility layer, and dynamic partition mapper for the **Samsung Galaxy A03 (`SM-A035F`)** built upon an existing **fastbootd-enabled recovery base**. This project enables unsigned package installation, legacy Non-A/B `update-binary` execution, and automatic dynamic partition mapping while maintaining the official recovery UI, fastbootd mode, and root ADB.

> [!IMPORTANT]
> **Project Lineage & Provenance**:
> This project did **NOT** begin directly from an untouched upstream Samsung stock recovery. The starting baseline was a pre-existing Galaxy A03 recovery image that had already been modified to support `fastbootd`.
> 
> ```
> Samsung Stock Recovery Upstream (pure stock, no fastbootd)
>     ↓
> Pre-existing Fastbootd-Enabled SM-A035F Recovery Base (Project Baseline)
>     ↓
> This Project's Patch Series:
>   • ADB root (uid=0, gid=0, full Linux capabilities)
>   • SELinux global permissive
>   • Unsigned package signature verification bypass
>   • Metadata fallback to legacy Non-A/B update-binary
>   • Userland compatibility (/sbin/sh, BusyBox applets, blkid)
>   • Dynamic partition mapping (lpmode + lpmode-run wrapper)
>     ↓
> Final Verified Recovery Build (final2)
> ```
> Direct transformation of a completely untouched Samsung stock recovery into this final build has **not been reproduced** and is **not supported** by the build scripts.

---

## Baseline Recovery Image (Project Starting Point)

The verified starting baseline recovery image for all patches in this repository:

- **Source Archive**: `recover.tar` (SHA256: `eabb15415804aef5e2034c08e627456c115911abbab057fd85b7486c46594b2c`)
- **Base Image**: `recovery.img`
- **SHA256**: `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`
- **Size**: `67,108,864` bytes (64 MB)
- **Header Info**: Android Boot Image Header Version 2
- **Kernel Size**: `23,717,904` bytes | **Ramdisk Size**: `11,319,676` bytes
- **Recovery Boot Image OS Version**: `11.0.0`
- **Recovery Boot Image Patch Level**: `2025-08`
- **Chipset**: Unisoc UMS9230-AB (`SRPUH31A009`, `console=ttyS1,115200n8`)
- **Key Feature of Base**: Pre-existing `system/bin/fastbootd` and init configurations.

---

## Features Added by This Project

- **Root ADB Shell**: Persistent `uid=0`, `gid=0` shell with full Linux capabilities preserved across privilege-drop routines.
- **SELinux Permissive**: Globally permissive policy initialization at boot.
- **Unrestricted Sideload & SD Update**: Complete signature verification bypass for ADB sideload and SD-card updates.
- **Multi-Format / Non-A/B Fallback**: Automatic redirection of metadata-less packages (e.g., Magisk APK renamed to ZIP) into Samsung's internal legacy `update-binary` interpreter.
- **Dynamic Partition Auto-Mapping (`lpmode`)**: Standalone AArch64 PIE helper invoking Samsung's `libfs_mgr.so` to create `/dev/block/mapper/{system, system_ext, vendor}` on recovery boot.
- **Userland Compatibility**: `/sbin/sh` interpreter resolution, `/system/bin/blkid` link, and static BusyBox tooling (`unzip`, `awk`, `hexdump`).
- **Proven Magisk v30.7 Installation**: Verified end-to-end (`Install from ADB completed with status 0`).

---

## Repository Structure

```
.
├── docs/                     # Technical documentation & runtime proofs
│   ├── architecture.md       # Overall architecture & execution flow
│   ├── patch-notes.md        # Binary patch breakdowns & disassembly
│   ├── dynamic-partitions.md # Dynamic partition mapper explanation
│   ├── magisk-sideload.md    # Sideload execution & compatibility notes
│   └── runtime-validation.md # Verified runtime command logs
├── src/                      # Source code
│   └── lpmode/               # Dynamic partition mapper helper (AArch64 ASM)
│       ├── lpmode.s
│       ├── build.sh
│       └── README.md
├── scripts/                  # Build, patching, and verification scripts
│   ├── build-recovery.sh     # Repack workflow (requires fastbootd base & Magisk APK)
│   ├── patch-recovery.py     # Binary patcher using offsets.json
│   ├── verify-recovery.py    # Offline patch & link verifier
│   └── lpmode-run            # Idempotent init wrapper for lpmode
├── patches/                  # Binary patch definitions & diffs
│   ├── recovery.md
│   ├── adbd.md
│   ├── init.md
│   ├── init.rc.patch
│   └── offsets.json
├── manifests/                # SHA256 hashes & known good milestone records
│   ├── SHA256SUMS
│   └── known-good-builds.md
└── examples/
    └── adb-runtime-tests.sh  # Live ADB verification script
```

---

## Building

### 1. Prerequisites
- Linux x86_64 host
- Clang & LLVM tools (`clang-21`, `ld.lld`, `llvm-strip` or equivalents with AArch64 target support)
- Python 3.8+
- `magiskboot`
- The proven **fastbootd-enabled base image** (`8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`)
- Official **Magisk v30.7 APK** (for static BusyBox extraction)

### 2. Compile `lpmode`
Extract `system/lib64` from your base recovery ramdisk and compile:
```bash
./src/lpmode/build.sh /path/to/extracted/system/lib64
```
Verify the output binary has SHA256:
`20cd4d0014b920f5b799bd4ab03d93838886ecdcfff4e186a5b038070b4f0ae2`

### 3. Patch & Repack Recovery
Run the build script with all required components:
```bash
./scripts/build-recovery.sh \
    /path/to/fastbootd_base_recovery.img \
    /path/to/magiskboot \
    /path/to/Magisk-v30.7.apk \
    ./dist
```
The script will automatically:
- Extract `lib/arm64-v8a/libbusybox.so` from the Magisk APK
- Validate its SHA256 against the proven hash (`4d60ab3f5a59ebb2ca863f2f514e6924401b581e9b64f602665c008177626651`)
- Install `/sbin/busybox` and create applet symlinks (`unzip`, `awk`, `hexdump`)
- Apply binary patches to `recovery`, `adbd`, and `init`
- Patch `init.rc` and install `lpmode` + `lpmode-run`
- Verify all modifications and generate the Odin flashable TAR

---

## Flashing Instructions

### Proven Flashing Method: Samsung Odin
The only proven and verified method for installing this recovery on the Galaxy A03 is flashing via **Samsung Odin / Odin4**:
1. Place the device into **Download Mode** (vol down + vol up while connecting USB).
2. Load the output TAR package (`recovery_patched.tar` or `recovery_root_permissive_multiformat_lpmapped_final2.tar`) into the **AP** slot.
3. Flash the image.

> [!CAUTION]
> - **Fastbootd Partition Flashing is NOT Proven**: Although this recovery includes working `fastbootd` mode support internally for userspace partition operations, writing or updating the `recovery` partition itself through `fastbootd` is **not supported** and was not the method used during development.
> - **Heimdall Flashing is UNTESTED**: Flashing PIT/partitions using Heimdall has not been validated for this firmware base.
> - **Do NOT attempt automated or unverified flashing tools.**

---

## License
Source code, scripts, and documentation are licensed under the [Apache License 2.0](LICENSE).
Proprietary Samsung binaries, libraries, and vendor partition images are not redistributed.
