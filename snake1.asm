BasicUpstart(main)
* = $0810

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
    .const FOOD_OFFSET = 3
    .const SIZE_OFFSET = 5
    .const DIRECTION_OFFSET = 7
    .const SEGMENT_OFFSET = 8
    // Top of screen memory (page)
    .const SCREEN_MEMORY_PAGE = $0288
    // Screen columns
    .const COLS_IN_ROW = 40
    // The character for drawing
    .const FOOD_CHAR = 88
    .const BLANK_CHAR = 32
    .const SNAKE_CHAR = 81
    .const CLS_CHAR = 147
    // Snake directions (based on ASCII)
    .const UP_DIRECTION = 145
    .const RIGHT_DIRECTION = 29
    .const DOWN_DIRECTION = 17
    .const LEFT_DIRECTION = 157
    // Other constants
    .const INIT_SNAKE_SIZE = 3
    .const START_ROW = 11
    .const START_COL = 20
    .const QUIT_GAME = $ff
    // Temp variables for parameters etc. Define as constants as may want to change these
    .const TEMP1 = $0334
    .const TEMP2 = $0335
    .const TEMP3 = $0336
    .const TEMP4 = $0337
    .const TEMP5 = $0338
    .const TEMP6 = $0339
    // ROM functions
    .const SCAN_STOP = $ffe1
    .const CHAR_OUT = $ffd2
    .const GET_IN = $ffe4
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
    //   Segment
    //   - The first segment in the array is blank
    //   ---------
    //   x (column): 1 byte (index 8 + (segment * 2))
    //   y (row): 1 byte (index 9 + (segment * 3))
init:
    // Set screen to black and clear all text
    lda #BLACK
    sta $d020
    sta $d021
    lda #CLS_CHAR
    jsr CHAR_OUT
    // Initialise variables
    lda #00
    ldy #00
    sta (MEMORY_INDIRECT_LOW), y
    iny
    sta (MEMORY_INDIRECT_LOW), y    // score = 0
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
    ldx #START_COL - INIT_SNAKE_SIZE
!:
    txa                             // get the current column 
    sta (MEMORY_INDIRECT_LOW), y    // set segment x
    lda #START_ROW
    iny
    sta (MEMORY_INDIRECT_LOW), y    // set segment y
    iny                             // ready for next segment...
    inx                             // increment the segment number
    cpx #START_COL
    bne !-

// lda $D41B will return a random number between 0-255
init_random:
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low byte
    sta $D40F // voice 3 frequency high byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

// Main game loop
    jsr draw_food
loop:
    jsr draw_snake
    jsr read_inputs
    // Check game state
    ldy #RUN_STATE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    cmp #QUIT_GAME
    beq !+
    jmp loop
!:
    jmp end

