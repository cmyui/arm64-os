// Benchmark Harness
// Run N iterations, track min/avg/max ticks, print results

.section .text
.global bench_start
.global bench_end
.global bench_section
.global bench_run

// Benchmark context layout (all 8-byte fields must be 8-byte aligned)
.equ BENCH_NAME,     0    // 8 bytes: pointer to name string
.equ BENCH_FUNC,     8    // 8 bytes: pointer to benchmark function
.equ BENCH_SETUP,    16   // 8 bytes: setup function (0 = none)
.equ BENCH_TEARDOWN, 24   // 8 bytes: teardown function (0 = none)
.equ BENCH_ITERS,    32   // 4 bytes: iteration count
                           // 4 bytes: padding
.equ BENCH_MIN,      40   // 8 bytes: min ticks
.equ BENCH_MAX,      48   // 8 bytes: max ticks
.equ BENCH_TOTAL,    56   // 8 bytes: total ticks
.equ BENCH_CTX_SIZE, 64

// bench_start: Print header, cache timer frequency
bench_start:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Cache timer frequency
    bl timer_freq
    ldr x1, =cached_freq
    str x0, [x1]

    // Reset bench count
    ldr x0, =bench_count
    str wzr, [x0]

    // Print header
    ldr x0, =msg_bench_header
    bl uart_puts

    ldp x29, x30, [sp], #16
    ret

// bench_end: Print summary
bench_end:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    ldr x0, =msg_bench_summary
    bl uart_puts

    // Print count
    ldr x0, =msg_bench_run
    bl uart_puts
    ldr x0, =bench_count
    ldr w0, [x0]
    bl bench_print_decimal
    bl uart_newline

    // Print frequency
    ldr x0, =msg_timer_freq
    bl uart_puts
    ldr x0, =cached_freq
    ldr x0, [x0]
    // Print 64-bit frequency as decimal
    bl bench_print_decimal_64
    ldr x0, =msg_hz
    bl uart_puts
    bl uart_newline

    ldp x29, x30, [sp], #16
    ret

// bench_section: Print section header
// Input: x0 = section name string
bench_section:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    mov x19, x0

    ldr x0, =msg_section_start
    bl uart_puts
    mov x0, x19
    bl uart_puts
    ldr x0, =msg_section_end
    bl uart_puts

    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// bench_run: Run a benchmark
