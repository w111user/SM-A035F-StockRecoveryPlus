# system/bin/init Binary Patches

Target: Samsung Galaxy A03 SM-A035F (`system/bin/init` AArch64)

## Global SELinux Permissive
- **Offset**: `0xeb4c0`
- **Original Bytes**: `20 00 80 52` (`mov w0, #1`)
- **Patched Bytes**: `e0 03 1f 2a` (`mov w0, wzr`)
- **Mechanism**:
  Sets default SELinux enforcement variable to 0 (Permissive) at early init before policy enforcement kicks in, avoiding denials across custom recovery tooling and sideload execution.
