# system/bin/recovery Binary Patches

Target: Samsung Galaxy A03 SM-A035F (`system/bin/recovery` AArch64)

## Patch 1: Metadata Fallback Bypass (Non-A/B Fallback)
- **Offset / VA**: `0x3d494`
- **Original Bytes**: `60 0c 00 36` (`tbz w0, #0, 0x3d620`)
- **Patched Bytes**: `40 1b 00 36` (`tbz w0, #0, 0x3d7fc`)
- **Mechanism**:
  Inside `InstallPackage()`, Samsung checks for `META-INF/com/android/metadata` via `Package::GetMetadata()`. Standard flashable ZIPs (such as Magisk) do not have this file and normally cause Samsung recovery to abort with `INSTALL_CORRUPT` at `0x3d620`.
  Branching to `0x3d7fc` bypasses the abort and falls directly into Samsung's existing `SetUpNonAbUpdatePackage()` engine at `0x3cda8`, which extracts `META-INF/com/google/android/update-binary` to `/tmp/update-binary` and executes it.

## Patch 2: Unsigned Package Verification Bypass
- **Offset / VA**: `0x3f6bc`
- **Original Bytes**: `b4 04 00 34` (`cbz w20, #0x3f750`)
- **Patched Bytes**: `25 00 00 14` (`b #0x3f750`)
- **Mechanism**:
  Bypasses the signature verification error check inside the package verification flow, treating any package as having passed signature check regardless of signing key or test keys.
