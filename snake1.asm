BasicUpstart2(main)
//* = $0810
//jmp main

snakeTextMap:
    .import binary "assets/snake_map.bin"

gameOverTextMap:
    .import binary "assets/game_over_map.bin"

windowMap:
    .import binary "assets/window.bin"

colourRamp:
    .byte $01, $0d, $03, $0c, $04, $02, $09, $02, $04, $0c, $03, $0d, $01

score:
    .byte $73, $74, $75, $76, $77

digits:
    .byte $78, $79, $7a, $7b, $7c, $7d, $7e, $7f, $80, $81

colourIndex:
    .byte $00

joyInput:
    .byte $00

lastInput:
    .byte $00

// Screen is 40 cols x 25 rows
main:
    // Use $C000 to store the snake variables (for now)
    .const MEMORY_START_LOW = $00
    .const MEMORY_START_HIGH = $c0
    // Zero Page for memory location: $FB/$FC
    .const MEMORY_INDIRECT_LOW = $fb
    .const MEMORY_INDIRECT_HIGH = $fc
    // Object memory offsets
    .const RUN_STATE_OFFSET = 0
    .const SCORE_OFFSET = 1
    .const FOOD_OFFSET = 3
    .const SIZE_OFFSET = 5
    .const DIRECTION_OFFSET = 7
    .const SEGMENT_OFFSET = 8
    .const LAST_SEGMENT_OFFSET = 10
    .const TAIL_SEGMENT_OFFSET = 13
    .const BLANK_OFFSET = 16
    .const SEGMENT_SIZE = 2
    .const INPUT_QUEUE_OFFSET = 18
    // Top of screen memory (page)
    .const SCREEN_MEMORY_PAGE = $0288
    // Screen columns & rows
    .const MIN_WINDOW_COL = 1
    .const MIN_WINDOW_ROW = 1
    .const MAX_WINDOW_COL = 38
    .const MAX_WINDOW_ROW = 19
    .const MAX_COL = 40
    .const MAX_ROW = 20
    // The characters for drawing
    .const FOOD_CHAR1 = $6a
    .const FOOD_CHAR2 = $69
    .const BLANK_CHAR = 0
    .const CLS_CHAR = 147
    .const FOOD_COLOUR = RED
    .const SNAKE_COLOUR = GREEN
    .const SCORE_COLOUR = ORANGE
    .const BORDER_COLOUR = LIGHT_BLUE
foodChar:
    .byte FOOD_CHAR1
    // Snake chars (head, straight, curve1, curve2, tail)
snakeUp:
    .byte $8b, $85, $83, $84, $8c  // curve1 = left, curve2 = right
snakeDown:
    .byte $8a, $85, $86, $87, $8d  // curve1 = left, curve2 = right
snakeLeft:
    .byte $89, $82, $83, $87, $8f  // curve1 = down, curve2 = up
snakeRight:
    .byte $88, $82, $84, $86, $8e  // curve1 = down, curve2 = up
    // Snake directions (based on ASCII)
    .const UP_DIRECTION = 87
    .const RIGHT_DIRECTION = 68
    .const DOWN_DIRECTION = 83
    .const LEFT_DIRECTION = 65
    // Joystick control
    .const JOY_PORT_2 = $dc00

    .const JOY_UP = %00001
    .const JOY_DN = %00010
    .const JOY_LT = %00100
    .const JOY_RT = %01000
    .const JOY_FR = %10000
    // Temp variables for parameters etc. Define as constants as may want to change these
    .const TEMP1 = $0334
    .const TEMP2 = $0335
    .const TEMP3 = $0336
    .const TEMP4 = $0337
    .const TEMP5 = $0338
    .const TEMP6 = $0339
    .const TEMP7 = $033a
    // Other constants
    .const INIT_SNAKE_SIZE = 3
    .const START_ROW = 11
    .const START_COL = 20
    .const QUIT_GAME = $ff
    .const GAME_OVER = $0f
    .const FRAMES_PER_UPDATE = 4
    .const FRAMES_PER_FOOD_UPDATE = 8
    .const FRAME_COUNT = TEMP7
    .const FOOD_FRAME_COUNT = TEMP6
    .const POINTS_PER_FOOD = 5
    .const SCORE_ROW = 22
    .const LOWEST_SNAKE_CHAR = $82
    // ROM functions / memory locations
    .const SCAN_STOP = $ffe1
    .const CHAR_OUT = $ffd2
    .const GET_IN = $ffe4
    .const SCREEN_RAM = $400
    .const COLOUR_RAM = $d800 
    // Init. memory
    lda #MEMORY_START_LOW
    sta MEMORY_INDIRECT_LOW
    lda #MEMORY_START_HIGH
    sta MEMORY_INDIRECT_HIGH

    // Run state: 1 byte
    // Score: 2 bytes

    // Food
    // ----
    // x (column): 1 byte (index 3)
    // y (row): 1 byte (index 4)

    // The Snake
    // ---------
    // size: 2 bytes (index 5)
    // direction: 1 byte (index 7)
    //
    //   Segment (head)
    //   ---------
    //   x (column): 1 byte (index 8)
    //   y (row): 1 byte (index 9)
    //  
    //   Last Segment
    //   ------------
    //   x: 1 byte (index 10)
    //   y: 1 byte (index 11)
    //   direction: 1 byte (index 12)
    //  
    //   Tail Segment
    //   ------------
    //   x: 1 byte (index 13)
    //   y: 1 byte (index 14)
    //   direction: 1 byte (index 15)
    //
    //   Blank Location
    //   --------------
    //   x: 1 byte (index 16)
    //   y: 1 byte (index 17)
    //
    // input size: 1 byte (index 18)
    // input queue: 1 byte per input (index 19+)
