.section .text
.global run_ipv4_tests

run_ipv4_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_ip_checksum_zero
    bl test_ip_checksum_known

    ldp x29, x30, [sp], #16
    ret

// Test: Checksum of all zeros should be 0xFFFF
test_ip_checksum_zero:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =test_zeros
    mov x1, #20
    bl ip_checksum

    // Checksum of zeros = ~0 = 0xFFFF
    mov x1, #0xFFFF
    ldr x2, =name_cksum_zero
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: Checksum of known header should be valid
test_ip_checksum_known:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // This header has a valid checksum embedded
    // Verifying it should give 0
    ldr x0, =test_ip_header_valid
    mov x1, #20
    bl ip_checksum

    // If header is valid, checksum should be 0
    mov x1, #0
    ldr x2, =name_cksum_valid
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

.section .rodata
section_name:
    .asciz "ipv4"
name_cksum_zero:
    .asciz "ip_checksum of zeros"
name_cksum_valid:
    .asciz "ip_checksum validates header"

// Test data
.balign 4
test_zeros:
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

// Known valid IP header (with correct checksum)
// Version: 4, IHL: 5, TOS: 0, Length: 40 (0x0028)
// ID: 0x1234, Flags: 0x4000 (DF)
// TTL: 64, Protocol: 6 (TCP)
// Src: 10.0.2.15, Dst: 10.0.2.2
// Checksum calculation:
// 0x4500 + 0x0028 + 0x1234 + 0x4000 + 0x4006 + 0x0a00 + 0x020f + 0x0a00 + 0x0202 = 0xEF73
// ~0xEF73 = 0x108C (but need to mask to 16 bits properly)
// Actually: 0xFFFF - 0xEF73 + 1 would be two's complement
// One's complement: just invert = 0x108C (but this is > 16 bits)
// Wait: ~0xEF73 in 16 bits is indeed 0x108C & 0xFFFF = 0x108C which is fine
.balign 4
test_ip_header_valid:
    .byte 0x45, 0x00        // Version/IHL, TOS
    .byte 0x00, 0x28        // Total length: 40
    .byte 0x12, 0x34        // ID
    .byte 0x40, 0x00        // Flags/Fragment (DF)
    .byte 0x40, 0x06        // TTL: 64, Protocol: TCP
    .byte 0x10, 0x8c        // Checksum = 0x108C in big-endian
    .byte 10, 0, 2, 15      // Source IP
    .byte 10, 0, 2, 2       // Dest IP
