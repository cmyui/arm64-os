.section .text
.global http_handle
.global http_response

// http_handle: Handle HTTP request data
// Input: x0 = request data, x1 = length
http_handle:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov x19, x0             // request data
    mov x20, x1             // length

    // Check minimum length for "GET "
    cmp x20, #4
    b.lt .http_done

    // Check for "GET " at start
    ldrb w0, [x19, #0]
    cmp w0, #'G'
    b.ne .http_done

    ldrb w0, [x19, #1]
    cmp w0, #'E'
    b.ne .http_done

    ldrb w0, [x19, #2]
    cmp w0, #'T'
    b.ne .http_done

    ldrb w0, [x19, #3]
    cmp w0, #' '
    b.ne .http_done

    // It's a GET request - send response
    ldr x0, =http_response
    ldr x1, =http_response_len
    ldr w1, [x1]
    bl tcp_send

    // Close connection by sending FIN
    // (The TCP layer will handle this when it sees FIN from client)

.http_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.section .rodata
// HTTP response
http_response:
    .ascii "HTTP/1.0 200 OK\r\n"
    .ascii "Content-Type: text/html\r\n"
    .ascii "Content-Length: 45\r\n"
    .ascii "Connection: close\r\n"
    .ascii "\r\n"
    .ascii "<html><body><h1>Hello World!</h1></body></html>"
http_response_end:

.section .data
http_response_len:
    .word http_response_end - http_response