init:
    // Set charset
    // Bits #1-#3: In text mode, pointer to character memory (bits #11-#13), relative to VIC bank, memory address $DD00. Values:
    // %100, 4: $2000-$27FF, 8192-10239.
    // %101, 5: $2800-$2FFF, 10240-12287.
    // Bits #4-#7: Pointer to screen memory (bits #10-#13), relative to VIC bank, memory address $DD00. Values:
    // %0001, 1: $0400-$07FF, 1024-2047. 
    lda #%00011010   
    sta $d018       // VIC memory control register

    // Set screen to black and clear all text
    lda #BLACK
    sta $d020
    sta $d021
    //lda #CLS_CHAR
   // jsr CHAR_OUT
    jsr clear_screen
    
    ldx #0
!:
    lda snakeTextMap, x
    // 12 rows down, 40 wide
    sta SCREEN_RAM + 12 * 40, x
    inx 
    cpx #80 // text is 2 rows (2 * 40)
    bne !-

colour_loop:
    .var coloursInRamp = 13
    // Increment the colour ramp
    ldx colourIndex
    inx
    cpx #coloursInRamp      // the number of colours in ramp
    bne !+
    ldx #0
!:
    stx colourIndex

    // Begin plotting colours in a loop
    ldy #0
inner_loop:
    lda colourRamp, x
    // COLOUR_RAM + row * cols in row + first character offset
    sta COLOUR_RAM + 12 * 40 + 8, y
    sta COLOUR_RAM + 13 * 40 + 8, y

    inx         // colour index
    cpx #coloursInRamp
    bne !+
    ldx #0
!:
    iny         // screen column index
    cpy #22     // col 29 is the last character index? 29-8 = 21 the final char
    bne inner_loop

    lda #$a0    // the raster line below the text
!:
    cmp $d012   // compare to the current raster line
    bne !-

    //jsr GET_IN
    //bne restart_game      // no input loads 0 into A (Z flag set means input read)
    lda JOY_PORT_2
    and #JOY_FR
    beq restart_game
    // Repeat
    jmp colour_loop
restart_game:
    // Load window
    jsr clear_screen
    ldx #210
draw_row:
    dex
    // Draw segments
    lda windowMap, x
    sta SCREEN_RAM, x  
    lda windowMap + 210, x
    sta SCREEN_RAM + 210, x
    lda windowMap + 420, x
    sta SCREEN_RAM + 420, x   
    lda windowMap + 630, x
    sta SCREEN_RAM + 630, x
    // Set colours
    lda #BORDER_COLOUR
    sta COLOUR_RAM, x
    sta COLOUR_RAM + 210, x
    sta COLOUR_RAM + 420, x
    sta COLOUR_RAM + 630, x
    cpx #0
    bne draw_row 

    // Initialise variables
    lda #00
    ldy #00
    sta lastInput
    sta FRAME_COUNT
    sta (MEMORY_INDIRECT_LOW), y
    iny
    sta (MEMORY_INDIRECT_LOW), y    // score = 0
    iny
    sta (MEMORY_INDIRECT_LOW), y    // score high byte
    // Initialise the snake
    ldy #SIZE_OFFSET
    lda #INIT_SNAKE_SIZE
    sta (MEMORY_INDIRECT_LOW), y    // set the size
    lda #0
    iny
    sta (MEMORY_INDIRECT_LOW), y   
    lda #RIGHT_DIRECTION            
    ldy #DIRECTION_OFFSET
    sta (MEMORY_INDIRECT_LOW), y    // set the direction
    ldy #SEGMENT_OFFSET
    // Set the start location
    lda #START_COL 
    sta (MEMORY_INDIRECT_LOW), y    // set head segment
    lda #START_ROW
    iny
    sta (MEMORY_INDIRECT_LOW), y    // set segment y
    // Set the body location
    iny
    lda #START_COL - 1
    sta (MEMORY_INDIRECT_LOW), y    // set body segment
    lda #START_ROW
    iny
    lda #START_ROW
    sta (MEMORY_INDIRECT_LOW), y    // set segment y
    lda #RIGHT_DIRECTION
    iny
    sta (MEMORY_INDIRECT_LOW), y
    // Set the tail location
    lda #START_COL - 2
    iny
    sta (MEMORY_INDIRECT_LOW), y
    lda #START_ROW
    iny
    sta (MEMORY_INDIRECT_LOW), y
    iny
    lda #RIGHT_DIRECTION
    sta (MEMORY_INDIRECT_LOW), y
    // Reset the input queue
    ldy #INPUT_QUEUE_OFFSET
    lda #0
    sta (MEMORY_INDIRECT_LOW), y

    jsr set_interrupt


