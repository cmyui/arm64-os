.section .text
.global virtio_probe
.global virtio_init
.global virtio_queue_setup
.global virtio_tx_packet
.global virtio_rx_poll
.global our_mac
.global virtio_net_base
.global rx_virtqueue
.global tx_virtqueue
.global rx_used_ring

// virtio-net MMIO region for QEMU virt machine
.equ VIRTIO_MMIO_START, 0x0a000000
.equ VIRTIO_MMIO_SLOT_SIZE, 0x200
.equ VIRTIO_MMIO_NUM_SLOTS, 32

// Device ID for network
.equ VIRTIO_DEV_NET, 1

// MMIO Register offsets (legacy virtio-mmio v1)
.equ VIRTIO_MAGIC,          0x000
.equ VIRTIO_VERSION,        0x004
.equ VIRTIO_DEVICE_ID,      0x008
.equ VIRTIO_VENDOR_ID,      0x00c
.equ VIRTIO_HOST_FEAT,      0x010
.equ VIRTIO_HOST_FEAT_SEL,  0x014
.equ VIRTIO_GUEST_FEAT,     0x020
.equ VIRTIO_GUEST_FEAT_SEL, 0x024
.equ VIRTIO_GUEST_PAGE_SIZE, 0x028
.equ VIRTIO_QUEUE_SEL,      0x030
.equ VIRTIO_QUEUE_NUM_MAX,  0x034
.equ VIRTIO_QUEUE_NUM,      0x038
.equ VIRTIO_QUEUE_ALIGN,    0x03c
.equ VIRTIO_QUEUE_PFN,      0x040
.equ VIRTIO_QUEUE_NOTIFY,   0x050
.equ VIRTIO_INT_STATUS,     0x060
.equ VIRTIO_INT_ACK,        0x064
.equ VIRTIO_STATUS,         0x070
.equ VIRTIO_CONFIG,         0x100

// Device status bits
.equ STATUS_ACK,         0x01
.equ STATUS_DRIVER,      0x02
.equ STATUS_DRIVER_OK,   0x04

// Virtqueue descriptor flags
.equ VRING_DESC_F_NEXT,  1
.equ VRING_DESC_F_WRITE, 2

// Queue configuration
.equ QUEUE_SIZE,        16
.equ RX_BUFFER_SIZE,    2048
.equ TX_BUFFER_SIZE,    2048
// Legacy virtio-net header is 10 bytes (no MRG_RXBUF)
.equ VIRTIO_NET_HDR_SIZE, 10
.equ PAGE_SIZE,         4096

// virtio_probe: Scan for and detect virtio-net device (version 1 only)
// Returns: x0 = 0 on success, -1 on failure
virtio_probe:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    ldr x0, =msg_scanning
    bl uart_puts

    // Scan all virtio-mmio slots
    ldr x19, =VIRTIO_MMIO_START
    mov x20, #0