// Input: x0 = pointer to benchmark context
bench_run:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    mov x19, x0              // benchmark context

    // Initialize min/max/total
    mov x0, #-1              // 0xFFFFFFFFFFFFFFFF
    str x0, [x19, #BENCH_MIN]
    str xzr, [x19, #BENCH_MAX]
    str xzr, [x19, #BENCH_TOTAL]

    // Increment bench count
    ldr x0, =bench_count
    ldr w1, [x0]
    add w1, w1, #1
    str w1, [x0]

    // Call setup once if present
    ldr x0, [x19, #BENCH_SETUP]
    cbz x0, .bench_loop_init
    blr x0

.bench_loop_init:
    ldr w20, [x19, #BENCH_ITERS] // iteration count
    mov w21, #0                   // current iteration

.bench_loop:
    cmp w21, w20
    b.ge .bench_loop_done

    // Read start time
    bl timer_read
    mov x22, x0

    // Call benchmark function
    ldr x0, [x19, #BENCH_FUNC]
    blr x0

    // Read end time
    bl timer_read
    sub x23, x0, x22         // elapsed = end - start

    // Update min
    ldr x0, [x19, #BENCH_MIN]
    cmp x23, x0
    b.hs .skip_min
    str x23, [x19, #BENCH_MIN]
.skip_min:

    // Update max
    ldr x0, [x19, #BENCH_MAX]
    cmp x23, x0
    b.ls .skip_max
    str x23, [x19, #BENCH_MAX]
.skip_max:

    // Update total
    ldr x0, [x19, #BENCH_TOTAL]
    add x0, x0, x23
    str x0, [x19, #BENCH_TOTAL]

    add w21, w21, #1
    b .bench_loop

.bench_loop_done:
    // Call teardown if present
    ldr x0, [x19, #BENCH_TEARDOWN]
    cbz x0, .bench_print
    blr x0

.bench_print:
    // Print: name | N iters | min: X (Y us) | avg: X (Y us) | max: X (Y us)

    // Print name (left-padded to 20 chars)
    ldr x0, [x19, #BENCH_NAME]
    bl bench_print_padded_name

    // Print " | "
    ldr x0, =msg_sep
    bl uart_puts

    // Print iteration count (right-aligned to 4 digits)
    ldr w0, [x19, #BENCH_ITERS]
    bl bench_print_rjust4
    ldr x0, =msg_iters
    bl uart_puts

    // Print min
    ldr x0, =msg_min
    bl uart_puts
    ldr x0, [x19, #BENCH_MIN]
    bl bench_print_decimal_64
    ldr x0, =msg_paren_open
    bl uart_puts
    ldr x0, [x19, #BENCH_MIN]
    bl bench_print_ns
    ldr x0, =msg_us_close
    bl uart_puts

    // Print avg
    ldr x0, =msg_avg
    bl uart_puts
    ldr x0, [x19, #BENCH_TOTAL]
    ldr w1, [x19, #BENCH_ITERS]
    udiv x0, x0, x1
    mov x24, x0              // save avg for us conversion
    bl bench_print_decimal_64
    ldr x0, =msg_paren_open
    bl uart_puts
    mov x0, x24
    bl bench_print_ns
    ldr x0, =msg_us_close
    bl uart_puts

    // Print max
    ldr x0, =msg_max
    bl uart_puts
    ldr x0, [x19, #BENCH_MAX]
    bl bench_print_decimal_64
    ldr x0, =msg_paren_open
    bl uart_puts
    ldr x0, [x19, #BENCH_MAX]
    bl bench_print_ns
    ldr x0, =msg_us_end
    bl uart_puts

    bl uart_newline

    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// bench_print_ns: Print ticks converted to nanoseconds
// Input: x0 = ticks
bench_print_ns:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // ns = ticks * 1000000000 / freq
    // 1000000000 = 0x3B9ACA00
    mov x1, #0xCA00
    movk x1, #0x3B9A, lsl #16
    mul x0, x0, x1
    ldr x1, =cached_freq
    ldr x1, [x1]
    udiv x0, x0, x1
    bl bench_print_decimal_64

    ldp x29, x30, [sp], #16
    ret

// bench_print_padded_name: Print name left-padded to 20 chars
// Input: x0 = name string
bench_print_padded_name:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov x19, x0
    // Get length
    bl strlen_simple
    mov x20, x0              // length

    // Print name
    mov x0, x19
    bl uart_puts

    // Pad with spaces
    mov x1, #20
.pad_loop:
    cmp x20, x1
    b.ge .pad_done
    mov w0, #' '
    stp x1, x20, [sp, #-16]!
    bl uart_putc
    ldp x1, x20, [sp], #16
    add x20, x20, #1
    b .pad_loop
.pad_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// bench_print_rjust4: Print number right-justified in 4 chars
// Input: w0 = number
bench_print_rjust4:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov w19, w0

    // Count digits
    mov w20, #0               // digit count
    mov w1, w19
    cbz w1, .rj_one_digit
.rj_count:
    cbz w1, .rj_pad
    mov w2, #10
    udiv w1, w1, w2
    add w20, w20, #1
    b .rj_count

.rj_one_digit:
    mov w20, #1

.rj_pad:
    // Print leading spaces
    mov w1, #4
    sub w1, w1, w20
.rj_space:
    cmp w1, #0
    b.le .rj_print
    mov w0, #' '
    stp x1, xzr, [sp, #-16]!
    bl uart_putc
    ldp x1, xzr, [sp], #16
    sub w1, w1, #1
    b .rj_space

.rj_print:
    mov w0, w19
    bl bench_print_decimal

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// bench_print_decimal: Print 32-bit decimal number
// Input: w0 = number
bench_print_decimal:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov w19, w0
    mov x20, sp               // save sp before any stack manipulation

    cbz w19, .bpd_zero

    // Build digits in reverse on stack
    sub sp, sp, #16
    mov x1, sp

    mov w2, #10
.bpd_loop:
    cbz w19, .bpd_print
    udiv w3, w19, w2
    msub w4, w3, w2, w19
    add w4, w4, #'0'
    strb w4, [x1], #1
    mov w19, w3
    b .bpd_loop

.bpd_print:
    mov x3, sp
.bpd_print_loop:
    cmp x1, x3
    b.le .bpd_done
    sub x1, x1, #1
    ldrb w0, [x1]
    stp x1, x3, [sp, #-16]!
    bl uart_putc
    ldp x1, x3, [sp], #16
    b .bpd_print_loop

.bpd_zero:
    mov w0, #'0'
    bl uart_putc
    b .bpd_done

.bpd_done:
    mov sp, x20
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// bench_print_decimal_64: Print 64-bit decimal number
// Input: x0 = number
bench_print_decimal_64:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov x19, x0
    mov x20, sp               // save sp before any stack manipulation

    cbz x19, .bpd64_zero

    sub sp, sp, #32
    mov x1, sp

    mov x2, #10
.bpd64_loop:
    cbz x19, .bpd64_print
    udiv x3, x19, x2
    msub x4, x3, x2, x19
    add w4, w4, #'0'
    strb w4, [x1], #1
    mov x19, x3
    b .bpd64_loop

.bpd64_print:
    mov x3, sp
.bpd64_print_loop:
    cmp x1, x3
    b.le .bpd64_done
    sub x1, x1, #1
    ldrb w0, [x1]
    stp x1, x3, [sp, #-16]!
    bl uart_putc
    ldp x1, x3, [sp], #16
    b .bpd64_print_loop

.bpd64_zero:
    mov w0, #'0'
    bl uart_putc
    b .bpd64_done

.bpd64_done:
    mov sp, x20
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

//=============================================================================
// Data
//=============================================================================

.section .rodata
msg_bench_header:
    .asciz "\n========== RUNNING BENCHMARKS ==========\n"
msg_bench_summary:
    .asciz "\n========== BENCHMARK SUMMARY ==========\n"
msg_bench_run:
    .asciz "Benchmarks run: "
msg_timer_freq:
    .asciz "Timer frequency: "
msg_hz:
    .asciz " Hz"
msg_section_start:
    .asciz "\n--- "
msg_section_end:
    .asciz " ---\n"
msg_sep:
    .asciz " | "
msg_iters:
    .asciz " iters | "
msg_min:
    .asciz "min: "
msg_avg:
    .asciz "avg: "
msg_max:
    .asciz "max: "
msg_paren_open:
    .asciz " ("
msg_us_close:
    .asciz " ns) | "
msg_us_end:
    .asciz " ns)"

.section .bss
.balign 8
cached_freq:
    .skip 8
bench_count:
    .skip 4