// lda $D41B will return a random number between 0-255
init_random:
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low byte
    sta $D40F // voice 3 frequency high byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

    // Display the score label
    ldx #0
!:
    lda score, x
    sta SCREEN_RAM + SCORE_ROW * MAX_COL + 1, x
    lda #SCORE_COLOUR
    sta COLOUR_RAM + SCORE_ROW * MAX_COL + 1, x
    inx
    cpx #5
    bne !-
    inx 
    lda #120
    sta SCREEN_RAM + SCORE_ROW * MAX_COL + 1, x
    lda #SCORE_COLOUR
    sta COLOUR_RAM + SCORE_ROW * MAX_COL + 1, x
    // Draw the score
    jsr draw_score

    jsr draw_food
    //jsr set_interrupt
    // Main game loop
loop:
    jsr read_inputs
    jsr player_control

    // Check game state
    ldy #RUN_STATE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
  
    cmp #GAME_OVER
    beq end_game
    jmp loop
end_game:
    jsr game_over_interrupt
!:
   // jsr GET_IN
    lda JOY_PORT_2
    and #JOY_FR         // Check if fire bit is pulled down (0)
    bne !-
    // Disable the raster interrupt while the game is reset (this ensures game over message is no longer displayed)
    lda #0
    sta $d01a
    jmp restart_game

game_over_interrupt:
    sei
    
    // Set pointer for raster interrupt
    lda #<game_over
    sta $0314       // store in Vector: Hardware IRQ Interrupt
    lda #>game_over
    sta $0315

    cli
    rts

set_interrupt:
    sei             // disable interrupts
    lda #$7f        // turn of the CIA timer interrupt: 0111 1111
    sta $dc0d       // CIA interrupt control register (Read IRQs/Write Mask)
    sta $dd0d       // CIA interrupt control register (Read NMIs/Write Mask)
    // Setup raster interrupt
    and $d011       // clear the high bit
    sta $d011
    lda #255        // this will set the IRQ to trigger on raster line 100
    sta $d012
    // Set pointer for raster interrupt
    lda #<my_interrupt
    sta $0314       // store in Vector: Hardware IRQ Interrupt
    lda #>my_interrupt
    sta $0315
    // Enable raster interrupt
    lda #01
    sta $d01a
    cli             // enable interrupts
    rts

my_interrupt:
    // Set bit 0 in Interrupt Status Register to acknowledge raster interrupt
    inc $d019       // VIC Interrupt Flag Register (1 = IRQ occurred)

    inc FRAME_COUNT
    lda FRAME_COUNT
    cmp #FRAMES_PER_UPDATE
    bne !+
    // Do some stuff...
    jsr set_next_direction
    jsr move_snake
    jsr draw_snake
    lda #0
    sta FRAME_COUNT
!:
    // Alternate snake frame
    inc FOOD_FRAME_COUNT
    lda FOOD_FRAME_COUNT
    cmp #FRAMES_PER_FOOD_UPDATE
    bne end
    lda foodChar
    cmp #FOOD_CHAR1
    beq set2
    lda #FOOD_CHAR1
    sta foodChar
    jmp !+
set2:
    lda #FOOD_CHAR2
    sta foodChar
!:
    ldy #FOOD_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    sta TEMP1
    iny
    lda (MEMORY_INDIRECT_LOW), y
    sta TEMP2
    lda foodChar
    sta TEMP3
    jsr draw_to_screen
    lda #0
    sta FOOD_FRAME_COUNT
!:
end:

    jmp $ea31       // Restores A, X & Y registers and CPU flags before returning from interrupt

