// Benchmark Runner Entry Point

.section .text.boot
.global _start

_start:
    // Set up stack pointer
    ldr x0, =_stack_top
    mov sp, x0

    // Initialize subsystems
    bl uart_init
    bl mem_init
    bl db_init

    // Run benchmarks
    bl bench_start
    bl run_slab_benchmarks
    bl run_db_benchmarks
    bl run_string_benchmarks
    bl run_json_benchmarks
    bl run_request_benchmarks
    bl bench_end

halt:
    wfe
    b halt
