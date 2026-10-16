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
print_title:
    lda title,x
    beq reset
    jsr $ffd2
    inx
    bne print_title
reset:
    lda #0
    sta frames
    sta seconds
    sta minutes
    sta paused
    lda $a2
    sta last_jiffy
main:
    jsr wait_frame
    jsr $ffe4
    cmp #81
    bne not_quit
    jmp exit
not_quit:
    cmp #82
    beq reset
    cmp #32
    bne update
    lda paused
    eor #1
    sta paused
update:
    lda paused
    bne display
    lda $a2
    cmp last_jiffy
    beq display
    sta last_jiffy
    inc frames
    lda frames
    cmp #60
    bne display
    lda #0
    sta frames
    inc seconds
    lda seconds
    cmp #60
    bne display
    lda #0
    sta seconds
    inc minutes
    lda minutes
    cmp #100
    bne display
    lda #0
    sta minutes
display:
    lda minutes
    jsr split_digits
    lda tens
    ora #$30
    sta $05f0
    lda ones
    ora #$30
    sta $05f1
    lda #58
    sta $05f2
    lda seconds
    jsr split_digits
    lda tens
    ora #$30
    sta $05f3
    lda ones
    ora #$30
    sta $05f4
    jmp main
split_digits:
    ldx #0
subtract_ten:
    cmp #10
    bcc split_done
    sec
    sbc #10
    inx
    bne subtract_ten
split_done:
    stx tens
    sta ones
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
    lda #147
    jsr $ffd2
    rts

title: !byte 147
!text "JIFFY CLOCK  R RESET  SPACE PAUSE  Q QUIT"
!byte 13,13,13,13,13,13,13,13,13,13,0
frames: !byte 0
seconds: !byte 0
minutes: !byte 0
paused: !byte 0
last_jiffy: !byte 0
tens: !byte 0
ones: !byte 0