// Move all the key snake segments along based on their next directions.
move_snake: {
    // ************************ Shift segments *****************************
    // Shift the head and first body segment
    ldy #SEGMENT_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    ldy #LAST_SEGMENT_OFFSET
    sta (MEMORY_INDIRECT_LOW), y    // shift x
    ldy #SEGMENT_OFFSET + 1
    lda (MEMORY_INDIRECT_LOW), y
    ldy #LAST_SEGMENT_OFFSET + 1
    sta (MEMORY_INDIRECT_LOW), y    // shift
    // Move the head
    // Push the segment offset to stack
    // Get the current direction
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    pha
    lda #SEGMENT_OFFSET
    pha
    jsr move_segment
    // Tidy up stack
    pla
    pla
    // Check if the head has collided with something
    ldy #SEGMENT_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    sta TEMP1
    iny
    lda (MEMORY_INDIRECT_LOW), y
    sta TEMP2
    jsr read_from_screen
    lda TEMP4
    cmp #FOOD_CHAR1
    beq eaten_food
    cmp #FOOD_CHAR2
    beq eaten_food
    bne !+
eaten_food:
    // ***************** Eaten food ********************************
    jsr next_food
    jsr draw_food
    // ***************** Increment score ******************************
    sed                             // Set BCD mode
    ldy #SCORE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y    // get the current score
    clc
    adc #POINTS_PER_FOOD
    sta (MEMORY_INDIRECT_LOW), y    // low byte
    iny
    lda (MEMORY_INDIRECT_LOW), y
    adc #0
    sta (MEMORY_INDIRECT_LOW), y    // high byte
    cld                             // Turn off BCD mode
    // **************** Display the score *****************************
    jsr draw_score
    rts
!: 
    cmp #LOWEST_SNAKE_CHAR    
    bcc !+
    // *************** Game Over ***********************************
    ldy #RUN_STATE_OFFSET
    lda #GAME_OVER
    sta (MEMORY_INDIRECT_LOW), y
    rts
!:
    // Before moving the tail, mark the current tail location as the blank sector
    ldy #TAIL_SEGMENT_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    ldy #BLANK_OFFSET
    sta (MEMORY_INDIRECT_LOW), y
    ldy #TAIL_SEGMENT_OFFSET + 1
    lda (MEMORY_INDIRECT_LOW), y
    ldy #BLANK_OFFSET + 1
    sta (MEMORY_INDIRECT_LOW), y
    // Move the tail
    ldy #TAIL_SEGMENT_OFFSET + 2
    lda (MEMORY_INDIRECT_LOW), y
    pha
    lda #TAIL_SEGMENT_OFFSET
    pha
    jsr move_segment
    pla
    pla
    // Check new tail direction
    ldy #TAIL_SEGMENT_OFFSET
    lda (MEMORY_INDIRECT_LOW), y    // the new x pos
    sta TEMP1
    iny
    lda (MEMORY_INDIRECT_LOW), y    // the new y pos
    sta TEMP2
    jsr read_from_screen
    // Get the current tail direction
    ldy #TAIL_SEGMENT_OFFSET + 2
    lda (MEMORY_INDIRECT_LOW), y
    ldx #4
    // ---------------- Tail moving up ----------------
    cmp #UP_DIRECTION
    bne !else+
    lda TEMP4
    cmp #$87        // turning left
    bne !+
    lda #LEFT_DIRECTION
    sta (MEMORY_INDIRECT_LOW), y
    jmp !end_if+
!:
    cmp #$86        // turning right
    bne !end_if+
    lda #RIGHT_DIRECTION
    sta (MEMORY_INDIRECT_LOW), y
!else:
    // --------------- Tail moving down --------------
    cmp #DOWN_DIRECTION
    bne !else+
    lda TEMP4
    cmp #$83        // turning left
    bne !+
    lda #LEFT_DIRECTION
    sta (MEMORY_INDIRECT_LOW), y
    jmp !end_if+
!:
    cmp #$84       // turning right
    bne !end_if+
    lda #RIGHT_DIRECTION
    sta (MEMORY_INDIRECT_LOW), y
    jmp !end_if+
!else:
    // --------------- Tail moving left ---------------
    cmp #LEFT_DIRECTION
    bne !else+
    lda TEMP4
    cmp #$84        // turning up
    bne !+
    lda #UP_DIRECTION
    sta (MEMORY_INDIRECT_LOW), y
    jmp !end_if+
!:
    cmp #$86        // turning down
    bne !end_if+
    lda #DOWN_DIRECTION
    sta (MEMORY_INDIRECT_LOW), y
    jmp !end_if+
!else:
    // -------------- Tail moving right -----------------
    lda TEMP4
    cmp #$83        // turning up
    bne !+
    lda #UP_DIRECTION
    sta (MEMORY_INDIRECT_LOW), y
    jmp !end_if+
!:
    cmp #$87        // turning down
    bne !end_if+
    lda #DOWN_DIRECTION
    sta (MEMORY_INDIRECT_LOW), y
!end_if:

    rts
}

