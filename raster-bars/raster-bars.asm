!cpu 6510

; Self-starting BASIC line: 10 SYS2061
* = $0801
!word basic_end
!word 10
!byte $9e
!text "2061"
!byte 0
basic_end:
!word 0

* = $080d
start:
    lda $d020
    sta old_border
    lda $d021
    sta old_background
    lda #147
    jsr $ffd2
    ldx #0
print_title:
    lda title,x
    beq initialize
    jsr $ffd2
    inx
    bne print_title
initialize:
    lda #4
    sta speed
    lda #0
    sta phase
    sta tick
    sta palette
main_loop:
    ldx #0
draw_bar:
    lda raster_lines,x
wait_line:
    cmp $d012
    bne wait_line
    txa
    clc
    adc phase
    and #7
    tay
    lda palette
    beq use_color
    tya
    clc
    adc #8
    tay
use_color:
    lda colors,y
    sta $d020
    sta $d021
    inx
    cpx #8
    bne draw_bar
    lda old_background
    sta $d021
    lda old_border
    sta $d020
    inc tick
    lda tick
    cmp speed
    bcc read_key
    lda #0
    sta tick
    inc phase
    lda phase
    and #7
    sta phase
read_key:
    jsr $ffe4
    beq main_loop
    cmp #'Q'
    beq exit
    cmp #'C'
    beq change_palette
    cmp #'1'
    beq slow
    cmp #'2'
    beq medium
    cmp #'3'
    beq fast
    jmp main_loop
slow:
    lda #8
    bne set_speed
medium:
    lda #4
    bne set_speed
fast:
    lda #1
set_speed:
    sta speed
    jmp main_loop
change_palette:
    lda palette
    eor #1
    sta palette
    jmp main_loop
exit:
    lda old_border
    sta $d020
    lda old_background
    sta $d021
    lda #147
    jsr $ffd2
    rts
title:
!text "           RASTER BARS",13,13
!text "1 2 3    CHANGE SPEED",13
!text "C        CHANGE PALETTE",13
!text "Q        RETURN TO BASIC",13,0
raster_lines: !byte 72,84,96,108,120,132,144,156
colors: !byte 2,8,10,7,1,7,10,8, 6,14,3,13,1,13,3,14
speed: !byte 4
phase: !byte 0
tick: !byte 0
palette: !byte 0
old_border: !byte 0
old_background: !byte 0
