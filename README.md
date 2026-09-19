# SM-A035F StockRecoveryPlus

An enhanced stock recovery for the **Samsung Galaxy A03 (`SM-A035F`)** that enables unsigned ZIP flashing, legacy Non-A/B `update-binary` execution (e.g. Magisk), and dynamic partition mapping while fully preserving the official Samsung recovery UI, fastbootd mode, and root ADB shell.

---

## Quick Start for Normal Users

If you only want to install and use this recovery, you **do not** need to compile anything or set up developer tools.

### What You Need
- A Samsung Galaxy A03 (`SM-A035F`) with an unlocked bootloader
- A PC with **Samsung Odin** (Windows) or **Odin4** (Linux)
- A USB data cable

> [!NOTE]
> Normal users do **NOT** need Clang, LLVM, `magiskboot`, the Magisk APK, the baseline recovery image, nor do you need to compile `lpmode` or run `build-recovery.sh`. Pre-packaged Odin TARs are provided ready-to-flash.

### Installation Steps
1. **Download**: Grab the latest release TAR (`recovery_root_permissive_multiformat_lpmapped_final2.tar`) from the [GitHub Releases](../../releases) page.
2. **Reboot to Download Mode**: Power off the device completely, hold both **Volume Up + Volume Down**, and connect the USB cable to your computer until the blue Download Mode warning appears; press **Volume Up** to confirm.
3. **Flash with Odin**:
   - Open Samsung Odin on Windows (or Odin4 on Linux).
   - Load the downloaded `.tar` file into the **AP** slot.
   - Click **Start** to flash.
4. **Boot Recovery**: Immediately after flashing, reboot directly into recovery by holding **Power + Volume Up** until the recovery menu appears.

> [!TIP]
> The build instructions below are **only** for developers who want to inspect or reproduce the recovery from source.

---

## Features

- **Root ADB Shell**: Persistent `uid=0`, `gid=0` shell with full Linux capability bounding set preserved across privilege-drop routines.
- **SELinux Permissive**: Globally permissive policy initialization at early boot.
- **Unrestricted Sideload & SD Update**: Complete signature verification bypass for both ADB sideload and SD-card updates.
- **Multi-Format / Non-A/B Fallback**: Automatic redirection of metadata-less packages (e.g., Magisk APK renamed to ZIP) into Samsung's internal legacy `update-binary` interpreter.
- **Dynamic Partition Auto-Mapping (`lpmode`)**: Standalone AArch64 PIE helper that calls `libfs_mgr.so` to create `/dev/block/mapper/{system, system_ext, vendor}` at boot.
- **Userland Compatibility**: `/sbin/sh` interpreter resolution, `/system/bin/blkid` linkage, and static BusyBox tooling (`unzip`, `awk`, `hexdump`).
- **Preserved Fastbootd**: Official `fastbootd` service and userspace partition commands remain operational.
- **Proven Magisk v30.7 Sideload**: Verified end-to-end (`Install from ADB completed with status 0`).

---

## Supported / Verified Target

- **Device**: Samsung Galaxy A03 (`SM-A035F`)
- **Chipset**: Unisoc UMS9230-AB (`SRPUH31A009`, `console=ttyS1,115200n8`)
- **Recovery Boot Image OS Version**: `11.0.0`
- **Recovery Boot Image Patch Level**: `2025-08`
- **Earliest Fastbootd-Only Baseline Asset SHA256**: `a5294ab70c209fd0cc10abc294f4a867d6cc25cb02b984fd097d935c3c7e7101`
- **Working ADB User-Shell Milestone Recovery SHA256**: `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`
- **Final2 Recovery Image SHA256**: `261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a`
- **Final2 Odin TAR SHA256**: `51e9a33e27d9d0b2849192d1c7acf88e62958a7fd4fc6121dc658b1c1649c48b`

> [!WARNING]
> Binary patch offsets are **strictly firmware/build-specific** to this recovery image. Do not attempt to apply these raw offsets to other devices or differing firmware revisions without disassembling and verifying the target functions.

---

## Flashing Instructions

### Proven Method: Samsung Odin / Odin4
Flashing via **Samsung Odin** (or **Odin4** on Linux) in the **AP** slot using a TAR package containing `recovery.img` is the **only proven and tested installation method** for this project.

> [!CAUTION]
> - **Fastbootd Partition Flashing is NOT Proven**: While `fastbootd` mode runs inside this recovery for managing dynamic logical partitions, writing or updating the `recovery` partition itself through `fastbootd` is **not supported** and was not used during development.
> - **Heimdall Flashing is UNTESTED**: Flashing via Heimdall has not been validated for this firmware base.
> - **Do NOT attempt automated or unverified flashing tools.**