move_segment: {
    tsx
    inx
    inx            // First two bytes are the program counter calling location
    lda $0101, x   // First stack value will be the segment offset
    tay
    inx
    lda $0101, x   // Second stack value will be the direction to use
    // ------------ UP ---------------
    cmp #UP_DIRECTION
    bne !++
    iny                 // get Y
    lda (MEMORY_INDIRECT_LOW), y
    // Decrement y
    tax
    dex
    txa
    // If < 0 row then wrap around
    cmp #MIN_WINDOW_ROW - 1
    bne !+                      // if positive number (not < 0) then skip the next bit
    lda #MAX_ROW - 1
!:
    sta (MEMORY_INDIRECT_LOW), y   // store the modified value
    jmp done
!:
    // ------------ DOWN ---------------
    cmp #DOWN_DIRECTION
    bne !++
    iny            // get Y
    lda (MEMORY_INDIRECT_LOW), y
    // Increment y
    tax
    inx
    txa
    // if > max rows then wrap around
    cmp #MAX_WINDOW_ROW + 1
    bne !+                      // if not equal then skip the next bit
    lda #MIN_WINDOW_ROW
!:
    sta (MEMORY_INDIRECT_LOW), y   // store the modified value
    jmp done
!:
    // ------------ LEFT ---------------
    cmp #LEFT_DIRECTION
    bne !++
    lda (MEMORY_INDIRECT_LOW), y
    // Decrement x
    tax
    dex
    txa
    // if < 0 col then wrap around
    cmp #MIN_WINDOW_COL - 1
    bne !+
    lda #MAX_WINDOW_COL
!:
    sta (MEMORY_INDIRECT_LOW), y
    jmp done
!:
    // ------------ RIGHT ---------------
    cmp #RIGHT_DIRECTION
    bne !+
    lda (MEMORY_INDIRECT_LOW), y
    // Increment x
    tax
    inx
    txa
    // if > max col then wrap around
    cmp #MAX_WINDOW_COL + 1
    bne !+
    lda #MIN_WINDOW_COL
!:
    sta (MEMORY_INDIRECT_LOW), y
done:
    rts
}

// Draw the score as Thousands, Hundreds, Tens and Units.
// - score is stored in BCD
draw_score: {
    ldy #SCORE_OFFSET + 1
    lda (MEMORY_INDIRECT_LOW), y
    // Thousands column...
    tay
    lsr
    lsr
    lsr
    lsr
    tax
    lda digits, x
    sta SCREEN_RAM + SCORE_ROW * MAX_COL + 7
    lda #SCORE_COLOUR
    sta COLOUR_RAM + SCORE_ROW * MAX_COL + 7
    // Hundreds column...
    tya
    and #$0f
    tax
    lda digits, x
    sta SCREEN_RAM + SCORE_ROW * MAX_COL + 8 
    lda #SCORE_COLOUR
    sta COLOUR_RAM + SCORE_ROW * MAX_COL + 8
    // Tens column...
    ldy #SCORE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    tay
    lsr
    lsr
    lsr
    lsr
    tax
    lda digits, x
    sta SCREEN_RAM + SCORE_ROW * MAX_COL + 9
    lda #SCORE_COLOUR
    sta COLOUR_RAM + SCORE_ROW * MAX_COL + 9
    // Units column...
    tya
    and #$0f
    tax
    lda digits, x
    sta SCREEN_RAM + SCORE_ROW * MAX_COL + 10
    lda #SCORE_COLOUR
    sta COLOUR_RAM + SCORE_ROW * MAX_COL + 10
    rts
}

