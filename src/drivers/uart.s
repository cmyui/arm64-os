.section .text
.global uart_init
.global uart_putc
.global uart_puts
.global uart_print_hex8
.global uart_print_hex16
.global uart_print_hex32
.global uart_newline

// PL011 UART base address for QEMU virt machine
.equ UART_BASE, 0x09000000
.equ UART_DR,   0x00        // Data register
.equ UART_FR,   0x18        // Flag register
.equ UART_FR_TXFF, 5        // TX FIFO full flag bit

// uart_init: Initialize UART (minimal - QEMU PL011 works without config)
uart_init:
    ret

// uart_putc: Write a single character
// Input: w0 = character to write
uart_putc:
    ldr x1, =UART_BASE
1:
    ldr w2, [x1, #UART_FR]      // Load flag register
    tbnz w2, #UART_FR_TXFF, 1b  // Loop if TX FIFO full
    strb w0, [x1, #UART_DR]     // Write character
    ret

// uart_puts: Write a null-terminated string
// Input: x0 = pointer to string
uart_puts:
    stp x29, x30, [sp, #-16]!   // Save frame pointer and return address
    mov x29, sp
    stp x19, xzr, [sp, #-16]!   // Save x19 FIRST

    mov x19, x0                  // Now safe to use x19 for string pointer

.puts_loop:
    ldrb w0, [x19], #1          // Load byte and increment pointer
    cbz w0, .puts_done          // If null terminator, done
    bl uart_putc                // Print character
    b .puts_loop

.puts_done:
    ldp x19, xzr, [sp], #16     // Restore x19
    ldp x29, x30, [sp], #16     // Restore frame pointer and return address
    ret

// uart_newline: Print a newline
uart_newline:
    stp x29, x30, [sp, #-16]!
    mov w0, #'\n'
    bl uart_putc
    ldp x29, x30, [sp], #16
    ret

// uart_print_hex8: Print 8-bit value as 2 hex digits
// Input: w0 = value (lower 8 bits used)
uart_print_hex8:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    and w19, w0, #0xff

    // High nibble
    lsr w0, w19, #4
    bl .print_nibble

    // Low nibble
    and w0, w19, #0x0f
    bl .print_nibble

    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// uart_print_hex16: Print 16-bit value as 4 hex digits
// Input: w0 = value (lower 16 bits used)
uart_print_hex16:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    and w19, w0, #0xffff

    lsr w0, w19, #8
    bl uart_print_hex8

    and w0, w19, #0xff
    bl uart_print_hex8

    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// uart_print_hex32: Print 32-bit value as 8 hex digits
// Input: w0 = value
uart_print_hex32:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, xzr, [sp, #-16]!

    mov w19, w0

    lsr w0, w19, #16
    bl uart_print_hex16

    and w0, w19, #0xffff
    bl uart_print_hex16

    ldp x19, xzr, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// .print_nibble: Print single hex digit
// Input: w0 = value 0-15
.print_nibble:
    stp x29, x30, [sp, #-16]!

    cmp w0, #10
    b.lt .digit
    add w0, w0, #('a' - 10)
    b .print_it
.digit:
    add w0, w0, #'0'
.print_it:
    bl uart_putc

    ldp x29, x30, [sp], #16
    ret
