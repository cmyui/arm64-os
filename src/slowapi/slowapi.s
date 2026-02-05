// SlowAPI Framework Core
// Main entry point and initialization

.section .text
.global slowapi_init
.global slowapi_handle
.global tcp_app_handler

.include "src/slowapi/macros.s"

// slowapi_init: Initialize the framework
// Called at boot to prepare route table
slowapi_init:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Print init message
    ldr x0, =msg_init
    bl uart_puts

    // Count routes for debugging
    ldr x0, =__routes_start
    ldr x1, =__routes_end
    sub x2, x1, x0
    mov x3, #ROUTE_SIZE
    udiv x2, x2, x3         // number of routes

    // Print route count
    mov w0, w2
    bl uart_print_hex8
    ldr x0, =msg_routes
    bl uart_puts

    ldp x29, x30, [sp], #16
    ret

// slowapi_handle: Main HTTP request handler
// Input: x0 = raw HTTP data, x1 = length
// Called by TCP layer instead of http_handle
slowapi_handle:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov x19, x0             // raw data
    mov x20, x1             // length

    // Debug: print received request
    ldr x0, =msg_request
    bl uart_puts
    mov w0, w20
    bl uart_print_hex16
    bl uart_newline

    // Parse request into context
    ldr x2, =request_ctx
    mov x0, x19
    mov x1, x20
    bl slowapi_parse_request

    // Check parse result
    cmp w0, #0
    b.ne .parse_failed

    // Debug: print parsed path
    ldr x0, =msg_path
    bl uart_puts

    ldr x0, =request_ctx
    ldr x1, [x0, #REQ_PATH]
    ldr w2, [x0, #REQ_PATH_LEN]

    // Print path (limited length)
    mov x3, x1
    mov w4, w2
.print_path:
    cbz w4, .path_printed
    ldrb w0, [x3], #1
    bl uart_putc
    sub w4, w4, #1
    b .print_path

.path_printed:
    bl uart_newline

    // Dispatch to router
    ldr x0, =request_ctx
    bl slowapi_dispatch

    b .handle_done

.parse_failed:
    // Send 400 Bad Request
    ldr x0, =msg_parse_fail
    bl uart_puts

    mov w0, #STATUS_BAD_REQUEST
    bl resp_error

.handle_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// tcp_app_handler: Called by TCP layer when data is received
// Checks if HTTP request is complete, processes it if so
// Input: x0 = data buffer, x1 = data length
// Output: w0 = 1 if request was processed, 0 if need more data
tcp_app_handler:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov x19, x0             // buffer
    mov x20, x1             // length

    // Check if we have a complete HTTP request
    // Look for \r\n\r\n (end of headers)
    bl http_check_complete
    cbz w0, .app_need_more

    // Request is complete - process it
    mov x0, x19
    mov x1, x20
    bl slowapi_handle

    // Return 1 = processed
    mov w0, #1
    b .app_done

.app_need_more:
    // Return 0 = need more data
    mov w0, #0

.app_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// http_check_complete: Check if buffer contains complete HTTP request
// Scans for \r\n\r\n (end of headers)
// Input: x0 = buffer, x1 = length
// Output: w0 = 1 if complete, 0 if not
http_check_complete:
    // Need at least 4 bytes for \r\n\r\n
    cmp x1, #4
    b.lt .http_incomplete

    // Scan for \r\n\r\n
    mov x2, x0              // current position
    sub x3, x1, #3          // can check up to len-3

.http_scan:
    cbz x3, .http_incomplete

    ldrb w4, [x2]
    cmp w4, #'\r'
    b.ne .http_next

    ldrb w4, [x2, #1]
    cmp w4, #'\n'
    b.ne .http_next

    ldrb w4, [x2, #2]
    cmp w4, #'\r'
    b.ne .http_next

    ldrb w4, [x2, #3]
    cmp w4, #'\n'
    b.ne .http_next

    // Found \r\n\r\n - headers complete
    mov w0, #1
    ret

.http_next:
    add x2, x2, #1
    sub x3, x3, #1
    b .http_scan

.http_incomplete:
    mov w0, #0
    ret

//=============================================================================
// Data
//=============================================================================

.section .rodata
msg_init:
    .asciz "[SlowAPI] init "
msg_routes:
    .asciz " routes\n"
msg_request:
    .asciz "[SlowAPI] req len="
msg_path:
    .asciz "[SlowAPI] path="
msg_parse_fail:
    .asciz "[SlowAPI] parse failed\n"

.section .bss
.balign 8
request_ctx:
    .skip REQ_SIZE
