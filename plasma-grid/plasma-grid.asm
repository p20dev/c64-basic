!cpu 6510

; Plasma Grid - real-time character and color RAM animation.
; Uses the collection's standard black splash screen.
; Self-starting BASIC line: 10 SYS2061
* = $0801
!word basic_end
!word 10
!byte $9e
!text "2061"
!byte 0
basic_end: !word 0

* = $080d
SCREEN = $0400
COLOR  = $d800
GETIN  = $ffe4
CHROUT = $ffd2

start:
    lda $d020
    sta old_border
    lda $d021
    sta old_background
    lda #0
    sta $d020
    sta $d021
    jsr show_splash
    lda #0
    sta $d020
    sta $d021
    lda #147
    jsr CHROUT
    lda #0
    sta phase_x
    sta phase_y
    sta palette_offset
    sta paused
    sta frame_count
    lda #3
    sta animation_speed
    lda $a2
    sta last_jiffy
    jsr render_plasma

main_loop:
    jsr GETIN
    beq check_clock
    cmp #81
    bne check_palette
    jmp exit
check_palette:
    cmp #67
    bne check_pause
    lda palette_offset
    eor #16
    sta palette_offset
    jmp check_clock
check_pause:
    cmp #32
    bne check_speed_one
    lda paused
    eor #1
    sta paused
    jmp check_clock
check_speed_one:
    cmp #49
    bne check_speed_two
    lda #6
    sta animation_speed
    jmp check_clock
check_speed_two:
    cmp #50
    bne check_speed_three
    lda #3
    sta animation_speed
    jmp check_clock
check_speed_three:
    cmp #51
    bne check_clock
    lda #1
    sta animation_speed

check_clock:
    lda paused
    bne main_loop
    lda $a2
    cmp last_jiffy
    beq main_loop
    sta last_jiffy
    inc frame_count
    lda frame_count
    cmp animation_speed
    bcc main_loop
    lda #0
    sta frame_count
    inc phase_x
    lda phase_x
    and #63
    sta phase_x
    lda phase_x
    and #1
    bne draw_frame
    inc phase_y
    lda phase_y
    and #63
    sta phase_y
draw_frame:
    jsr render_plasma
    jmp main_loop

render_plasma:
    lda #0
    sta row
row_loop:
    ldx row
    lda screen_row_lo,x
    sta $fb
    lda screen_row_hi,x
    sta $fc
    lda color_row_lo,x
    sta $fd
    lda color_row_hi,x
    sta $fe
    lda #0
    sta column
column_loop:
    lda column
    clc
    adc phase_x
    and #63
    tax
    lda wave,x
    sta wave_sum
    lda row
    asl
    clc
    adc phase_y
    and #63
    tax
    lda wave,x
    clc
    adc wave_sum
    and #15
    sta pattern
    clc
    adc palette_offset
    tax
    lda palettes,x
    ldy column
    sta ($fd),y
    lda pattern
    and #4
    beq solid_cell
    lda #102
    bne paint_cell
solid_cell:
    lda #160
paint_cell:
    sta ($fb),y
    inc column
    lda column
    cmp #40
    bne column_loop
    inc row
    lda row
    cmp #25
    bne row_loop
    rts

show_splash:
    ldx #0
print_splash:
    lda splash_text,x
    beq wait_for_space
    jsr CHROUT
    inx
    bne print_splash
wait_for_space:
    jsr GETIN
    cmp #32
    bne wait_for_space
    rts

exit:
    lda old_border
    sta $d020
    lda old_background
    sta $d021
    lda #147
    jsr CHROUT
    rts

splash_text:
!byte 147,13,13,13
!byte 154
!text "             PLASMA GRID"
!byte 13,13
!byte 5
!text "   A FLOWING FIELD OF COLOR AND MOTION"
!byte 13,13,13
!byte 153
!text "                CONTROLS"
!byte 13,13
!text " "
!byte 158
!text "1-3"
!byte 5
!text " SPEED  "
!byte 158
!text "C"
!byte 5
!text " COLOR  "
!byte 158
!text "SPACE"
!byte 5
!text " PAUSE  "
!byte 158
!text "Q"
!byte 5
!text " QUIT"
!byte 13,13,13
!byte 5
!text "          HTTPS://C64.P20.DEV"
!byte 13,13
!byte 152
!text "        RELEASED 16 OCTOBER 2026"
!byte 13,13,13
!byte 158
!text "         PRESS SPACE TO START"
!byte 0

; Two deliberately different 16-color sequences.
palettes:
!byte 0,6,11,4,14,3,13,1,13,3,14,4,11,6,0,6
!byte 0,2,8,7,1,7,8,2,9,10,5,13,3,14,6,0

; A 64-step triangle/sine-like wave. Combining horizontal and vertical
; samples produces the moving plasma interference pattern.
wave:
!byte 8,9,10,11,12,13,14,15,15,15,15,14,14,13,12,11
!byte 10,9,8,7,6,5,4,3,2,1,0,0,0,0,1,1
!byte 2,3,4,5,6,7,8,9,10,11,12,13,14,15,15,15
!byte 14,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0

screen_row_lo: !for i,0,24 { !byte <(SCREEN+i*40) }
screen_row_hi: !for i,0,24 { !byte >(SCREEN+i*40) }
color_row_lo:  !for i,0,24 { !byte <(COLOR+i*40) }
color_row_hi:  !for i,0,24 { !byte >(COLOR+i*40) }

phase_x: !byte 0
phase_y: !byte 0
palette_offset: !byte 0
paused: !byte 0
animation_speed: !byte 0
frame_count: !byte 0
last_jiffy: !byte 0
row: !byte 0
column: !byte 0
wave_sum: !byte 0
pattern: !byte 0
old_border: !byte 0
old_background: !byte 0
