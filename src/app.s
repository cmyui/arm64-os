// SlowAPI Chess Application
// A chess game API written in pure ARM64 assembly

.section .text

.include "src/slowapi/macros.s"

//=============================================================================
// Chess Constants
//=============================================================================

// Piece encoding (high nibble = color: 0=white, 1=black)
.equ PIECE_EMPTY,   0x00
.equ PIECE_KING,    0x01
.equ PIECE_QUEEN,   0x02
.equ PIECE_ROOK,    0x03
.equ PIECE_BISHOP,  0x04
.equ PIECE_KNIGHT,  0x05
.equ PIECE_PAWN,    0x06
.equ COLOR_BLACK,   0x10    // OR with piece type for black pieces

// Game record layout (96 bytes)
.equ GAME_BOARD,        0       // 64 bytes: board state
.equ GAME_NEXT_TURN,    64      // 1 byte: 0=white, 1=black
.equ GAME_STATUS,       65      // 1 byte: 0=waiting, 1=active, 2=finished
.equ GAME_MOVE_COUNT,   66      // 2 bytes: number of moves made
.equ GAME_WHITE_ID,     68      // 4 bytes: white player ID (0=empty)
.equ GAME_BLACK_ID,     72      // 4 bytes: black player ID (0=empty)
.equ GAME_INVITE,       76      // 16 bytes: invite secret
.equ GAME_SIZE,         96

// Game status values
.equ STATUS_WAITING,    0
.equ STATUS_ACTIVE,     1
.equ STATUS_FINISHED,   2

//=============================================================================
// JSON and Stack Frame Sizes
//=============================================================================
.equ JSON_CTX_SIZE,     16
.equ LIST_GAMES_LOCAL,  JSON_CTX_SIZE + 2048
.equ GET_GAME_LOCAL,    JSON_CTX_SIZE + 1024
.equ CREATE_GAME_LOCAL, GAME_SIZE + JSON_CTX_SIZE + 512
.equ MOVE_LOCAL,        JSON_CTX_SIZE + 512

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

// GET /api/games - List all games
ENDPOINT METHOD_GET, "/api/games"
handler_list_games:
    FRAME_ENTER 0, LIST_GAMES_LOCAL

    JSON_INIT sp, 2048
    JSON_ARR_START sp

    ldr x0, =list_game_callback
    mov x1, sp
    bl db_list

    JSON_ARR_END sp
    JSON_RESPOND sp

    FRAME_LEAVE 0, LIST_GAMES_LOCAL

