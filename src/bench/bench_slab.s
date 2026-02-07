// Slab Allocator Benchmarks

.section .text
.global run_slab_benchmarks

run_slab_benchmarks:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl bench_section

    ldr x0, =ctx_mem_alloc
    bl bench_run
    ldr x0, =ctx_mem_free
    bl bench_run
    ldr x0, =ctx_alloc_free_cycle
    bl bench_run

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark functions
//=============================================================================

// Allocate 64 bytes (free immediately to avoid exhausting blocks)
bench_fn_mem_alloc:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    mov x0, #64
    bl mem_alloc
    mov x19, x0

    // Free to keep pool available for next iteration
    mov x0, x19
    bl mem_free

    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// Free a block (alloc first, then free)
bench_fn_mem_free:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x0, #64
    bl mem_alloc
    bl mem_free

    ldp x29, x30, [sp], #16
    ret

// Allocate + free together
bench_fn_alloc_free_cycle:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    mov x0, #64
    bl mem_alloc
    bl mem_free

    ldp x29, x30, [sp], #16
    ret

// Setup: reinit allocator
bench_setup_reinit:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl mem_init
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark contexts
//=============================================================================

.section .data
.balign 8
ctx_mem_alloc:
    .quad name_mem_alloc       // BENCH_NAME
    .quad bench_fn_mem_alloc   // BENCH_FUNC
    .quad bench_setup_reinit   // BENCH_SETUP
    .quad 0                    // BENCH_TEARDOWN
    .word 1000                 // BENCH_ITERS
    .skip 28                   // min/max/total (runtime)

.balign 8
ctx_mem_free:
    .quad name_mem_free
    .quad bench_fn_mem_free
    .quad bench_setup_reinit
    .quad 0
    .word 1000
    .skip 28

.balign 8
ctx_alloc_free_cycle:
    .quad name_alloc_free_cycle
    .quad bench_fn_alloc_free_cycle
    .quad bench_setup_reinit
    .quad 0
    .word 1000
    .skip 28

.section .rodata
section_name:
    .asciz "slab allocator"
name_mem_alloc:
    .asciz "mem_alloc"
name_mem_free:
    .asciz "mem_free"
name_alloc_free_cycle:
    .asciz "alloc_free_cycle"
