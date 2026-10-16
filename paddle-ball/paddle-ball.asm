!cpu 6510

; Self-starting BASIC line: 10 SYS2061
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
    lda #147
    jsr $ffd2
    ldx #0
title_loop:
    lda title,x
    beq new_ball
    jsr $ffd2
    inx
    bne title_loop
new_ball:
    lda #20
    sta paddle_x
    lda #20
    sta ball_x
    lda #10
    sta ball_y
    lda #1
    sta dx
    sta dy
main_loop:
    jsr erase_objects
    jsr read_key
    cmp #81
    bne not_quit
    jmp exit
not_quit:
    cmp #65
    bne check_right
    lda paddle_x
    beq check_right
    dec paddle_x
check_right:
    cmp #68
    bne update_ball
    lda paddle_x
    cmp #34
    beq update_ball
    inc paddle_x
update_ball:
    lda ball_x
    clc
    adc dx
    sta ball_x
    beq bounce_x
    cmp #39
    bne move_y
bounce_x:
    lda dx
    eor #$fe
    clc
    adc #1
    sta dx
move_y:
    lda ball_y
    clc
    adc dy
    sta ball_y
    beq bounce_y
    cmp #22
    bne draw
    lda ball_x
    cmp paddle_x
    bcc missed
    sec
    sbc paddle_x
    cmp #6
    bcc bounce_y
missed:
    jsr draw_objects
wait_serve:
    jsr $ffe4
    cmp #81
    bne serve_key
    jmp exit
serve_key:
    cmp #32
    bne wait_serve
    jmp new_ball
bounce_y:
    lda dy
    eor #$fe
    clc
    adc #1
    sta dy
draw:
    jsr draw_objects
    ldx #6
delay_outer:
    ldy #0
delay_inner:
    dey
    bne delay_inner
    dex
    bne delay_outer
    jmp main_loop
erase_objects:
    lda #32
    jsr draw_ball
    ldx #5
erase_paddle:
    txa
    pha
    clc
    adc paddle_x
    tax
    ldy #23
    lda #32
    jsr plot
    pla
    tax
    dex
    bpl erase_paddle
    rts
draw_objects:
    lda #81
    jsr draw_ball
    ldx #5
draw_paddle:
    txa
    pha
    clc
    adc paddle_x
    tax
    ldy #23
    lda #160
    jsr plot
    pla
    tax
    dex
    bpl draw_paddle
    rts
draw_ball:
    pha
    ldx ball_x
    ldy ball_y
    pla
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
read_key:
    jsr $ffe4
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
!text "PADDLE BALL  A/D MOVE  SPACE SERVE  Q QUIT"
!byte 13,0
row_lo: !for i,0,24 { !byte <($0400+i*40) }
row_hi: !for i,0,24 { !byte >($0400+i*40) }
paddle_x: !byte 0
ball_x: !byte 0
ball_y: !byte 0
dx: !byte 0
dy: !byte 0
char_value: !byte 0
old_border: !byte 0
old_background: !byte 0
