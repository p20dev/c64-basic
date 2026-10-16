!cpu 6510
* = $0801
!word basic_end
!word 10
!byte $9e
!text "2061"
!byte 0
basic_end: !word 0

* = $080d
start:
    lda $d020
    sta old_border
    lda $d021
    sta old_background
    lda #6
    sta $d020
    lda #14
    sta $d021
    lda #147
    jsr $ffd2
    ldx #0
title_loop:
    lda title,x
    beq setup
    jsr $ffd2
    inx
    bne title_loop
setup:
    lda #4
    sta speed
    lda #0
    sta tick
    sta food_y
main:
    jsr wait_frame
    jsr $ffe4
    cmp #81
    bne not_quit
    jmp exit
not_quit:
    cmp #70
    bne speed_keys
    lda #3
    sta food_x
    lda #2
    sta food_y
speed_keys:
    cmp #49
    bne speed_two
    lda #7
    sta speed
speed_two:
    cmp #50
    bne speed_three
    lda #4
    sta speed
speed_three:
    cmp #51
    bne animate
    lda #2
    sta speed
animate:
    inc tick
    lda tick
    cmp speed
    bcc main
    lda #0
    sta tick
    ldx #0
fish_loop:
    stx fish_index
    lda fish_x,x
    sta old_x
    ldy fish_y,x
    ldx old_x
    lda #32
    jsr plot
    ldx fish_index
    inc fish_x,x
    lda fish_x,x
    cmp #39
    bcc draw_fish
    lda #0
    sta fish_x,x
draw_fish:
    sta old_x
    ldy fish_y,x
    ldx old_x
    lda #62
    jsr plot
    ldx fish_index
    inx
    cpx #5
    bne fish_loop
    lda food_y
    bne move_food
    jmp main
move_food:
    ldx food_x
    ldy food_y
    lda #32
    jsr plot
    inc food_y
    lda food_y
    cmp #22
    bcc draw_food
    lda #0
    sta food_y
    jmp main
draw_food:
    tay
    ldx food_x
    lda #46
    jsr plot
    jmp main
plot:
    sta char_value
    lda row_lo,y
    sta $fb
    lda row_hi,y
    sta $fc
    txa
    tay
    lda char_value
    sta ($fb),y
    rts
wait_frame:
    lda #250
wait_raster:
    cmp $d012
    bne wait_raster
wait_leave:
    cmp $d012
    beq wait_leave
    rts
exit:
    lda old_border
    sta $d020
    lda old_background
    sta $d021
    lda #147
    jsr $ffd2
    rts

title: !byte 147
!text "PETSCII AQUARIUM  F FEED  1-3 SPEED  Q QUIT"
!byte 13,0
fish_x: !byte 2,9,16,23,30
fish_y: !byte 5,9,13,17,20
row_lo: !for i,0,24 { !byte <($0400+i*40) }
row_hi: !for i,0,24 { !byte >($0400+i*40) }
speed: !byte 0
tick: !byte 0
food_x: !byte 0
food_y: !byte 0
fish_index: !byte 0
old_x: !byte 0
char_value: !byte 0
old_border: !byte 0
old_background: !byte 0
