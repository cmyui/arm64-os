// SlowAPI Macros - Include this in your application
// Provides ENDPOINT macro for decorator-style route definitions

//=============================================================================
// HTTP Methods (bitmask for multiple methods per route)
//=============================================================================
.equ METHOD_GET,     0x01
.equ METHOD_POST,    0x02
.equ METHOD_PUT,     0x04
.equ METHOD_DELETE,  0x08
.equ METHOD_PATCH,   0x10

//=============================================================================
// Content Types
//=============================================================================
.equ CTYPE_HTML,     0
.equ CTYPE_JSON,     1
.equ CTYPE_TEXT,     2
.equ CTYPE_BINARY,   3

//=============================================================================
// HTTP Status Codes
//=============================================================================
.equ STATUS_OK,           200
.equ STATUS_CREATED,      201
.equ STATUS_NO_CONTENT,   204
.equ STATUS_BAD_REQUEST,  400
.equ STATUS_NOT_FOUND,    404
.equ STATUS_METHOD_NOT_ALLOWED, 405
.equ STATUS_SERVER_ERROR, 500

//=============================================================================
// Request Context Offsets (80 bytes)
//=============================================================================
.equ REQ_METHOD,         0     // 4 bytes: METHOD_GET, METHOD_POST, etc.
.equ REQ_PATH,           8     // 8 bytes: pointer to path string
.equ REQ_PATH_LEN,       16    // 4 bytes: path length
.equ REQ_QUERY,          24    // 8 bytes: pointer to query string (after ?)
.equ REQ_QUERY_LEN,      32    // 4 bytes: query string length
.equ REQ_BODY,           40    // 8 bytes: pointer to body data
.equ REQ_BODY_LEN,       48    // 4 bytes: body length
.equ REQ_HEADERS,        56    // 8 bytes: pointer to headers section
.equ REQ_PATH_PARAM,     64    // 8 bytes: pointer to path param value
.equ REQ_PATH_PARAM_LEN, 72    // 4 bytes: path param length
.equ REQ_SIZE,           80

//=============================================================================
// Response Context Offsets (32 bytes)
//=============================================================================
.equ RESP_STATUS,     0     // 4 bytes: status code (200, 404, etc.)
.equ RESP_BODY,       8     // 8 bytes: pointer to body data
.equ RESP_BODY_LEN,   16    // 4 bytes: body length
.equ RESP_CTYPE,      20    // 4 bytes: content type enum
.equ RESP_SIZE,       24

//=============================================================================
// Route Entry Offsets (32 bytes)
//=============================================================================
.equ ROUTE_PATH,      0     // 8 bytes: pointer to path string
.equ ROUTE_PATH_LEN,  8     // 4 bytes: path length
.equ ROUTE_METHODS,   12    // 4 bytes: method constant
.equ ROUTE_HANDLER,   16    // 8 bytes: pointer to handler
.equ ROUTE_SIZE,      24

//=============================================================================
// ENDPOINT Macro - The "decorator"
//
// Usage: ENDPOINT methods, "/path"
// Must be followed immediately by handler label and code
//
// Example:
//     ENDPOINT GET, "/api/time"
//     handler_time:
//         ldr x0, =json_time
//         ldr x1, =json_time_len
//         b resp_json
//=============================================================================

.macro ENDPOINT methods:req, path:req
    // Store path string in regular rodata (not routes section)
    .pushsection .rodata, "a", @progbits
.Lpath_\@:
    .asciz "\path"
.Lpath_end_\@:
    .popsection

    // Generate fixed-size route entry in .rodata.routes section
    .pushsection .rodata.routes, "a", @progbits
    .balign 8

.Lroute_\@:
    .quad .Lpath_\@                         // path pointer
    .word .Lpath_end_\@ - .Lpath_\@ - 1     // path length (excluding null)
    .word \methods                          // method constant
    .quad .Lhandler_\@                      // handler pointer

    .popsection

    // Handler label follows in .text
.Lhandler_\@:
.endm

//=============================================================================
// Frame Macros - Manage function prologues/epilogues
//
// FRAME_ENTER: Set up stack frame with optional callee-saved registers
// FRAME_LEAVE: Clean up stack frame and return
//
// Parameters:
//   regs: Number of register pairs to save (0-3)
//         0 = none, 1 = x19-x20, 2 = x19-x22, 3 = x19-x24
//   local_size: Additional stack space for local variables (default 0)
//
// Example:
//     handler_example:
//         FRAME_ENTER 1, 64    // saves x29,x30,x19,x20 + 64 bytes local
//         ...
//         FRAME_LEAVE 1, 64
//=============================================================================

.macro FRAME_ENTER regs:req, local_size=0
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    .if \regs >= 1
        stp x19, x20, [sp, #-16]!
    .endif
    .if \regs >= 2
        stp x21, x22, [sp, #-16]!
    .endif
    .if \regs >= 3
        stp x23, x24, [sp, #-16]!
    .endif
    .if \local_size > 0
        sub sp, sp, #\local_size
    .endif
.endm

.macro FRAME_LEAVE regs:req, local_size=0
    .if \local_size > 0
        add sp, sp, #\local_size
    .endif
    .if \regs >= 3
        ldp x23, x24, [sp], #16
    .endif
    .if \regs >= 2
        ldp x21, x22, [sp], #16
    .endif
    .if \regs >= 1
        ldp x19, x20, [sp], #16
    .endif
    ldp x29, x30, [sp], #16
    ret
.endm

//=============================================================================
// JSON Builder Macros - Convenience wrappers for common JSON operations
//
// These macros reduce boilerplate when building JSON responses.
// They assume JSON_CTX_SIZE is defined (typically 16 bytes).
//=============================================================================

// Initialize JSON context at base_reg with buffer of buf_size bytes
// Buffer starts at base_reg + JSON_CTX_SIZE
.macro JSON_INIT base_reg:req, buf_size:req
    mov x0, \base_reg
    add x1, \base_reg, #JSON_CTX_SIZE
    mov x2, #\buf_size
    bl json_init
.endm

// Add a key to JSON object
// ctx: register holding JSON context pointer
// label: symbol for the key string
// len: length of the key string
.macro JSON_KEY ctx:req, label:req, len:req
    mov x0, \ctx
    ldr x1, =\label
    mov x2, #\len
    bl json_add_key
.endm

// Add an integer value to JSON
.macro JSON_INT ctx:req, val:req
    mov x0, \ctx
    mov w1, \val
    bl json_add_int
.endm

// Add a comma separator
.macro JSON_COMMA ctx:req
    mov x0, \ctx
    bl json_comma
.endm

// Finish JSON and send response (calls json_finish then resp_json)
.macro JSON_RESPOND ctx:req
    mov x0, \ctx
    bl json_finish
    bl resp_json
.endm

// Start JSON object
.macro JSON_OBJ_START ctx:req
    mov x0, \ctx
    bl json_start_obj
.endm

// End JSON object
.macro JSON_OBJ_END ctx:req
    mov x0, \ctx
    bl json_end_obj
.endm

// Start JSON array
.macro JSON_ARR_START ctx:req
    mov x0, \ctx
    bl json_start_arr
.endm

// End JSON array
.macro JSON_ARR_END ctx:req
    mov x0, \ctx
    bl json_end_arr
.endm
