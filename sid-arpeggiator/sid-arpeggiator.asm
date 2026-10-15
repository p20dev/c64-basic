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
    ldx #0
save_sid:
    lda $d400,x
    sta old_sid,x
    inx
    cpx #25
    bne save_sid
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
    ldx #0
clear_sid:
    lda #0
    sta $d400,x
    inx
    cpx #25
    bne clear_sid
    lda #9
    sta $d405
    lda #$f0
    sta $d406
    lda #$0f
    sta $d418
    lda #0
    sta root
    sta step
    sta tick
    sta paused
    lda #6
    sta tempo
    lda #$21
    sta waveform
    jsr play_note
main_loop:
    jsr wait_frame
    jsr read_key
    lda paused
    bne main_loop
    inc tick
    lda tick
    cmp tempo
    bcc main_loop
    lda #0
    sta tick
    inc step
    lda step
    and #3
    sta step
    jsr play_note
    jmp main_loop
read_key:
    jsr $ffe4
    beq key_done
    cmp #'Q'
    bne not_quit
    jmp exit
not_quit:
    cmp #' '
    beq toggle_pause
    cmp #'1'
    beq triangle
    cmp #'2'
    beq saw
    cmp #'3'
    beq pulse
    cmp #'+'
    beq faster
    cmp #'-'
    beq slower
    ldx #0
find_root:
    cmp key_codes,x
    beq set_root
    inx
    cpx #8
    bne find_root
key_done:
    rts
set_root:
    stx root
    jsr play_note
    rts
triangle:
    lda #$11
    bne set_waveform
saw:
    lda #$21
    bne set_waveform
pulse:
    lda #$41
set_waveform:
    sta waveform
    sta $d404
    rts
faster:
    lda tempo
    cmp #2
    beq key_done
    dec tempo
    rts
slower:
    lda tempo
    cmp #12
    beq key_done
    inc tempo
    rts
toggle_pause:
    lda paused
    eor #1
    sta paused
    beq resume
    lda waveform
    and #$fe
    sta $d404
    rts
resume:
    jsr play_note
    rts
play_note:
    ldx step
    lda arp_offsets,x
    clc
    adc root
    tay
    lda frequencies_low,y
    sta $d400
    lda frequencies_high,y
    sta $d401
    lda waveform
    sta $d404
    rts
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
    ldx #0
restore_sid:
    lda old_sid,x
    sta $d400,x
    inx
    cpx #25
    bne restore_sid
    lda #147
    jsr $ffd2
    ; Discard the JSR read_key return address, then return from SYS.
    pla
    pla
    rts
title:
!text "          SID ARPEGGIATOR",13,13
!text "A-K      SELECT ROOT NOTE",13
!text "1 2 3    TRIANGLE SAW PULSE",13
!text "+ -      CHANGE TEMPO",13
!text "SPACE    PAUSE OR RESUME",13
!text "Q        RETURN TO BASIC",13,0
key_codes: !text "ASDFGHJK"
arp_offsets: !byte 0,4,7,12
frequencies_low:
!byte <4389,<4650,<4927,<5220,<5530,<5859,<6207,<6577,<6968,<7382
!byte <7821,<8286,<8779,<9301,<9854,<10440,<11060,<11718,<12414,<13154
frequencies_high:
!byte >4389,>4650,>4927,>5220,>5530,>5859,>6207,>6577,>6968,>7382
!byte >7821,>8286,>8779,>9301,>9854,>10440,>11060,>11718,>12414,>13154
root: !byte 0
step: !byte 0
tick: !byte 0
tempo: !byte 6
waveform: !byte $21
paused: !byte 0
old_sid: !fill 25,0
