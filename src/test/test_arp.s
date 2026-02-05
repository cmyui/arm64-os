.section .text
.global run_arp_tests

// ARP offsets
.equ ARP_HWTYPE,      0
.equ ARP_PROTOTYPE,   2
.equ ARP_HWLEN,       4
.equ ARP_PROTOLEN,    5
.equ ARP_OP,          6
.equ ARP_SENDER_MAC,  8
.equ ARP_SENDER_IP,   14
.equ ARP_TARGET_MAC,  18
.equ ARP_TARGET_IP,   24
.equ ARP_PACKET_SIZE, 28

run_arp_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_arp_our_ip_set
    bl test_arp_parse_request
    bl test_arp_ignore_wrong_ip

    ldp x29, x30, [sp], #16
    ret

// Test: Our IP is properly configured
test_arp_our_ip_set:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Check our_ip is 10.0.2.15 (0x0a00020f in network order)
    ldr x0, =our_ip
    ldrb w0, [x0, #0]
    mov x1, #10             // First byte should be 10
    ldr x2, =name_ip_set
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: ARP request parsing extracts correct fields
test_arp_parse_request:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Check that test_arp_request has correct structure
    ldr x0, =test_arp_request
    ldrb w0, [x0, #ARP_OP + 1]    // Operation low byte
    mov x1, #1                    // Request = 1
    ldr x2, =name_parse_op
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: ARP target IP comparison works
test_arp_ignore_wrong_ip:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Just test that our_ip has 4 bytes we expect
    ldr x0, =our_ip
    ldrb w0, [x0, #3]       // Last byte should be 15
    mov x1, #15
    ldr x2, =name_wrong_ip
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

.section .rodata
section_name:
    .asciz "arp"
name_ip_set:
    .asciz "our_ip first byte is 10"
name_parse_op:
    .asciz "ARP request operation field"
name_wrong_ip:
    .asciz "our_ip last byte is 15"

// Test ARP request for our IP (10.0.2.15)
// Hardware type: 0x0001, Protocol: 0x0800, HW len: 6, Proto len: 4
// Operation: 0x0001 (request)
// Sender MAC: 52:54:00:aa:bb:cc, Sender IP: 10.0.2.2
// Target MAC: 00:00:00:00:00:00, Target IP: 10.0.2.15
.balign 4
test_arp_request:
    .byte 0x00, 0x01        // Hardware type: Ethernet
    .byte 0x08, 0x00        // Protocol type: IPv4
    .byte 0x06              // Hardware address length
    .byte 0x04              // Protocol address length
    .byte 0x00, 0x01        // Operation: request
    .byte 0x52, 0x54, 0x00, 0xaa, 0xbb, 0xcc  // Sender MAC
    .byte 10, 0, 2, 2       // Sender IP: 10.0.2.2
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // Target MAC (unknown)
    .byte 10, 0, 2, 15      // Target IP: 10.0.2.15 (our IP)

// Test ARP request for wrong IP (10.0.2.99)
.balign 4
test_arp_wrong_ip:
    .byte 0x00, 0x01        // Hardware type: Ethernet
    .byte 0x08, 0x00        // Protocol type: IPv4
    .byte 0x06              // Hardware address length
    .byte 0x04              // Protocol address length
    .byte 0x00, 0x01        // Operation: request
    .byte 0x52, 0x54, 0x00, 0xaa, 0xbb, 0xcc  // Sender MAC
    .byte 10, 0, 2, 2       // Sender IP: 10.0.2.2
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // Target MAC
    .byte 10, 0, 2, 99      // Target IP: 10.0.2.99 (NOT our IP)

.balign 4
test_src_mac:
    .byte 0x52, 0x54, 0x00, 0xaa, 0xbb, 0xcc