.scan_loop:
    cmp x20, #VIRTIO_MMIO_NUM_SLOTS
    b.ge .probe_fail

    // Check magic value
    ldr w0, [x19, #VIRTIO_MAGIC]
    ldr w1, =0x74726976
    cmp w0, w1
    b.ne .scan_next

    // Check if it's a network device (ID = 1) with version 1
    ldr w0, [x19, #VIRTIO_DEVICE_ID]
    cmp w0, #VIRTIO_DEV_NET
    b.ne .scan_next

    ldr w0, [x19, #VIRTIO_VERSION]
    cmp w0, #1
    b.eq .found_net

.scan_next:
    add x19, x19, #VIRTIO_MMIO_SLOT_SIZE
    add x20, x20, #1
    b .scan_loop

.found_net:
    // Save the device base address
    ldr x0, =virtio_net_base
    str x19, [x0]

    // Print device info
    ldr x0, =msg_virtio_found
    bl uart_puts

    // Read and store MAC address from config space
    ldr x21, =our_mac
    add x22, x19, #VIRTIO_CONFIG
    mov x2, #0
.read_mac_loop:
    ldrb w0, [x22, x2]
    strb w0, [x21, x2]
    add x2, x2, #1
    cmp x2, #6
    b.lt .read_mac_loop

    // Print MAC
    ldr x0, =msg_mac
    bl uart_puts
    mov x22, #0
.print_mac_loop:
    ldr x0, =our_mac
    ldrb w0, [x0, x22]
    bl uart_print_hex8
    add x22, x22, #1
    cmp x22, #6
    b.ge .mac_done
    mov w0, #':'
    bl uart_putc
    b .print_mac_loop

.mac_done:
    bl uart_newline

    ldr x0, =msg_probe_ok
    bl uart_puts
    mov x0, #0
    b .probe_exit

.probe_fail:
    ldr x0, =msg_probe_fail
    bl uart_puts
    mov x0, #-1

.probe_exit:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// virtio_init: Initialize virtio device (legacy v1)
// Returns: x0 = 0 on success, -1 on failure
virtio_init:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    ldr x0, =virtio_net_base
    ldr x19, [x0]

    // Step 1: Reset device
    str wzr, [x19, #VIRTIO_STATUS]

    // Step 2: Set ACKNOWLEDGE
    mov w0, #STATUS_ACK
    str w0, [x19, #VIRTIO_STATUS]

    // Step 3: Set DRIVER
    mov w0, #(STATUS_ACK | STATUS_DRIVER)
    str w0, [x19, #VIRTIO_STATUS]

    // Step 4: Read and negotiate features
    // Read features
    str wzr, [x19, #VIRTIO_HOST_FEAT_SEL]
    ldr w20, [x19, #VIRTIO_HOST_FEAT]

    // Accept VIRTIO_NET_F_MAC (bit 5) only
    str wzr, [x19, #VIRTIO_GUEST_FEAT_SEL]
    mov w0, #0x20
    str w0, [x19, #VIRTIO_GUEST_FEAT]

    // Set page size for legacy mode
    mov w0, #PAGE_SIZE
    str w0, [x19, #VIRTIO_GUEST_PAGE_SIZE]

    ldr x0, =msg_init_ok
    bl uart_puts
    mov x0, #0

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// virtio_queue_setup: Set up RX and TX virtqueues (legacy v1)
// Returns: x0 = 0 on success, -1 on failure
virtio_queue_setup:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    ldr x0, =virtio_net_base
    ldr x19, [x0]

    // === Set up Queue 0 (RX) ===
    ldr x0, =msg_setup_rx
    bl uart_puts

    mov w0, #0
    str w0, [x19, #VIRTIO_QUEUE_SEL]

    // Check max queue size
    ldr w0, [x19, #VIRTIO_QUEUE_NUM_MAX]
    cmp w0, #QUEUE_SIZE
    b.lt .queue_fail

    // Set queue size
    mov w0, #QUEUE_SIZE
    str w0, [x19, #VIRTIO_QUEUE_NUM]

    // Set queue alignment for legacy
    mov w0, #PAGE_SIZE
    str w0, [x19, #VIRTIO_QUEUE_ALIGN]

    // Set queue PFN (page frame number = address / page_size)
    ldr x0, =rx_virtqueue
    // Debug: print RX queue address
    stp x0, x19, [sp, #-16]!
    ldr x0, =msg_rx_addr
    bl uart_puts
    ldr x0, =rx_virtqueue
    lsr x0, x0, #32
    bl uart_print_hex32
    ldr x0, =rx_virtqueue
    bl uart_print_hex32
    bl uart_newline
    ldp x0, x19, [sp], #16

    ldr x0, =rx_virtqueue
    lsr x0, x0, #12         // Divide by 4096 (page size)
    str w0, [x19, #VIRTIO_QUEUE_PFN]

    // Verify queue was accepted
    ldr w0, [x19, #VIRTIO_QUEUE_PFN]
    stp x0, x19, [sp, #-16]!
    ldr x0, =msg_pfn_readback
    bl uart_puts
    ldp x0, x19, [sp], #16
    ldr w0, [x19, #VIRTIO_QUEUE_PFN]
    bl uart_print_hex32
    bl uart_newline

    // === Set up Queue 1 (TX) ===
    ldr x0, =msg_setup_tx
    bl uart_puts

    mov w0, #1
    str w0, [x19, #VIRTIO_QUEUE_SEL]

    // Check max queue size
    ldr w0, [x19, #VIRTIO_QUEUE_NUM_MAX]
    cmp w0, #QUEUE_SIZE
    b.lt .queue_fail

    // Set queue size
    mov w0, #QUEUE_SIZE
    str w0, [x19, #VIRTIO_QUEUE_NUM]

    // Set queue alignment
    mov w0, #PAGE_SIZE
    str w0, [x19, #VIRTIO_QUEUE_ALIGN]

    // Set queue PFN
    ldr x0, =tx_virtqueue
    // Debug: print TX queue address
    stp x0, x19, [sp, #-16]!
    ldr x0, =msg_tx_addr
    bl uart_puts
    ldr x0, =tx_virtqueue
    lsr x0, x0, #32
    bl uart_print_hex32
    ldr x0, =tx_virtqueue
    bl uart_print_hex32
    bl uart_newline
    ldp x0, x19, [sp], #16

    ldr x0, =tx_virtqueue
    lsr x0, x0, #12
    str w0, [x19, #VIRTIO_QUEUE_PFN]

    // Verify
    ldr w0, [x19, #VIRTIO_QUEUE_PFN]
    stp x0, x19, [sp, #-16]!
    ldr x0, =msg_pfn_readback
    bl uart_puts
    ldp x0, x19, [sp], #16
    ldr w0, [x19, #VIRTIO_QUEUE_PFN]
    bl uart_print_hex32
    bl uart_newline

    // Initialize RX buffers
    bl virtio_init_rx_buffers

    // Set DRIVER_OK
    mov w0, #(STATUS_ACK | STATUS_DRIVER | STATUS_DRIVER_OK)
    str w0, [x19, #VIRTIO_STATUS]

    // Send a gratuitous ARP to trigger network
    bl send_test_arp

    ldr x0, =msg_queue_ok
    bl uart_puts
    mov x0, #0
    b .queue_exit

.queue_fail:
    ldr x0, =msg_queue_fail
    bl uart_puts
    mov x0, #-1

.queue_exit:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// virtio_init_rx_buffers: Initialize RX descriptors and post buffers
virtio_init_rx_buffers:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    ldr x19, =rx_virtqueue      // Descriptor table at start of virtqueue
    ldr x20, =rx_buffers
    mov x21, #0

.init_rx_loop:
    // Calculate descriptor address (16 bytes each)
    lsl x22, x21, #4
    add x1, x19, x22

    // Calculate buffer address
    mov x2, #RX_BUFFER_SIZE
    mul x3, x21, x2
    add x3, x20, x3

    // Set buffer address
    str x3, [x1, #0]
    // Set length
    mov w4, #RX_BUFFER_SIZE
    str w4, [x1, #8]
    // Set flags (WRITE = device can write)
    mov w4, #VRING_DESC_F_WRITE
    strh w4, [x1, #12]
    // Set next
    strh wzr, [x1, #14]

    add x21, x21, #1
    cmp x21, #QUEUE_SIZE
    b.lt .init_rx_loop

    // Fill available ring (starts after descriptor table)
    // Descriptor table: 16 * 16 = 256 bytes
    // Available ring at offset 256
    add x1, x19, #256
    strh wzr, [x1, #0]          // flags = 0

    // Fill ring entries
    mov x2, #0
.fill_avail_loop:
    add x3, x1, #4
    lsl x4, x2, #1
    add x3, x3, x4
    strh w2, [x3]
    add x2, x2, #1
    cmp x2, #QUEUE_SIZE
    b.lt .fill_avail_loop

    // Memory barrier
    dmb sy

    // Set idx
    mov w0, #QUEUE_SIZE
    strh w0, [x1, #2]

    // Initialize tracking variables
    ldr x0, =rx_last_used_idx
    str wzr, [x0]
    ldr x0, =tx_avail_idx
    str wzr, [x0]

    // Memory barrier before notify
    dmb sy

    // Debug: print avail idx
    ldr x0, =msg_avail_idx
    bl uart_puts
    ldr x0, =rx_virtqueue
    add x0, x0, #256
    ldrh w0, [x0, #2]
    bl uart_print_hex16
    bl uart_newline

    // Notify RX queue
    ldr x0, =virtio_net_base
    ldr x0, [x0]
    str wzr, [x0, #VIRTIO_QUEUE_NOTIFY]

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// virtio_tx_packet: Transmit a packet
// Input: x0 = packet data, x1 = length
// Returns: x0 = 0 on success
virtio_tx_packet:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    mov x19, x0
    mov x20, x1

    // Prepare TX buffer with virtio-net header
    ldr x21, =tx_buffer

    // Zero virtio-net header (12 bytes)
    str xzr, [x21, #0]
    str wzr, [x21, #8]

    // Copy packet data after header
    add x0, x21, #VIRTIO_NET_HDR_SIZE
    mov x1, x19
    mov x2, x20
    bl memcpy

    // Get TX descriptor index
    ldr x22, =tx_avail_idx
    ldr w23, [x22]
    and w23, w23, #(QUEUE_SIZE - 1)

    // Set up TX descriptor
    ldr x0, =tx_virtqueue
    lsl x1, x23, #4
    add x0, x0, x1

    str x21, [x0, #0]           // buffer address
    add w1, w20, #VIRTIO_NET_HDR_SIZE
    str w1, [x0, #8]            // length
    strh wzr, [x0, #12]         // flags = 0
    strh wzr, [x0, #14]         // next = 0

    // Add to available ring (at offset 256 from virtqueue start)
    ldr x0, =tx_virtqueue
    add x0, x0, #256
    ldrh w1, [x0, #2]           // current idx
    and w2, w1, #(QUEUE_SIZE - 1)
    add x3, x0, #4
    lsl x4, x2, #1
    strh w23, [x3, x4]          // store descriptor index
    add w1, w1, #1
    strh w1, [x0, #2]           // increment idx

    // Memory barrier
    dmb sy

    // Notify TX queue
    ldr x0, =virtio_net_base
    ldr x0, [x0]
    mov w1, #1
    str w1, [x0, #VIRTIO_QUEUE_NOTIFY]

    // Update our index
    ldr w0, [x22]
    add w0, w0, #1
    str w0, [x22]

    mov x0, #0

    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// virtio_rx_poll: Poll for received packets
// Returns: x0 = packet pointer (after virtio header), or 0
//          x1 = packet length
virtio_rx_poll:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    // Check used ring
    // Used ring is at: desc_table + 256 (avail ring) + 6 + 2*QUEUE_SIZE (pad to 4096 alignment for legacy)
    // For legacy with page alignment, used ring is at page boundary after avail
    // With 16 entries: desc=256, avail=6+32=38, total=294, pad to 4096 -> used at offset 4096
    ldr x0, =rx_virtqueue
    add x0, x0, #4096           // Used ring at next page boundary
    ldrh w1, [x0, #2]           // device's idx

    ldr x2, =rx_last_used_idx
    ldr w3, [x2]

    cmp w1, w3
    b.eq .rx_none

    // Get used ring entry
    and w4, w3, #(QUEUE_SIZE - 1)
    add x5, x0, #4
    lsl x6, x4, #3
    add x5, x5, x6

    ldr w19, [x5, #0]           // descriptor index
    ldr w20, [x5, #4]           // length

    // Get buffer from descriptor
    ldr x0, =rx_virtqueue
    and w1, w19, #(QUEUE_SIZE - 1)
    lsl x1, x1, #4
    add x0, x0, x1
    ldr x0, [x0, #0]

    // Return pointer after virtio header
    add x0, x0, #VIRTIO_NET_HDR_SIZE
    sub w1, w20, #VIRTIO_NET_HDR_SIZE

    // Update last used idx
    add w3, w3, #1
    str w3, [x2]

    // Re-post buffer to available ring
    ldr x2, =rx_virtqueue
    add x2, x2, #256            // avail ring offset
    ldrh w3, [x2, #2]
    and w4, w3, #(QUEUE_SIZE - 1)
    add x5, x2, #4
    lsl x6, x4, #1
    strh w19, [x5, x6]
    add w3, w3, #1
    strh w3, [x2, #2]

    // Memory barrier and notify
    dmb sy
    ldr x2, =virtio_net_base
    ldr x2, [x2]
    str wzr, [x2, #VIRTIO_QUEUE_NOTIFY]

    b .rx_done

.rx_none:
    mov x0, #0
    mov x1, #0

.rx_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// memcpy: Copy memory
memcpy:
    cbz x2, .memcpy_done
.memcpy_loop:
    ldrb w3, [x1], #1
    strb w3, [x0], #1
    subs x2, x2, #1
    b.ne .memcpy_loop
.memcpy_done:
    ret

// send_test_arp: Send a broadcast ARP to trigger network
send_test_arp:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =test_arp_pkt

    // Ethernet: dst = broadcast
    mov w1, #0xff
    strb w1, [x0, #0]
    strb w1, [x0, #1]
    strb w1, [x0, #2]
    strb w1, [x0, #3]
    strb w1, [x0, #4]
    strb w1, [x0, #5]

    // Ethernet: src = our MAC
    ldr x1, =our_mac
    ldrb w2, [x1, #0]
    strb w2, [x0, #6]
    ldrb w2, [x1, #1]
    strb w2, [x0, #7]
    ldrb w2, [x1, #2]
    strb w2, [x0, #8]
    ldrb w2, [x1, #3]
    strb w2, [x0, #9]
    ldrb w2, [x1, #4]
    strb w2, [x0, #10]
    ldrb w2, [x1, #5]
    strb w2, [x0, #11]

    // Ethernet: type = 0x0806 (ARP)
    mov w1, #0x08
    strb w1, [x0, #12]
    mov w1, #0x06
    strb w1, [x0, #13]

    // ARP: htype=1, ptype=0x0800, hlen=6, plen=4, op=1
    strb wzr, [x0, #14]
    mov w1, #1
    strb w1, [x0, #15]
    mov w1, #0x08
    strb w1, [x0, #16]
    strb wzr, [x0, #17]
    mov w1, #6
    strb w1, [x0, #18]
    mov w1, #4
    strb w1, [x0, #19]
    strb wzr, [x0, #20]
    mov w1, #1
    strb w1, [x0, #21]

    // ARP: sender MAC
    ldr x1, =our_mac
    ldrb w2, [x1, #0]
    strb w2, [x0, #22]
    ldrb w2, [x1, #1]
    strb w2, [x0, #23]
    ldrb w2, [x1, #2]
    strb w2, [x0, #24]
    ldrb w2, [x1, #3]
    strb w2, [x0, #25]
    ldrb w2, [x1, #4]
    strb w2, [x0, #26]
    ldrb w2, [x1, #5]
    strb w2, [x0, #27]

    // ARP: sender IP = 10.0.2.15
    mov w1, #10
    strb w1, [x0, #28]
    strb wzr, [x0, #29]
    mov w1, #2
    strb w1, [x0, #30]
    mov w1, #15
    strb w1, [x0, #31]

    // ARP: target MAC = 0
    strb wzr, [x0, #32]
    strb wzr, [x0, #33]
    strb wzr, [x0, #34]
    strb wzr, [x0, #35]
    strb wzr, [x0, #36]
    strb wzr, [x0, #37]

    // ARP: target IP = 10.0.2.2 (gateway)
    mov w1, #10
    strb w1, [x0, #38]
    strb wzr, [x0, #39]
    mov w1, #2
    strb w1, [x0, #40]
    mov w1, #2
    strb w1, [x0, #41]

    // Send: 14 (eth) + 28 (arp) = 42 bytes
    mov x1, #42
    bl virtio_tx_packet

    // Print debug
    ldr x0, =msg_arp_sent
    bl uart_puts

    // Delay a bit, then check TX used ring
    mov x0, #0
.delay_loop:
    add x0, x0, #1
    cmp x0, #0x100000
    b.lt .delay_loop

    // Print TX used ring idx
    ldr x0, =msg_tx_used
    bl uart_puts
    ldr x0, =tx_virtqueue
    add x0, x0, #4096           // Used ring at page boundary
    ldrh w0, [x0, #2]
    bl uart_print_hex16
    bl uart_newline

    ldp x29, x30, [sp], #16
    ret

.section .rodata
msg_scanning:
    .asciz "Scanning for virtio-net device...\n"
msg_virtio_found:
    .asciz "virtio-net device found (legacy v1)\n"
msg_mac:
    .asciz "  MAC: "
msg_probe_ok:
    .asciz "virtio-net probe OK\n"
msg_probe_fail:
    .asciz "virtio-net probe FAILED\n"
msg_init_ok:
    .asciz "virtio-net init OK\n"
msg_setup_rx:
    .asciz "Setting up RX queue...\n"
msg_setup_tx:
    .asciz "Setting up TX queue...\n"
msg_queue_ok:
    .asciz "virtio queues ready\n"
msg_queue_fail:
    .asciz "virtio queue setup FAILED\n"
msg_arp_sent:
    .asciz "Sent ARP request\n"
msg_rx_addr:
    .asciz "  RX virtqueue addr: 0x"
msg_tx_addr:
    .asciz "  TX virtqueue addr: 0x"
msg_pfn_readback:
    .asciz "  Queue PFN readback: 0x"
msg_tx_used:
    .asciz "  TX used idx: 0x"
msg_avail_idx:
    .asciz "  RX avail idx: 0x"

.section .bss
.balign 8
virtio_net_base:
    .skip 8

.balign 8
our_mac:
    .skip 8

// Legacy virtqueue layout (must be contiguous and page-aligned):
// - Descriptor table: 16 entries * 16 bytes = 256 bytes (offset 0)
// - Available ring: 6 + 2*16 = 38 bytes (offset 256)
// - Padding to page boundary
// - Used ring: 6 + 8*16 = 134 bytes (offset 4096)

.balign 4096
rx_virtqueue:
    .skip 8192              // Descriptor table + avail ring + used ring

.balign 4096
tx_virtqueue:
    .skip 8192

// RX buffers
.balign 4096
rx_buffers:
    .skip RX_BUFFER_SIZE * QUEUE_SIZE

// TX buffer
.balign 4096
tx_buffer:
    .skip TX_BUFFER_SIZE

// Aliases for compatibility
.equ rx_used_ring, rx_virtqueue + 4096

// State tracking
.balign 4
rx_last_used_idx:
    .skip 4
tx_avail_idx:
    .skip 4

// Test ARP packet buffer
.balign 4
test_arp_pkt:
    .skip 64
