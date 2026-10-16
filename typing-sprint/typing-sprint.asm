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
    beq ready
    jsr $ffd2
    inx
    bne title_loop
ready:
    ldx #0
ready_loop:
    lda ready_text,x
    beq wait_start
    jsr $ffd2
    inx
    bne ready_loop
wait_start:
    jsr $ffe4
    cmp #81
    bne start_key
    jmp exit
start_key:
    cmp #32
    bne wait_start
new_round:
    lda #147
    jsr $ffd2
    ldx #0
prompt_loop:
    lda prompt,x
    beq setup
    jsr $ffd2
    inx
    bne prompt_loop
setup:
    lda #0
    sta position
    sta mistakes
    sta frames
    sta seconds
    lda $a2
    sta last_jiffy
main:
    lda $a2
    cmp last_jiffy
    beq read_key
    sta last_jiffy
    inc frames
    lda frames
    cmp #60
    bne read_key
    lda #0
    sta frames
    inc seconds
read_key:
    jsr $ffe4
    beq main
    cmp #81
    bne type_key
    jmp exit
type_key:
    ldx position
    cmp target,x
    beq correct
    inc mistakes
    lda #18
    jsr $ffd2
    lda #42
    jsr $ffd2
    lda #146
    jsr $ffd2
    jmp main
correct:
    jsr $ffd2
    inc position
    ldx position
    lda target,x
    bne main
    lda #13
    jsr $ffd2
    ldx #0
done_loop:
    lda done_text,x
    beq show_time
    jsr $ffd2
    inx
    bne done_loop
show_time:
    lda seconds
    ldx #0
time_tens:
    cmp #10
    bcc print_time
    sec
    sbc #10
    inx
    bne time_tens
print_time:
    pha
    txa
    beq print_ones
    ora #$30
    jsr $ffd2
print_ones:
    pla
    ora #$30
    jsr $ffd2
    ldx #0
seconds_loop:
    lda seconds_text,x
    beq wait_again
    jsr $ffd2
    inx
    bne seconds_loop
wait_again:
    jsr $ffe4
    cmp #81
    bne again_key
    jmp exit
again_key:
    cmp #32
    bne wait_again
    jmp new_round
exit:
    lda #147
    jsr $ffd2
    rts

title: !byte 147
!text "TYPING SPRINT  COPY THE PHRASE WITHOUT ERRORS"
!byte 13,13,0
ready_text: !text "SPACE STARTS A SPRINT   Q QUITS"
!byte 0
prompt: !byte 147
!text "TYPE: COMMODORE SIXTY FOUR"
!byte 13,13,0
target: !text "COMMODORE SIXTY FOUR"
!byte 0
done_text: !text "FINISH IN "
!byte 0
seconds_text: !text " SECONDS  SPACE RUNS AGAIN"
!byte 0
position: !byte 0
mistakes: !byte 0
frames: !byte 0
seconds: !byte 0
last_jiffy: !byte 0
