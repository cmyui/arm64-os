.section .text
.global arp_handle
.global arp_request
.global our_ip
.global gateway_mac

// ARP constants
.equ ARP_HW_ETHERNET, 0x0001
.equ ARP_PROTO_IPV4,  0x0800
.equ ARP_OP_REQUEST,  0x0001
.equ ARP_OP_REPLY,    0x0002

// ARP packet offsets
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

// Ethernet constants
.equ ETHERTYPE_ARP,   0x0806
.equ ETH_HEADER_SIZE, 14

// arp_handle: Handle incoming ARP packet
// Input: x0 = ARP packet data (after Ethernet header)
//        x1 = length
//        x2 = source MAC (from Ethernet header)
arp_handle:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0             // ARP packet pointer
    mov x20, x1             // length
    mov x21, x2             // source MAC

    // Check minimum length
    cmp x20, #ARP_PACKET_SIZE
    b.lt .arp_done

    // Check hardware type (big-endian 0x0001)
    ldrb w0, [x19, #ARP_HWTYPE]
    ldrb w1, [x19, #ARP_HWTYPE + 1]
    lsl w0, w0, #8
    orr w0, w0, w1
    cmp w0, #ARP_HW_ETHERNET
    b.ne .arp_done

    // Check protocol type (big-endian 0x0800)
    ldrb w0, [x19, #ARP_PROTOTYPE]
    ldrb w1, [x19, #ARP_PROTOTYPE + 1]
    lsl w0, w0, #8
    orr w0, w0, w1
    cmp w0, #ARP_PROTO_IPV4
    b.ne .arp_done

    // Get operation (big-endian)
    ldrb w22, [x19, #ARP_OP]
    ldrb w0, [x19, #ARP_OP + 1]
    lsl w22, w22, #8
    orr w22, w22, w0

    // Is it a request?
    cmp w22, #ARP_OP_REQUEST
    b.eq .arp_request_received

    // Is it a reply? (store sender's MAC if it's the gateway)
    cmp w22, #ARP_OP_REPLY
    b.eq .arp_reply_received

    b .arp_done

.arp_request_received:
    // Check if target IP is our IP
    add x0, x19, #ARP_TARGET_IP
    ldr x1, =our_ip
    bl arp_compare_ip
    cbz x0, .arp_done       // Not for us

    // It's for us - send reply
    // Sender becomes target, we become sender
    mov x0, x19             // Original ARP packet
    mov x1, x21             // Requester's MAC (from Ethernet header)
    bl arp_send_reply

    b .arp_done

.arp_reply_received:
    // Store sender's MAC (could be gateway responding)
    // For simplicity, always store the last ARP reply sender
    ldr x0, =gateway_mac
    add x1, x19, #ARP_SENDER_MAC
    mov x2, #6
    bl arp_memcpy
    b .arp_done

.arp_done:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// arp_compare_ip: Compare IP in packet to our IP
// Input: x0 = pointer to IP in packet (big-endian), x1 = pointer to our IP
// Returns: x0 = 1 if match, 0 if not
arp_compare_ip:
    ldr w2, [x0]            // Packet IP (big-endian)
    ldr w3, [x1]            // Our IP (stored big-endian)
    cmp w2, w3
    cset x0, eq
    ret

// arp_send_reply: Send ARP reply
// Input: x0 = original request packet, x1 = destination MAC
arp_send_reply:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0             // Original request
    mov x20, x1             // Destination MAC

    // Use tx_buffer for our response
    ldr x21, =arp_tx_buffer

    // Build Ethernet header
    mov x0, x21
    mov x1, x20             // Destination MAC
    mov x2, #ETHERTYPE_ARP
    bl eth_build_header
    mov x22, x0             // Save pointer to ARP payload

    // Build ARP reply
    // Hardware type (big-endian 0x0001)
    mov w0, #0x00
    strb w0, [x22, #ARP_HWTYPE]
    mov w0, #0x01
    strb w0, [x22, #ARP_HWTYPE + 1]

    // Protocol type (big-endian 0x0800)
    mov w0, #0x08
    strb w0, [x22, #ARP_PROTOTYPE]
    mov w0, #0x00
    strb w0, [x22, #ARP_PROTOTYPE + 1]

    // Hardware address length = 6
    mov w0, #6
    strb w0, [x22, #ARP_HWLEN]

    // Protocol address length = 4
    mov w0, #4
    strb w0, [x22, #ARP_PROTOLEN]

    // Operation = reply (big-endian 0x0002)
    mov w0, #0x00
    strb w0, [x22, #ARP_OP]
    mov w0, #0x02
    strb w0, [x22, #ARP_OP + 1]

    // Sender MAC = our MAC
    add x0, x22, #ARP_SENDER_MAC
    ldr x1, =our_mac
    mov x2, #6
    bl arp_memcpy

    // Sender IP = our IP
    add x0, x22, #ARP_SENDER_IP
    ldr x1, =our_ip
    mov x2, #4
    bl arp_memcpy

    // Target MAC = requester's MAC (from original request's sender)
    add x0, x22, #ARP_TARGET_MAC
    add x1, x19, #ARP_SENDER_MAC
    mov x2, #6
    bl arp_memcpy

    // Target IP = requester's IP (from original request's sender)
    add x0, x22, #ARP_TARGET_IP
    add x1, x19, #ARP_SENDER_IP
    mov x2, #4
    bl arp_memcpy

    // Send the frame
    mov x0, x21                         // Frame buffer
    mov x1, #(ETH_HEADER_SIZE + ARP_PACKET_SIZE)
    bl eth_send

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// arp_memcpy: Copy memory
// Input: x0 = dest, x1 = src, x2 = len
arp_memcpy:
    cbz x2, .arp_memcpy_done
.arp_memcpy_loop:
    ldrb w3, [x1], #1
    strb w3, [x0], #1
    subs x2, x2, #1
    b.ne .arp_memcpy_loop
.arp_memcpy_done:
    ret

.section .data
// Our IP address: 10.0.2.15 (QEMU user-mode default)
// Stored in network byte order (big-endian)
our_ip:
    .byte 10, 0, 2, 15

.section .bss
// Gateway MAC (learned from ARP)
.balign 8
gateway_mac:
    .skip 8

// TX buffer for ARP replies
.balign 8
arp_tx_buffer:
    .skip 64
