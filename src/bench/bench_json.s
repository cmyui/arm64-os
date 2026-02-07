// JSON Builder Benchmarks

.section .text
.global run_json_benchmarks

.include "src/slowapi/macros.s"

.equ JSON_CTX_SIZE, 16

run_json_benchmarks:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl bench_section

    ldr x0, =ctx_json_init
    bl bench_run
    ldr x0, =ctx_json_build_object
    bl bench_run

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark functions
//=============================================================================

// Initialize JSON context (stack-allocated buffer)
bench_fn_json_init:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Allocate JSON context + buffer on stack
    sub sp, sp, #272           // 16 (ctx) + 256 (buffer)
    mov x0, sp                 // context
    add x1, sp, #JSON_CTX_SIZE // buffer
    mov x2, #256
    bl json_init

    add sp, sp, #272
    ldp x29, x30, [sp], #16
    ret

// Build {"id":42,"name":"test"} end-to-end
bench_fn_json_build_object:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    // Allocate JSON context + buffer on stack
    sub sp, sp, #272
    mov x19, sp               // save context pointer

    // Init
    mov x0, x19
    add x1, x19, #JSON_CTX_SIZE
    mov x2, #256
    bl json_init

    // Start object
    mov x0, x19
    bl json_start_obj

    // Add "id": 42
    mov x0, x19
    ldr x1, =key_id
    mov x2, #2
    bl json_add_key

    mov x0, x19
    mov w1, #42
    bl json_add_int

    // Comma
    mov x0, x19
    bl json_comma

    // Add "name": "test"
    mov x0, x19
    ldr x1, =key_name
    mov x2, #4
    bl json_add_key

    mov x0, x19
    ldr x1, =val_test
    mov x2, #4
    bl json_add_string

    // End object
    mov x0, x19
    bl json_end_obj

    // Finish
    mov x0, x19
    bl json_finish

    add sp, sp, #272
    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark contexts
//=============================================================================

.section .data
.balign 8
ctx_json_init:
    .quad name_json_init
    .quad bench_fn_json_init
    .quad 0
    .quad 0
    .word 1000
    .skip 28

.balign 8
ctx_json_build_object:
    .quad name_json_build_object
    .quad bench_fn_json_build_object
    .quad 0
    .quad 0
    .word 500
    .skip 28

.section .rodata
section_name:
    .asciz "json builder"
name_json_init:
    .asciz "json_init"
name_json_build_object:
    .asciz "json_build_object"

key_id:
    .asciz "id"
key_name:
    .asciz "name"
val_test:
    .asciz "test"
