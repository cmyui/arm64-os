.section .text
.global run_virtio_tests

// virtio MMIO constants (must match virtio.s)
.equ VIRTIO_MAGIC,      0x000
.equ VIRTIO_VERSION,    0x004
.equ VIRTIO_DEVICE_ID,  0x008
.equ VIRTIO_STATUS,     0x070
.equ VIRTIO_CONFIG,     0x100

.equ STATUS_ACK,        0x01
.equ STATUS_DRIVER,     0x02
.equ STATUS_DRIVER_OK,  0x04
.equ STATUS_FEATURES_OK, 0x08

run_virtio_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    // First probe to find and store the device address
    bl test_virtio_probe_success

    // These tests run after probe, using stored address
    bl test_virtio_magic
    bl test_virtio_version
    bl test_virtio_device_id
    bl test_virtio_init_success
    bl test_virtio_mac_read
    bl test_virtio_queues_ready

    ldp x29, x30, [sp], #16
    ret

// Test: Probe returns success (finds network device)
test_virtio_probe_success:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl virtio_probe
    ldr x1, =name_probe
    bl test_assert_zero

    ldp x29, x30, [sp], #16
    ret

// Test: Magic value is correct (after probe)
test_virtio_magic:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Load stored device address
    ldr x0, =virtio_net_base
    ldr x0, [x0]
    cbz x0, .magic_skip     // Skip if probe failed

    ldr w0, [x0, #VIRTIO_MAGIC]
    ldr w1, =0x74726976      // "virt" in little-endian
    ldr x2, =name_magic
    bl test_assert_eq
    b .magic_done

.magic_skip:
    ldr x0, =name_magic
    bl test_fail

.magic_done:
    ldp x29, x30, [sp], #16
    ret

// Test: Version is 1 (legacy) or 2 (modern virtio)
test_virtio_version:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =virtio_net_base
    ldr x0, [x0]
    cbz x0, .ver_skip

    ldr w0, [x0, #VIRTIO_VERSION]
    // Accept version 1 or 2
    cmp w0, #1
    b.eq .version_ok
    cmp w0, #2
    b.eq .version_ok
    mov x0, #0
    b .version_check
.version_ok:
    mov x0, #1
.version_check:
    ldr x1, =name_version
    bl test_assert_nonzero
    b .ver_done

.ver_skip:
    ldr x0, =name_version
    bl test_fail

.ver_done:
    ldp x29, x30, [sp], #16
    ret

// Test: Device ID is 1 (network)
test_virtio_device_id:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =virtio_net_base
    ldr x0, [x0]
    cbz x0, .devid_skip

    ldr w0, [x0, #VIRTIO_DEVICE_ID]
    mov x1, #1
    ldr x2, =name_device_id
    bl test_assert_eq
    b .devid_done

.devid_skip:
    ldr x0, =name_device_id
    bl test_fail

.devid_done:
    ldp x29, x30, [sp], #16
    ret

// Test: Init returns success
test_virtio_init_success:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl virtio_init
    ldr x1, =name_init
    bl test_assert_zero

    ldp x29, x30, [sp], #16
    ret

// Test: MAC address was read (non-zero)
test_virtio_mac_read:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Check that at least one byte of MAC is non-zero
    // QEMU assigns 52:54:00:xx:xx:xx by default
    ldr x0, =our_mac
    ldrb w0, [x0, #0]
    ldr x1, =name_mac
    bl test_assert_nonzero

    ldp x29, x30, [sp], #16
    ret

// Test: Queues are ready after setup
test_virtio_queues_ready:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl virtio_queue_setup
    ldr x1, =name_queues
    bl test_assert_zero

    ldp x29, x30, [sp], #16
    ret

.section .rodata
section_name:
    .asciz "virtio-net"
name_magic:
    .asciz "virtio magic value"
name_version:
    .asciz "virtio version"
name_device_id:
    .asciz "virtio device id"
name_probe:
    .asciz "virtio_probe finds device"
name_init:
    .asciz "virtio_init returns 0"
name_mac:
    .asciz "MAC address read"
name_queues:
    .asciz "virtio_queue_setup returns 0"
