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
    lda $d016
    sta old_d016
    lda $d020
    sta old_border
    lda #147
    jsr $ffd2
    ldx #0
header:
    lda title,x
    beq setup
    jsr $ffd2
    inx
    bne header
setup:
    lda #7
    sta fine
    lda #3
    sta speed
    lda #0
    sta tick
    sta message_pos
    lda #1
    sta text_color
main:
    jsr wait_frame
    jsr $ffe4
    cmp #81
    bne not_quit
    jmp exit
not_quit:
    cmp #43
    bne slower
    lda speed
    cmp #1
    beq slower
    dec speed
slower:
    cmp #45
    bne color_key
    lda speed
    cmp #8
    beq color_key
    inc speed
color_key:
    cmp #67
    bne animate
    inc text_color
    lda text_color
    and #15
    sta text_color
animate:
    inc tick
    lda tick
    cmp speed
    bcc main
    lda #0
    sta tick
    dec fine
    lda fine
    and #7
    sta fine
    lda old_d016
    and #$f8
    ora fine
    sta $d016
    lda fine
    cmp #7
    bne main
    ldx #0
shift:
    lda $0619,x
    sta $0618,x
    inx
    cpx #39
    bne shift
    ldy message_pos
    lda message,y
    bne put_char
    ldy #0
    sty message_pos
    lda message
put_char:
    sta $063f
    lda text_color
    sta $da3f
    inc message_pos
    jmp main
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
    lda old_d016
    sta $d016
    lda old_border
    sta $d020
    lda #147
    jsr $ffd2
    rts

title: !byte 147
!text "SMOOTH SCROLLER  +/- SPEED  C COLOR  Q QUIT"
!byte 13,13,0
message: !scr "   WELCOME TO THE C64 PROGRAM COLLECTION   BUILT WITH 6502 MACHINE CODE   "
!byte 0
fine: !byte 0
speed: !byte 0
tick: !byte 0
message_pos: !byte 0
text_color: !byte 0
old_d016: !byte 0
old_border: !byte 0
