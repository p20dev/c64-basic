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
    lda #147
    jsr $ffd2
    ldx #0
title_loop:
    lda title,x
    beq shuffle
    jsr $ffd2
    inx
    bne title_loop
shuffle:
    ldx #0
copy_board:
    lda shuffled,x
    sta board,x
    inx
    cpx #16
    bne copy_board
    lda #13
    sta blank
main:
    jsr draw_board
wait_key:
    jsr $ffe4
    beq wait_key
    cmp #81
    bne not_quit
    jmp exit
not_quit:
    cmp #82
    beq shuffle
    cmp #87
    bne key_down
    lda blank
    cmp #12
    bcs wait_key
    clc
    adc #4
    jmp move_tile
key_down:
    cmp #83
    bne key_left
    lda blank
    cmp #4
    bcc wait_key
    sec
    sbc #4
    jmp move_tile
key_left:
    cmp #65
    bne key_right
    lda blank
    and #3
    cmp #3
    beq wait_key
    lda blank
    clc
    adc #1
    jmp move_tile
key_right:
    cmp #68
    bne wait_key
    lda blank
    and #3
    beq wait_key
    lda blank
    sec
    sbc #1
move_tile:
    tax
    ldy blank
    lda board,x
    sta board,y
    lda #0
    sta board,x
    stx blank
    jmp main
draw_board:
    ldx #0
draw_loop:
    stx tile_index
    lda positions_lo,x
    sta $fb
    lda positions_hi,x
    sta $fc
    lda board,x
    beq draw_blank
    jsr split_digits
    ldy #0
    lda tens
    beq leading_space
    ora #$30
    bne store_first
leading_space:
    lda #32
store_first:
    sta ($fb),y
    iny
    lda ones
    ora #$30
    sta ($fb),y
    jmp next_tile
draw_blank:
    ldy #0
    lda #32
    sta ($fb),y
    iny
    sta ($fb),y
next_tile:
    ldx tile_index
    inx
    cpx #16
    bne draw_loop
    rts
split_digits:
    ldy #0
split_loop:
    cmp #10
    bcc split_done
    sec
    sbc #10
    iny
    bne split_loop
split_done:
    sty tens
    sta ones
    rts
exit:
    lda #147
    jsr $ffd2
    rts

title: !byte 147
!text "FIFTEEN PUZZLE  WASD SLIDE  R RESET  Q QUIT"
!byte 13,13,13,0
shuffled: !byte 1,2,3,4,5,6,7,8,9,10,11,12,13,0,14,15
board: !fill 16,0
positions_lo:
!for row,0,3 { !for col,0,3 { !byte <($04f5+row*80+col*5) } }
positions_hi:
!for row,0,3 { !for col,0,3 { !byte >($04f5+row*80+col*5) } }
blank: !byte 0
tile_index: !byte 0
tens: !byte 0
ones: !byte 0
