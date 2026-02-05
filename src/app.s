// SlowAPI Hotel CRUD Application
// Demonstrates path parameters, JSON building, and in-memory database

.section .text

.include "src/slowapi/macros.s"

// Hotel record layout (stored in database)
.equ HOTEL_NAME_OFF,    0    // 32 bytes: name (null-terminated)
.equ HOTEL_CITY_OFF,    32   // 32 bytes: city (null-terminated)
.equ HOTEL_SIZE,        64
.equ HOTEL_NAME_MAX,    31   // max name length (leave 1 for null)
.equ HOTEL_CITY_MAX,    31   // max city length

//=============================================================================
// JSON CONTEXT SIZE (from json.s)
//=============================================================================
.equ JSON_CTX_SIZE, 16

//=============================================================================
// Stack Frame Sizes (named constants for clarity)
//=============================================================================
.equ LIST_HOTELS_LOCAL,   JSON_CTX_SIZE + 1024
.equ GET_HOTEL_LOCAL,     JSON_CTX_SIZE + 512
.equ CREATE_HOTEL_LOCAL,  HOTEL_SIZE + JSON_CTX_SIZE + 512

//=============================================================================
// ROUTES
//=============================================================================

// GET / - Homepage
ENDPOINT METHOD_GET, "/"
handler_index:
    ldr x0, =html_index
    ldr x1, =html_index_len
    ldr w1, [x1]
    b resp_html

// GET /api/hotels - List all hotels
ENDPOINT METHOD_GET, "/api/hotels"
handler_list_hotels:
    FRAME_ENTER 0, LIST_HOTELS_LOCAL

    JSON_INIT sp, 1024
    JSON_ARR_START sp

    // Iterate over all hotels
    ldr x0, =list_hotel_callback
    mov x1, sp               // pass JSON context as user data
    bl db_list

    JSON_ARR_END sp
    JSON_RESPOND sp

    FRAME_LEAVE 0, LIST_HOTELS_LOCAL

