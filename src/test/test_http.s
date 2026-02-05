.section .text
.global run_http_tests

run_http_tests:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl test_section

    bl test_http_response_starts_http
    bl test_http_response_has_200

    ldp x29, x30, [sp], #16
    ret

// Test: HTTP response starts with "HTTP"
test_http_response_starts_http:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =http_response
    ldrb w0, [x0, #0]
    mov x1, #'H'
    ldr x2, =name_starts_http
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

// Test: HTTP response contains 200
test_http_response_has_200:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Check "200" is at offset 9 ("HTTP/1.0 200")
    ldr x0, =http_response
    ldrb w0, [x0, #9]
    mov x1, #'2'
    ldr x2, =name_has_200
    bl test_assert_eq

    ldp x29, x30, [sp], #16
    ret

.section .rodata
section_name:
    .asciz "http"
name_starts_http:
    .asciz "http_response starts with H"
name_has_200:
    .asciz "http_response contains 200"
