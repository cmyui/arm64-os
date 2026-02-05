.section .text.boot
.global _start

_start:
    // Set up stack pointer
    ldr x0, =_stack_top
    mov sp, x0

    // Initialize UART
    bl uart_init

    // Start test framework
    bl test_start

    // Run all test suites
    bl run_virtio_tests
    bl run_ethernet_tests
    bl run_arp_tests
    bl run_ipv4_tests
    bl run_tcp_tests
    bl run_http_tests

    // Print summary and halt
    bl test_end

halt:
    wfe
    b halt
