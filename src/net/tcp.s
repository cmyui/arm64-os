.section .text
.global tcp_handle
.global tcp_send
.global tcp_state
.global tcp_listen_port

// TCP header offsets
.equ TCP_SRC_PORT,    0
.equ TCP_DST_PORT,    2
.equ TCP_SEQ,         4
.equ TCP_ACK_NUM,     8       // ACK number field offset
.equ TCP_DATA_OFF,    12      // Data offset (high 4 bits) + reserved + flags
.equ TCP_FLAGS,       13      // Flags byte
.equ TCP_WINDOW,      14
.equ TCP_CHECKSUM,    16
.equ TCP_URGENT,      18
.equ TCP_HEADER_SIZE, 20

// TCP flag bits
.equ FLAG_FIN, 0x01
.equ FLAG_SYN, 0x02
.equ FLAG_RST, 0x04
.equ FLAG_PSH, 0x08
.equ FLAG_ACK, 0x10

// TCP states
.equ STATE_CLOSED,      0
.equ STATE_LISTEN,      1
.equ STATE_SYN_RECV,    2
.equ STATE_ESTABLISHED, 3
.equ STATE_FIN_WAIT,    4

// Listen port (80 for HTTP)
.equ HTTP_PORT, 80

// IP constants
.equ IP_PROTO_TCP, 6
.equ IP_HEADER_SIZE, 20