// Draw the snake.
// - Start from the lowest segment (tail blank), then work up to the head
draw_snake: {
    // Load params for draw_to_screen method
    .var xPointer = TEMP1
    .var yPointer = TEMP2
    .var charPointer = TEMP3
    .var lastDirection = TEMP4
    // Now start the drawing...
    // First, get the previous direction
    ldy #LAST_SEGMENT_OFFSET + 2
    lda (MEMORY_INDIRECT_LOW), y
    sta lastDirection
    // -------------- Work out the body segments --------------------
    // Get the x location of the segment
    ldy #SEGMENT_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    sta xPointer
    // Get the y location of the segment
    iny
    lda (MEMORY_INDIRECT_LOW), y       
    sta yPointer
    // Get the current direction
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    // Work out which body segments to paint
    cmp #UP_DIRECTION
    bne !+
    lda lastDirection
    cmp #LEFT_DIRECTION
    bne !else+
    ldx #3
    lda snakeUp, x          // turning left
    pha 
    jmp !get_head+
!else:
    cmp #RIGHT_DIRECTION
    bne !else+
    ldx #2
    lda snakeUp, x          // turning right
    pha
    jmp !get_head+
!else:
    ldx #1
    lda snakeUp, x          // going up
    pha
!get_head:
    ldx #0
    lda snakeUp, x          // get the head
    jmp end_if
!:
    cmp #DOWN_DIRECTION
    bne !+
    lda lastDirection
    cmp #LEFT_DIRECTION
    bne !else+
    ldx #2
    lda snakeDown, x          // turning left
    pha 
    jmp !get_head+
!else:
    cmp #RIGHT_DIRECTION
    bne !else+
    ldx #3
    lda snakeDown, x          // turning right
    pha
    jmp !get_head+
!else:
    ldx #1
    lda snakeUp, x          // going up
    pha
!get_head:
    ldx #0
    lda snakeDown, x        // get the head
    jmp end_if
!:
    cmp #LEFT_DIRECTION
    bne !+
    lda lastDirection
    cmp #DOWN_DIRECTION
    bne !else+
    ldx #2
    lda snakeLeft, x          // turning down
    pha 
    jmp !get_head+
!else:
    cmp #UP_DIRECTION
    bne !else+
    ldx #3
    lda snakeLeft, x          // turning up
    pha
    jmp !get_head+
!else:
    ldx #1
    lda snakeLeft, x          // going left
    pha
!get_head:
    ldx #0
    lda snakeLeft, x        // get the head
    jmp end_if
!:
    cmp #RIGHT_DIRECTION
    lda lastDirection
    cmp #DOWN_DIRECTION
    bne !else+
    ldx #2
    lda snakeRight, x          // turning down
    pha 
    jmp !get_head+
!else:
    cmp #UP_DIRECTION
    bne !else+
    ldx #3
    lda snakeRight, x          // turning up
    pha
    jmp !get_head+
!else:
    ldx #1
    lda snakeRight, x          // going right
    pha
!get_head:
    ldx #0
    lda snakeRight, x        // get the head
end_if:
    // --------------------- Draw the head -----------------
    // Draw the char
    sta charPointer
    jsr draw_to_screen
    // --------------------- Draw the body segments -----------------
    // Draw the next body segment
    ldy #LAST_SEGMENT_OFFSET
    // Get x location
    lda (MEMORY_INDIRECT_LOW), y
    sta xPointer
    // Get y location
    iny
    lda (MEMORY_INDIRECT_LOW), y
    sta yPointer
    pla
    sta charPointer
    jsr draw_to_screen
    // --------------------- Draw the tail --------------------------
    ldy #TAIL_SEGMENT_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    sta xPointer
    iny
    lda (MEMORY_INDIRECT_LOW), y
    sta yPointer
    // Work out the char
    iny
    ldx #4
    lda (MEMORY_INDIRECT_LOW), y
    cmp #UP_DIRECTION
    bne !else+
    lda snakeUp, x
    jmp !end_if+
!else:
    cmp #DOWN_DIRECTION
    bne !else+
    lda snakeDown, x
    jmp !end_if+
!else:
    cmp #LEFT_DIRECTION
    bne !else+
    lda snakeLeft, x
    jmp !end_if+
!else:
    lda snakeRight, x
!end_if:
    sta charPointer
    jsr draw_to_screen
    // ------------------ Draw blank sector -------------------
    ldy #BLANK_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    sta xPointer
    iny
    lda (MEMORY_INDIRECT_LOW), y
    sta yPointer
    lda #BLANK_CHAR
    sta charPointer
    jsr draw_to_screen

    // Shift the direction down
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    ldy #LAST_SEGMENT_OFFSET + 2
    sta (MEMORY_INDIRECT_LOW), y    // shift direction

    rts
}

// Gets the next random X & Y for the food.
// For each coordinate:
// - Get the next random value (0 - 255)
// - Apply a mask to get the bits that contain the desired max number
// -- e.g., max column = 39 (100111), so mask 111111
// -- check if number is greater than max, e.g., bits 3 or 4 set 
// -- if greater than xor with mask to flip bits and ensure number is less
// - Write x/y values to food memory locations
// This is not a very good way of getting random coords as it produces a bias due to the 
// handling of overflowed values.
next_food:
    ldy #FOOD_OFFSET
    lda $d41b       // get the random number
    and #%11_1111
    clc
    adc #MIN_WINDOW_COL
    cmp #MAX_WINDOW_COL + 2 - MIN_WINDOW_COL
    bcc !+           // < max so ok
    sec 
    sbc #MAX_WINDOW_COL // subtract the max
!:
    sta (MEMORY_INDIRECT_LOW), y    // food x
    lda $d41b       // next random number
    and #%1_1111
    clc
    adc #MIN_WINDOW_ROW  
    cmp #MAX_WINDOW_ROW + 2 - MIN_WINDOW_ROW
    bcc !+        // < max so ok
    sec
    sbc #MAX_WINDOW_ROW
!:
    iny
    sta (MEMORY_INDIRECT_LOW), y   // food y
    rts

// Draw the food by getting the x/y from memory and calling the
// draw_to_screen method.
draw_food: {
    // Load params for draw_to_screen method
    .var xPointer = TEMP1
    .var yPointer = TEMP2
    .var charPointer = TEMP3
    .var drawResult = TEMP4
!:
    // Get the next food
    jsr next_food
    // Get the x location of the food
    ldy #FOOD_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    sta xPointer 
    // Get the Y location of the food
    iny
    lda (MEMORY_INDIRECT_LOW), y
    sta yPointer 
    // Finally draw the food to scren memory
    lda foodChar
    sta charPointer
    jsr draw_to_screen
    // Check for any illegal food positions (collisions with snake or other food)
    lda drawResult
    cmp #LOWEST_SNAKE_CHAR    // This is the first snake char
    bcs !-      // Hit a part of the snake; try again...
    cmp #FOOD_CHAR1
    beq !-      // Hit another food; try again...
    cmp #FOOD_CHAR2
    beq !-
    // This will loop forever if game ever gets 'completed' - should think of a fix for that
    rts    
}

