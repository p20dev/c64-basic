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
    lda #0
    sta $d020
    sta $d021
    lda #147
    jsr $ffd2
    ldx #0
print_title:
    lda title,x
    beq setup
    jsr $ffd2
    inx
    bne print_title
setup:
    lda #7
    sta center_x
    lda #5
    sta burst_color
main:
    jsr $ffe4
    cmp #81
    bne not_quit
    jmp exit
not_quit:
    cmp #67
    bne launch_key
    inc burst_color
    lda burst_color
    and #15
    sta burst_color
launch_key:
    cmp #32
    bne main
    jsr launch
    jmp main
launch:
    lda #22
    sta rocket_y
rise:
    ldx center_x
    ldy rocket_y
    lda #46
    jsr plot
    jsr delay
    ldx center_x
    ldy rocket_y
    lda #32
    jsr plot
    dec rocket_y
    lda rocket_y
    cmp #7
    bne rise
    ldx #0
burst_loop:
    stx particle_index
    lda burst_dx,x
    clc
    adc center_x
    sta px
    lda burst_dy,x
    clc
    adc rocket_y
    tay
    ldx px
    lda #42
    jsr plot
    ldx particle_index
    inx
    cpx #12
    bne burst_loop
    jsr long_delay
    ldx #0
clear_burst:
    stx particle_index
    lda burst_dx,x
    clc
    adc center_x
    sta px
    lda burst_dy,x
    clc
    adc rocket_y
    tay
    ldx px
    lda #32
    jsr plot
    ldx particle_index
    inx
    cpx #12
    bne clear_burst
    lda center_x
    clc
    adc #11
    cmp #35
    bcc save_center
    sbc #31
save_center:
    sta center_x
    rts
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
    lda $fb
    clc
    adc #<$d400
    sta $fd
    lda $fc
    adc #>$d400
    sta $fe
    lda burst_color
    sta ($fd),y
    rts
delay:
    ldx #8
delay_outer:
    ldy #0
delay_inner:
    dey
    bne delay_inner
    dex
    bne delay_outer
    rts
long_delay:
    ldx #45
    bne delay_outer
exit:
    lda old_border
    sta $d020
    lda old_background
    sta $d021
    lda #147
    jsr $ffd2
    rts

title: !byte 147
!text "FIREWORKS  SPACE LAUNCH  C COLOR  Q QUIT"
!byte 13,0
burst_dx: !byte 0,1,2,$ff,$fe,0,0,1,2,$ff,$fe,0
burst_dy: !byte $fe,$ff,0,$ff,0,2,1,1,2,1,2,$ff
row_lo: !for i,0,24 { !byte <($0400+i*40) }
row_hi: !for i,0,24 { !byte >($0400+i*40) }
center_x: !byte 0
rocket_y: !byte 0
burst_color: !byte 0
particle_index: !byte 0
px: !byte 0
char_value: !byte 0
old_border: !byte 0
old_background: !byte 0
