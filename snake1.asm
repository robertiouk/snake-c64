BasicUpstart(main)
* = $0810
jmp main

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
    .const SEGMENT_SIZE = 2
    // Top of screen memory (page)
    .const SCREEN_MEMORY_PAGE = $0288
    // Screen columns & rows
    .const MIN_WINDOW_COL = 1
    .const MIN_WINDOW_ROW = 1
    .const MAX_WINDOW_COL = 38
    .const MAX_WINDOW_ROW = 19
    .const MAX_COL = 40
    .const MAX_ROW = 20
    // The character for drawing
    .const FOOD_CHAR = 106
    .const BLANK_CHAR = 0
    .const SNAKE_CHAR = 105
    .const CLS_CHAR = 147
    .const FOOD_COLOUR = GREEN
    .const SNAKE_COLOUR = RED
    // Snake directions (based on ASCII)
    .const UP_DIRECTION = 145
    .const RIGHT_DIRECTION = 29
    .const DOWN_DIRECTION = 17
    .const LEFT_DIRECTION = 157
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
    .const FRAME_COUNT = TEMP7
    .const POINTS_PER_FOOD = 5
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
    //   Segment
    //   - The first segment in the array is blank
    //   ---------
    //   x (column): 1 byte (index 8 + (segment * 2))
    //   y (row): 1 byte (index 9 + (segment * 3))
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

    jsr GET_IN
    bne restart_game      // no input loads 0 into A (Z flag set means input read)
    // Repeat
    jmp colour_loop
restart_game:
    // Load window
    jsr set_interrupt
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
    lda #LIGHT_GREY
    sta COLOUR_RAM, x
    sta COLOUR_RAM + 210, x
    sta COLOUR_RAM + 420, x
    sta COLOUR_RAM + 630, x
    cpx #0
    bne draw_row 

    // Initialise variables
    lda #00
    ldy #00
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

    // Display the score label
    .var scoreRow = 22
    ldx #0
!:
    lda score, x
    sta SCREEN_RAM + scoreRow * MAX_COL + 1, x
    inx
    cpx #5
    bne !-
    inx 
    lda #120
    sta SCREEN_RAM + scoreRow * MAX_COL + 1, x
    // Draw the score
    jsr draw_score

    jsr draw_food
    //jsr set_interrupt
    // Main game loop
loop:
    jsr read_inputs

    // Check game state
    ldy #RUN_STATE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
  
    cmp #GAME_OVER
    beq end_game
    jmp loop
end_game:
    jsr game_over_interrupt
!:
    jsr GET_IN
    beq !-
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
    jsr move_snake
    jsr draw_snake
    lda #0
    sta FRAME_COUNT
!:
    
    jmp $ea31       // Restores A, X & Y registers and CPU flags before returning from interrupt

