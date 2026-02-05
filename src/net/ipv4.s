.section .text
.global ip_recv
.global ip_send
.global ip_checksum
.global ip_pseudo_checksum

// IP header offsets
.equ IP_VER_IHL,     0
.equ IP_TOS,         1
.equ IP_TOTAL_LEN,   2
.equ IP_ID,          4
.equ IP_FLAGS_FRAG,  6
.equ IP_TTL,         8
.equ IP_PROTOCOL,    9
.equ IP_CHECKSUM,    10
.equ IP_SRC,         12
.equ IP_DST,         16
.equ IP_HEADER_SIZE, 20

// Protocol numbers
.equ IP_PROTO_TCP,   6

// Ethernet constants
.equ ETHERTYPE_IPV4, 0x0800
.equ ETH_HEADER_SIZE, 14

// ip_recv: Handle incoming IP packet
// Input: x0 = IP packet data (after Ethernet header)
//        x1 = length
ip_recv:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0             // IP packet pointer
    mov x20, x1             // length

    // Check minimum length
    cmp x20, #IP_HEADER_SIZE
    b.lt .ip_recv_done

    // Check version (should be 4) and IHL (should be 5)
    ldrb w0, [x19, #IP_VER_IHL]
    cmp w0, #0x45
    b.ne .ip_recv_done      // Only handle IPv4 with no options

    // Verify checksum
    mov x0, x19
    mov x1, #IP_HEADER_SIZE
    bl ip_checksum
    cbz w0, .cksum_ok

    // Debug: checksum failed
    stp x19, x20, [sp, #-16]!
    ldr x0, =msg_cksum_fail
    bl uart_puts
    ldp x19, x20, [sp], #16
    b .ip_recv_done

.cksum_ok:

    // Get protocol
    ldrb w21, [x19, #IP_PROTOCOL]

    // Get source IP (for TCP handler)
    add x22, x19, #IP_SRC

    // Calculate payload pointer and length
    add x0, x19, #IP_HEADER_SIZE

    // Get total length from header (big-endian)
    ldrb w1, [x19, #IP_TOTAL_LEN]
    ldrb w2, [x19, #IP_TOTAL_LEN + 1]
    lsl w1, w1, #8
    orr w1, w1, w2
    sub x1, x1, #IP_HEADER_SIZE     // payload length

    // Dispatch based on protocol
    cmp w21, #IP_PROTO_TCP
    b.eq .dispatch_tcp

    // Unknown protocol - ignore
    b .ip_recv_done

.dispatch_tcp:
    // Debug: print before tcp_handle
    stp x0, x1, [sp, #-16]!
    stp x2, x3, [sp, #-16]!
    stp x19, x22, [sp, #-16]!
    ldr x0, =msg_tcp_dispatch
    bl uart_puts
    ldp x19, x22, [sp], #16
    ldp x2, x3, [sp], #16
    ldp x0, x1, [sp], #16

    mov x2, x22             // source IP
    mov x3, x19             // IP header (for pseudo-header)
    bl tcp_handle
    b .ip_recv_done

.ip_recv_done:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ip_send: Send IP packet
// Input: x0 = dest IP (32-bit value, big-endian)
//        x1 = protocol
//        x2 = payload pointer
//        x3 = payload length
ip_send:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    mov w19, w0             // dest IP
    mov w20, w1             // protocol
    mov x21, x2             // payload pointer
    mov x22, x3             // payload length

    // Use tx buffer
    ldr x23, =ip_tx_buffer

    // First, we need the destination MAC
    // For now, assume gateway_mac is set (from ARP)
    ldr x24, =gateway_mac

    // Build Ethernet header
    mov x0, x23
    mov x1, x24             // dest MAC (gateway)
    mov x2, #ETHERTYPE_IPV4
    bl eth_build_header
    mov x23, x0             // Now points to IP header start

    // Build IP header (all byte stores for unaligned access)
    // Version/IHL = 0x45
    mov w0, #0x45
    strb w0, [x23, #IP_VER_IHL]

    // TOS = 0
    strb wzr, [x23, #IP_TOS]

    // Total length = header + payload (big-endian)
    add w0, w22, #IP_HEADER_SIZE
    lsr w1, w0, #8
    strb w1, [x23, #IP_TOTAL_LEN]
    strb w0, [x23, #IP_TOTAL_LEN + 1]

    // ID = 0 (we don't fragment) - use byte stores
    strb wzr, [x23, #IP_ID]
    strb wzr, [x23, #IP_ID + 1]

    // Flags/Fragment = 0x4000 (Don't Fragment, big-endian = 0x40 0x00)
    mov w0, #0x40
    strb w0, [x23, #IP_FLAGS_FRAG]
    strb wzr, [x23, #IP_FLAGS_FRAG + 1]

    // TTL = 64
    mov w0, #64
    strb w0, [x23, #IP_TTL]

    // Protocol
    strb w20, [x23, #IP_PROTOCOL]

    // Checksum = 0 initially - use byte stores
    strb wzr, [x23, #IP_CHECKSUM]
    strb wzr, [x23, #IP_CHECKSUM + 1]

    // Source IP = our IP (use byte stores for unaligned access)
    ldr x0, =our_ip
    ldrb w1, [x0, #0]
    strb w1, [x23, #IP_SRC]
    ldrb w1, [x0, #1]
    strb w1, [x23, #IP_SRC + 1]
    ldrb w1, [x0, #2]
    strb w1, [x23, #IP_SRC + 2]
    ldrb w1, [x0, #3]
    strb w1, [x23, #IP_SRC + 3]

    // Dest IP (use byte stores for unaligned access)
    // w19 has bytes packed as: byte0 in bits 24-31, byte1 in bits 16-23, etc.
    // Need to store in network byte order (big-endian): first byte at lowest address
    lsr w0, w19, #24
    strb w0, [x23, #IP_DST]          // byte 0 (first/high byte)
    lsr w0, w19, #16
    strb w0, [x23, #IP_DST + 1]      // byte 1
    lsr w0, w19, #8
    strb w0, [x23, #IP_DST + 2]      // byte 2
    strb w19, [x23, #IP_DST + 3]     // byte 3 (last/low byte)

    // Calculate checksum
    mov x0, x23
    mov x1, #IP_HEADER_SIZE
    bl ip_checksum
    // Result is already in one's complement, store it (big-endian)
    lsr w1, w0, #8
    strb w1, [x23, #IP_CHECKSUM]
    strb w0, [x23, #IP_CHECKSUM + 1]

    // Copy payload after IP header
    add x0, x23, #IP_HEADER_SIZE
    mov x1, x21
    mov x2, x22
    bl ip_memcpy

    // Send the complete frame
    ldr x0, =ip_tx_buffer
    add x1, x22, #(ETH_HEADER_SIZE + IP_HEADER_SIZE)
    bl eth_send

    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ip_checksum: Calculate IP checksum (one's complement sum)
// Input: x0 = data pointer, x1 = length (must be even)
// Returns: x0 = checksum (0 if valid header)
ip_checksum:
    mov x2, #0              // accumulator
    mov x3, x0              // data pointer
    mov x4, x1              // length

.ip_cksum_loop:
    cmp x4, #2
    b.lt .ip_cksum_fold

    // Load 16-bit word (big-endian)
    ldrb w5, [x3], #1
    ldrb w6, [x3], #1
    lsl w5, w5, #8
    orr w5, w5, w6

    add x2, x2, x5
    sub x4, x4, #2
    b .ip_cksum_loop

.ip_cksum_fold:
    // Fold 32-bit sum to 16 bits
    lsr x5, x2, #16
    and x2, x2, #0xFFFF
    add x2, x2, x5

    // Fold again if needed
    lsr x5, x2, #16
    and x2, x2, #0xFFFF
    add x2, x2, x5

    // One's complement
    mvn w0, w2
    and w0, w0, #0xFFFF

    ret

// ip_pseudo_checksum: Calculate TCP pseudo-header checksum
// Input: x0 = src IP (pointer), x1 = dst IP (pointer), x2 = protocol, x3 = tcp length
// Returns: x0 = partial checksum
ip_pseudo_checksum:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x4, #0              // accumulator

    // Source IP (4 bytes as 2 x 16-bit)
    ldrb w5, [x0, #0]
    ldrb w6, [x0, #1]
    lsl w5, w5, #8
    orr w5, w5, w6
    add x4, x4, x5

    ldrb w5, [x0, #2]
    ldrb w6, [x0, #3]
    lsl w5, w5, #8
    orr w5, w5, w6
    add x4, x4, x5

    // Dest IP (4 bytes as 2 x 16-bit)
    ldrb w5, [x1, #0]
    ldrb w6, [x1, #1]
    lsl w5, w5, #8
    orr w5, w5, w6
    add x4, x4, x5

    ldrb w5, [x1, #2]
    ldrb w6, [x1, #3]
    lsl w5, w5, #8
    orr w5, w5, w6
    add x4, x4, x5

    // Zero + Protocol (as 16-bit)
    add x4, x4, x2

    // TCP length (as 16-bit, already in host order)
    add x4, x4, x3

    mov x0, x4

    ldp x29, x30, [sp], #16
    ret

// ip_memcpy: Copy memory
// Input: x0 = dest, x1 = src, x2 = len
ip_memcpy:
    cbz x2, .ip_memcpy_done
.ip_memcpy_loop:
    ldrb w3, [x1], #1
    strb w3, [x0], #1
    subs x2, x2, #1
    b.ne .ip_memcpy_loop
.ip_memcpy_done:
    ret

.section .rodata
msg_tcp_dispatch:
    .asciz "->TCP "
msg_cksum_fail:
    .asciz "CKSUM!"
msg_before_store:
    .asciz "ip="

.section .bss
.balign 8
ip_tx_buffer:
    .skip 1600              // Max Ethernet frame size
