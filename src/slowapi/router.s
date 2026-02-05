// SlowAPI Router
// Route matching and dispatch

.section .text
.global slowapi_dispatch

.include "src/slowapi/macros.s"

// slowapi_dispatch: Match request to route and call handler
// Input: x0 = request context ptr
// Output: Calls appropriate handler or sends error response
slowapi_dispatch:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    mov x19, x0             // request context

    // Get request path and method
    ldr x20, [x19, #REQ_PATH]       // path pointer
    ldr w21, [x19, #REQ_PATH_LEN]   // path length
    ldr w22, [x19, #REQ_METHOD]     // method

    // Debug: print dispatch info
    stp x19, x20, [sp, #-16]!
    ldr x0, =msg_dispatch
    bl uart_puts
    ldp x19, x20, [sp], #16

    // Get route table bounds
    ldr x23, =__routes_start
    ldr x24, =__routes_end

    // Track if we found a path match (for 405 vs 404)
    mov w25, #0             // path_matched flag

.route_loop:
    cmp x23, x24
    b.ge .no_route_match

    // Load route entry
    ldr x0, [x23, #ROUTE_PATH]      // route path ptr
    ldr w1, [x23, #ROUTE_PATH_LEN]  // route path len
    ldr w2, [x23, #ROUTE_METHODS]   // route methods
    ldr x3, [x23, #ROUTE_HANDLER]   // route handler

    // Compare path lengths first
    cmp w1, w21
    b.ne .next_route

    // Compare paths
    mov x4, x0              // route path
    mov x5, x20             // request path
    mov w6, w1              // length

.path_cmp:
    cbz w6, .path_match

    ldrb w7, [x4], #1
    ldrb w8, [x5], #1
    cmp w7, w8
    b.ne .next_route

    sub w6, w6, #1
    b .path_cmp

.path_match:
    // Path matches! Set flag
    mov w25, #1

    // Check if method is allowed
    and w4, w22, w2
    cbz w4, .next_route     // Method not in bitmask

    // Match found! Call handler with request context in x0
    mov x0, x19

    // Debug: print calling handler
    stp x0, x3, [sp, #-16]!
    ldr x0, =msg_handler
    bl uart_puts
    ldp x0, x3, [sp], #16

    blr x3

    // Handler returns - we're done
    b .dispatch_done

.next_route:
    add x23, x23, #ROUTE_SIZE
    b .route_loop

.no_route_match:
    // Check if path matched but method didn't
    cbnz w25, .method_not_allowed

    // 404 Not Found
    mov w0, #STATUS_NOT_FOUND
    bl resp_error
    b .dispatch_done

.method_not_allowed:
    // 405 Method Not Allowed
    mov w0, #STATUS_METHOD_NOT_ALLOWED
    bl resp_error

.dispatch_done:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.section .rodata
msg_dispatch:
    .asciz "[ROUTER] "
msg_handler:
    .asciz "->handler "
