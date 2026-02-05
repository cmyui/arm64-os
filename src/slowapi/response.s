// SlowAPI Response Builder
// Builds HTTP responses and sends via TCP

.section .text
.global resp_html
.global resp_json
.global resp_text
.global resp_binary
.global resp_status
.global resp_error
.global resp_created
.global resp_no_content

.include "src/slowapi/macros.s"

// resp_html: Send HTML response (200 OK)
// Input: x0 = body ptr, x1 = body length
resp_html:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x2, x1              // body length
    mov x1, x0              // body ptr
    mov w0, #STATUS_OK
    mov w3, #CTYPE_HTML
    bl build_and_send_response

    ldp x29, x30, [sp], #16
    ret

// resp_json: Send JSON response (200 OK)
// Input: x0 = body ptr, x1 = body length
resp_json:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x2, x1              // body length
    mov x1, x0              // body ptr
    mov w0, #STATUS_OK
    mov w3, #CTYPE_JSON
    bl build_and_send_response

    ldp x29, x30, [sp], #16
    ret

// resp_text: Send plain text response (200 OK)
// Input: x0 = body ptr, x1 = body length
resp_text:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x2, x1              // body length
    mov x1, x0              // body ptr
    mov w0, #STATUS_OK
    mov w3, #CTYPE_TEXT
    bl build_and_send_response

    ldp x29, x30, [sp], #16
    ret

// resp_binary: Send binary/octet-stream response (200 OK)
// Input: x0 = body ptr, x1 = body length
resp_binary:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x2, x1              // body length
    mov x1, x0              // body ptr
    mov w0, #STATUS_OK
    mov w3, #CTYPE_BINARY
    bl build_and_send_response

    ldp x29, x30, [sp], #16
    ret

// resp_status: Send response with custom status
// Input: w0 = status code, x1 = body ptr, x2 = body length, w3 = content type
resp_status:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl build_and_send_response

    ldp x29, x30, [sp], #16
    ret

// resp_created: Send 201 Created with JSON body
// Input: x0 = body ptr, x1 = body length
resp_created:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x2, x1              // body length
    mov x1, x0              // body ptr
    mov w0, #STATUS_CREATED
    mov w3, #CTYPE_JSON
    bl build_and_send_response

    ldp x29, x30, [sp], #16
    ret

// resp_no_content: Send 204 No Content
resp_no_content:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov w0, #STATUS_NO_CONTENT
    mov x1, #0              // no body
    mov x2, #0
    mov w3, #CTYPE_TEXT
    bl build_and_send_response

    ldp x29, x30, [sp], #16
    ret

// resp_error: Send error response
// Input: w0 = status code
resp_error:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov w19, w0             // status code

    // Select error body based on status
    cmp w19, #STATUS_NOT_FOUND
    b.eq .error_404

    cmp w19, #STATUS_METHOD_NOT_ALLOWED
    b.eq .error_405

    cmp w19, #STATUS_BAD_REQUEST
    b.eq .error_400

    // Default: 500 Internal Server Error
    ldr x1, =error_500_body
    ldr x2, =error_500_len
    ldr w2, [x2]
    b .send_error

.error_404:
    ldr x1, =error_404_body
    ldr x2, =error_404_len
    ldr w2, [x2]
    b .send_error

.error_405:
    ldr x1, =error_405_body
    ldr x2, =error_405_len
    ldr w2, [x2]
    b .send_error

.error_400:
    ldr x1, =error_400_body
    ldr x2, =error_400_len
    ldr w2, [x2]

