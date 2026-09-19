// lpmode.s — AArch64 assembly for lpmode
// Dynamic linker: /system/bin/linker64
// Links against: libfs_mgr.so, libc++.so, libc.so, liblog.so
//
// Function:
//   1. Check /dev/block/by-name/super exists (access)
//   2. Construct std::string("/dev/block/by-name/super")
//   3. Call android::fs_mgr::CreateLogicalPartitions(const std::string&)
//   4. Log result to stderr
//   5. exit(0) on success, exit(1) on failure
//
// AArch64 calling convention:
//   x0-x7  : arguments
//   x0      : return value
//   x30     : link register (lr)
//   sp      : stack pointer (16-byte aligned)
//   x19-x28 : callee-saved

    .text
    .balign 4

    // ==============================================================
    // _start — entry point (replaces CRT startup)
    // ==============================================================
    .globl _start
    .type  _start, @function
_start:
    // Set up a proper stack frame for nested calls
    // We need:
    //   - 24 bytes for std::string object on stack
    //   - 8 bytes for x30 save
    //   - 8 bytes padding (alignment)
    //   Total: 48 bytes
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp

    // --- Step 1: Check /dev/block/by-name/super exists ---
    adrp    x0, superdev
    add     x0, x0, :lo12:superdev
    mov     x1, #0              // F_OK
    bl      access
    // x0 = 0 on success, -1 if not found
    cbnz    x0, .Lno_super

    // --- Step 2: Construct std::string on stack ---
    // std::string object is at [sp+16] (24 bytes)
    // Zero-initialize the string object first
    add     x19, sp, #16        // x19 = &str (callee-saved)
    stp     xzr, xzr, [x19]
    str     xzr, [x19, #16]
    // Call __init(const char* ptr, size_t len)
    // x0 = this, x1 = ptr, x2 = len
    mov     x0, x19             // this = &str
    adrp    x1, superdev
    add     x1, x1, :lo12:superdev
    mov     x2, #26             // strlen("/dev/block/by-name/super") = 26
    bl      _ZNSt3__112basic_stringIcNS_11char_traitsIcEENS_9allocatorIcEEE6__initEPKcm

    // --- Step 3: Call CreateLogicalPartitions(&str) ---
    mov     x0, x19             // x0 = &str (const std::string&)
    bl      _ZN7android6fs_mgr23CreateLogicalPartitionsERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE
    // x0 = bool (1 = success, 0 = failure)
    mov     x20, x0             // save result (callee-saved)

    // --- Step 4: Destroy std::string ---
    mov     x0, x19
    bl      _ZNSt3__112basic_stringIcNS_11char_traitsIcEENS_9allocatorIcEEED1Ev

    // --- Step 5: Log to stderr and exit ---
    cbz     x20, .Lfail

    // success
    adrp    x1, msg_ok
    add     x1, x1, :lo12:msg_ok
    mov     x0, #2              // stderr fd
    adrp    x2, msg_ok_end
    add     x2, x2, :lo12:msg_ok_end
    sub     x2, x2, x1         // length
    bl      write
    mov     x0, #0
    bl      _exit

.Lfail:
    // CreateLogicalPartitions returned false
    adrp    x1, msg_fail
    add     x1, x1, :lo12:msg_fail
    mov     x0, #2
    adrp    x2, msg_fail_end
    add     x2, x2, :lo12:msg_fail_end
    sub     x2, x2, x1
    bl      write
    mov     x0, #1
    bl      _exit

.Lno_super:
    // /dev/block/by-name/super does not exist
    adrp    x1, msg_nosuper
    add     x1, x1, :lo12:msg_nosuper
    mov     x0, #2
    adrp    x2, msg_nosuper_end
    add     x2, x2, :lo12:msg_nosuper_end
    sub     x2, x2, x1
    bl      write
    mov     x0, #1
    bl      _exit

    // .size _start, . - _start

    // ==============================================================
    // Read-only data
    // ==============================================================
    .section .rodata, "a", @progbits
    .balign 8

superdev:
    .asciz  "/dev/block/by-name/super"
    .balign 4

msg_ok:
    .ascii  "lpmode: CreateLogicalPartitions OK\n"
msg_ok_end:
    .balign 4

msg_fail:
    .ascii  "lpmode: CreateLogicalPartitions FAILED\n"
msg_fail_end:
    .balign 4

msg_nosuper:
    .ascii  "lpmode: /dev/block/by-name/super not found, skipping\n"
msg_nosuper_end:
    .balign 4
