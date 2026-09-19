# system/bin/adbd Binary Patches

Target: Samsung Galaxy A03 SM-A035F (`system/bin/adbd` AArch64)

These patches bypass privilege-drop routines in `adbd` to maintain persistent root access (`uid=0`, `gid=0`, full Linux capabilities):

1. **Offset `0x883f8`**:
   - Original: `80 00 00 35` (`cbnz w0, #0x88408`)
   - Patched:  `04 00 00 14` (`b #0x88408`)
   - Unconditional branch through privilege-retention path / bypasses a privilege-drop-related conditional.

2. **Offset `0x88410`**:
   - Original: `fe d8 01 94` (`bl <helper>`)
   - Patched:  `1f 20 03 d5` (`nop`)
   - NOPs one privilege-drop helper call in the adbd drop-privileges path.

3. **Offset `0x8841c`**:
   - Original: `e8 d8 01 94` (`bl <helper>`)
   - Patched:  `1f 20 03 d5` (`nop`)
   - NOPs another privilege-drop helper call in the adbd drop-privileges path.

4. **Offset `0x884e4`**:
   - Original: `9b d8 01 94` (`bl <helper>`)
   - Patched:  `e0 03 1f 2a` (`mov w0, wzr`)
   - Replaces a helper call with a successful zero return value, preserving the proven root/capability behavior.
