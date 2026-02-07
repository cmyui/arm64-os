// HTTP Request Parsing Benchmarks

.section .text
.global run_request_benchmarks

.include "src/slowapi/macros.s"

run_request_benchmarks:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl bench_section

    ldr x0, =ctx_parse_request
    bl bench_run

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark functions
//=============================================================================

// Parse a complete HTTP request
bench_fn_parse_request:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Allocate request context on stack
    sub sp, sp, #REQ_SIZE

    ldr x0, =http_request
    ldr x1, =http_request_len
    ldr w1, [x1]
    mov x2, sp                 // request context
    bl slowapi_parse_request

    add sp, sp, #REQ_SIZE
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark contexts
//=============================================================================

.section .data
.balign 8
ctx_parse_request:
    .quad name_parse_request
    .quad bench_fn_parse_request
    .quad 0
    .quad 0
    .word 500
    .skip 28

.section .rodata
section_name:
    .asciz "request parsing"
name_parse_request:
    .asciz "parse_request"

http_request:
    .ascii "GET /api/hotels?city=tokyo HTTP/1.1\r\n"
    .ascii "Host: localhost\r\n"
    .ascii "Accept: application/json\r\n"
    .ascii "\r\n"
http_request_end:

.balign 4
http_request_len:
    .word http_request_end - http_request
