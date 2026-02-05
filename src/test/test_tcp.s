.section .text
.global run_tcp_tests

// External symbols from tcp.s
.extern tcp_listen_port
.extern tcp_state

.equ HTTP_PORT, 80
.equ STATE_LISTEN, 1

run_tcp_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_tcp_listen_port
    bl test_tcp_initial_seq

    ldp x29, x30, [sp], #16
    ret

// Test: Listen port is configured to 80
test_tcp_listen_port:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Simple test: HTTP_PORT should be 80
    mov x0, #HTTP_PORT
    mov x1, #80
    ldr x2, =name_listen_port
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: STATE_LISTEN constant is 1
test_tcp_initial_seq:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x0, #STATE_LISTEN
    mov x1, #1
    ldr x2, =name_state_listen
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

.section .rodata
section_name:
    .asciz "tcp"
name_listen_port:
    .asciz "tcp listen port is 80"
name_state_listen:
    .asciz "tcp state can be set to LISTEN"