// Callback for db_list: adds a hotel to JSON array
// x0 = id, x1 = data ptr, x2 = data size, x3 = context (JSON ctx)
list_hotel_callback:
    FRAME_ENTER 2

    mov w19, w0              // id
    mov x20, x1              // data ptr (hotel record)
    mov x21, x3              // JSON context

    // Check if we need a comma (check if array already has content)
    // Simple heuristic: if length > 1 (just '['), add comma
    ldr w0, [x21, #12]       // JSON_LEN
    cmp w0, #1
    b.le .no_comma_needed

    JSON_COMMA x21

.no_comma_needed:
    JSON_OBJ_START x21

    // Add "id": <id>
    JSON_KEY x21, key_id, 2
    JSON_INT x21, w19

    JSON_COMMA x21

    // Add "name": "<name>"
    JSON_KEY x21, key_name, 4

    add x22, x20, #HOTEL_NAME_OFF
    mov x0, x22
    bl strlen_simple
    mov w1, w0

    mov x0, x21
    mov x2, x1               // length
    mov x1, x22              // name pointer
    bl json_add_string

    JSON_COMMA x21

    // Add "city": "<city>"
    JSON_KEY x21, key_city, 4

    add x22, x20, #HOTEL_CITY_OFF
    mov x0, x22
    bl strlen_simple
    mov w1, w0

    mov x0, x21
    mov x2, x1
    mov x1, x22
    bl json_add_string

    JSON_OBJ_END x21

    // Return 0 to continue iteration
    mov x0, #0

    FRAME_LEAVE 2

// GET /api/hotels/{id} - Get single hotel
ENDPOINT METHOD_GET, "/api/hotels/{id}"
handler_get_hotel:
    FRAME_ENTER 1, GET_HOTEL_LOCAL

    mov x19, x0              // request context

    // Parse ID from path param
    ldr x0, [x19, #REQ_PATH_PARAM]
    ldr w1, [x19, #REQ_PATH_PARAM_LEN]
    bl parse_int
    cbz x0, .get_hotel_err
    mov w20, w0              // hotel ID

    // Get hotel from database
    mov w0, w20
    bl db_get
    cbz x0, .get_hotel_err
    mov x19, x0              // hotel data

    // Build JSON response
    JSON_INIT sp, 512

    mov x0, sp
    mov x1, x19
    mov w2, w20
    bl build_hotel_json

    JSON_RESPOND sp
    b .get_hotel_exit

.get_hotel_err:
    mov w0, #STATUS_NOT_FOUND
    bl resp_error

.get_hotel_exit:
    FRAME_LEAVE 1, GET_HOTEL_LOCAL

// POST /api/hotels - Create hotel
// Body format: "name,city"
ENDPOINT METHOD_POST, "/api/hotels"
handler_create_hotel:
    FRAME_ENTER 2, CREATE_HOTEL_LOCAL

    mov x19, x0              // request context

    // Get body
    ldr x20, [x19, #REQ_BODY]
    ldr w21, [x19, #REQ_BODY_LEN]

    cbz x20, .create_err_400
    cbz w21, .create_err_400

    // Parse "name,city" format - find comma
    mov x0, x20
    mov w1, w21
    mov w2, #','
    bl find_char
    cbz x0, .create_err_400
    mov x22, x0              // comma position

    // Build hotel record on stack
    add x0, sp, #JSON_CTX_SIZE + 512  // hotel record buffer

    // Copy name (from body start to comma)
    sub w1, w22, w20         // name length
    cmp w1, #HOTEL_NAME_MAX
    b.gt .create_err_400
    cbz w1, .create_err_400

    mov x2, x0               // dest
    mov x3, x20              // src (body start)
.copy_name:
    cbz w1, .name_copied
    ldrb w4, [x3], #1
    strb w4, [x2], #1
    sub w1, w1, #1
    b .copy_name
.name_copied:
    strb wzr, [x2]           // null terminate

    // Copy city (from after comma to end)
    add x0, sp, #JSON_CTX_SIZE + 512
    add x3, x22, #1          // skip comma
    add x2, x0, #HOTEL_CITY_OFF

    // Calculate city length
    add x4, x20, x21         // body end
    sub w1, w4, w3           // city length
    cmp w1, #HOTEL_CITY_MAX
    b.gt .create_err_400
    cbz w1, .create_err_400

.copy_city:
    cbz w1, .city_copied
    ldrb w4, [x3], #1
    strb w4, [x2], #1
    sub w1, w1, #1
    b .copy_city
.city_copied:
    strb wzr, [x2]           // null terminate

    // Create record in database
    add x0, sp, #JSON_CTX_SIZE + 512
    mov x1, #HOTEL_SIZE
    bl db_create
    cbz x0, .create_err_500
    mov w20, w0              // new hotel ID

    // Get the record back to build response
    mov w0, w20
    bl db_get
    mov x21, x0              // hotel data ptr

    // Build JSON response
    JSON_INIT sp, 512

    mov x0, sp
    mov x1, x21
    mov w2, w20
    bl build_hotel_json

    mov x0, sp
    bl json_finish
    // x0 = buffer, x1 = length

    mov x2, x1
    mov x1, x0
    mov w0, #STATUS_CREATED
    mov w3, #CTYPE_JSON
    bl resp_status
    b .create_exit

.create_err_400:
    mov w0, #STATUS_BAD_REQUEST
    b .create_err

.create_err_500:
    mov w0, #STATUS_SERVER_ERROR

.create_err:
    bl resp_error

.create_exit:
    FRAME_LEAVE 2, CREATE_HOTEL_LOCAL

// DELETE /api/hotels/{id} - Delete hotel
ENDPOINT METHOD_DELETE, "/api/hotels/{id}"
handler_delete_hotel:
    FRAME_ENTER 1

    mov x19, x0              // request context

    // Parse ID from path param
    ldr x0, [x19, #REQ_PATH_PARAM]
    ldr w1, [x19, #REQ_PATH_PARAM_LEN]
    bl parse_int
    cbz x0, .delete_err
    mov w20, w0

    // Delete from database
    mov w0, w20
    bl db_delete
    cmp x0, #0
    b.ne .delete_err

    // 204 No Content
    bl resp_no_content
    b .delete_exit

.delete_err:
    mov w0, #STATUS_NOT_FOUND
    bl resp_error

.delete_exit:
    FRAME_LEAVE 1

//=============================================================================
// HELPER FUNCTIONS
//=============================================================================

// build_hotel_json: Build JSON for a hotel
// Input: x0 = JSON context, x1 = hotel data ptr, w2 = hotel ID
build_hotel_json:
    FRAME_ENTER 2

    mov x19, x0              // JSON context
    mov x20, x1              // hotel data
    mov w21, w2              // hotel ID

    JSON_OBJ_START x19

    // "id": <id>
    JSON_KEY x19, key_id, 2
    JSON_INT x19, w21

    JSON_COMMA x19

    // "name": "<name>"
    JSON_KEY x19, key_name, 4

    add x22, x20, #HOTEL_NAME_OFF
    mov x0, x22
    bl strlen_simple

    mov x2, x0
    mov x0, x19
    mov x1, x22
    bl json_add_string

    JSON_COMMA x19

    // "city": "<city>"
    JSON_KEY x19, key_city, 4

    add x22, x20, #HOTEL_CITY_OFF
    mov x0, x22
    bl strlen_simple

    mov x2, x0
    mov x0, x19
    mov x1, x22
    bl json_add_string

    JSON_OBJ_END x19

    FRAME_LEAVE 2

//=============================================================================
// STATIC DATA
//=============================================================================
.section .rodata

key_id:
    .asciz "id"
key_name:
    .asciz "name"
key_city:
    .asciz "city"

html_index:
    .ascii "<html><head><title>SlowAPI Hotel API</title></head>"
    .ascii "<body><h1>SlowAPI Hotel API</h1>"
    .ascii "<p>A CRUD API for hotels, written in pure ARM64 assembly</p>"
    .ascii "<h2>Endpoints:</h2>"
    .ascii "<ul>"
    .ascii "<li>GET /api/hotels - List all hotels</li>"
    .ascii "<li>GET /api/hotels/{id} - Get a specific hotel</li>"
    .ascii "<li>POST /api/hotels - Create a hotel (body: name,city)</li>"
    .ascii "<li>DELETE /api/hotels/{id} - Delete a hotel</li>"
    .ascii "</ul>"
    .ascii "<h2>Try it:</h2>"
    .ascii "<pre>"
    .ascii "# Create a hotel\n"
    .ascii "curl -X POST -d 'Hilton,Toronto' http://localhost:8888/api/hotels\n\n"
    .ascii "# List all hotels\n"
    .ascii "curl http://localhost:8888/api/hotels\n\n"
    .ascii "# Get a specific hotel\n"
    .ascii "curl http://localhost:8888/api/hotels/1\n\n"
    .ascii "# Delete a hotel\n"
    .ascii "curl -X DELETE http://localhost:8888/api/hotels/1"
    .ascii "</pre>"
    .ascii "</body></html>"
html_index_end:

.section .data
html_index_len:
    .word html_index_end - html_index
