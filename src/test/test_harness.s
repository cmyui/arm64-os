.section .text
.global test_start
.global test_end
.global test_section
.global test_assert_eq
.global test_assert_neq
.global test_assert_zero
.global test_assert_nonzero
.global test_assert_mem_eq
.global test_pass
.global test_fail

// Test state
.equ MAX_TESTS, 256

// test_start: Initialize test framework
// Call at beginning of test run
test_start:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Initialize counters
    ldr x0, =test_count
    str wzr, [x0]
    ldr x0, =test_passed
    str wzr, [x0]
    ldr x0, =test_failed
    str wzr, [x0]

    // Print header
    ldr x0, =msg_header
    bl uart_puts

    ldp x29, x30, [sp], #16
    ret

// test_end: Print summary and halt
// Call at end of test run
test_end:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Print summary
    ldr x0, =msg_summary
    bl uart_puts

    // Print passed count
    ldr x0, =msg_passed
    bl uart_puts
    ldr x0, =test_passed
    ldr w0, [x0]
    bl uart_print_decimal
    bl uart_newline

    // Print failed count
    ldr x0, =msg_failed
    bl uart_puts
    ldr x0, =test_failed
    ldr w0, [x0]
    bl uart_print_decimal
    bl uart_newline

    // Print final status
    ldr x0, =test_failed
    ldr w0, [x0]
    cbnz w0, .tests_failed

    ldr x0, =msg_all_passed
    bl uart_puts
    b .test_end_done

.tests_failed:
    ldr x0, =msg_some_failed
    bl uart_puts

.test_end_done:
    ldp x29, x30, [sp], #16
    ret

// test_section: Print section header
// Input: x0 = section name string
test_section:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    mov x19, x0

    ldr x0, =msg_section_start
    bl uart_puts
    mov x0, x19
    bl uart_puts
    ldr x0, =msg_section_end
    bl uart_puts

    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// test_assert_eq: Assert x0 == x1
// Input: x0 = actual, x1 = expected, x2 = test name string
// Returns: x0 = 1 if passed, 0 if failed
test_assert_eq:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0     // actual
    mov x20, x1     // expected
    mov x21, x2     // name

    // Increment test count
    ldr x0, =test_count
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // Compare
    cmp x19, x20
    b.ne .assert_eq_fail

    // Pass
    mov x0, x21
    bl test_pass
    mov x0, #1
    b .assert_eq_done

.assert_eq_fail:
    mov x0, x21
    mov x1, x19
    mov x2, x20
    bl test_fail_with_values
    mov x0, #0

.assert_eq_done:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// test_assert_neq: Assert x0 != x1
// Input: x0 = actual, x1 = not_expected, x2 = test name string
test_assert_neq:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0
    mov x20, x1
    mov x21, x2

    ldr x0, =test_count
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    cmp x19, x20
    b.eq .assert_neq_fail

    mov x0, x21
    bl test_pass
    mov x0, #1
    b .assert_neq_done

.assert_neq_fail:
    mov x0, x21
    bl test_fail
    mov x0, #0

.assert_neq_done:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// test_assert_zero: Assert x0 == 0
// Input: x0 = value, x1 = test name string
test_assert_zero:
    mov x2, x1
    mov x1, #0
    b test_assert_eq

// test_assert_nonzero: Assert x0 != 0
// Input: x0 = value, x1 = test name string
test_assert_nonzero:
    mov x2, x1
    mov x1, #0
    b test_assert_neq

// test_assert_mem_eq: Assert memory regions are equal
// Input: x0 = ptr1, x1 = ptr2, x2 = length, x3 = test name
test_assert_mem_eq:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    mov x19, x0     // ptr1
    mov x20, x1     // ptr2
    mov x21, x2     // length
    mov x22, x3     // name

    ldr x0, =test_count
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    mov x23, #0     // index
.mem_cmp_loop:
    cmp x23, x21
    b.ge .mem_cmp_pass

    ldrb w0, [x19, x23]
    ldrb w1, [x20, x23]
    cmp w0, w1
    b.ne .mem_cmp_fail

    add x23, x23, #1
    b .mem_cmp_loop

.mem_cmp_pass:
    mov x0, x22
    bl test_pass
    mov x0, #1
    b .mem_cmp_done

.mem_cmp_fail:
    mov x0, x22
    bl test_fail
    mov x0, #0

.mem_cmp_done:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// test_pass: Record and print pass
// Input: x0 = test name
test_pass:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    mov x19, x0

    // Increment passed
    ldr x0, =test_passed
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // Print
    ldr x0, =msg_pass
    bl uart_puts
    mov x0, x19
    bl uart_puts
    bl uart_newline

    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// test_fail: Record and print fail
// Input: x0 = test name
test_fail:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    mov x19, x0

    // Increment failed
    ldr x0, =test_failed
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // Print
    ldr x0, =msg_fail
    bl uart_puts
    mov x0, x19
    bl uart_puts
    bl uart_newline

    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// test_fail_with_values: Print fail with actual/expected
// Input: x0 = name, x1 = actual, x2 = expected
test_fail_with_values:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0
    mov x20, x1
    mov x21, x2

    // Increment failed
    ldr x0, =test_failed
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // Print fail message
    ldr x0, =msg_fail
    bl uart_puts
    mov x0, x19
    bl uart_puts

    // Print actual
    ldr x0, =msg_actual
    bl uart_puts
    mov w0, w20
    bl uart_print_hex32

    // Print expected
    ldr x0, =msg_expected
    bl uart_puts
    mov w0, w21
    bl uart_print_hex32
    bl uart_newline

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// uart_print_decimal: Print decimal number
// Input: w0 = number
uart_print_decimal:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov w19, w0

    // Handle zero specially
    cbz w19, .print_zero

    // Build digits in reverse on stack
    mov x20, sp
    sub sp, sp, #16
    mov x1, sp

    mov w2, #10
.decimal_loop:
    cbz w19, .decimal_print
    udiv w3, w19, w2        // w3 = w19 / 10
    msub w4, w3, w2, w19    // w4 = w19 - (w3 * 10) = remainder
    add w4, w4, #'0'
    strb w4, [x1], #1
    mov w19, w3
    b .decimal_loop

.decimal_print:
    // Print in reverse
    mov x3, sp              // Can't use sp directly in cmp
.decimal_print_loop:
    cmp x1, x3
    b.le .decimal_done
    sub x1, x1, #1
    ldrb w0, [x1]
    stp x1, x3, [sp, #-16]! // Save across call
    bl uart_putc
    ldp x1, x3, [sp], #16
    b .decimal_print_loop

.print_zero:
    mov w0, #'0'
    bl uart_putc
    b .decimal_done

.decimal_done:
    mov sp, x20
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.section .rodata
msg_header:
    .asciz "\n========== RUNNING TESTS ==========\n\n"
msg_summary:
    .asciz "\n========== TEST SUMMARY ==========\n"
msg_passed:
    .asciz "Passed: "
msg_failed:
    .asciz "Failed: "
msg_all_passed:
    .asciz "\nALL TESTS PASSED\n"
msg_some_failed:
    .asciz "\nSOME TESTS FAILED\n"
msg_section_start:
    .asciz "\n--- "
msg_section_end:
    .asciz " ---\n"
msg_pass:
    .asciz "[PASS] "
msg_fail:
    .asciz "[FAIL] "
msg_actual:
    .asciz " (got: 0x"
msg_expected:
    .asciz ", expected: 0x"

.section .bss
.balign 4
test_count:
    .skip 4
test_passed:
    .skip 4
test_failed:
    .skip 4
