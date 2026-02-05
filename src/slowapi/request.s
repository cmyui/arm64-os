// SlowAPI Request Parser
// Parses raw HTTP requests into structured request context

.section .text
.global slowapi_parse_request

.include "src/slowapi/macros.s"

// slowapi_parse_request: Parse raw HTTP into request context
// Input: x0 = raw HTTP data ptr
//        x1 = data length
//        x2 = request context ptr (to fill)
// Output: w0 = 0 on success, -1 on failure
slowapi_parse_request:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    mov x19, x0             // raw data
    mov x20, x1             // length
    mov x21, x2             // request context

    // Initialize context to zero
    mov x0, x21
    mov x1, #REQ_SIZE
    bl memzero

    // Check minimum length for "GET / "
    cmp x20, #5
    b.lt .parse_fail

    // Parse method
    mov x0, x19
    mov x1, x20
    bl parse_method
    cmp w0, #0
    b.lt .parse_fail
    str w0, [x21, #REQ_METHOD]
    mov x22, x1             // x1 = position after method + space

    // Parse path (starts at x22, ends at space or ?)
    mov x0, x19
    add x0, x0, x22         // pointer to path start
    sub x1, x20, x22        // remaining length
    bl parse_path
    cmp x0, #0
    b.eq .parse_fail

    // x0 = path pointer, x1 = path length, x2 = query pointer (or 0), x3 = query length
    str x0, [x21, #REQ_PATH]
    str w1, [x21, #REQ_PATH_LEN]
    str x2, [x21, #REQ_QUERY]
    str w3, [x21, #REQ_QUERY_LEN]

    // Find end of request line (look for \r\n)
    mov x0, x19
    mov x1, x20
    bl find_crlf
    cbz x0, .parse_fail
    mov x23, x0             // x23 = pointer to first \r\n

    // Headers start after first \r\n
    add x0, x23, #2
    str x0, [x21, #REQ_HEADERS]

    // Find body (after \r\n\r\n)
    mov x0, x19
    mov x1, x20
    bl find_body
    cbz x0, .no_body

    // x0 = body pointer
    str x0, [x21, #REQ_BODY]

    // Calculate body length
    sub x1, x19, x0         // negative offset
    neg x1, x1              // positive offset from start
    sub x1, x20, x1         // remaining = total - offset
    str w1, [x21, #REQ_BODY_LEN]
    b .parse_done

.no_body:
    str xzr, [x21, #REQ_BODY]
    str wzr, [x21, #REQ_BODY_LEN]

.parse_done:
    mov w0, #0
    b .parse_exit

.parse_fail:
    mov w0, #-1

.parse_exit:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// parse_method: Parse HTTP method
// Input: x0 = data ptr, x1 = length
// Output: w0 = method constant (or -1), x1 = position after method + space
parse_method:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov x19, x0
    mov x20, x1

    // Check for GET
    cmp x20, #4
    b.lt .method_fail

    ldrb w0, [x19, #0]
    cmp w0, #'G'
    b.ne .try_post

    ldrb w0, [x19, #1]
    cmp w0, #'E'
    b.ne .try_post

    ldrb w0, [x19, #2]
    cmp w0, #'T'
    b.ne .try_post

    ldrb w0, [x19, #3]
    cmp w0, #' '
    b.ne .try_post

    mov w0, #METHOD_GET
    mov x1, #4
    b .method_done

.try_post:
    cmp x20, #5
    b.lt .try_put

    ldrb w0, [x19, #0]
    cmp w0, #'P'
    b.ne .try_put

    ldrb w0, [x19, #1]
    cmp w0, #'O'
    b.ne .try_put

    ldrb w0, [x19, #2]
    cmp w0, #'S'
    b.ne .try_put

    ldrb w0, [x19, #3]
    cmp w0, #'T'
    b.ne .try_put

    ldrb w0, [x19, #4]
    cmp w0, #' '
    b.ne .try_put

    mov w0, #METHOD_POST
    mov x1, #5
    b .method_done

.try_put:
    cmp x20, #4
    b.lt .try_delete

    ldrb w0, [x19, #0]
    cmp w0, #'P'
    b.ne .try_delete

    ldrb w0, [x19, #1]
    cmp w0, #'U'
    b.ne .try_delete

    ldrb w0, [x19, #2]
    cmp w0, #'T'
    b.ne .try_delete

    ldrb w0, [x19, #3]
    cmp w0, #' '
    b.ne .try_delete

    mov w0, #METHOD_PUT
    mov x1, #4
    b .method_done

.try_delete:
    cmp x20, #7
    b.lt .try_patch

    ldrb w0, [x19, #0]
    cmp w0, #'D'
    b.ne .try_patch

    ldrb w0, [x19, #1]
    cmp w0, #'E'
    b.ne .try_patch

    ldrb w0, [x19, #2]
    cmp w0, #'L'
    b.ne .try_patch

    ldrb w0, [x19, #3]
    cmp w0, #'E'
    b.ne .try_patch

    ldrb w0, [x19, #4]
    cmp w0, #'T'
    b.ne .try_patch

    ldrb w0, [x19, #5]
    cmp w0, #'E'
    b.ne .try_patch

    ldrb w0, [x19, #6]
    cmp w0, #' '
    b.ne .try_patch

    mov w0, #METHOD_DELETE
    mov x1, #7
    b .method_done

.try_patch:
    cmp x20, #6
    b.lt .method_fail

    ldrb w0, [x19, #0]
    cmp w0, #'P'
    b.ne .method_fail

    ldrb w0, [x19, #1]
    cmp w0, #'A'
    b.ne .method_fail

    ldrb w0, [x19, #2]
    cmp w0, #'T'
    b.ne .method_fail

    ldrb w0, [x19, #3]
    cmp w0, #'C'
    b.ne .method_fail

    ldrb w0, [x19, #4]
    cmp w0, #'H'
    b.ne .method_fail

    ldrb w0, [x19, #5]
    cmp w0, #' '
    b.ne .method_fail

    mov w0, #METHOD_PATCH
    mov x1, #6
    b .method_done

.method_fail:
    mov w0, #-1
    mov x1, #0

.method_done:
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// parse_path: Parse path and query string
// Input: x0 = path start ptr, x1 = remaining length
// Output: x0 = path ptr, x1 = path len, x2 = query ptr (or 0), x3 = query len
parse_path:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0             // path start
    mov x20, x1             // remaining length
    mov x21, #0             // query ptr
    mov x22, #0             // query len

    // Scan for space, ?, or end
    mov x0, x19
    mov x1, #0              // path length counter

.path_scan:
    cmp x1, x20
    b.ge .path_end

    ldrb w2, [x0, x1]

    // Check for space (end of path+query)
    cmp w2, #' '
    b.eq .path_end

    // Check for ? (start of query)
    cmp w2, #'?'
    b.eq .found_query

    add x1, x1, #1
    b .path_scan

.found_query:
    // x1 = path length (before ?)
    mov x3, x1              // save path length

    // Query starts after ?
    add x21, x19, x1
    add x21, x21, #1        // skip ?

    // Scan for space to find query end
    add x4, x1, #1          // position after ?
.query_scan:
    cmp x4, x20
    b.ge .query_end

    ldrb w2, [x19, x4]
    cmp w2, #' '
    b.eq .query_end

    add x4, x4, #1
    b .query_scan

.query_end:
    // Query length = current pos - query start pos
    sub x22, x4, x3
    sub x22, x22, #1        // subtract 1 for ?
    mov x1, x3              // restore path length
    b .path_done

.path_end:
    // No query string

.path_done:
    mov x0, x19             // path ptr
    // x1 = path length (already set)
    mov x2, x21             // query ptr
    mov x3, x22             // query length

    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// find_crlf: Find first \r\n in data
// Input: x0 = data ptr, x1 = length
// Output: x0 = pointer to \r (or 0 if not found)
find_crlf:
    mov x2, x0
    mov x3, x1

.crlf_scan:
    cmp x3, #2
    b.lt .crlf_not_found

    ldrb w4, [x2]
    cmp w4, #'\r'
    b.ne .crlf_next

    ldrb w4, [x2, #1]
    cmp w4, #'\n'
    b.ne .crlf_next

    mov x0, x2
    ret

.crlf_next:
    add x2, x2, #1
    sub x3, x3, #1
    b .crlf_scan

.crlf_not_found:
    mov x0, #0
    ret

// find_body: Find body (after \r\n\r\n)
// Input: x0 = data ptr, x1 = length
// Output: x0 = pointer to body (or 0 if not found)
find_body:
    mov x2, x0
    mov x3, x1

.body_scan:
    cmp x3, #4
    b.lt .body_not_found

    ldrb w4, [x2]
    cmp w4, #'\r'
    b.ne .body_next

    ldrb w4, [x2, #1]
    cmp w4, #'\n'
    b.ne .body_next

    ldrb w4, [x2, #2]
    cmp w4, #'\r'
    b.ne .body_next

    ldrb w4, [x2, #3]
    cmp w4, #'\n'
    b.ne .body_next

    // Found \r\n\r\n - body starts after
    add x0, x2, #4
    ret

.body_next:
    add x2, x2, #1
    sub x3, x3, #1
    b .body_scan

.body_not_found:
    mov x0, #0
    ret

// memzero: Zero memory
// Input: x0 = ptr, x1 = length
memzero:
    cbz x1, .memzero_done
.memzero_loop:
    strb wzr, [x0], #1
    subs x1, x1, #1
    b.ne .memzero_loop
.memzero_done:
    ret
