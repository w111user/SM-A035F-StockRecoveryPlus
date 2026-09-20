# Build Reproducibility & Determinism Audit

## 1. Executive Summary

An in-depth forensic investigation was performed to identify why automated runs of `scripts/build-recovery.sh` from the canonical non-root ADB baseline (`8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`) previously produced non-deterministic output hashes (e.g., `f5bf89...`, `ebe873...`) that deviated from the canonical `final2` milestone (`261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a`).

### Key Findings
1. **Zero Functional Code Divergence**: Across the entire 25.9 MiB ramdisk userland, all executable binaries (`recovery`, `adbd`, `init`, `lpmode`, `lpmode-run`, `busybox`, `sh`, `blkid`), libraries, SELinux policies (`sepolicy`), file/property contexts, and rc scripts were **100% functionally identical** across all builds.
2. **Root Cause of Non-Determinism**:
   - The legacy repack step used `(cd "$WORK_DIR/ramdisk_root" && find . | cpio -H newc -o > ../ramdisk.cpio)`.
   - `find .` traverses directories in the non-deterministic order returned by the host filesystem's `readdir()`.
   - `cpio -H newc -o` captured host-dependent inode numbers, host build timestamps (`mtime`), host numeric ownership (`uid`/`gid`), and inserted a spurious `.` root directory entry.
   - Gzip compression amplified these metadata fluctuations across the entire compressed ramdisk segment.
   - Reusing `$OUTPUT_DIR/work` caused `magiskboot cpio extract` to fail with `os error 17` (file exists) or pollute subsequent builds.
