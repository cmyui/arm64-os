// Database Benchmarks

.section .text
.global run_db_benchmarks

run_db_benchmarks:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =section_name
    bl bench_section

    ldr x0, =ctx_db_create
    bl bench_run
    ldr x0, =ctx_db_get
    bl bench_run
    ldr x0, =ctx_db_delete
    bl bench_run
    ldr x0, =ctx_db_list
    bl bench_run

    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark functions
//=============================================================================

// Create + delete a record (self-contained per iteration)
bench_fn_db_create:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =test_record
    mov x1, #8
    bl db_create
    // Delete to keep db clean for next iteration
    bl db_delete

    ldp x29, x30, [sp], #16
    ret

// Get a record by ID (record created in setup)
bench_fn_db_get:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =db_saved_id
    ldr w0, [x0]
    bl db_get

    ldp x29, x30, [sp], #16
    ret

// Create + delete (measures delete cost, self-contained)
bench_fn_db_delete:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =test_record
    mov x1, #8
    bl db_create
    bl db_delete

    ldp x29, x30, [sp], #16
    ret

// Count records
bench_fn_db_list:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl db_count

    ldp x29, x30, [sp], #16
    ret

// Setup: reinit mem + db
bench_db_setup_reinit:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl mem_init
    bl db_init

    ldp x29, x30, [sp], #16
    ret

// Setup: reinit + create one record (for get benchmark)
bench_db_setup_create:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    bl mem_init
    bl db_init
    ldr x0, =test_record
    mov x1, #8
    bl db_create
    ldr x1, =db_saved_id
    str w0, [x1]

    ldp x29, x30, [sp], #16
    ret

// Setup: reinit + populate 10 records (for list benchmark)
bench_db_setup_populate:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    bl mem_init
    bl db_init

    mov w19, #10
.populate_loop:
    cbz w19, .populate_done
    ldr x0, =test_record
    mov x1, #8
    bl db_create
    sub w19, w19, #1
    b .populate_loop
.populate_done:

    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Benchmark contexts
//=============================================================================

.section .data
.balign 8
ctx_db_create:
    .quad name_db_create
    .quad bench_fn_db_create
    .quad bench_db_setup_reinit
    .quad 0
    .word 500
    .skip 28

.balign 8
ctx_db_get:
    .quad name_db_get
    .quad bench_fn_db_get
    .quad bench_db_setup_create
    .quad 0
    .word 1000
    .skip 28

.balign 8
ctx_db_delete:
    .quad name_db_delete
    .quad bench_fn_db_delete
    .quad bench_db_setup_reinit
    .quad 0
    .word 500
    .skip 28

.balign 8
ctx_db_list:
    .quad name_db_list
    .quad bench_fn_db_list
    .quad bench_db_setup_populate
    .quad 0
    .word 100
    .skip 28

.section .rodata
section_name:
    .asciz "database"
name_db_create:
    .asciz "db_create"
name_db_get:
    .asciz "db_get"
name_db_delete:
    .asciz "db_delete"
name_db_list:
    .asciz "db_list"

test_record:
    .ascii "testdata"

.section .bss
.balign 4
db_saved_id:
    .skip 4
