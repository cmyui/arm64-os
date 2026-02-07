// String Utility Benchmarks

.section .text
.global run_string_benchmarks

run_string_benchmarks:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl bench_section

    ldr x0, =ctx_parse_int
    bl bench_run
    ldr x0, =ctx_strlen
    bl bench_run
    ldr x0, =ctx_find_char
    bl bench_run

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark functions
//=============================================================================

// Parse "12345"
bench_fn_parse_int:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =str_number
    mov w1, #5
    bl parse_int

    ldp x29, x30, [sp], #16
    ret

// strlen on 50-char string
bench_fn_strlen:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =str_50chars
    bl strlen_simple

    ldp x29, x30, [sp], #16
    ret

// find_char in 50-char string (char near end)
bench_fn_find_char:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =str_50chars
    mov w1, #50
    mov w2, #'Z'
    bl find_char

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark contexts
//=============================================================================

.section .data
.balign 8
ctx_parse_int:
    .quad name_parse_int
    .quad bench_fn_parse_int
    .quad 0                    // no setup
    .quad 0                    // no teardown
    .word 1000
    .skip 28

.balign 8
ctx_strlen:
    .quad name_strlen
    .quad bench_fn_strlen
    .quad 0
    .quad 0
    .word 1000
    .skip 28

.balign 8
ctx_find_char:
    .quad name_find_char
    .quad bench_fn_find_char
    .quad 0
    .quad 0
    .word 1000
    .skip 28

.section .rodata
section_name:
    .asciz "string utilities"
name_parse_int:
    .asciz "parse_int"
name_strlen:
    .asciz "strlen_simple"
name_find_char:
    .asciz "find_char"

str_number:
    .asciz "12345"

str_50chars:
    .asciz "ABCDEFGHIJKLMNOPQRSTUVWXYabcdefghijklmnopqrstuvwxZ"