// Move the snake by shifting segments down array.
move_snake: {
    .var snakeIndirectLow = $fd
    .var snakeIndirectHigh = $fe    
    .var currentSegmentIndexLow = TEMP5  // This will hold the current segment index
    .var currentSegmentIndexHigh = TEMP6
    lda MEMORY_INDIRECT_LOW
    sta snakeIndirectLow
    lda MEMORY_INDIRECT_HIGH
    sta snakeIndirectHigh
    // Init the segment index
    ldy #SIZE_OFFSET
    lda (snakeIndirectLow), y
    sta currentSegmentIndexLow
    iny
    lda (snakeIndirectLow), y
    sta currentSegmentIndexHigh
    // Subtract 1 from the total
    sec
    dec currentSegmentIndexLow
    lda currentSegmentIndexHigh
    sbc #0
    sta currentSegmentIndexHigh
    // Get the char that was in coord the snake just moved to
    ldx #0              // use the x register to determine wheter food was eaten (1 = eaten)
    lda TEMP4
    cmp #FOOD_CHAR
    beq eaten_food
    cmp #SNAKE_CHAR
    bne !+
game_over:
    ldy #RUN_STATE_OFFSET
    lda #GAME_OVER
    sta (MEMORY_INDIRECT_LOW), y
    rts
eaten_food:
    // Got food
    jsr next_food
    jsr draw_food
    // Grow the snake 
    ldy #SIZE_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    clc
    adc #1
    sta (MEMORY_INDIRECT_LOW), y
    iny
    lda (MEMORY_INDIRECT_LOW), y
    adc #0
    sta (MEMORY_INDIRECT_LOW), y
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
    ldx #1              // food eaten
!:
    // Shift the snake segments down
    ldy #SEGMENT_OFFSET + SEGMENT_SIZE  // Get the x value of the next segment to current
    lda (snakeIndirectLow), y
    ldy #SEGMENT_OFFSET                 // Move to x value to the current segment
    sta (snakeIndirectLow), y
    ldy #SEGMENT_OFFSET + SEGMENT_SIZE + 1 // Now do the same with y
    lda (snakeIndirectLow), y
    ldy #SEGMENT_OFFSET+1
    sta (snakeIndirectLow), y
    // Decrement the segment index
    sec
    dec currentSegmentIndexLow
    lda currentSegmentIndexHigh 
    sbc #0
    sta currentSegmentIndexHigh
    bne !+
    lda currentSegmentIndexLow
    bne !+
    // If we reach here index is 0 and we're done
    // If food has been eaten then increment segment index 1 more time to grow snake
    cpx #1              // has the food been eaten?
    bne move_head       // no food eaten, so draw head immediately (no need to grow)
    inx                 // if food has been eating inc x to indicate it's time to draw the head finally
    // Now increment segment one more time...
!:
    // Increment to next segment
    clc
    lda snakeIndirectLow
    adc #SEGMENT_SIZE
    sta snakeIndirectLow
    lda snakeIndirectHigh
    adc #0
    sta snakeIndirectHigh
    cpx #2             // if snake has just grown then we're done, so move the head
    bne !--
grow_head:
    // First the current head needs shifting to the right so we have a value to move
    ldy #SEGMENT_OFFSET                     // Get the x value of the next segment to current
    lda (snakeIndirectLow), y
    ldy #SEGMENT_OFFSET + SEGMENT_SIZE      // Move to x value to the final segment
    sta (snakeIndirectLow), y
    ldy #SEGMENT_OFFSET +1                  // Now do the same with y
    lda (snakeIndirectLow), y
    ldy #SEGMENT_OFFSET + SEGMENT_SIZE + 1
    sta (snakeIndirectLow), y
move_head:
    // Get the current direction
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    // ------------ UP ---------------
    cmp #UP_DIRECTION
    bne !++
    ldy #SEGMENT_OFFSET + 1 + SEGMENT_SIZE    // get Y
    lda (snakeIndirectLow), y
    // Decrement y
    tax
    dex
    txa
    // If < 0 row then wrap around
    cmp #MIN_WINDOW_ROW - 1
    bne !+                      // if positive number (not < 0) then skip the next bit
    lda #MAX_ROW - 1
!:
    sta (snakeIndirectLow), y   // store the modified value
    jmp done
!:
    // ------------ DOWN ---------------
    cmp #DOWN_DIRECTION
    bne !++
    ldy #SEGMENT_OFFSET + 1 + SEGMENT_SIZE    // get Y
    lda (snakeIndirectLow), y
    // Increment y
    tax
    inx
    txa
    // if > max rows then wrap around
    cmp #MAX_WINDOW_ROW + 1
    bne !+                      // if not equal then skip the next bit
    lda #MIN_WINDOW_ROW
!:
    sta (snakeIndirectLow), y   // store the modified value
    jmp done
!:
    // ------------ LEFT ---------------
    cmp #LEFT_DIRECTION
    bne !++
    ldy #SEGMENT_OFFSET + SEGMENT_SIZE        // get x
    lda (snakeIndirectLow), y
    // Decrement x
    tax
    dex
    txa
    // if < 0 col then wrap around
    cmp #MIN_WINDOW_COL - 1
    bne !+
    lda #MAX_WINDOW_COL
!:
    sta (snakeIndirectLow), y
    jmp done
!:
    // ------------ RIGHT ---------------
    cmp #RIGHT_DIRECTION
    bne !+
    ldy #SEGMENT_OFFSET + SEGMENT_SIZE        // get x
    lda (snakeIndirectLow), y
    // Increment x
    tax
    inx
    txa
    // if > max col then wrap around
    cmp #MAX_WINDOW_COL + 1
    bne !+
    lda #MIN_WINDOW_COL
!:
    sta (snakeIndirectLow), y
done:
    rts
}

// Draw the score as Thousands, Hundreds, Tens and Units
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
    sta SCREEN_RAM + scoreRow * MAX_COL + 7
    // Hundreds column...
    tya
    and #$0f
    tax
    lda digits, x
    sta SCREEN_RAM + scoreRow * MAX_COL + 8 
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
    sta SCREEN_RAM + scoreRow * MAX_COL + 9
    // Units column...
    tya
    and #$0f
    tax
    lda digits, x
    sta SCREEN_RAM + scoreRow * MAX_COL + 10
    rts
}

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
    adc #SEGMENT_SIZE
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
    cmp #SNAKE_CHAR
    bne !+              // It's not a snake char, so go ahead and draw
    lda charPointer
    cmp #BLANK_CHAR     
    bne !++             // It's a snake char and NOT a blank char so don't draw
!:
    // Now we can draw; doesn't matter if food already exists as it's cheap to re-write
    lda charPointer
    sta (screenIndirectLow), y
    cmp #SNAKE_CHAR
    beq colour_snake
    lda #FOOD_COLOUR
    jmp draw
colour_snake:
    lda #SNAKE_COLOUR
draw:
    sta (colourIndirectLow), y
!:
    rts
}

read_inputs: {
    .var mask = %0001_1111
    .var temp = $03a0
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
    sta temp           // put it away in memory for a future comparison
    // Load the current direction 
    ldy #DIRECTION_OFFSET
    lda (MEMORY_INDIRECT_LOW), y
    // Check if the opposite direction has been entered
    and #mask           // apply a mask to compare with the opposite
    cmp temp           // compare with the lower bits of the entered direction
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