// Callback for db_list: adds a game summary to JSON array
list_game_callback:
    FRAME_ENTER 2

    mov w19, w0              // game id
    mov x20, x1              // game data ptr
    mov x21, x3              // JSON context

    // Add comma if needed
    ldr w0, [x21, #12]
    cmp w0, #1
    b.le .list_no_comma
    JSON_COMMA x21
.list_no_comma:

    JSON_OBJ_START x21

    // "id": <id>
    JSON_KEY x21, key_id, 2
    JSON_INT x21, w19

    JSON_COMMA x21

    // "status": "<status>"
    JSON_KEY x21, key_status, 6
    ldrb w0, [x20, #GAME_STATUS]
    cmp w0, #STATUS_WAITING
    b.eq .status_waiting
    cmp w0, #STATUS_ACTIVE
    b.eq .status_active
    b .status_finished

.status_waiting:
    mov x0, x21
    ldr x1, =str_waiting
    mov x2, #7
    bl json_add_string
    b .status_done

.status_active:
    mov x0, x21
    ldr x1, =str_active
    mov x2, #6
    bl json_add_string
    b .status_done

.status_finished:
    mov x0, x21
    ldr x1, =str_finished
    mov x2, #8
    bl json_add_string

.status_done:
    JSON_COMMA x21

    // "next_turn": "white" or "black"
    JSON_KEY x21, key_next_turn, 9
    ldrb w0, [x20, #GAME_NEXT_TURN]
    cbz w0, .turn_white
    mov x0, x21
    ldr x1, =str_black
    mov x2, #5
    bl json_add_string
    b .turn_done
.turn_white:
    mov x0, x21
    ldr x1, =str_white
    mov x2, #5
    bl json_add_string
.turn_done:

    JSON_OBJ_END x21

    mov x0, #0
    FRAME_LEAVE 2

// GET /api/games/{id} - Get single game with full board state
ENDPOINT METHOD_GET, "/api/games/{id}"
handler_get_game:
    FRAME_ENTER 1, GET_GAME_LOCAL

    mov x19, x0

    // Parse game ID
    ldr x0, [x19, #REQ_PATH_PARAM]
    ldr w1, [x19, #REQ_PATH_PARAM_LEN]
    bl parse_int
    cbz x0, .get_game_err
    mov w20, w0

    // Get game from database
    mov w0, w20
    bl db_get
    cbz x0, .get_game_err
    mov x19, x0

    // Build JSON response
    JSON_INIT sp, 1024

    mov x0, sp
    mov x1, x19
    mov w2, w20
    bl build_game_json

    JSON_RESPOND sp
    b .get_game_exit

.get_game_err:
    mov w0, #STATUS_NOT_FOUND
    bl resp_error

.get_game_exit:
    FRAME_LEAVE 1, GET_GAME_LOCAL

// POST /api/games - Create new game
// Body: "W" or "B" for desired color
ENDPOINT METHOD_POST, "/api/games"
handler_create_game:
    FRAME_ENTER 2, CREATE_GAME_LOCAL

    mov x19, x0

    // Get body
    ldr x20, [x19, #REQ_BODY]
    ldr w21, [x19, #REQ_BODY_LEN]

    cbz x20, .create_err_400
    cbz w21, .create_err_400

    // Parse desired color (W or B)
    ldrb w22, [x20]
    cmp w22, #'W'
    b.eq .create_white
    cmp w22, #'B'
    b.eq .create_black
    b .create_err_400

.create_white:
    mov w22, #0              // white_id = 1 (placeholder), black_id = 0
    b .create_init

.create_black:
    mov w22, #1              // white_id = 0, black_id = 1 (placeholder)

.create_init:
    // Initialize game record on stack
    add x0, sp, #JSON_CTX_SIZE + 512

    // Zero out the entire record first
    mov x1, #GAME_SIZE
    mov x2, x0
.zero_game:
    cbz x1, .zero_done
    strb wzr, [x2], #1
    sub x1, x1, #1
    b .zero_game
.zero_done:

    // Set up initial board position
    add x0, sp, #JSON_CTX_SIZE + 512
    bl setup_initial_board

    // Set game status to waiting
    add x0, sp, #JSON_CTX_SIZE + 512
    mov w1, #STATUS_WAITING
    strb w1, [x0, #GAME_STATUS]

    // Set player ID based on color choice
    cbz w22, .set_white_player
    // Black player
    mov w1, #1               // placeholder player ID
    str w1, [x0, #GAME_BLACK_ID]
    b .player_set
.set_white_player:
    mov w1, #1               // placeholder player ID
    str w1, [x0, #GAME_WHITE_ID]
.player_set:

    // Generate simple invite secret (just use counter for now)
    ldr x1, =invite_counter
    ldr w2, [x1]
    add w3, w2, #1
    str w3, [x1]
    str w2, [x0, #GAME_INVITE]

    // Create record in database
    add x0, sp, #JSON_CTX_SIZE + 512
    mov x1, #GAME_SIZE
    bl db_create
    cbz x0, .create_err_500
    mov w20, w0

    // Get the record back
    mov w0, w20
    bl db_get
    mov x21, x0

    // Build JSON response
    JSON_INIT sp, 512

    mov x0, sp
    mov x1, x21
    mov w2, w20
    bl build_game_json

    mov x0, sp
    bl json_finish

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
    FRAME_LEAVE 2, CREATE_GAME_LOCAL

// POST /api/games/{id}/join - Join a game
// Query: secret=<invite_secret>
ENDPOINT METHOD_POST, "/api/games/{id}/join"
handler_join_game:
    FRAME_ENTER 2, GET_GAME_LOCAL

    mov x19, x0

    // Parse game ID
    ldr x0, [x19, #REQ_PATH_PARAM]
    ldr w1, [x19, #REQ_PATH_PARAM_LEN]
    bl parse_int
    cbz x0, .join_err_404
    mov w20, w0

    // Get game
    mov w0, w20
    bl db_get
    cbz x0, .join_err_404
    mov x21, x0

    // Check game is waiting for player
    ldrb w0, [x21, #GAME_STATUS]
    cmp w0, #STATUS_WAITING
    b.ne .join_err_400

    // Check which slot is empty and fill it
    ldr w0, [x21, #GAME_WHITE_ID]
    cbz w0, .join_as_white
    ldr w0, [x21, #GAME_BLACK_ID]
    cbz w0, .join_as_black
    b .join_err_400          // Game is full

.join_as_white:
    mov w0, #2               // placeholder player ID for second player
    str w0, [x21, #GAME_WHITE_ID]
    b .join_activate

.join_as_black:
    mov w0, #2
    str w0, [x21, #GAME_BLACK_ID]

.join_activate:
    // Set game to active
    mov w0, #STATUS_ACTIVE
    strb w0, [x21, #GAME_STATUS]

    // No need to call db_update - db_get returns direct pointer, changes are in-place

    // Build response
    JSON_INIT sp, 1024

    mov x0, sp
    mov x1, x21
    mov w2, w20
    bl build_game_json

    JSON_RESPOND sp
    b .join_exit

.join_err_400:
    mov w0, #STATUS_BAD_REQUEST
    b .join_err

.join_err_404:
    mov w0, #STATUS_NOT_FOUND

.join_err:
    bl resp_error

.join_exit:
    FRAME_LEAVE 2, GET_GAME_LOCAL

// POST /api/games/{id}/move - Make a move
// Body: "e2e4" format (from_file from_rank to_file to_rank)
ENDPOINT METHOD_POST, "/api/games/{id}/move"
handler_move:
    FRAME_ENTER 3, MOVE_LOCAL

    mov x19, x0

    // Parse game ID
    ldr x0, [x19, #REQ_PATH_PARAM]
    ldr w1, [x19, #REQ_PATH_PARAM_LEN]
    bl parse_int
    cbz x0, .move_err_404
    mov w20, w0

    // Get game
    mov w0, w20
    bl db_get
    cbz x0, .move_err_404
    mov x21, x0

    // Check game is active
    ldrb w0, [x21, #GAME_STATUS]
    cmp w0, #STATUS_ACTIVE
    b.ne .move_err_400

    // Get body (e.g., "e2e4")
    ldr x22, [x19, #REQ_BODY]
    ldr w23, [x19, #REQ_BODY_LEN]

    cmp w23, #4
    b.lt .move_err_400

    // Parse from square
    ldrb w0, [x22]           // from_file char
    bl parse_file
    cmp w0, #-1
    b.eq .move_err_400
    mov w24, w0              // from_file (0-7)

    ldrb w0, [x22, #1]       // from_rank char
    bl parse_rank
    cmp w0, #-1
    b.eq .move_err_400
    mov w25, w0              // from_rank (0-7)

    // Parse to square
    ldrb w0, [x22, #2]       // to_file char
    bl parse_file
    cmp w0, #-1
    b.eq .move_err_400
    mov w26, w0              // to_file (0-7)

    ldrb w0, [x22, #3]       // to_rank char
    bl parse_rank
    cmp w0, #-1
    b.eq .move_err_400
    mov w27, w0              // to_rank (0-7)

    // Calculate board indices
    // from_idx = from_rank * 8 + from_file
    lsl w0, w25, #3
    add w0, w0, w24          // from_idx in w0

    // Get piece at from square
    add x1, x21, #GAME_BOARD
    ldrb w2, [x1, x0]        // piece at from

    // Check there's a piece there
    cbz w2, .move_err_400

    // Check piece color matches current turn
    ldrb w3, [x21, #GAME_NEXT_TURN]
    lsr w4, w2, #4           // piece color (0=white, 1=black)
    cmp w3, w4
    b.ne .move_err_403       // Not your turn

    // Calculate to_idx = to_rank * 8 + to_file
    lsl w5, w27, #3
    add w5, w5, w26          // to_idx in w5

    // Check destination isn't occupied by same color
    ldrb w6, [x1, x5]        // piece at to
    cbz w6, .dest_ok
    lsr w7, w6, #4           // dest piece color
    cmp w4, w7
    b.eq .move_err_400       // Can't capture own piece
.dest_ok:

    // Validate move based on piece type
    and w2, w2, #0x0F        // piece type (without color)
    mov w0, w2               // piece type
    mov w1, w24              // from_file
    mov w2, w25              // from_rank
    mov w3, w26              // to_file
    mov w4, w27              // to_rank
    bl validate_move
    cbz w0, .move_err_400    // Invalid move

    // Make the move
    add x1, x21, #GAME_BOARD

    // Calculate indices again
    lsl w0, w25, #3
    add w0, w0, w24          // from_idx
    lsl w5, w27, #3
    add w5, w5, w26          // to_idx

    // Move piece
    ldrb w2, [x1, x0]        // get piece
    strb wzr, [x1, x0]       // clear from
    strb w2, [x1, x5]        // set to

    // Toggle turn
    ldrb w0, [x21, #GAME_NEXT_TURN]
    eor w0, w0, #1
    strb w0, [x21, #GAME_NEXT_TURN]

    // Increment move count
    ldrh w0, [x21, #GAME_MOVE_COUNT]
    add w0, w0, #1
    strh w0, [x21, #GAME_MOVE_COUNT]

    // No need to call db_update - db_get returns direct pointer, changes are in-place

    // Build response
    JSON_INIT sp, 512

    mov x0, sp
    mov x1, x21
    mov w2, w20
    bl build_game_json

    JSON_RESPOND sp
    b .move_exit

.move_err_400:
.move_err_403:
    mov w0, #STATUS_BAD_REQUEST
    b .move_err

.move_err_404:
    mov w0, #STATUS_NOT_FOUND

.move_err:
    bl resp_error

.move_exit:
    FRAME_LEAVE 3, MOVE_LOCAL

//=============================================================================
// HELPER FUNCTIONS
//=============================================================================

// parse_file: Convert file char ('a'-'h' or 'A'-'H') to index (0-7)
// Input: w0 = char
// Output: w0 = index (0-7) or -1 if invalid
parse_file:
    // Check lowercase
    cmp w0, #'a'
    b.lt .try_upper_file
    cmp w0, #'h'
    b.gt .invalid_file
    sub w0, w0, #'a'
    ret

.try_upper_file:
    cmp w0, #'A'
    b.lt .invalid_file
    cmp w0, #'H'
    b.gt .invalid_file
    sub w0, w0, #'A'
    ret

.invalid_file:
    mov w0, #-1
    ret

// parse_rank: Convert rank char ('1'-'8') to index (0-7)
// Input: w0 = char
// Output: w0 = index (0-7) or -1 if invalid
parse_rank:
    cmp w0, #'1'
    b.lt .invalid_rank
    cmp w0, #'8'
    b.gt .invalid_rank
    sub w0, w0, #'1'
    ret

.invalid_rank:
    mov w0, #-1
    ret

// validate_move: Check if a move is valid for the piece type
// Input: w0 = piece type (1-6), w1 = from_file, w2 = from_rank,
//        w3 = to_file, w4 = to_rank
// Output: w0 = 1 if valid, 0 if invalid
validate_move:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // Calculate file and rank differences
    sub w5, w3, w1           // file_diff (signed)
    sub w6, w4, w2           // rank_diff (signed)

    // Absolute values
    cmp w5, #0
    cneg w7, w5, lt          // abs_file_diff
    cmp w6, #0
    cneg w8, w6, lt          // abs_rank_diff

    // Check piece type
    cmp w0, #PIECE_KING
    b.eq .validate_king
    cmp w0, #PIECE_QUEEN
    b.eq .validate_queen
    cmp w0, #PIECE_ROOK
    b.eq .validate_rook
    cmp w0, #PIECE_BISHOP
    b.eq .validate_bishop
    cmp w0, #PIECE_KNIGHT
    b.eq .validate_knight
    cmp w0, #PIECE_PAWN
    b.eq .validate_pawn

    mov w0, #0
    b .validate_done

.validate_king:
    // King moves one square in any direction
    cmp w7, #1
    b.gt .validate_fail
    cmp w8, #1
    b.gt .validate_fail
    // Must move at least one square
    orr w0, w7, w8
    cbz w0, .validate_fail
    b .validate_ok

.validate_queen:
    // Queen moves like rook or bishop
    cbz w7, .validate_ok     // straight vertical
    cbz w8, .validate_ok     // straight horizontal
    cmp w7, w8
    b.eq .validate_ok        // diagonal
    b .validate_fail

.validate_rook:
    // Rook moves straight
    cbz w7, .validate_ok     // vertical
    cbz w8, .validate_ok     // horizontal
    b .validate_fail

.validate_bishop:
    // Bishop moves diagonally
    cmp w7, w8
    b.eq .validate_ok
    b .validate_fail

.validate_knight:
    // Knight moves in L-shape
    cmp w7, #1
    b.ne .knight_check2
    cmp w8, #2
    b.eq .validate_ok
    b .validate_fail
.knight_check2:
    cmp w7, #2
    b.ne .validate_fail
    cmp w8, #1
    b.eq .validate_ok
    b .validate_fail

.validate_pawn:
    // Simplified pawn: moves forward 1 (or 2 from start), captures diagonal
    // Note: not checking for captures properly, just basic movement
    cbz w7, .pawn_forward
    // Diagonal move (capture)
    cmp w7, #1
    b.ne .validate_fail
    cmp w8, #1
    b.ne .validate_fail
    b .validate_ok

.pawn_forward:
    // Forward move
    cmp w8, #1
    b.eq .validate_ok
    cmp w8, #2
    b.ne .validate_fail
    // Two squares only from starting rank
    cmp w2, #1               // white start rank
    b.eq .validate_ok
    cmp w2, #6               // black start rank
    b.eq .validate_ok
    b .validate_fail

.validate_ok:
    mov w0, #1
    b .validate_done

.validate_fail:
    mov w0, #0

.validate_done:
    ldp x29, x30, [sp], #16
    ret

// setup_initial_board: Set up the starting chess position
// Input: x0 = pointer to game record
setup_initial_board:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!

    mov x19, x0              // game record ptr

    // White pieces (rank 0 = row 1)
    // Rooks at a1, h1
    mov w0, #PIECE_ROOK
    strb w0, [x19, #0]       // a1
    strb w0, [x19, #7]       // h1

    // Knights at b1, g1
    mov w0, #PIECE_KNIGHT
    strb w0, [x19, #1]       // b1
    strb w0, [x19, #6]       // g1

    // Bishops at c1, f1
    mov w0, #PIECE_BISHOP
    strb w0, [x19, #2]       // c1
    strb w0, [x19, #5]       // f1

    // Queen at d1
    mov w0, #PIECE_QUEEN
    strb w0, [x19, #3]       // d1

    // King at e1
    mov w0, #PIECE_KING
    strb w0, [x19, #4]       // e1

    // White pawns at rank 1 (indices 8-15)
    mov w0, #PIECE_PAWN
    mov w1, #8
.white_pawns:
    strb w0, [x19, x1]
    add w1, w1, #1
    cmp w1, #16
    b.lt .white_pawns

    // Black pieces (rank 7 = row 8, indices 56-63)
    // Rooks at a8, h8
    mov w0, #PIECE_ROOK
    orr w0, w0, #COLOR_BLACK
    strb w0, [x19, #56]      // a8
    strb w0, [x19, #63]      // h8

    // Knights at b8, g8
    mov w0, #PIECE_KNIGHT
    orr w0, w0, #COLOR_BLACK
    strb w0, [x19, #57]      // b8
    strb w0, [x19, #62]      // g8

    // Bishops at c8, f8
    mov w0, #PIECE_BISHOP
    orr w0, w0, #COLOR_BLACK
    strb w0, [x19, #58]      // c8
    strb w0, [x19, #61]      // f8

    // Queen at d8
    mov w0, #PIECE_QUEEN
    orr w0, w0, #COLOR_BLACK
    strb w0, [x19, #59]      // d8

    // King at e8
    mov w0, #PIECE_KING
    orr w0, w0, #COLOR_BLACK
    strb w0, [x19, #60]      // e8

    // Black pawns at rank 6 (indices 48-55)
    mov w0, #PIECE_PAWN
    orr w0, w0, #COLOR_BLACK
    mov w1, #48
.black_pawns:
    strb w0, [x19, x1]
    add w1, w1, #1
    cmp w1, #56
    b.lt .black_pawns

    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// build_game_json: Build full JSON for a game
// Input: x0 = JSON context, x1 = game data ptr, w2 = game ID
build_game_json:
    FRAME_ENTER 3

    mov x19, x0              // JSON context
    mov x20, x1              // game data
    mov w21, w2              // game ID

    JSON_OBJ_START x19

    // "id": <id>
    JSON_KEY x19, key_id, 2
    JSON_INT x19, w21

    JSON_COMMA x19

    // "status": "<status>"
    JSON_KEY x19, key_status, 6
    ldrb w0, [x20, #GAME_STATUS]
    cmp w0, #STATUS_WAITING
    b.eq .json_status_waiting
    cmp w0, #STATUS_ACTIVE
    b.eq .json_status_active
    mov x0, x19
    ldr x1, =str_finished
    mov x2, #8
    bl json_add_string
    b .json_status_done
.json_status_waiting:
    mov x0, x19
    ldr x1, =str_waiting
    mov x2, #7
    bl json_add_string
    b .json_status_done
.json_status_active:
    mov x0, x19
    ldr x1, =str_active
    mov x2, #6
    bl json_add_string
.json_status_done:

    JSON_COMMA x19

    // "next_turn": "white" or "black"
    JSON_KEY x19, key_next_turn, 9
    ldrb w0, [x20, #GAME_NEXT_TURN]
    cbz w0, .json_turn_white
    mov x0, x19
    ldr x1, =str_black
    mov x2, #5
    bl json_add_string
    b .json_turn_done
.json_turn_white:
    mov x0, x19
    ldr x1, =str_white
    mov x2, #5
    bl json_add_string
.json_turn_done:

    JSON_COMMA x19

    // "move_count": <count>
    JSON_KEY x19, key_move_count, 10
    ldrh w0, [x20, #GAME_MOVE_COUNT]
    mov w1, w0
    mov x0, x19
    bl json_add_int

    JSON_COMMA x19

    // "board": "<64-char string>"
    JSON_KEY x19, key_board, 5
    mov x0, x19
    add x1, x20, #GAME_BOARD
    bl json_add_board

    JSON_OBJ_END x19

    FRAME_LEAVE 3

// json_add_board: Add board as a 64-char string showing piece positions
// Input: x0 = JSON context, x1 = board pointer (64 bytes)
json_add_board:
    FRAME_ENTER 2
    stp x23, x24, [sp, #-16]!

    mov x19, x0              // JSON context
    mov x20, x1              // board ptr

    // Get buffer position
    ldr x21, [x19, #0]       // buffer ptr
    ldr w22, [x19, #12]      // current length

    // Add opening quote
    mov w0, #'"'
    strb w0, [x21, x22]
    add w22, w22, #1

    // Add 64 characters for board
    mov w23, #0              // index
.board_loop:
    ldrb w0, [x20, x23]      // get piece

    // Convert piece to char
    cbz w0, .piece_empty
    and w1, w0, #0x0F        // piece type
    lsr w2, w0, #4           // color (0=white, 1=black)

    // Get base char for piece type
    cmp w1, #PIECE_KING
    b.eq .piece_king
    cmp w1, #PIECE_QUEEN
    b.eq .piece_queen
    cmp w1, #PIECE_ROOK
    b.eq .piece_rook
    cmp w1, #PIECE_BISHOP
    b.eq .piece_bishop
    cmp w1, #PIECE_KNIGHT
    b.eq .piece_knight
    cmp w1, #PIECE_PAWN
    b.eq .piece_pawn
    b .piece_empty

.piece_king:
    mov w0, #'K'
    b .piece_color
.piece_queen:
    mov w0, #'Q'
    b .piece_color
.piece_rook:
    mov w0, #'R'
    b .piece_color
.piece_bishop:
    mov w0, #'B'
    b .piece_color
.piece_knight:
    mov w0, #'N'
    b .piece_color
.piece_pawn:
    mov w0, #'P'

.piece_color:
    // If black, convert to lowercase
    cbz w2, .piece_store
    add w0, w0, #32          // to lowercase

.piece_store:
    b .store_char

.piece_empty:
    mov w0, #'.'

.store_char:
    strb w0, [x21, x22]
    add w22, w22, #1
    add w23, w23, #1
    cmp w23, #64
    b.lt .board_loop

    // Add closing quote
    mov w0, #'"'
    strb w0, [x21, x22]
    add w22, w22, #1

    // Update length
    str w22, [x19, #12]

    ldp x23, x24, [sp], #16
    FRAME_LEAVE 2

//=============================================================================
// STATIC DATA
//=============================================================================
.section .rodata

key_id:
    .asciz "id"
key_status:
    .asciz "status"
key_next_turn:
    .asciz "next_turn"
key_move_count:
    .asciz "move_count"
key_board:
    .asciz "board"

str_waiting:
    .asciz "waiting"
str_active:
    .asciz "active"
str_finished:
    .asciz "finished"
str_white:
    .asciz "white"
str_black:
    .asciz "black"

html_index:
    .ascii "<html><head><title>SlowAPI Chess</title></head>"
    .ascii "<body><h1>SlowAPI Chess API</h1>"
    .ascii "<p>A chess game API written in pure ARM64 assembly</p>"
    .ascii "<h2>Endpoints:</h2>"
    .ascii "<ul>"
    .ascii "<li>GET /api/games - List all games</li>"
    .ascii "<li>GET /api/games/{id} - Get game state</li>"
    .ascii "<li>POST /api/games - Create game (body: W or B for color)</li>"
    .ascii "<li>POST /api/games/{id}/join - Join a game</li>"
    .ascii "<li>POST /api/games/{id}/move - Make move (body: e2e4)</li>"
    .ascii "</ul>"
    .ascii "<h2>Board format:</h2>"
    .ascii "<p>64-char string, a1-h1, a2-h2, ..., a8-h8</p>"
    .ascii "<p>Uppercase=white, lowercase=black, .=empty</p>"
    .ascii "<p>K=king, Q=queen, R=rook, B=bishop, N=knight, P=pawn</p>"
    .ascii "<h2>Try it:</h2>"
    .ascii "<pre>"
    .ascii "# Create a game as white\n"
    .ascii "curl -X POST -d 'W' http://localhost:8888/api/games\n\n"
    .ascii "# Join game 1\n"
    .ascii "curl -X POST http://localhost:8888/api/games/1/join\n\n"
    .ascii "# Move pawn e2 to e4\n"
    .ascii "curl -X POST -d 'e2e4' http://localhost:8888/api/games/1/move\n\n"
    .ascii "# Get game state\n"
    .ascii "curl http://localhost:8888/api/games/1"
    .ascii "</pre>"
    .ascii "</body></html>"
html_index_end:

.section .data
html_index_len:
    .word html_index_end - html_index

invite_counter:
    .word 1000
