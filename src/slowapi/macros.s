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
// Request Context Offsets (64 bytes)
//=============================================================================
.equ REQ_METHOD,      0     // 4 bytes: METHOD_GET, METHOD_POST, etc.
.equ REQ_PATH,        8     // 8 bytes: pointer to path string
.equ REQ_PATH_LEN,    16    // 4 bytes: path length
.equ REQ_QUERY,       24    // 8 bytes: pointer to query string (after ?)
.equ REQ_QUERY_LEN,   32    // 4 bytes: query string length
.equ REQ_BODY,        40    // 8 bytes: pointer to body data
.equ REQ_BODY_LEN,    48    // 4 bytes: body length
.equ REQ_HEADERS,     56    // 8 bytes: pointer to headers section
.equ REQ_SIZE,        64

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
.equ ROUTE_METHODS,   12    // 4 bytes: method bitmask
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
    .word \methods                          // methods bitmask
    .quad .Lhandler_\@                      // handler pointer

    .popsection

    // Handler label follows in .text
.Lhandler_\@:
.endm