// Draw a character to the screen
// - lookup x coord in TEMP1
// - lookup y coord in TEMP2
// - lookup char in TEMP3
// @return store the char that was already occupying screen memory in TEMP4
draw_to_screen: {
    // Put the screen memory page number into $BB/BC (Pointer: Current File Name)
    .var screenIndirectLow = $bb
    .var screenIndirectHigh = $bc
    // Put the colour memory page number into $35/$36 (Utility String Pointer)
    .var colourIndirectLow = $35
    .var colourIndirectHigh = $36
    .var xPointer = TEMP1
    .var yPointer = TEMP2
    .var charPointer = TEMP3
    .var result = TEMP4
    lda SCREEN_MEMORY_PAGE
    sta screenIndirectHigh                // high byte
    lda #0
    sta screenIndirectLow                 // low byte
    // Colour starts at $D800
    lda #0
    sta colourIndirectLow
    lda #$d8
    sta colourIndirectHigh
    // First, get the Y location
    lda yPointer
    tax                     // transfer the y coord to the x register so we can count down rows                         
!:
    cpx #0
    beq !+
    // Increment the screen row
    clc
    lda screenIndirectLow
    adc #MAX_COL
    sta screenIndirectLow
    lda screenIndirectHigh
    adc #0
    sta screenIndirectHigh
    // Increment the colour row
    clc
    lda colourIndirectLow
    adc #MAX_COL
    sta colourIndirectLow
    lda colourIndirectHigh
    adc #0
    sta colourIndirectHigh
    dex
    jmp !-
!:
    // Next, get the x location of the chars
    lda xPointer 
    // Finally draw the char to scren memory
    tay
    // Before drawing store the char currently loaded on screen 
    lda (screenIndirectLow), y
    sta result 
    // We never want to draw over a snake segment (unless blanking), ensure screen contains anything else
    cmp #LOWEST_SNAKE_CHAR
    bcc !+              // It's not a snake char, so go ahead and draw
    cmp #BLANK_CHAR
    beq !+             // blank char can overwrite any part of a snake
    // It's a snake char, so check if the head is being drawn
    lda charPointer
    cmp #FOOD_CHAR1
    beq !++             // Food can't be drawn on top of a snake
    cmp #FOOD_CHAR2
    beq !++
!:
    // Now we can draw; doesn't matter if food already exists as it's cheap to re-write
    lda charPointer
    sta (screenIndirectLow), y
    cmp #LOWEST_SNAKE_CHAR
    bcs colour_snake
    lda #FOOD_COLOUR
    jmp draw
colour_snake:
    lda #SNAKE_COLOUR
draw:
    sta (colourIndirectLow), y
!:
    rts
}

// Read a character to the screen
// - lookup x coord in TEMP1
// - lookup y coord in TEMP2
// @return store the char that was already occupying screen memory in TEMP4
read_from_screen: {
    // Put the screen memory page number into $BB/BC (Pointer: Current File Name)
    .var screenIndirectLow = $bb
    .var screenIndirectHigh = $bc
    .var xPointer = TEMP1
    .var yPointer = TEMP2
    .var result = TEMP4
    lda SCREEN_MEMORY_PAGE
    sta screenIndirectHigh                // high byte
    lda #0
    sta screenIndirectLow                 // low byte
    // First, get the Y location
    lda yPointer
    tax                     // transfer the y coord to the x register so we can count down rows                         
!:
    cpx #0
    beq !+
    // Increment the screen row
    clc
    lda screenIndirectLow
    adc #MAX_COL
    sta screenIndirectLow
    lda screenIndirectHigh
    adc #0
    sta screenIndirectHigh
    dex
    jmp !-
!:
    // Next, get the x location of the chars
    lda xPointer 
    // Finally draw the char to scren memory
    tay
    // Get the character loaded on screen 
    lda (screenIndirectLow), y
    sta result 
    rts
}