// Draw the snake.
// - Start from the lowest segment (tail blank), then work up to the head
draw_snake: {
    // Load params for draw_to_screen method
    .var xPointer = TEMP1
    .var yPointer = TEMP2
    .var charPointer = TEMP3
     // Set up zero page variables
    .var snakeIndirectLow = $fd
    .var snakeIndirectHigh = $fe
    .var currentSegmentIndexLow = TEMP5  // This will hold the current segment index
    .var currentSegmentIndexHigh = TEMP6
    lda MEMORY_INDIRECT_LOW
    sta snakeIndirectLow
    lda MEMORY_INDIRECT_HIGH
    sta snakeIndirectHigh 
    // Push segment tracking to temp variables (2 bytes init to 0)  
    lda #0
    sta currentSegmentIndexLow
    sta currentSegmentIndexHigh 
    // Now start the drawing...
draw_next_segment:
    // Draw next segment
    // Get the x location of the segment
    ldy #SEGMENT_OFFSET
    lda (snakeIndirectLow), y
    sta xPointer
    // Get the y location of the segnebt
    iny
    lda (snakeIndirectLow), y       
    sta yPointer
    // Work out which character to draw (end of tail is blank)
    lda currentSegmentIndexHigh
    bne !+
    lda currentSegmentIndexLow
    bne !+
    lda #BLANK_CHAR         // if we've got here then this is the first segment (end of tail)
    jmp draw_the_char
!:
    lda #SNAKE_CHAR
draw_the_char:
    sta charPointer
    jsr draw_to_screen
    // Increment the current segment count
    clc
    inc currentSegmentIndexLow
    lda currentSegmentIndexHigh
    adc #0
    sta currentSegmentIndexHigh
    // Increment current segment reference
    clc
    lda snakeIndirectLow
    adc #2
    sta snakeIndirectLow
    lda snakeIndirectHigh
    adc #0
    sta snakeIndirectHigh
    // Are there any more segments to draw?
    lda currentSegmentIndexLow
    ldy #SIZE_OFFSET
    cmp (MEMORY_INDIRECT_LOW), y
    bne draw_next_segment
    lda currentSegmentIndexHigh
    iny
    cmp (MEMORY_INDIRECT_LOW), y
    bne draw_next_segment
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
    lda $d41b       // get the random number
    ldy #FOOD_OFFSET
    and #%11_1111    // 39 (max col) is 100111
    cmp #40
    bcc !+           // < 40 so ok
    eor #%11_1111    // if number is greater than 39 then flip the bits
!:
    sta (MEMORY_INDIRECT_LOW), y    // food x
    lda $d41b       // next random number
    and #%1_1111         // 24 (max row) is 11000
    cmp #25         
    bcc !+        // < 25 so ok
    eor #%1_1111
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
    lda #FOOD_CHAR
    sta charPointer

    jsr draw_to_screen
    // Check for any illegal food positions (collisions with snake or other food)
    lda drawResult
    cmp #SNAKE_CHAR
    beq !-      // Hit a part of the snake; try again...
    cmp #FOOD_CHAR
    beq !-      // Hit another food; try again...
    // This will loop forever if game ever gets 'completed' - should think of a fix for that
    rts    
}

// Draw a character to the screen
// - lookup x coord in TEMP1
// - lookup y coord in TEMP2
// - lookup char in TEMP3
// @return store the char that was already occupying screen memory in TEMP4
draw_to_screen: {
    // Put the screen memory page number into $BB/BC
    .var screenIndirectLow = $bb
    .var screenIndirectHigh = $bc
    .var xPointer = TEMP1
    .var yPointer = TEMP2
    .var charPointer = TEMP3
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
    adc #COLS_IN_ROW
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
    // Before drawing store the char currently loaded on screen 
    lda (screenIndirectLow), y
    sta result 
    // We never want to draw over a snake segment, ensure screen contains anything else
    cmp #SNAKE_CHAR
    beq !+
    // Now we can draw; doesn't matter if food already exists as it's cheap to re-write
    lda charPointer
    sta (screenIndirectLow), y
!:
    rts
}

read_inputs: {
    .var mask = %0001_1111
    jsr SCAN_STOP
    bne !+
    // Break has been hit - store the quit state
    ldy #RUN_STATE_OFFSET
    lda #QUIT_GAME
    sta (MEMORY_INDIRECT_LOW), y
    rts
!:
    jsr GET_IN          // read the keyboard
    beq !+              // no input loads 0 into A (Z flag will be set)
    pha                 // chuck it on the stack for now, we'll come back to it later...
    and #mask           // apply the mask to get to trim off the high bit
    sta TEMP1           // put it away in memory for a future comparison
    // Load the current direction 
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    // Check if the opposite direction has been entered
    and #mask           // apply a mask to compare with the opposite
    cmp TEMP1           // compare with the lower bits of the entered direction
    beq fix_stack_and_quit  // if they're equal then they must be opposites or the same, so return
    // Get the entered direction back
    pla 
    cmp #UP_DIRECTION
    beq store
    cmp #DOWN_DIRECTION
    beq store
    cmp #LEFT_DIRECTION
    beq store
    cmp #RIGHT_DIRECTION
    beq store
    jmp !+              // if we got here then invalid key was pressed, so return
store:
    sta (MEMORY_INDIRECT_LOW), y
!: 
    rts
fix_stack_and_quit:
    pla
    jmp !-
}

end:
    // Clear the screen
    lda #CLS_CHAR
    jsr CHAR_OUT
    // Reset screen colour
    lda #LIGHT_BLUE
    sta $d020
    lda #BLUE
    sta $d021
    rts