3. **Symlink Target Discrepancy**: Legacy scripts created relative symlinks in `/sbin/` (`ln -sf busybox unzip` $\rightarrow$ target: `busybox`), whereas canonical `final2` utilized absolute symlinks (`/sbin/busybox`).
4. **Achieved Solution**:
   - Replaced host `cpio` invocation with a deterministic Python builder ([`scripts/pack-cpio.py`](file:///media/GooningData/fastbootd-recovery/github_repo/scripts/pack-cpio.py)) that mimics the exact metadata format used by `magiskboot cpio` (alphabetical sorting, zeroed mtimes, `uid=0, gid=0`, sequential inodes `300000 + idx`, no `.` entry, 4-byte alignment).
   - Enforced clean workspace creation (`rm -rf "$WORK_DIR"`).
   - Fixed `/sbin/busybox` applet symlink targets and set `sbin` directory mode to `0755`.
   - Enforced strict SHA256 pre-flight validation on the baseline image, BusyBox, and `lpmode`.
5. **Final Status**: **Classification A: 100% BIT-FOR-BIT REPRODUCIBLE WITH CANONICAL FINAL2**. Three consecutive clean builds independently reproduced `recovery.img` with SHA256 `261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a`.

---

## 2. Input Artifacts & Verification

All baseline inputs were cryptographically validated prior to experimentation:

| Component | Path / Provenance | Expected SHA256 | Actual SHA256 |
| :--- | :--- | :--- | :--- |
| **Canonical Baseline** | `/home/w11user/Pictures/demo/recovery_fastbootd_adb_user.img` | `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce` | `8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce` |
| **Precompiled `lpmode`** | `src/lpmode/lpmode_stripped` | `20cd4d0014b920f5b799bd4ab03d93838886ecdcfff4e186a5b038070b4f0ae2` | `20cd4d0014b920f5b799bd4ab03d93838886ecdcfff4e186a5b038070b4f0ae2` |
| **Magisk v30.7 APK** | `/home/w11user/Downloads/Magisk-v30.7.apk` | (Official release) | `e0d32d2123532860f97123d927b1bb86c4e08e6fd8a48bfc6b5bee0afae9ebd5` |
| **Extracted BusyBox** | Extracted `lib/arm64-v8a/libbusybox.so` | `4d60ab3f5a59ebb2ca863f2f514e6924401b581e9b64f602665c008177626651` | `4d60ab3f5a59ebb2ca863f2f514e6924401b581e9b64f602665c008177626651` |
| **Target Milestone** | Canonical `final2` `recovery.img` | `261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a` | `261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a` |

---

## 3. Reproduction of Non-Determinism

To demonstrate the initial failure, the unmodified build script was executed twice into separate clean directories (`/tmp/build_test_1` and `/tmp/build_test_2`):

- **Build 1 `recovery.img` SHA256**: `5860dbfad3d2f07f68ba2007fdf3f2902915c854956034f325b8e1298df8e10f`
- **Build 2 `recovery.img` SHA256**: `a8c5f41ecf50898185d39737a44519530ccd947540f9d1809be61b1022fd2468`
- **Build 1 `ramdisk.cpio` SHA256**: `91ee912c48601299cf74c9ea3cb259a0e968a234a0a9e6e6126ad03f487a7408`
- **Build 2 `ramdisk.cpio` SHA256**: `73e77261e5708623dfd9cc371ede042a77d2e16250d14ba3814f4883edbf31f4`

Both builds used identical inputs and identical commands, yet produced divergent whole-image hashes.

---

## 4. Analysis of Differences (Build 1 vs Build 2 vs Final2)

Decoding and comparing the raw partition segments and CPIO headers revealed the following:

### 1. Boot Image Segments
- **Kernel** (23,717,904 bytes, SHA256: `648a657d...`): **100% bit-identical** in all builds.
- **DTB** (179,505 bytes, SHA256: `b66c3f3e...`): **100% bit-identical** in all builds.
- **Recovery DTBO** (494,126 bytes, SHA256: `09672a38...`): **100% bit-identical** in all builds.
- **Boot Header Differences**:
  - The boot header differed only in `ramdisk_size` and the SHA-1 checksum `id`.
  - When `ramdisk_size` differed by even a few bytes across 2048-byte page boundaries, `recovery_dtbo_offset` shifted from `0x2257800` (final2) to `0x2258000` (build 1 & 2), displacing the trailing partitions by 1 page.

### 2. CPIO Metadata Analysis (Build 1 vs Build 2)
Comparing all 440 entries in Build 1's CPIO against Build 2's CPIO:
- **Zero Content Differences**: Exactly 0 files differed in file size or payload hash.
- **Metadata Fluctuations**:
  - `ino` (inodes): Every single entry differed (e.g., `.` had inode `4722` in B1 vs `5171` in B2).
  - `mtime` (timestamps): Every newly created entry reflected the host system wall-clock execution time.

### 3. Comparison with Canonical `final2` CPIO
- **Entry Count**: `final2` contains **439 entries**; legacy automated builds contained **440 entries**.
- **Root Directory Entry**: Legacy builds included an explicit `.` entry created by `find .`. Canonical `final2` did **not** include `.`.
- **Inode Sequence**: `final2` assigned sequential inodes starting at `300000` (`ino = 300000 + idx`).
- **Timestamps**: `final2` had `mtime = 0` across all 439 entries.
- **Symlink Targets**: In `final2`, `sbin/unzip`, `sbin/awk`, and `sbin/hexdump` pointed to `/sbin/busybox` (13 bytes). In legacy builds, they pointed to relative `busybox` (7 bytes).
- **Directory Mode**: In `final2`, `sbin` had mode `0755` (`0o40755`). Legacy builds created `sbin` without explicit `chmod`, resulting in `0o40775` due to host umask.

---

## 5. Implementation of Fixes

The following hardening measures were implemented in the repository:

1. **Deterministic CPIO Packer ([`scripts/pack-cpio.py`](file:///media/GooningData/fastbootd-recovery/github_repo/scripts/pack-cpio.py))**:
   - Replaced `find . | cpio -H newc -o` with a Python script that traverses the directory tree using `os.scandir`.
   - Sorts all entry names in strict ASCII lexicographical order.
   - Enforces `mtime = 0`, `uid = 0`, `gid = 0`, `nlink = 1`, and `ino = 300000 + idx`.
   - Omits the root directory `.` entry.
   - Emits 4-byte aligned records with standard `TRAILER!!!` (mode `0755`) without trailing 512-byte block padding, perfectly matching `magiskboot cpio` output.
2. **Deterministic & Canonical Odin TAR Packaging ([`scripts/pack-tar.py`](file:///media/GooningData/fastbootd-recovery/github_repo/scripts/pack-tar.py))**:
   - Replaced host-dependent TAR generation with a standalone deterministic Python packer (`scripts/pack-tar.py`).
   - Forensic analysis of the historical release TAR (`51e9a33e27d9d0b2849192d1c7acf88e62958a7fd4fc6121dc658b1c1649c48b`) revealed that it was packaged using GNU tar format (`magic = b"ustar  \0"`) with:
     * `name`: `recovery.img`
     * `mode`: `0000644\0` (mode 0644)
     * `uid`: `0001750\0` (1000)
     * `gid`: `0001750\0` (1000)
     * `mtime`: `15253427242\0` (Unix timestamp `1789800098`, `2026-09-19 06:41:38 UTC`)
     * `uname`: `w11user`
     * `gname`: `w11user`
     * Standard 20-block record alignment (7 trailing zero blocks = 3,584 bytes).
   - Packaging with these canonical metadata attributes reproduces the historical canonical Odin TAR `51e9a33e...` byte-for-byte (`cmp` exit code 0).
   - An alternative epoch-0 normalized TAR (`ec93fb8cd08060adc5a76b711eb0116d031ea118ca51f80bd5061d15d85bd18b`) using `--mtime='@0' --owner=0 --group=0 --numeric-owner` was also tested and documented during initial auditing.
3. **Build Script Cleanliness ([`scripts/build-recovery.sh`](file:///media/GooningData/fastbootd-recovery/github_repo/scripts/build-recovery.sh))**:
   - Enforced `rm -rf "$WORK_DIR"` before unpacking to eliminate cross-build pollution and `os error 17` extract aborts.
   - Corrected `/sbin/busybox` applet symlink targets to `/sbin/busybox`.
   - Explicitly enforced `chmod 0755 "$WORK_DIR/ramdisk_root/sbin"`.
   - Replaced permissive fallback warnings with hard fatal exits on input and output hash mismatches.
   - Validated that TAR packaging does not alter `recovery.img` contents.
4. **Enhanced Verification ([`scripts/verify-recovery.py`](file:///media/GooningData/fastbootd-recovery/github_repo/scripts/verify-recovery.py))**:
   - Added verification for `ro.adb.secure=0` in `prop.default`.
   - Added exact string matching for the `init.rc` `lpmode-run` hook.
   - Added explicit symlink target verification (`sbin/sh`, `sbin/busybox` applets, `system/bin/blkid`, `default.prop`).
   - Added permission mode checks on critical directories and binaries.
   - Added boot image v2 header and component SHA256 verification against canonical final2.

---

## 6. Three-Run Reproducibility Test

Using the updated script, three full builds were executed from scratch in separate workspaces:

```text
=== RUN 1 ===
recovery.img:         261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a
recovery_patched.tar: 51e9a33e27d9d0b2849192d1c7acf88e62958a7fd4fc6121dc658b1c1649c48b
work/ramdisk.cpio:    1550ee14937a8828fc312d70e027606d8071802f05503848cc6b4367f2bcb91c

=== RUN 2 ===
recovery.img:         261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a
recovery_patched.tar: 51e9a33e27d9d0b2849192d1c7acf88e62958a7fd4fc6121dc658b1c1649c48b
work/ramdisk.cpio:    1550ee14937a8828fc312d70e027606d8071802f05503848cc6b4367f2bcb91c

=== RUN 3 ===
recovery.img:         261f5c284a823cc8f9e309b4d589ca83cb6a98720d356c2e362a787b7449224a
recovery_patched.tar: 51e9a33e27d9d0b2849192d1c7acf88e62958a7fd4fc6121dc658b1c1649c48b
work/ramdisk.cpio:    1550ee14937a8828fc312d70e027606d8071802f05503848cc6b4367f2bcb91c
```

Binary comparison with historical canonical `final2`:
```bash
cmp /tmp/build_run1/recovery.img /media/GooningData/fastbootd-recovery/root_permissive_multiformat_lpmapped_final2/recovery.img
# Exit code 0 (Bit-for-bit identical)
cmp /tmp/build_run1/recovery_patched.tar /media/GooningData/fastbootd-recovery/root_permissive_multiformat_lpmapped_final2/recovery_root_permissive_multiformat_lpmapped_final2.tar
# Exit code 0 (Bit-for-bit identical)
cmp /tmp/build_run1/recovery_patched.tar /tmp/build_run2/recovery_patched.tar
# Exit code 0 (Bit-for-bit identical)
cmp /tmp/build_run2/recovery_patched.tar /tmp/build_run3/recovery_patched.tar
# Exit code 0 (Bit-for-bit identical)
```

---

## 7. Audit Conclusion

- **Classification**: **A. HISTORICAL TAR REPRODUCED BIT-FOR-BIT**
- Both `recovery.img` (`261f5c28...`) and the historical canonical Odin TAR `recovery_patched.tar` (`51e9a33e...`) are 100% deterministic and byte-for-byte reproducible across clean runs.
- The build pipeline is now completely deterministic and certified to produce historical canonical `final2` bit-identical artifacts.