// Read the joystick for control
player_control: {
    lda JOY_PORT_2
    .var JOY_ZP = joyInput
    sta JOY_ZP        

    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
!up:
    cmp #DOWN_DIRECTION
    beq !+
    lda JOY_ZP
    and #JOY_UP
    // accumulator will contain 0 if pressed, 1 if not
    bne !+          // if it's not 0 then it hasn't been pressed
    lda #UP_DIRECTION
    jmp done
!:

!down:
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    cmp #UP_DIRECTION
    beq !+
    lda JOY_ZP   
    and #JOY_DN
    bne !+
    lda #DOWN_DIRECTION
    jmp done
!:

!left:
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    cmp #RIGHT_DIRECTION
    beq !+
    lda JOY_ZP
    and #JOY_LT
    bne !+
    lda #LEFT_DIRECTION
    jmp done
!:

!right:
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    cmp #LEFT_DIRECTION
    beq !+
    lda JOY_ZP
    and #JOY_RT
    bne !+
    lda #RIGHT_DIRECTION
    jmp done
!:
    rts
done:
    // Don't add the same value twice to the queue
    cmp lastInput
    beq !++
    sta lastInput
add_to_queue:
    pha     // push to the stack
    // First, increment the queue size
    ldy #INPUT_QUEUE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    clc
    adc #1
    sta (MEMORY_INDIRECT_LOW), y
    // Next, add the input to the queue 
!:
    iny
    sec
    sbc #1
    bne !-
    pla     // get the input back from the stack
    sta (MEMORY_INDIRECT_LOW), y  // add to the queue 
!:

    rts   
}


// Read the keyboard and check for a valid input. 
// - add valid inputs to the input queue. this is required in case fast inputs beat the raster to produce a double input
read_inputs: {
    jsr SCAN_STOP
    bne !+
    // Break has been hit - store the quit state
    ldy #RUN_STATE_OFFSET
    lda #QUIT_GAME
    sta (MEMORY_INDIRECT_LOW), y
    rts
!:
    jsr GET_IN          // read the keyboard
    beq !++              // no input loads 0 into A (Z flag will be set)
    cmp #UP_DIRECTION
    beq add_to_queue
    cmp #DOWN_DIRECTION
    beq add_to_queue
    cmp #LEFT_DIRECTION
    beq add_to_queue
    cmp #RIGHT_DIRECTION
    beq add_to_queue      
    rts                 // not a valid input so return
add_to_queue:
    pha     // push to the stack
    // First, increment the queue size
    ldy #INPUT_QUEUE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    clc
    adc #1
    sta (MEMORY_INDIRECT_LOW), y
    // Next, add the input to the queue 
!:
    iny
    sec
    sbc #1
    bne !-
    pla     // get the input back from the stack
    sta (MEMORY_INDIRECT_LOW), y  // add to the queue 
!:
    rts
}
    
// Pull the next direction from the queue and set as the current snake direction
set_next_direction: {
    .var temp = $03a0
    // Load the queue size
    ldy #INPUT_QUEUE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    bne !+
    rts         // the queue is empty so return
    // Next, load the next input in the queue
!:
    iny
    beq finally
    sec
    sbc #1
    bne !-
    lda (MEMORY_INDIRECT_LOW), y
    sta temp        // put the entered direction to one side...
    // Load the current direction 
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    // Check if the opposite direction has been entered
    cmp #UP_DIRECTION
    bne !+
    lda temp
    cmp #DOWN_DIRECTION
    beq finally
    jmp store
!:
    cmp #DOWN_DIRECTION
    bne !+
    lda temp
    cmp #UP_DIRECTION
    beq finally
    jmp store
!:
    cmp #LEFT_DIRECTION
    bne !+
    lda temp
    cmp #RIGHT_DIRECTION
    beq finally
    jmp store
!:
    lda temp
    cmp #LEFT_DIRECTION
    beq finally
store:
    sta (MEMORY_INDIRECT_LOW), y
finally: 
    // Finally, decrement the queue size
    ldy #INPUT_QUEUE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    sec
    sbc #1
    sta (MEMORY_INDIRECT_LOW), y
    rts
}

// Clear the screen.
// - Screen is 1000 chars so clear in chunks of 250
clear_screen: {
    lda #0
    ldx #250
!:
    dex
    sta SCREEN_RAM, x
    sta SCREEN_RAM + 250, x
    sta SCREEN_RAM + 500, x
    sta SCREEN_RAM + 750, x
    bne !-
    rts
}

display_score: {
    ldx #0
!:
    lda score, x
    sta SCREEN_RAM + 22 * 40 + 1, x
    inx
    cpx #5
    bne !-
    rts
}

// End the game
game_over: {
    //jsr clear_interrupt
    inc $d019       // VIC Interrupt Flag Register (1 = IRQ occurred)
    ldx #0
!:
    lda gameOverTextMap, x
    // 12 rows down, 40 wide
    sta SCREEN_RAM + 12 * 40, x
    inx 
    cpx #80 // text is 2 rows (2 * 40)
    bne !-

    // Loop colours
    ldx colourIndex
    ldy #0
colour_loop:  
    lda colourRamp, x
    sta COLOUR_RAM + 12 * 40, y
    sta COLOUR_RAM + 13 * 40, y

    inx
    cpx #coloursInRamp
    bcc !+
    ldx #0
!:
    stx colourIndex
    iny
    cpy #40
    bcc colour_loop
    ldy #0
!:
//    jmp colour_loop
    jmp $ea31       // Restores A, X & Y registers and CPU flags before returning from interrupt
}

*= $2800
.import binary "assets/charset.bin"
