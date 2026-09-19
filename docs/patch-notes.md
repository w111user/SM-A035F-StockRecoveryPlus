# Binary Patch Notes

All binary patches in this repository apply directly to AArch64 machine code found in the **working ADB user-shell milestone recovery base** (`8ff126c0acd2906c2dd4ce4942f1261f72b70e6cf4a8aa5b08f86e3864e0afce`, extracted from `recover.tar`).

## 1. `system/bin/recovery`
- **Metadata Fallback (`0x3d494`)**:
  - `60 0c 00 36` (`tbz w0, #0, 0x3d620`) -> `40 1b 00 36` (`tbz w0, #0, 0x3d7fc`)
  - Prevents early abort when `META-INF/com/android/metadata` is missing. Bypasses the error path and triggers `SetUpNonAbUpdatePackage()`.
- **Signature Bypass (`0x3f6bc`)**:
  - `b4 04 00 34` (`cbz w20, #0x3f750`) -> `25 00 00 14` (`b #0x3f750`)
  - Ensures `verify_file()` logic always branches to success, allowing unsigned sideload and SD-card updates.

## 2. `system/bin/adbd`
- **Privilege Retention**:
  - `0x883f8`: `80 00 00 35` -> `04 00 00 14` (unconditional branch through privilege-retention path / bypasses a privilege-drop-related conditional)
  - `0x88410`: `fe d8 01 94` -> `1f 20 03 d5` (NOPs one privilege-drop helper call in the adbd drop-privileges path)
  - `0x8841c`: `e8 d8 01 94` -> `1f 20 03 d5` (NOPs another privilege-drop helper call in the adbd drop-privileges path)
  - `0x884e4`: `9b d8 01 94` -> `e0 03 1f 2a` (replaces a helper call with a successful zero return value, preserving the proven root/capability behavior)

## 3. `system/bin/init`
- **SELinux Permissive (`0xeb4c0`)**:
  - `20 00 80 52` -> `e0 03 1f 2a` (`mov w0, wzr`)
  - Overrides enforcing initialization flag to 0.
