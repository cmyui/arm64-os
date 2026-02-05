// SlowAPI String Utilities
// Common string manipulation functions for use by applications

.section .text

//=============================================================================
// parse_int: Parse decimal integer from string
// Input: x0 = string pointer, w1 = length
// Output: x0 = parsed value (0 on failure)
//=============================================================================
.global parse_int
parse_int:
    cbz x0, .parse_fail
    cbz w1, .parse_fail

    mov x2, #0               // result
    mov w3, #0               // index

.parse_loop:
    cmp w3, w1
    b.ge .parse_done

    ldrb w4, [x0, x3]

    // Check if digit
    cmp w4, #'0'
    b.lt .parse_fail
    cmp w4, #'9'
    b.gt .parse_fail

    // result = result * 10 + digit
    mov x5, #10
    mul x2, x2, x5
    sub w4, w4, #'0'
    add x2, x2, x4

    add w3, w3, #1
    b .parse_loop

.parse_done:
    mov x0, x2
    ret

.parse_fail:
    mov x0, #0
    ret

//=============================================================================
// strlen_simple: Get string length
// Input: x0 = null-terminated string
// Output: x0 = length (not including null)
//=============================================================================
.global strlen_simple
strlen_simple:
    mov x1, x0
    mov x2, #0
.strlen_loop:
    ldrb w3, [x1], #1
    cbz w3, .strlen_done
    add x2, x2, #1
    b .strlen_loop
.strlen_done:
    mov x0, x2
    ret

//=============================================================================
// find_char: Find character in string
// Input: x0 = string, w1 = length, w2 = character to find
// Output: x0 = pointer to character, or 0 if not found
//=============================================================================
.global find_char
find_char:
    cbz w1, .find_not_found
.find_loop:
    ldrb w3, [x0]
    cmp w3, w2
    b.eq .find_found
    add x0, x0, #1
    sub w1, w1, #1
    cbnz w1, .find_loop
.find_not_found:
    mov x0, #0
    ret
.find_found:
    ret
