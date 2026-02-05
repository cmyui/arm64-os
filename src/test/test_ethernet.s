.section .text
.global run_ethernet_tests

.equ ETH_HEADER_SIZE, 14
.equ ETHERTYPE_ARP, 0x0806
.equ ETHERTYPE_IPV4, 0x0800

run_ethernet_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_eth_build_header_dest_mac
    bl test_eth_build_header_src_mac
    bl test_eth_build_header_ethertype
    bl test_eth_build_header_returns_payload_ptr

    ldp x29, x30, [sp], #16
    ret

// Test: eth_build_header sets destination MAC correctly
test_eth_build_header_dest_mac:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Set up test data
    ldr x0, =test_buffer
    ldr x1, =test_dest_mac
    mov x2, #ETHERTYPE_ARP
    bl eth_build_header

    // Check destination MAC (first 6 bytes)
    ldr x0, =test_buffer
    ldr x1, =test_dest_mac
    mov x2, #6
    ldr x3, =name_dest_mac
    bl test_assert_mem_eq

    ldp x29, x30, [sp], #16
    ret

// Test: eth_build_header sets source MAC (our MAC) correctly
test_eth_build_header_src_mac:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Set up test - need to set our_mac first
    ldr x0, =our_mac
    ldr x1, =test_src_mac
    mov x2, #6
    bl test_memcpy

    // Build header
    ldr x0, =test_buffer
    ldr x1, =test_dest_mac
    mov x2, #ETHERTYPE_ARP
    bl eth_build_header

    // Check source MAC (bytes 6-11)
    ldr x0, =test_buffer
    add x0, x0, #6
    ldr x1, =test_src_mac
    mov x2, #6
    ldr x3, =name_src_mac
    bl test_assert_mem_eq

    ldp x29, x30, [sp], #16
    ret

// Test: eth_build_header sets EtherType correctly (big-endian)
test_eth_build_header_ethertype:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =test_buffer
    ldr x1, =test_dest_mac
    mov x2, #ETHERTYPE_ARP      // 0x0806
    bl eth_build_header

    // Check EtherType at offset 12-13 (big-endian: 08 06)
    ldr x0, =test_buffer
    ldrb w0, [x0, #12]
    mov x1, #0x08               // High byte
    ldr x2, =name_ethertype_hi
    bl test_assert_eq

    ldr x0, =test_buffer
    ldrb w0, [x0, #13]
    mov x1, #0x06               // Low byte
    ldr x2, =name_ethertype_lo
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: eth_build_header returns pointer to payload (after header)
test_eth_build_header_returns_payload_ptr:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =test_buffer
    mov x19, x0                 // Save buffer start
    ldr x1, =test_dest_mac
    mov x2, #ETHERTYPE_IPV4
    bl eth_build_header

    // x0 should be test_buffer + 14
    add x1, x19, #ETH_HEADER_SIZE
    ldr x2, =name_payload_ptr
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Helper: memcpy
// Input: x0 = dest, x1 = src, x2 = len
test_memcpy:
    cbz x2, .memcpy_done
.memcpy_loop:
    ldrb w3, [x1], #1
    strb w3, [x0], #1
    subs x2, x2, #1
    b.ne .memcpy_loop
.memcpy_done:
    ret

.section .rodata
section_name:
    .asciz "ethernet"
name_dest_mac:
    .asciz "eth_build_header dest MAC"
name_src_mac:
    .asciz "eth_build_header src MAC"
name_ethertype_hi:
    .asciz "eth_build_header ethertype high byte"
name_ethertype_lo:
    .asciz "eth_build_header ethertype low byte"
name_payload_ptr:
    .asciz "eth_build_header returns payload ptr"

// Test data
test_dest_mac:
    .byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff  // broadcast
test_src_mac:
    .byte 0x52, 0x54, 0x00, 0x12, 0x34, 0x56  // test MAC

.section .bss
.balign 8
test_buffer:
    .skip 64