---

## Intermediate Recovery Images

This project involves two distinct intermediate recovery stages prior to the final patched recovery:

| Stage | How to obtain | `recovery.img` SHA256 | Purpose |
|---|---|---|---|
| **Fastbootd-only** | Download historical release asset | `461a0344e6d7018fe0b1ee76e526458ce1aa9f66f2aaabf8f592e980bc4e4e77` | Input for `scripts/enable-adb-user.sh` |
| **Non-root ADB-only** | Generate with `scripts/enable-adb-user.sh` | `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce` | Input for `scripts/build-recovery.sh` |

- **Fastbootd-only recovery**: Available as the historical release archive [`fastbootd-recovery.tar.md5`](https://github.com/w111user/Patch-Recovery/releases/download/25625329948/fastbootd-recovery.tar.md5) (Archive SHA256: `a5294ab70c209fd0cc10abc294f4a867d6cc25cb02b984fd097d935c3c7e7101`).
  - *Capabilities*: `fastbootd` operational; `adbd` service, FunctionFS, and USB gadget configfs present; ADB unusable on host because `ro.adb.secure=1`; no root privileges.
- **Non-root ADB-only recovery**: The non-root ADB-only recovery does not require a separate download. It is reproducibly generated from the fastbootd-only baseline with `scripts/enable-adb-user.sh`.
  - *Capabilities*: `fastbootd` operational; usable unprivileged ADB shell (`uid=2000`, `gid=2000`); no root ADB, no SELinux permissive patch, no unsigned ZIP bypass, and no dynamic partition mapping yet.

### Build & Transformation Pipeline
```text
Fastbootd-only Recovery
461a0344e6d7018fe0b1ee76e526458ce1aa9f66f2aaabf8f592e980bc4e4e77
    ↓  scripts/enable-adb-user.sh
Non-root ADB-only Recovery
8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce
    ↓  scripts/build-recovery.sh
Final Multi-Format Root Recovery (final2)
261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a
```

---

## Developer / Reproducible Build

The following instructions allow developers to rebuild and verify the recovery from source.

### Build Workflow Overview
1. **Obtain Base Recovery**: The fastbootd-only recovery can be reproducibly transformed into the canonical non-root ADB milestone using `scripts/enable-adb-user.sh` (or you can use the pre-existing working ADB user-shell image `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`).
2. **Extract System Libraries**: Extract `/system/lib64` from the base ramdisk so `lpmode` can link against target Bionic libraries.
3. **Compile `lpmode`**: Assemble and link `src/lpmode/lpmode.s` as an AArch64 PIE binary.
4. **Supply Magisk v30.7 APK**: Provide the official Magisk APK so the build script can extract the proven static BusyBox.
5. **Run `build-recovery.sh`**: The build script verifies hashes, applies binary patches, patches `init.rc`, injects compatibility files, and repacks `recovery.img` and the Odin TAR.

### 1. Prerequisites
- Linux x86_64 host
- Clang & LLVM tools (`clang-21`, `ld.lld`, `llvm-strip` or equivalents with AArch64 target support)
- Python 3.8+
- `magiskboot` (from Magisk)
- Non-root ADB-only recovery image (`8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`, generated via `scripts/enable-adb-user.sh`)
- Official Magisk v30.7 APK

# Waste all the time and still cannot create the adb-shell only image? Download here: https://github.com/w111user/Custom-Rom-Builder-For-Samsung-Galaxy-A03/releases/download/0.0/recover.tar

### 2. Compile `lpmode`
`lpmode` is an AArch64 PIE executable that calls `android::fs_mgr::CreateLogicalPartitions` at boot. It must dynamically link against the target recovery's Samsung Bionic libraries (`libfs_mgr.so`, `libc++.so`, and `libc.so`).

Extract `system/lib64` from your baseline recovery ramdisk, then run:
```bash
./src/lpmode/build.sh /path/to/extracted/system/lib64
```
Verify that the output binary (`src/lpmode/lpmode_stripped`) has SHA256:
`20cd4d0014b920f5b799bd4ab03d93838886ecdcfff4e186a5b038070b4f0ae2`

### 3. Patch & Repack Recovery
Execute the main build script:
```bash
./scripts/build-recovery.sh \
    /path/to/fastbootd_base_recovery.img \
    /path/to/magiskboot \
    /path/to/Magisk-v30.7.apk \
    ./dist
```

**Arguments explained**:
1. `/path/to/fastbootd_base_recovery.img`: Working ADB user-shell milestone recovery image (`8ff126c0...`, SHA256 verified).
2. `/path/to/magiskboot`: Path to the `magiskboot` binary for image unpacking/repacking.
3. `/path/to/Magisk-v30.7.apk`: Used solely to extract `lib/arm64-v8a/libbusybox.so` (SHA256 verified).
4. `./dist`: Output directory for generated artifacts.

**What the script executes**:
- Verifies SHA256 hashes of the base image, `lpmode_stripped`, and the extracted BusyBox.
- Applies binary patches to `system/bin/recovery`, `system/bin/adbd`, and `system/bin/init`.
- Applies the unified patch to `system/etc/init/hw/init.rc`.
- Injects compatibility symlinks (`/sbin/sh -> /system/bin/sh`, `/system/bin/blkid -> /system/bin/toybox`).
- Installs `/sbin/busybox` and creates applet symlinks (`unzip`, `awk`, `hexdump`).
- Injects `/system/bin/lpmode` and `/system/bin/lpmode-run`.
- Verifies all modifications using `scripts/verify-recovery.py`.
- Repacks `ramdisk.cpio`, `recovery.img`, and generates `recovery_patched.tar`.

---

## Project Lineage / Provenance

This project did **NOT** begin directly from an untouched upstream Samsung stock recovery. The complete historical development lineage is:

```
Upstream Samsung Stock Recovery (pure stock, no fastbootd)
    │
    ▼
1. Earliest Fastbootd-Only Project Baseline (No Working ADB)
    │  • GitHub Release: https://github.com/w111user/Patch-Recovery/releases/tag/25625329948
    │  • Asset: fastbootd-recovery.tar.md5
    │  • Asset SHA256: a5294ab70c209fd0cc10abc294f4a867d6cc25cb02b984fd097d935c3c7e7101
    │  • Earliest port enabling fastbootd; ADB was not functional.
    │
    ▼  [ADB Enablement Work — Historical milestone, not yet scripted]
    │
2. Working ADB User-Shell Milestone / Base [Current Reproducible Build Input]
    │  • Source Archive: recover.tar (SHA256: eabb15415804aef5e2034c08e627456c115911abbab057fd85b7486c46594b2c)
    │  • Extracted recovery.img SHA256: 8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce
    │  • Functional fastbootd + unprivileged user ADB daemon.
    │  • Serves as the verified input image for scripts/build-recovery.sh.
    │
    ▼
3. This Project's Patch Series:
    • Root ADB privilege retention (uid=0, gid=0, full Linux capabilities)
    • SELinux global permissive (init patch + early-init setenforce 0)
    • Unsigned package signature bypass (recovery 0x3f6bc)
    • Metadata fallback to legacy Non-A/B update-binary (recovery 0x3d494)
    • Userland compatibility (/sbin/sh, static BusyBox applets, blkid)
    • Dynamic partition mapping (lpmode + lpmode-run wrapper)
    │
    ▼
4. Final Verified Recovery Build (final2)
    • recovery.img SHA256: 261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a
    • Odin TAR SHA256:     51e9a33e27d9d0b2849192d1c7acf88e62958a7fd4fc6121dc658b1c1649c48b
```

> [!IMPORTANT]
> - **Historical Origin vs. Build Input**: `fastbootd-recovery.tar.md5` represents the historical starting point of fastbootd porting, whereas `recover.tar` (`8ff126c0...`) represents the subsequent milestone where user-shell ADB was working.
> - The transition from the historical fastbootd-only image to the working ADB user-shell milestone is fully automated via `scripts/enable-adb-user.sh`. The main script `scripts/build-recovery.sh` then consumes this milestone image to apply the root privilege retention, userland compatibility, and dynamic partition mapper stages.

---

## Historical ADB Enablement

Forensic bit-level comparison between the **earliest fastbootd-only base** (`fastbootd-recovery.tar.md5`, `recovery.img` SHA256: `461a0344e6d7018fe0b1ee76e526458ce1aa9f66f2aaabf8f592e980bc4e4e77`) and the **working ADB user-shell milestone** (`recover.tar`, `recovery.img` SHA256: `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`) reveals that:

- Kernel, DTB, and recovery DTBO are bit-for-bit **identical**.
- `system/bin/adbd`, `system/bin/init`, and `system/bin/recovery` binaries are bit-for-bit **identical** (no binary patches were applied at this stage).
- SELinux `sepolicy`, `file_contexts`, and `property_contexts` are **identical**.
- Init rc files, USB gadget configfs triggers, FunctionFS mounts, and service declarations are **identical**.
- Ramdisk filesystem entries and directory structure are **identical**.

### The Technical Mechanism
The earliest fastbootd recovery already had a fully configured `adbd` service, FunctionFS mount, and USB gadget enumeration. However, ADB appeared unusable (`device unauthorized`) because `ro.adb.secure=1` enforced host RSA key verification against `/data/misc/adb/adb_keys`. Because `/data` is inaccessible in recovery and the recovery UI lacks interactive user authentication dialogs, ADB access was permanently blocked.

Setting `ro.adb.secure=0` disabled RSA authorization enforcement, enabling immediate, unauthenticated non-root user shell access (`uid=2000`).

### The Complete Verified Change
Out of 24,247,012 bytes in the uncompressed ramdisk CPIO, **exactly 1 byte differs** at offset `0xc2` in `prop.default` (`0x31` / `'1'` $\rightarrow$ `0x30` / `'0'`):

```diff
--- prop.default
+++ prop.default
@@
-ro.adb.secure=1
+ro.adb.secure=0
```

> [!NOTE]
> This stage **only enabled an unprivileged user shell** (`shell` user: `uid=2000`, `gid=2000`). No `adbd` binary patches, `init` binary patches, or SELinux policy modifications were involved. Persistent root privilege retention was introduced in a subsequent, separate patch stage.

---

## Enable Non-Root ADB on the Fastbootd-Only Base

The historical fastbootd-only image (`461a0344e6d7018fe0b1ee76e526458ce1aa9f66f2aaabf8f592e980bc4e4e77`) can be transformed into the working non-root ADB user-shell milestone using the reproducible helper script `scripts/enable-adb-user.sh`:

```bash
./scripts/enable-adb-user.sh \
    /path/to/fastbootd-only-recovery.img \
    /path/to/magiskboot \
    ./dist
```

### What the Script Executes
1. Verifies the input recovery image SHA256 against `461a0344e6d7018fe0b1ee76e526458ce1aa9f66f2aaabf8f592e980bc4e4e77`.
2. Unpacks the recovery image using `magiskboot`.
3. Verifies that `prop.default` contains `ro.adb.secure=1`.
4. Performs an exact in-place byte patch (`ro.adb.secure=1` $\rightarrow$ `ro.adb.secure=0`) on `ramdisk.cpio`.
5. Verifies that `ro.adb.secure=0` is present and `ro.adb.secure=1` is absent.
6. Repacks the recovery image as `recovery_fastbootd_adb_user.img` and creates an Odin TAR (`recovery_fastbootd_adb_user.tar`).
7. Confirms that the generated image is **100% bit-identical** to the verified milestone recovery (`8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`).

### Pipeline Execution Order
```text
Historical Fastbootd-Only Recovery (461a0344...)
    ↓  [scripts/enable-adb-user.sh]
Working Non-Root ADB User-Shell Milestone (8ff126c0...)
    ↓  [scripts/build-recovery.sh]
Final Multi-Format Root Recovery (final2, 261f5c28...)
```

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
│   ├── avbtool 
│   ├── build-recovery.sh     # Repack workflow (requires fastbootd base & Magisk APK)
│   ├── enable-adb-user.sh    # Historical non-root ADB enablement script
│   ├── patch-recovery.py     # Binary patcher using offsets.json
│   ├── verify-recovery.py    # Offline patch & link verifier
│   ├── magiskboot
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

## Runtime Validation

All modifications were tested and confirmed on a live device:
- Dynamic partition device-mapper nodes created on boot:
  - `/dev/block/mapper/system -> /dev/block/dm-0`
  - `/dev/block/mapper/system_ext -> /dev/block/dm-1`
  - `/dev/block/mapper/vendor -> /dev/block/dm-2`
- Post-fs hook `/system/bin/lpmode-run` executed in `u:r:recovery:s0` exiting with status 0.
- Magisk v30.7 sideload completed successfully: `Install from ADB completed with status 0`.

For detailed command logs and output traces, refer to [docs/runtime-validation.md](docs/runtime-validation.md).

---

## License

Source code, scripts, and documentation are licensed under the [Apache License 2.0](LICENSE).  
Proprietary Samsung binaries, libraries, and base recovery partition images are not redistributed.
