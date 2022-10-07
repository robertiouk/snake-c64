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
    .const FOOD_OFFSET = 2
    .const SIZE_OFFSET = 4
    .const DIRECTION_OFFSET = 6
    .const SEGMENT_OFFSET = 7
    // Top of screen memory (page)
    .const SCREEN_MEMORY_PAGE = $0288
    // Screen columns
    .const COLS_IN_ROW = 40
    // The character for drawing
    .const FOOD_CHAR = 88
    .const BLANK_CHAR = 32
    .const SNAKE_CHAR = 81
    // Snake directions
    .const UP_DIRECTION = 0
    .const RIGHT_DIRECTION = 1
    .const DOWN_DIRECTION = 2
    .const LEFT_DIRECTION = 3
    // Other constants
    .const INIT_SNAKE_SIZE = 3
    .const START_ROW = 11
    .const START_COL = 20
    // Init. memory
    lda #MEMORY_START_LOW
    sta MEMORY_INDIRECT_LOW
    lda #MEMORY_START_HIGH
    sta MEMORY_INDIRECT_HIGH

    // Score: 2 bytes

    // Food
    // ----
    // x (column): 1 byte (index 2)
    // y (row): 1 byte (index 3)

    // The Snake
    // ---------
    // size: 2 bytes (index 4)
    // direction: 1 byte (index 6)
    //
    //   Segment
    //   - The first segment in the array is blank
    //   ---------
    //   x (column): 1 byte (index 7 + (segment * 2))
    //   y (row): 1 byte (index 8 + (segment * 3))

init:
    // Set screen to black and clear all text
    lda #00
    sta $d020
    sta $d021
    lda #147    
    jsr $ffd2
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
loop:
    jsr next_food
    jsr draw_food
    jsr draw_snake
    jmp loop

// Draw the snake.
// - Start from the lowest segment (tail blank), then work up to the head
draw_snake:
    // Set up zero page variables
    .var screenIndirectLow = $bb
    .var screenIndirectHigh = $bc
    .var snakeIndirectLow = $fd
    .var snakeIndirectHigh = $fe
    .var currentSegmentIndexLow = $03a0  // This will hold the current segment index
    .var currentSegmentIndexHigh = $03a1
    lda MEMORY_INDIRECT_LOW
    sta snakeIndirectLow
    lda MEMORY_INDIRECT_HIGH
    sta snakeIndirectHigh 
    // Push segment tracking to stack (2 bytes init to 0)  
    lda #0
    sta currentSegmentIndexLow
    sta currentSegmentIndexHigh 
    // Now start the drawing...
draw_next_segment:
    // First adjust relative memory
    /*lda MEMORY_INDIRECT_LOW
    clc
    adc currentSegmentIndexLow
    sta snakeIndirectLow
    lda MEMORY_INDIRECT_HIGH
    adc currentSegmentIndexHigh
    sta snakeIndirectHigh*/
    // Reset screen memory
    lda SCREEN_MEMORY_PAGE
    sta screenIndirectHigh
    lda #0
    sta screenIndirectLow
    // Draw next segment
    ldy #SEGMENT_OFFSET + 1
    lda (snakeIndirectLow), y       // y (row) of the current segment
    tax                             // transfer the y coord to the x register so we can count down rows                         
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
    // Next, get the x location of the segment
    ldy #SEGMENT_OFFSET
    lda (snakeIndirectLow), y
    // Work out which character to draw (end of tail is blank)
    tay
    lda currentSegmentIndexHigh
    bne !+
    lda currentSegmentIndexLow
    bne !+
    lda #BLANK_CHAR         // if we've got here then this is the first segment (end of tail)
    jmp draw_the_char
!:
    lda #SNAKE_CHAR
draw_the_char:
    // Finally draw the segment to scren memory
    sta (screenIndirectLow), y
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

// Gets the next random X & Y for the food.
// For each coordinate:
// - Get the next random value (0 - 255)
// - Apply a mask to get the bits that contain the desired max number
// -- e.g., max column = 39 (100111), so mask 111111
// -- check if number is greater than max, e.g., bits 3 or 4 set 
// -- if greater than xor with mask to flip bits and ensure number is less
// - Write x/y values to food memory locations
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

draw_food:
    // Put the screen memory page number into $BB/BC
    lda SCREEN_MEMORY_PAGE
    sta $bc                 // high byte
    lda #0
    sta $bb                 // low byte
    // First, get the Y location of the food
    ldy #FOOD_OFFSET + 1
    lda (MEMORY_INDIRECT_LOW), y
    tax                     // transfer the y coord to the x register so we can count down rows                         
!:
    cpx #0
    beq !+
    // Increment the screen row
    clc
    lda $bb
    adc #COLS_IN_ROW
    sta $bb
    lda $bc
    adc #0
    sta $bc
    dex
    jmp !-
!:
    // Next, get the x location of the food
    ldy #FOOD_OFFSET
    lda (MEMORY_INDIRECT_LOW), y 
    // Finally draw the food to scren memory
    tay
    lda #FOOD_CHAR
    sta ($bb), y
    rts    

end:
    rts