// SlowAPI Example Application
// Demonstrates decorator-style route definitions

.section .text

.include "src/slowapi/macros.s"

//=============================================================================
// ROUTES - Define them right where the handler is!
//=============================================================================

// GET / - Homepage
ENDPOINT METHOD_GET, "/"
handler_index:
    ldr x0, =html_index
    ldr x1, =html_index_len
    ldr w1, [x1]
    b resp_html

// GET /api/info - JSON API endpoint
ENDPOINT METHOD_GET, "/api/info"
handler_info:
    ldr x0, =json_info
    ldr x1, =json_info_len
    ldr w1, [x1]
    b resp_json

// POST /api/echo - Echo request body
ENDPOINT METHOD_POST, "/api/echo"
handler_echo:
    // x0 = request context
    ldr x1, [x0, #REQ_BODY]      // body pointer
    ldr w2, [x0, #REQ_BODY_LEN]  // body length

    // If no body, return empty
    cbz x1, .echo_empty
    cbz w2, .echo_empty

    mov x0, x1
    mov x1, x2
    b resp_text

.echo_empty:
    ldr x0, =empty_body
    mov x1, #0
    b resp_text

// GET /health - Health check (plain text)
ENDPOINT METHOD_GET, "/health"
handler_health:
    ldr x0, =txt_ok
    mov x1, #2
    b resp_text

// GET|POST /api/data - Multiple methods on same route
ENDPOINT (METHOD_GET | METHOD_POST), "/api/data"
handler_data:
    ldr w1, [x0, #REQ_METHOD]
    cmp w1, #METHOD_POST
    b.eq .data_post

    // GET - return current data
    ldr x0, =json_data
    ldr x1, =json_data_len
    ldr w1, [x1]
    b resp_json

.data_post:
    // POST - acknowledge receipt
    mov w0, #STATUS_CREATED
    ldr x1, =json_created
    ldr x2, =json_created_len
    ldr w2, [x2]
    mov w3, #CTYPE_JSON
    b resp_status

// GET /binary - Binary response demo
ENDPOINT METHOD_GET, "/binary"
handler_binary:
    ldr x0, =binary_data
    mov x1, #16
    b resp_binary

// DELETE /api/resource - Delete endpoint demo
ENDPOINT METHOD_DELETE, "/api/resource"
handler_delete:
    // Return 204 No Content
    b resp_no_content

//=============================================================================
// STATIC DATA
//=============================================================================
.section .rodata

html_index:
    .ascii "<html><head><title>SlowAPI</title></head>"
    .ascii "<body><h1>SlowAPI</h1>"
    .ascii "<p>The world's slowest web framework</p>"
    .ascii "<p>Written in pure ARM64 assembly, running bare-metal</p>"
    .ascii "<ul>"
    .ascii "<li><a href='/api/info'>API Info (JSON)</a></li>"
    .ascii "<li><a href='/health'>Health Check</a></li>"
    .ascii "<li><a href='/api/data'>Data Endpoint (GET/POST)</a></li>"
    .ascii "<li><a href='/binary'>Binary Response</a></li>"
    .ascii "</ul>"
    .ascii "<h2>Try it:</h2>"
    .ascii "<pre>curl -X POST -d 'Hello!' http://localhost:8080/api/echo</pre>"
    .ascii "</body></html>"
html_index_end:

json_info:
    .ascii "{\"framework\":\"SlowAPI\","
    .ascii "\"version\":\"0.1.0\","
    .ascii "\"language\":\"ARM64 Assembly\","
    .ascii "\"runtime\":\"bare-metal\","
    .ascii "\"features\":[\"routing\",\"content-types\",\"method-dispatch\"]}"
json_info_end:

json_data:
    .ascii "{\"items\":[1,2,3],\"count\":3}"
json_data_end:

json_created:
    .ascii "{\"status\":\"created\"}"
json_created_end:

txt_ok:
    .asciz "OK"

empty_body:
    .byte 0

binary_data:
    // PNG magic bytes (just for demo)
    .byte 0x89, 0x50, 0x4E, 0x47
    .byte 0x0D, 0x0A, 0x1A, 0x0A
    .byte 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00

.section .data
html_index_len:
    .word html_index_end - html_index
json_info_len:
    .word json_info_end - json_info
json_data_len:
    .word json_data_end - json_data
json_created_len:
    .word json_created_end - json_created