.send_error:
    mov w0, w19
    mov w3, #CTYPE_HTML
    bl build_and_send_response

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// build_and_send_response: Build complete HTTP response and send
// Input: w0 = status, x1 = body ptr, x2 = body len, w3 = content type
build_and_send_response:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!
    stp x25, x26, [sp, #-16]!

    mov w19, w0             // status
    mov x20, x1             // body ptr
    mov x21, x2             // body len
    mov w22, w3             // content type

    // Get response buffer
    ldr x23, =resp_buffer
    mov x24, x23            // write position

    // Write "HTTP/1.0 "
    ldr x0, =http_version
    mov x1, x24
    bl strcpy_advance
    mov x24, x0

    // Write status code as decimal
    mov w0, w19
    mov x1, x24
    bl write_decimal
    mov x24, x0

    // Write space
    mov w0, #' '
    strb w0, [x24], #1

    // Write status text
    mov w0, w19
    bl get_status_text
    mov x1, x24
    bl strcpy_advance
    mov x24, x0

    // Write \r\n
    mov w0, #'\r'
    strb w0, [x24], #1
    mov w0, #'\n'
    strb w0, [x24], #1

    // Write Content-Type header
    ldr x0, =hdr_content_type
    mov x1, x24
    bl strcpy_advance
    mov x24, x0

    // Write content type value
    mov w0, w22
    bl get_content_type
    mov x1, x24
    bl strcpy_advance
    mov x24, x0

    // Write \r\n
    mov w0, #'\r'
    strb w0, [x24], #1
    mov w0, #'\n'
    strb w0, [x24], #1

    // Write Content-Length header
    ldr x0, =hdr_content_length
    mov x1, x24
    bl strcpy_advance
    mov x24, x0

    // Write body length as decimal
    mov w0, w21
    mov x1, x24
    bl write_decimal
    mov x24, x0

    // Write \r\n
    mov w0, #'\r'
    strb w0, [x24], #1
    mov w0, #'\n'
    strb w0, [x24], #1

    // Write Connection: close\r\n
    ldr x0, =hdr_connection
    mov x1, x24
    bl strcpy_advance
    mov x24, x0

    // Write final \r\n (end of headers)
    mov w0, #'\r'
    strb w0, [x24], #1
    mov w0, #'\n'
    strb w0, [x24], #1

    // Copy body if present
    cbz x21, .no_body_copy

    mov x0, x24
    mov x1, x20
    mov x2, x21
    bl memcpy_resp
    add x24, x24, x21

.no_body_copy:
    // Calculate total length
    sub x25, x24, x23

    // Send via TCP
    mov x0, x23
    mov x1, x25
    bl tcp_send

    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// get_status_text: Get status text for code
// Input: w0 = status code
// Output: x0 = pointer to status text
get_status_text:
    cmp w0, #200
    b.eq .st_200
    cmp w0, #201
    b.eq .st_201
    cmp w0, #204
    b.eq .st_204
    cmp w0, #400
    b.eq .st_400
    cmp w0, #404
    b.eq .st_404
    cmp w0, #405
    b.eq .st_405
    cmp w0, #500
    b.eq .st_500

    // Default
    ldr x0, =status_500
    ret

.st_200:
    ldr x0, =status_200
    ret
.st_201:
    ldr x0, =status_201
    ret
.st_204:
    ldr x0, =status_204
    ret
.st_400:
    ldr x0, =status_400
    ret
.st_404:
    ldr x0, =status_404
    ret
.st_405:
    ldr x0, =status_405
    ret
.st_500:
    ldr x0, =status_500
    ret

// get_content_type: Get content type string
// Input: w0 = content type enum
// Output: x0 = pointer to content type string
get_content_type:
    cmp w0, #CTYPE_HTML
    b.eq .ct_html
    cmp w0, #CTYPE_JSON
    b.eq .ct_json
    cmp w0, #CTYPE_TEXT
    b.eq .ct_text
    cmp w0, #CTYPE_BINARY
    b.eq .ct_binary

    // Default to text
    ldr x0, =ctype_text
    ret

.ct_html:
    ldr x0, =ctype_html
    ret
.ct_json:
    ldr x0, =ctype_json
    ret
.ct_text:
    ldr x0, =ctype_text
    ret
.ct_binary:
    ldr x0, =ctype_binary
    ret

// strcpy_advance: Copy string and return end position
// Input: x0 = src (null-terminated), x1 = dst
// Output: x0 = dst end position (after last char, before null)
strcpy_advance:
    mov x2, x1
.strcpy_loop:
    ldrb w3, [x0], #1
    cbz w3, .strcpy_done
    strb w3, [x2], #1
    b .strcpy_loop
.strcpy_done:
    mov x0, x2
    ret

// write_decimal: Write number as decimal string
// Input: w0 = number, x1 = dst
// Output: x0 = dst end position
write_decimal:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov w19, w0             // number
    mov x20, x1             // dst
    mov x21, sp             // save sp

    // Handle zero specially
    cbnz w19, .decimal_nonzero
    mov w0, #'0'
    strb w0, [x20], #1
    b .decimal_done

.decimal_nonzero:
    // Push digits onto stack (reversed)
    sub sp, sp, #16         // space for digits
    mov x22, sp             // digit buffer

    mov w2, #0              // digit count
.decimal_div:
    cbz w19, .decimal_write

    // Divide by 10
    mov w3, #10
    udiv w4, w19, w3        // quotient
    msub w5, w4, w3, w19    // remainder = num - quot*10

    // Push digit
    add w5, w5, #'0'
    strb w5, [x22, x2]
    add w2, w2, #1

    mov w19, w4             // num = quotient
    b .decimal_div

.decimal_write:
    // Write digits in reverse (they're stored reversed)
    sub w2, w2, #1
.decimal_write_loop:
    cmp w2, #0
    b.lt .decimal_restore

    ldrb w3, [x22, x2]
    strb w3, [x20], #1
    sub w2, w2, #1
    b .decimal_write_loop

.decimal_restore:
    mov sp, x21             // restore sp

.decimal_done:
    mov x0, x20

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// memcpy_resp: Copy memory
// Input: x0 = dst, x1 = src, x2 = len
memcpy_resp:
    cbz x2, .memcpy_done
.memcpy_loop:
    ldrb w3, [x1], #1
    strb w3, [x0], #1
    subs x2, x2, #1
    b.ne .memcpy_loop
.memcpy_done:
    ret

//=============================================================================
// Data
//=============================================================================

.section .rodata

http_version:
    .asciz "HTTP/1.0 "

status_200:
    .asciz "OK"
status_201:
    .asciz "Created"
status_204:
    .asciz "No Content"
status_400:
    .asciz "Bad Request"
status_404:
    .asciz "Not Found"
status_405:
    .asciz "Method Not Allowed"
status_500:
    .asciz "Internal Server Error"

ctype_html:
    .asciz "text/html"
ctype_json:
    .asciz "application/json"
ctype_text:
    .asciz "text/plain"
ctype_binary:
    .asciz "application/octet-stream"

hdr_content_type:
    .asciz "Content-Type: "
hdr_content_length:
    .asciz "Content-Length: "
hdr_connection:
    .asciz "Connection: close\r\n"

error_404_body:
    .ascii "<html><body><h1>404 Not Found</h1>"
    .ascii "<p>The requested resource was not found.</p>"
    .asciz "</body></html>"
error_404_end:

error_405_body:
    .ascii "<html><body><h1>405 Method Not Allowed</h1>"
    .ascii "<p>The requested method is not allowed for this resource.</p>"
    .asciz "</body></html>"
error_405_end:

error_400_body:
    .ascii "<html><body><h1>400 Bad Request</h1>"
    .ascii "<p>The request could not be understood.</p>"
    .asciz "</body></html>"
error_400_end:

error_500_body:
    .ascii "<html><body><h1>500 Internal Server Error</h1>"
    .ascii "<p>An internal error occurred.</p>"
    .asciz "</body></html>"
error_500_end:

.section .data
error_404_len:
    .word error_404_end - error_404_body
error_405_len:
    .word error_405_end - error_405_body
error_400_len:
    .word error_400_end - error_400_body
error_500_len:
    .word error_500_end - error_500_body

.section .bss
.balign 8
resp_buffer:
    .skip 4096