// tcp_handle: Handle incoming TCP segment
// Input: x0 = TCP segment data
//        x1 = TCP segment length
//        x2 = source IP (pointer)
//        x3 = IP header (pointer, for checksum)
tcp_handle:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    stp x27, x28, [sp, #-16]!

    mov x19, x0             // TCP segment
    mov x20, x1             // length
    mov x21, x2             // source IP
    mov x22, x3             // IP header

    // Debug: print TCP length
    stp x19, x20, [sp, #-16]!
    ldr x0, =msg_tcp_len
    bl uart_puts
    mov w0, w20
    bl uart_print_hex16
    mov w0, #' '
    bl uart_putc
    ldp x19, x20, [sp], #16

    // Check minimum length
    cmp x20, #TCP_HEADER_SIZE
    b.lt .tcp_done

    // Get destination port (big-endian)
    ldrb w23, [x19, #TCP_DST_PORT]
    ldrb w0, [x19, #TCP_DST_PORT + 1]
    lsl w23, w23, #8
    orr w23, w23, w0

    // Debug: print dest port we got
    stp x19, x20, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    ldr x0, =msg_dport
    bl uart_puts
    mov w0, w23
    bl uart_print_hex16
    mov w0, #' '
    bl uart_putc
    ldp x23, x24, [sp], #16
    ldp x19, x20, [sp], #16

    // Debug: marker
    mov w0, #'A'
    bl uart_putc

    // Check if it's for our listening port
    ldr x0, =tcp_listen_port
    ldrh w0, [x0]

    // Debug: marker
    stp x0, xzr, [sp, #-16]!
    mov w0, #'B'
    bl uart_putc
    ldp x0, xzr, [sp], #16

    // Debug: print our listen port
    stp x19, x20, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    mov w23, w0             // temp save
    ldr x0, =msg_lport
    bl uart_puts
    mov w0, w23
    bl uart_print_hex16
    mov w0, #' '
    bl uart_putc
    mov w0, w23             // restore for comparison
    ldp x23, x24, [sp], #16
    ldp x19, x20, [sp], #16

    cmp w23, w0
    b.ne .tcp_done          // Not for us

    // Get source port (big-endian)
    ldrb w24, [x19, #TCP_SRC_PORT]
    ldrb w0, [x19, #TCP_SRC_PORT + 1]
    lsl w24, w24, #8
    orr w24, w24, w0

    // Get flags
    ldrb w25, [x19, #TCP_FLAGS]

    // Get sequence number (big-endian)
    ldrb w26, [x19, #TCP_SEQ]
    ldrb w0, [x19, #TCP_SEQ + 1]
    lsl w26, w26, #8
    orr w26, w26, w0
    ldrb w0, [x19, #TCP_SEQ + 2]
    lsl w26, w26, #8
    orr w26, w26, w0
    ldrb w0, [x19, #TCP_SEQ + 3]
    lsl w26, w26, #8
    orr w26, w26, w0

    // Save remote info for response - copy the IP value, not the pointer!
    ldr x0, =tcp_remote_ip
    ldrb w1, [x21, #0]
    strb w1, [x0, #0]
    ldrb w1, [x21, #1]
    strb w1, [x0, #1]
    ldrb w1, [x21, #2]
    strb w1, [x0, #2]
    ldrb w1, [x21, #3]
    strb w1, [x0, #3]
    ldr x0, =tcp_remote_port
    strh w24, [x0]

    // Load current state
    ldr x0, =tcp_state
    ldrb w27, [x0]              // Use w27 to preserve across calls

    // Debug: print state
    stp x19, x20, [sp, #-16]!
    ldr x0, =msg_state
    bl uart_puts
    mov w0, w27
    bl uart_print_hex8
    mov w0, #' '
    bl uart_putc
    ldp x19, x20, [sp], #16

    // State machine
    cmp w27, #STATE_LISTEN
    b.eq .handle_listen

    cmp w27, #STATE_SYN_RECV
    b.eq .handle_syn_recv

    cmp w27, #STATE_ESTABLISHED
    b.eq .handle_established

    b .tcp_done

.handle_listen:
    // Debug: print flags
    stp x19, x20, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    ldr x0, =msg_flags
    bl uart_puts
    mov w0, w25
    bl uart_print_hex8
    mov w0, #'\n'
    bl uart_putc
    ldp x25, x26, [sp], #16
    ldp x19, x20, [sp], #16

    // Expecting SYN
    tst w25, #FLAG_SYN
    b.eq .tcp_done

    // Debug: got SYN
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    ldr x0, =msg_tcp_syn
    bl uart_puts
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16

    // Received SYN, save their sequence number + 1 (we need to ACK their SYN)
    ldr x0, =tcp_their_seq
    add w26, w26, #1        // Their seq + 1 (ACK their SYN)
    str w26, [x0]           // Store the incremented value

    // Send SYN+ACK
    mov w0, #(FLAG_SYN | FLAG_ACK)
    bl tcp_send_control

    // Move to SYN_RECV
    ldr x0, =tcp_state
    mov w1, #STATE_SYN_RECV
    strb w1, [x0]

    b .tcp_done

.handle_syn_recv:
    // Debug: print flags we received
    stp x19, x20, [sp, #-16]!
    stp x25, x26, [sp, #-16]!
    ldr x0, =msg_synrecv_flags
    bl uart_puts
    mov w0, w25
    bl uart_print_hex8
    mov w0, #' '
    bl uart_putc
    ldp x25, x26, [sp], #16
    ldp x19, x20, [sp], #16

    // Expecting ACK of our SYN+ACK
    tst w25, #FLAG_ACK
    b.eq .tcp_done

    // Connection established
    ldr x0, =tcp_state
    mov w1, #STATE_ESTABLISHED
    strb w1, [x0]

    // Debug: print that we got ACK, established
    stp x19, x20, [sp, #-16]!
    ldr x0, =msg_established
    bl uart_puts
    ldp x19, x20, [sp], #16

    // Check if this packet also has data (common with HTTP)
    ldrb w0, [x19, #TCP_DATA_OFF]
    lsr w0, w0, #4          // Data offset in 32-bit words
    lsl w0, w0, #2          // Convert to bytes
    sub w1, w20, w0         // Payload length
    cbz w1, .tcp_done       // No data - just ACK

    // There's data! Process it now
    add x0, x19, x0, UXTW   // x0 = data pointer

    // Debug: print data length
    stp x0, x1, [sp, #-16]!
    ldr x0, =msg_data_len
    bl uart_puts
    ldp x0, x1, [sp], #16
    stp x0, x1, [sp, #-16]!
    mov x0, x1
    bl uart_print_hex16
    bl uart_newline
    ldp x0, x1, [sp], #16

    // Save payload info
    ldr x2, =tcp_rx_data
    str x0, [x2]
    ldr x2, =tcp_rx_len
    str w1, [x2]

    // Update their sequence number
    ldr x2, =tcp_their_seq
    ldr w3, [x2]
    add w3, w3, w1
    str w3, [x2]

    // Send ACK for the data
    stp x0, x1, [sp, #-16]!
    mov w0, #FLAG_ACK
    bl tcp_send_control
    ldp x0, x1, [sp], #16

    // Call HTTP handler
    bl http_handle

    b .tcp_done

.handle_established:
    // Check for FIN
    tst w25, #FLAG_FIN
    b.ne .handle_fin

    // Check for data (segment length > header)
    ldrb w0, [x19, #TCP_DATA_OFF]
    lsr w0, w0, #4          // Data offset in 32-bit words
    lsl w0, w0, #2          // Convert to bytes
    sub w1, w20, w0         // Payload length
    cbz w1, .tcp_done       // No data

    // Calculate data pointer
    add x0, x19, x0         // x0 = data pointer

    // Save payload info for HTTP handler
    ldr x2, =tcp_rx_data
    str x0, [x2]
    ldr x2, =tcp_rx_len
    str w1, [x2]

    // Update their sequence number
    ldr x2, =tcp_their_seq
    ldr w3, [x2]
    add w3, w3, w1          // Add data length
    str w3, [x2]

    // Send ACK
    mov w0, #FLAG_ACK
    bl tcp_send_control

    // Call HTTP handler
    ldr x0, =tcp_rx_data
    ldr x0, [x0]
    ldr x1, =tcp_rx_len
    ldr w1, [x1]
    bl http_handle

    b .tcp_done

.handle_fin:
    // Update their seq for FIN
    ldr x0, =tcp_their_seq
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // Send ACK+FIN
    mov w0, #(FLAG_ACK | FLAG_FIN)
    bl tcp_send_control

    // Go to CLOSED
    ldr x0, =tcp_state
    mov w1, #STATE_LISTEN   // Ready for next connection
    strb w1, [x0]

    // Reset sequence numbers
    ldr x0, =tcp_our_seq
    mov w1, #1000
    str w1, [x0]

    b .tcp_done

.tcp_done:
    ldp x27, x28, [sp], #16
    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// tcp_send_control: Send a control segment (SYN, ACK, FIN, etc.)
// Input: w0 = flags
tcp_send_control:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov w19, w0             // flags

    // Debug: print flags we're sending
    stp x19, xzr, [sp, #-16]!
    ldr x0, =msg_send_flags
    bl uart_puts
    mov w0, w19
    bl uart_print_hex8
    mov w0, #' '
    bl uart_putc
    ldp x19, xzr, [sp], #16

    // Build TCP segment in buffer
    ldr x20, =tcp_tx_buffer

    // Source port (big-endian) = our listen port
    ldr x0, =tcp_listen_port
    ldrh w0, [x0]
    lsr w1, w0, #8
    strb w1, [x20, #TCP_SRC_PORT]
    strb w0, [x20, #TCP_SRC_PORT + 1]

    // Dest port (big-endian) = remote port
    ldr x0, =tcp_remote_port
    ldrh w0, [x0]
    lsr w1, w0, #8
    strb w1, [x20, #TCP_DST_PORT]
    strb w0, [x20, #TCP_DST_PORT + 1]

    // Sequence number (big-endian)
    ldr x0, =tcp_our_seq
    ldr w0, [x0]
    lsr w1, w0, #24
    strb w1, [x20, #TCP_SEQ]
    lsr w1, w0, #16
    strb w1, [x20, #TCP_SEQ + 1]
    lsr w1, w0, #8
    strb w1, [x20, #TCP_SEQ + 2]
    strb w0, [x20, #TCP_SEQ + 3]

    // ACK number (big-endian) = their seq
    ldr x0, =tcp_their_seq
    ldr w0, [x0]
    lsr w1, w0, #24
    strb w1, [x20, #TCP_ACK_NUM]
    lsr w1, w0, #16
    strb w1, [x20, #TCP_ACK_NUM + 1]
    lsr w1, w0, #8
    strb w1, [x20, #TCP_ACK_NUM + 2]
    strb w0, [x20, #TCP_ACK_NUM + 3]

    // Data offset (5 words = 20 bytes) + reserved
    mov w0, #0x50           // 5 << 4
    strb w0, [x20, #TCP_DATA_OFF]

    // Flags
    strb w19, [x20, #TCP_FLAGS]

    // Window size (4096 in big-endian = 0x1000)
    mov w0, #0x10
    strb w0, [x20, #TCP_WINDOW]
    strb wzr, [x20, #TCP_WINDOW + 1]

    // Checksum = 0 initially
    strh wzr, [x20, #TCP_CHECKSUM]

    // Urgent pointer = 0
    strh wzr, [x20, #TCP_URGENT]

    // Increment our sequence if sending SYN or FIN
    tst w19, #(FLAG_SYN | FLAG_FIN)
    b.eq .no_seq_inc
    ldr x0, =tcp_our_seq
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]
.no_seq_inc:

    // Calculate checksum
    // Need pseudo-header: src IP, dst IP, zero, protocol, TCP length
    ldr x0, =our_ip
    ldr x1, =tcp_remote_ip  // Now direct pointer to stored IP
    mov x2, #IP_PROTO_TCP
    mov x3, #TCP_HEADER_SIZE
    bl ip_pseudo_checksum
    mov x21, x0             // Save partial checksum

    // Add TCP header checksum
    mov x0, x20
    mov x1, #TCP_HEADER_SIZE
    bl tcp_checksum_partial
    add x21, x21, x0

    // Fold and complement
    lsr x0, x21, #16
    and x21, x21, #0xFFFF
    add x21, x21, x0
    lsr x0, x21, #16
    and x21, x21, #0xFFFF
    add x21, x21, x0
    mvn w21, w21
    and w21, w21, #0xFFFF

    // Store checksum (big-endian)
    lsr w0, w21, #8
    strb w0, [x20, #TCP_CHECKSUM]
    strb w21, [x20, #TCP_CHECKSUM + 1]

    // Debug: print remote IP value
    ldr x4, =tcp_remote_ip
    stp x4, xzr, [sp, #-16]!
    ldr x0, =msg_rip
    bl uart_puts
    ldp x4, xzr, [sp], #16

    // Print IP bytes directly
    stp x4, xzr, [sp, #-16]!
    ldrb w0, [x4, #0]
    bl uart_print_hex8
    ldp x4, xzr, [sp], #16
    stp x4, xzr, [sp, #-16]!
    ldrb w0, [x4, #1]
    bl uart_print_hex8
    ldp x4, xzr, [sp], #16
    stp x4, xzr, [sp, #-16]!
    ldrb w0, [x4, #2]
    bl uart_print_hex8
    ldp x4, xzr, [sp], #16
    stp x4, xzr, [sp, #-16]!
    ldrb w0, [x4, #3]
    bl uart_print_hex8
    ldp x4, xzr, [sp], #16
    mov w0, #' '
    bl uart_putc

    // Debug: about to call ip_send
    ldr x0, =msg_calling_ip_send
    bl uart_puts

    // Load the remote IP value for sending
    ldr x0, =tcp_remote_ip
    ldrb w4, [x0, #0]
    ldrb w5, [x0, #1]
    ldrb w6, [x0, #2]
    ldrb w7, [x0, #3]
    // Reconstruct as 32-bit value (network byte order = big endian)
    lsl w4, w4, #24
    lsl w5, w5, #16
    lsl w6, w6, #8
    orr w0, w4, w5
    orr w0, w0, w6
    orr w0, w0, w7

    // Send via IP
    mov x1, #IP_PROTO_TCP
    mov x2, x20             // TCP segment
    mov x3, #TCP_HEADER_SIZE
    bl ip_send

    // Debug: ip_send returned
    ldr x0, =msg_sent
    bl uart_puts

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// tcp_send: Send TCP data segment
// Input: x0 = data, x1 = length
tcp_send:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, xzr, [sp, #-16]!

    mov x19, x0             // data
    mov x20, x1             // length

    // Build TCP segment in buffer
    ldr x21, =tcp_tx_buffer

    // Source port
    ldr x0, =tcp_listen_port
    ldrh w0, [x0]
    lsr w1, w0, #8
    strb w1, [x21, #TCP_SRC_PORT]
    strb w0, [x21, #TCP_SRC_PORT + 1]

    // Dest port
    ldr x0, =tcp_remote_port
    ldrh w0, [x0]
    lsr w1, w0, #8
    strb w1, [x21, #TCP_DST_PORT]
    strb w0, [x21, #TCP_DST_PORT + 1]

    // Sequence number
    ldr x0, =tcp_our_seq
    ldr w22, [x0]
    lsr w1, w22, #24
    strb w1, [x21, #TCP_SEQ]
    lsr w1, w22, #16
    strb w1, [x21, #TCP_SEQ + 1]
    lsr w1, w22, #8
    strb w1, [x21, #TCP_SEQ + 2]
    strb w22, [x21, #TCP_SEQ + 3]

    // ACK number
    ldr x0, =tcp_their_seq
    ldr w0, [x0]
    lsr w1, w0, #24
    strb w1, [x21, #TCP_ACK_NUM]
    lsr w1, w0, #16
    strb w1, [x21, #TCP_ACK_NUM + 1]
    lsr w1, w0, #8
    strb w1, [x21, #TCP_ACK_NUM + 2]
    strb w0, [x21, #TCP_ACK_NUM + 3]

    // Data offset + flags (ACK + PSH)
    mov w0, #0x50
    strb w0, [x21, #TCP_DATA_OFF]
    mov w0, #(FLAG_ACK | FLAG_PSH)
    strb w0, [x21, #TCP_FLAGS]

    // Window
    mov w0, #0x10
    strb w0, [x21, #TCP_WINDOW]
    strb wzr, [x21, #TCP_WINDOW + 1]

    // Checksum = 0
    strh wzr, [x21, #TCP_CHECKSUM]

    // Urgent = 0
    strh wzr, [x21, #TCP_URGENT]

    // Copy data after header
    add x0, x21, #TCP_HEADER_SIZE
    mov x1, x19
    mov x2, x20
    bl tcp_memcpy

    // Update our sequence
    ldr x0, =tcp_our_seq
    add w22, w22, w20
    str w22, [x0]

    // Calculate total segment length
    add x23, x20, #TCP_HEADER_SIZE

    // Calculate checksum
    ldr x0, =our_ip
    ldr x1, =tcp_remote_ip  // Direct pointer to stored IP
    mov x2, #IP_PROTO_TCP
    mov x3, x23
    bl ip_pseudo_checksum
    mov x22, x0

    mov x0, x21
    mov x1, x23
    bl tcp_checksum_partial
    add x22, x22, x0

    // Fold
    lsr x0, x22, #16
    and x22, x22, #0xFFFF
    add x22, x22, x0
    lsr x0, x22, #16
    and x22, x22, #0xFFFF
    add x22, x22, x0
    mvn w22, w22
    and w22, w22, #0xFFFF

    // Store checksum
    lsr w0, w22, #8
    strb w0, [x21, #TCP_CHECKSUM]
    strb w22, [x21, #TCP_CHECKSUM + 1]

    // Send via IP - load IP bytes and reconstruct as 32-bit
    ldr x0, =tcp_remote_ip
    ldrb w4, [x0, #0]
    ldrb w5, [x0, #1]
    ldrb w6, [x0, #2]
    ldrb w7, [x0, #3]
    lsl w4, w4, #24
    lsl w5, w5, #16
    lsl w6, w6, #8
    orr w0, w4, w5
    orr w0, w0, w6
    orr w0, w0, w7
    mov x1, #IP_PROTO_TCP
    mov x2, x21
    mov x3, x23
    bl ip_send

    ldp x23, xzr, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// tcp_checksum_partial: Sum 16-bit words (no complement)
// Input: x0 = data, x1 = length
// Returns: x0 = partial sum
tcp_checksum_partial:
    mov x2, #0              // accumulator
.tcp_cksum_loop:
    cmp x1, #2
    b.lt .tcp_cksum_odd
    ldrb w3, [x0], #1
    ldrb w4, [x0], #1
    lsl w3, w3, #8
    orr w3, w3, w4
    add x2, x2, x3
    sub x1, x1, #2
    b .tcp_cksum_loop
.tcp_cksum_odd:
    cbz x1, .tcp_cksum_done
    ldrb w3, [x0]
    lsl w3, w3, #8
    add x2, x2, x3
.tcp_cksum_done:
    mov x0, x2
    ret

// tcp_memcpy
tcp_memcpy:
    cbz x2, .tcp_memcpy_done
.tcp_memcpy_loop:
    ldrb w3, [x1], #1
    strb w3, [x0], #1
    subs x2, x2, #1
    b.ne .tcp_memcpy_loop
.tcp_memcpy_done:
    ret

.section .rodata
msg_tcp_syn:
    .asciz "TCP SYN "
msg_tcp_len:
    .asciz "len="
msg_dport:
    .asciz "dp="
msg_lport:
    .asciz "lp="
msg_state:
    .asciz "st="
msg_flags:
    .asciz "fl="
msg_send_flags:
    .asciz "TX fl="
msg_rip:
    .asciz "rip="
msg_sent:
    .asciz "SENT\n"
msg_calling_ip_send:
    .asciz "->ip_send "
msg_established:
    .asciz "ESTAB "
msg_data_len:
    .asciz "data="
msg_synrecv_flags:
    .asciz "SR_fl="

.section .data
// Listening port (80)
.balign 2
tcp_listen_port:
    .hword HTTP_PORT

// Initial sequence number
.balign 4
tcp_our_seq:
    .word 1000

.section .bss
// TCP state
.balign 4
tcp_state:
    .skip 4

// Remote connection info
.balign 4
tcp_remote_ip:
    .skip 4                 // Actual IP bytes (not a pointer)
tcp_remote_port:
    .skip 2
.balign 4
tcp_their_seq:
    .skip 4

// RX data info
.balign 8
tcp_rx_data:
    .skip 8
tcp_rx_len:
    .skip 4

// TX buffer
.balign 8
tcp_tx_buffer:
    .skip 1600
