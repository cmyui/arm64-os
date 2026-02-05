.section .text
.global eth_send
.global eth_recv
.global eth_build_header

// EtherType values
.equ ETHERTYPE_ARP,  0x0806
.equ ETHERTYPE_IPV4, 0x0800

// Ethernet header size
.equ ETH_HEADER_SIZE, 14

// eth_build_header: Build Ethernet header
// Input: x0 = buffer pointer
//        x1 = pointer to destination MAC (6 bytes)
//        x2 = EtherType (16-bit, will be byte-swapped)
// Returns: x0 = pointer after header
eth_build_header:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0             // buffer
    mov x20, x1             // dest MAC
    mov x21, x2             // EtherType

    // Copy destination MAC (bytes 0-5)
    ldrb w0, [x20, #0]
    strb w0, [x19, #0]
    ldrb w0, [x20, #1]
    strb w0, [x19, #1]
    ldrb w0, [x20, #2]
    strb w0, [x19, #2]
    ldrb w0, [x20, #3]
    strb w0, [x19, #3]
    ldrb w0, [x20, #4]
    strb w0, [x19, #4]
    ldrb w0, [x20, #5]
    strb w0, [x19, #5]

    // Copy source MAC (our MAC, bytes 6-11)
    ldr x1, =our_mac
    ldrb w0, [x1, #0]
    strb w0, [x19, #6]
    ldrb w0, [x1, #1]
    strb w0, [x19, #7]
    ldrb w0, [x1, #2]
    strb w0, [x19, #8]
    ldrb w0, [x1, #3]
    strb w0, [x19, #9]
    ldrb w0, [x1, #4]
    strb w0, [x19, #10]
    ldrb w0, [x1, #5]
    strb w0, [x19, #11]

    // EtherType (big-endian)
    lsr w0, w21, #8
    strb w0, [x19, #12]
    strb w21, [x19, #13]

    // Return pointer after header
    add x0, x19, #ETH_HEADER_SIZE

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// eth_send: Send Ethernet frame
// Input: x0 = pointer to complete frame (with header)
//        x1 = total frame length
eth_send:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Just pass through to virtio TX
    bl virtio_tx_packet

    ldp x29, x30, [sp], #16
    ret

// eth_recv: Process received Ethernet frame
// Input: x0 = pointer to frame data
//        x1 = frame length
// Dispatches to appropriate handler based on EtherType
eth_recv:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0             // frame pointer
    mov x20, x1             // frame length

    // Debug: print frame length and first bytes
    stp x0, x1, [sp, #-16]!
    ldr x0, =msg_eth_recv
    bl uart_puts
    mov x0, x20
    bl uart_print_hex16
    mov w0, #' '
    bl uart_putc
    // Print first 14 bytes (Ethernet header)
    ldrb w0, [x19, #0]
    bl uart_print_hex8
    ldrb w0, [x19, #1]
    bl uart_print_hex8
    ldrb w0, [x19, #2]
    bl uart_print_hex8
    ldrb w0, [x19, #3]
    bl uart_print_hex8
    ldrb w0, [x19, #4]
    bl uart_print_hex8
    ldrb w0, [x19, #5]
    bl uart_print_hex8
    mov w0, #' '
    bl uart_putc
    ldrb w0, [x19, #12]
    bl uart_print_hex8
    ldrb w0, [x19, #13]
    bl uart_print_hex8
    bl uart_newline
    ldp x0, x1, [sp], #16

    // Check minimum length
    cmp x20, #ETH_HEADER_SIZE
    b.lt .eth_recv_done

    // Extract EtherType (big-endian at offset 12)
    ldrb w21, [x19, #12]
    ldrb w22, [x19, #13]
    lsl w21, w21, #8
    orr w21, w21, w22

    // Calculate payload pointer and length
    add x0, x19, #ETH_HEADER_SIZE
    sub x1, x20, #ETH_HEADER_SIZE

    // Also pass source MAC for ARP to use
    add x2, x19, #6         // source MAC at offset 6

    // Dispatch based on EtherType
    cmp w21, #ETHERTYPE_ARP
    b.eq .dispatch_arp

    cmp w21, #ETHERTYPE_IPV4
    b.eq .dispatch_ipv4

    // Unknown EtherType - ignore
    b .eth_recv_done

.dispatch_arp:
    stp x0, x1, [sp, #-16]!
    stp x2, xzr, [sp, #-16]!
    ldr x0, =msg_arp
    bl uart_puts
    ldp x2, xzr, [sp], #16
    ldp x0, x1, [sp], #16
    bl arp_handle
    b .eth_recv_done

.dispatch_ipv4:
    stp x0, x1, [sp, #-16]!
    stp x2, xzr, [sp, #-16]!
    ldr x0, =msg_ipv4
    bl uart_puts
    ldp x2, xzr, [sp], #16
    ldp x0, x1, [sp], #16
    bl ip_recv
    b .eth_recv_done

.eth_recv_done:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.section .rodata
msg_arp:
    .asciz "ARP "
msg_ipv4:
    .asciz "IPv4 "
msg_eth_recv:
    .asciz "ETH len="
