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
    lda $d015
    sta old_sprite_enable
    lda $d000
    sta old_sprite_x
    lda $d001
    sta old_sprite_y
    lda $d010
    sta old_sprite_x_msb
    lda $d027
    sta old_sprite_color
    lda $07f8
    sta old_sprite_pointer
    lda #147
    jsr $ffd2
    ldx #0
print_title:
    lda title,x
    beq setup_sprite
    jsr $ffd2
    inx
    bne print_title
setup_sprite:
    lda #$30
    sta $07f8
    lda #120
    sta sprite_x
    sta $d000
    sta sprite_y
    sta $d001
    lda #0
    sta $d010
    lda #1
    sta sprite_color
    sta $d027
    lda $d015
    ora #1
    sta $d015
main_loop:
    jsr wait_frame
    jsr $ffe4
    beq main_loop
    cmp #'Q'
    bne not_quit
    jmp exit
not_quit:
    cmp #'C'
    beq change_color
    cmp #'W'
    beq move_up
    cmp #'S'
    beq move_down
    cmp #'A'
    beq move_left
    cmp #'D'
    beq move_right
    jmp main_loop
move_up:
    lda sprite_y
    cmp #58
    bcc main_loop
    sec
    sbc #2
    sta sprite_y
    sta $d001
    jmp main_loop
move_down:
    lda sprite_y
    cmp #228
    bcs main_loop
    clc
    adc #2
    sta sprite_y
    sta $d001
    jmp main_loop
move_left:
    lda sprite_x
    cmp #26
    bcc main_loop
    sec
    sbc #2
    sta sprite_x
    sta $d000
    jmp main_loop
move_right:
    lda sprite_x
    cmp #238
    bcs main_loop
    clc
    adc #2
    sta sprite_x
    sta $d000
    jmp main_loop
change_color:
    inc sprite_color
    lda sprite_color
    and #15
    bne set_color
    lda #1
    sta sprite_color
set_color:
    sta $d027
    jmp main_loop
wait_frame:
wait_bottom:
    lda $d012
    cmp #250
    bne wait_bottom
wait_top:
    lda $d012
    cmp #10
    bne wait_top
    rts
exit:
    lda old_sprite_enable
    sta $d015
    lda old_sprite_x
    sta $d000
    lda old_sprite_y
    sta $d001
    lda old_sprite_x_msb
    sta $d010
    lda old_sprite_color
    sta $d027
    lda old_sprite_pointer
    sta $07f8
    lda old_border
    sta $d020
    lda old_background
    sta $d021
    lda #147
    jsr $ffd2
    rts
title:
!text "       SPRITE PLAYGROUND",13,13
!text "W A S D  MOVE THE HARDWARE SPRITE",13
!text "C        CHANGE COLOR",13
!text "Q        RETURN TO BASIC",13,0
sprite_x: !byte 120
sprite_y: !byte 120
sprite_color: !byte 1
old_border: !byte 0
old_background: !byte 0
old_sprite_enable: !byte 0
old_sprite_x: !byte 0
old_sprite_y: !byte 0
old_sprite_x_msb: !byte 0
old_sprite_color: !byte 0
old_sprite_pointer: !byte 0

* = $0c00
sprite_data:
!byte $00,$18,$00, $00,$3c,$00, $00,$7e,$00
!byte $00,$ff,$00, $01,$ff,$80, $03,$ff,$c0
!byte $07,$ff,$e0, $0f,$ff,$f0, $1f,$ff,$f8
!byte $3f,$ff,$fc, $7f,$ff,$fe, $ff,$ff,$ff
!byte $7f,$ff,$fe, $3f,$ff,$fc, $1f,$ff,$f8
!byte $0f,$ff,$f0, $07,$ff,$e0, $03,$ff,$c0
!byte $01,$ff,$80, $00,$ff,$00, $00,$7e,$00
!byte 0
