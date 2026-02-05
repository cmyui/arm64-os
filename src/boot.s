.section .text.boot
.global _start
.extern rx_used_ring

// TCP states
.equ STATE_LISTEN, 1

_start:
    // Set up stack pointer
    ldr x0, =_stack_top
    mov sp, x0

    // Initialize UART
    bl uart_init

    // Print boot message
    ldr x0, =boot_msg
    bl uart_puts

    // Probe virtio-net device
    bl virtio_probe
    cbnz x0, halt

    // Initialize virtio-net device
    bl virtio_init
    cbnz x0, halt

    // Set up virtqueues
    bl virtio_queue_setup
    cbnz x0, halt

    // Initialize TCP state to LISTEN
    ldr x0, =tcp_state
    mov w1, #STATE_LISTEN
    strb w1, [x0]

    // Print ready message
    ldr x0, =ready_msg
    bl uart_puts

    // Main loop - poll for packets
main_loop:
    bl virtio_rx_poll
    cbz x0, .no_packet

    // Got a packet!
    stp x0, x1, [sp, #-16]!
    ldr x0, =pkt_msg
    bl uart_puts
    ldp x0, x1, [sp], #16

    // x0 = packet pointer, x1 = length
    bl eth_recv

.no_packet:
    b main_loop

halt:
    ldr x0, =halt_msg
    bl uart_puts
.halt_loop:
    wfe
    b .halt_loop

.section .rodata
boot_msg:
    .asciz "Bare-metal HTTP server booting...\n"
ready_msg:
    .asciz "Network stack ready. Listening on port 80.\n"
halt_msg:
    .asciz "System halted.\n"
pkt_msg:
    .asciz "[PKT] "
