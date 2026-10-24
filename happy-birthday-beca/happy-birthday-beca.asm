!cpu 6510

; HAPPY BIRTHDAY, BECA!
; A fifth-birthday celebration with balloons, confetti, cake and SID music.
; Self-starting BASIC line: 10 SYS4096
* = $0801
!word basic_end
!word 10
!byte $9e
!text "4096"
!byte 0
basic_end: !word 0

* = $1000
SCREEN = $0400
COLOR  = $d800
GETIN  = $ffe4
CHROUT = $ffd2

start:
    jsr save_state
    lda #0
    sta $d020
    sta $d021
    jsr show_splash
    jsr initialize_demo

main_loop:
    jsr read_controls
    lda quit_flag
    beq wait_jiffy
    jmp exit_demo
wait_jiffy:
    lda $a2
    cmp last_jiffy
    beq main_loop
    sta last_jiffy
    lda paused
    bne main_loop
    lda music_muted
    bne skip_music
    jsr update_music
skip_music:
    inc frame_divider
    lda frame_divider
    cmp #3
    bcc main_loop
    lda #0
    sta frame_divider
    jsr update_balloons
    jsr update_confetti
    jsr animate_candles
    jmp main_loop

save_state:
    lda $d020
    sta old_border
    lda $d021
    sta old_background
    lda $d011
    sta old_d011
    lda $d016
    sta old_d016
    lda $d018
    sta old_d018
    lda $d015
    sta old_sprite_enable
    lda $d010
    sta old_sprite_msb
    lda $d017
    sta old_sprite_expand_y
    lda $d01d
    sta old_sprite_expand_x
    lda $d01b
    sta old_sprite_priority
    lda $d01c
    sta old_sprite_multicolor
    ldx #0
save_sprite_positions:
    lda $d000,x
    sta old_sprite_positions,x
    inx
    cpx #16
    bne save_sprite_positions
    ldx #0
save_sprite_colors:
    lda $d027,x
    sta old_sprite_colors,x
    inx
    cpx #8
    bne save_sprite_colors
    ldx #0
save_sprite_pointers:
    lda $07f8,x
    sta old_sprite_pointers,x
    inx
    cpx #8
    bne save_sprite_pointers
    ldx #0
save_sid:
    lda $d400,x
    sta old_sid,x
    inx
    cpx #25
    bne save_sid
    rts

initialize_demo:
    lda #0
    sta paused
    sta music_muted
    sta quit_flag
    sta frame_divider
    sta animation_phase
    sta music_tick
    sta music_index
    sta note_ticks
    sta candle_phase
    lda $a2
    sta last_jiffy
    lda #6
    sta $d020
    lda #14
    sta $d021
    lda old_d011
    and #$9f
    ora #$10
    sta $d011
    lda old_d016
    and #$e8
    ora #8
    sta $d016
    lda old_d018
    and #$f1
    ora #$14
    sta $d018
    jsr clear_screen
    jsr draw_banner
    jsr draw_cake
    jsr initialize_confetti
    jsr initialize_sprites
    jsr initialize_sid
    rts

clear_screen:
    ldx #0
clear_loop:
    lda #32
    sta SCREEN,x
    sta SCREEN+256,x
    sta SCREEN+512,x
    sta SCREEN+768,x
    lda #6
    sta COLOR,x
    sta COLOR+256,x
    sta COLOR+512,x
    sta COLOR+768,x
    inx
    bne clear_loop
    rts

draw_banner:
    lda #<banner_line_one
    sta $fb
    lda #>banner_line_one
    sta $fc
    lda #<(SCREEN+47)
    sta $fd
    lda #>(SCREEN+47)
    sta $fe
    lda #7
    sta text_color
    jsr draw_text
    lda #<banner_line_two
    sta $fb
    lda #>banner_line_two
    sta $fc
    lda #<(SCREEN+83)
    sta $fd
    lda #>(SCREEN+83)
    sta $fe
    lda #1
    sta text_color
    jsr draw_text
    rts

draw_text:
    ldy #0
draw_text_loop:
    lda ($fb),y
    beq draw_text_done
    cmp #65
    bcc store_text_char
    cmp #91
    bcs store_text_char
    sec
    sbc #64
store_text_char:
    sta ($fd),y
    lda text_color
    pha
    lda $fd
    clc
    adc #<$d400
    sta $f9
    lda $fe
    adc #>$d400
    sta $fa
    pla
    sta ($f9),y
    iny
    bne draw_text_loop
draw_text_done:
    rts

draw_cake:
    ; Plate.
    ldx #0
plate_loop:
    lda #102
    sta SCREEN+890,x
    lda #3
    sta COLOR+890,x
    inx
    cpx #20
    bne plate_loop
    ; Two cake layers.
    ldx #0
cake_loop:
    lda #160
    sta SCREEN+812,x
    sta SCREEN+852,x
    sta SCREEN+772,x
    lda #10
    sta COLOR+812,x
    sta COLOR+852,x
    lda #1
    sta COLOR+772,x
    inx
    cpx #16
    bne cake_loop
    ; Five candles and flames.
    ldx #0
candle_loop:
    lda candle_columns,x
    tay
    lda #160
    sta SCREEN+692,y
    sta SCREEN+732,y
    lda candle_colors,x
    sta COLOR+692,y
    sta COLOR+732,y
    lda #81
    sta SCREEN+652,y
    lda #7
    sta COLOR+652,y
    inx
    cpx #5
    bne candle_loop
    rts

initialize_confetti:
    ldx #0
confetti_init_loop:
    lda confetti_start_x,x
    sta confetti_x,x
    lda confetti_start_y,x
    sta confetti_y,x
    inx
    cpx #18
    bne confetti_init_loop
    jsr draw_all_confetti
    rts

draw_all_confetti:
    ldx #0
confetti_draw_loop:
    jsr draw_one_confetti
    inx
    cpx #18
    bne confetti_draw_loop
    rts

draw_one_confetti:
    lda confetti_y,x
    tay
    lda row_lo,y
    sta $fb
    lda row_hi,y
    sta $fc
    lda color_row_lo,y
    sta $fd
    lda color_row_hi,y
    sta $fe
    ldy confetti_x,x
    lda confetti_chars,x
    sta ($fb),y
    lda confetti_colors,x
    sta ($fd),y
    rts

erase_one_confetti:
    lda confetti_y,x
    tay
    lda row_lo,y
    sta $fb
    lda row_hi,y
    sta $fc
    ldy confetti_x,x
    lda #32
    sta ($fb),y
    rts

update_confetti:
    ldx #0
confetti_update_loop:
    jsr erase_one_confetti
    inc confetti_y,x
    lda confetti_y,x
    cmp #15
    bcc confetti_keep_y
    lda #3
    sta confetti_y,x
    lda confetti_x,x
    clc
    adc #11
    cmp #39
    bcc confetti_store_x
    sbc #38
confetti_store_x:
    sta confetti_x,x
confetti_keep_y:
    jsr draw_one_confetti
    inx
    cpx #18
    bne confetti_update_loop
    rts

burst_confetti:
    ldx #0
burst_loop:
    jsr erase_one_confetti
    txa
    asl
    clc
    adc animation_phase
    and #31
    clc
    adc #4
    sta confetti_x,x
    txa
    and #7
    clc
    adc #3
    sta confetti_y,x
    inx
    cpx #18
    bne burst_loop
    jsr draw_all_confetti
    rts

initialize_sprites:
    lda #$e0
    sta $07f8
    sta $07f9
    sta $07fa
    lda #$e1
    sta $07fb
    lda #$e2
    sta $07fc
    lda #$1f
    sta $d015
    lda #0
    sta $d010
    sta $d01c
    sta $d01b
    lda #$18
    sta $d017
    sta $d01d
    lda #2
    sta $d027
    lda #5
    sta $d028
    lda #13
    sta $d029
    lda #1
    sta $d02a
    lda #9
    sta $d02b
    lda #44
    sta $d000
    lda #88
    sta $d001
    lda #214
    sta $d002
    lda #70
    sta $d003
    lda #235
    sta $d004
    lda #126
    sta $d005
    lda #128
    sta $d006
    sta $d008
    lda #104
    sta $d007
    sta $d009
    rts

update_balloons:
    inc animation_phase
    lda animation_phase
    and #31
    tax
    lda balloon_wave,x
    clc
    adc #64
    sta $d001
    lda animation_phase
    clc
    adc #9
    and #31
    tax
    lda balloon_wave,x
    clc
    adc #54
    sta $d003
    lda animation_phase
    clc
    adc #18
    and #31
    tax
    lda balloon_wave,x
    clc
    adc #96
    sta $d005
    ; Beca gently nods while the tabby markings remain aligned.
    lda animation_phase
    and #15
    tax
    lda cat_bob,x
    clc
    adc #98
    sta $d007
    sta $d009
    rts

animate_candles:
    inc candle_phase
    lda candle_phase
    and #1
    beq warm_flames
    lda #8
    bne paint_flames
warm_flames:
    lda #7
paint_flames:
    ldx #0
flame_loop:
    ldy candle_columns,x
    sta COLOR+652,y
    inx
    cpx #5
    bne flame_loop
    rts

initialize_sid:
    ldx #0
sid_clear_loop:
    lda #0
    sta $d400,x
    inx
    cpx #25
    bne sid_clear_loop
    lda #$08
    sta $d405
    lda #$a8
    sta $d406
    lda #$05
    sta $d40c
    lda #$98
    sta $d40d
    lda #$02
    sta $d413
    lda #$58
    sta $d414
    lda #$21
    sta $d404
    lda #$41
    sta $d40b
    lda #$81
    sta $d412
    lda #$0f
    sta $d418
    jsr start_note
    rts

update_music:
    inc music_tick
    lda music_tick
    cmp #3
    bcc music_done
    lda #0
    sta music_tick
    inc note_ticks
    ldx music_index
    lda note_ticks
    cmp note_durations,x
    bcc music_done
    lda #0
    sta note_ticks
    inc music_index
    lda music_index
    cmp #25
    bcc start_note
    lda #0
    sta music_index
start_note:
    ldx music_index
    lda melody_lo,x
    sta $d400
    lda melody_hi,x
    sta $d401
    lda bass_lo,x
    sta $d407
    lda bass_hi,x
    sta $d408
    txa
    and #3
    bne close_drum
    lda #$28
    sta $d40e
    lda #$02
    sta $d40f
    lda #$81
    sta $d412
    rts
close_drum:
    lda #$80
    sta $d412
music_done:
    rts

read_controls:
    jsr GETIN
    bne have_key
    rts
have_key:
    cmp #81
    bne check_pause
    lda #1
    sta quit_flag
    rts
check_pause:
    cmp #32
    bne check_mute
    lda paused
    eor #1
    sta paused
    bne silence_pause
    lda music_muted
    bne controls_done
    lda #$0f
    sta $d418
    rts
silence_pause:
    lda #0
    sta $d418
    rts
check_mute:
    cmp #77
    bne check_fanfare
    lda music_muted
    eor #1
    sta music_muted
    bne silence_music
    lda paused
    bne controls_done
    lda #$0f
    sta $d418
    rts
silence_music:
    lda #0
    sta $d418
    rts
check_fanfare:
    cmp #70
    bne check_confetti
    lda #0
    sta music_index
    sta note_ticks
    sta music_tick
    jsr start_note
    rts
check_confetti:
    cmp #67
    bne controls_done
    jsr burst_confetti
controls_done:
    rts

show_splash:
    lda #147
    jsr CHROUT
    lda #<splash_text
    sta $fb
    lda #>splash_text
    sta $fc
    ldy #0
splash_loop:
    lda ($fb),y
    beq splash_wait
    jsr CHROUT
    iny
    bne splash_loop
    inc $fc
    jmp splash_loop
splash_wait:
    jsr GETIN
    cmp #32
    bne splash_wait
    rts

exit_demo:
    lda #0
    sta $d418
    ldx #0
restore_sid:
    lda old_sid,x
    sta $d400,x
    inx
    cpx #25
    bne restore_sid
    lda old_sprite_enable
    sta $d015
    lda old_sprite_msb
    sta $d010
    lda old_sprite_expand_y
    sta $d017
    lda old_sprite_expand_x
    sta $d01d
    lda old_sprite_priority
    sta $d01b
    lda old_sprite_multicolor
    sta $d01c
    ldx #0
restore_sprite_positions:
    lda old_sprite_positions,x
    sta $d000,x
    inx
    cpx #16
    bne restore_sprite_positions
    ldx #0
restore_sprite_colors:
    lda old_sprite_colors,x
    sta $d027,x
    inx
    cpx #8
    bne restore_sprite_colors
    ldx #0
restore_sprite_pointers:
    lda old_sprite_pointers,x
    sta $07f8,x
    inx
    cpx #8
    bne restore_sprite_pointers
    lda old_d011
    sta $d011
    lda old_d016
    sta $d016
    lda old_d018
    sta $d018
    lda old_border
    sta $d020
    lda old_background
    sta $d021
    lda #147
    jsr CHROUT
    rts

splash_text:
!byte 13,13,13,154
!text "        HAPPY BIRTHDAY, BECA!"
!byte 13,13,5
!text " A FIVE-CANDLE CELEBRATION FOR BECA"
!byte 13,13,13,153
!text "                CONTROLS"
!byte 13,13,158
!text " F"
!byte 5
!text " REPLAY SONG   "
!byte 158
!text "C"
!byte 5
!text " CONFETTI"
!byte 13,158
!text " SPACE"
!byte 5
!text " PAUSE   "
!byte 158
!text "M"
!byte 5
!text " MUSIC   "
!byte 158
!text "Q"
!byte 5
!text " QUIT"
!byte 13,13,13,5
!text "          HTTPS://C64.P20.DEV"
!byte 13,13,152
!text "        RELEASED 23 OCTOBER 2026"
!byte 13,13,13,158
!text "         PRESS SPACE TO START"
!byte 0

banner_line_one: !text "HAPPY 5TH BIRTHDAY, BECA!",0
banner_line_two: !text "CAKE, BALLOONS AND PURRS FOR YOU",0
text_color: !byte 0

candle_columns: !byte 1,4,7,10,13
candle_colors: !byte 2,5,7,13,3

; Happy Birthday melody: G G A G C B / G G A G D C /
; G G G5 E5 C5 B A / F5 F5 E5 C5 D5 C5.
melody_lo:
!byte $b1,$b1,$d6,$b1,$4b,$5f,$b1,$b1,$d6,$b1,$7e,$4b
!byte $b1,$b1,$4b,$9a,$4b,$5f,$d6,$e3,$e3,$9a,$4b,$7e,$4b
melody_hi:
!byte $19,$19,$1c,$19,$22,$20,$19,$19,$1c,$19,$26,$22
!byte $19,$19,$32,$2b,$22,$20,$1c,$2d,$2d,$2b,$22,$26,$22
note_durations:
!byte 2,2,4,4,4,8,2,2,4,4,4,8,2,2,4,4,4,4,8,2,2,4,4,4,10
bass_lo:
!byte $25,$25,$25,$25,$4b,$4b,$25,$25,$25,$25,$3f,$4b
!byte $25,$25,$4b,$4b,$4b,$4b,$36,$72,$72,$4b,$4b,$3f,$4b
bass_hi:
!byte $11,$11,$11,$11,$11,$11,$11,$11,$11,$11,$13,$11
!byte $11,$11,$11,$11,$11,$11,$0e,$16,$16,$11,$11,$13,$11

balloon_wave:
!byte 8,7,6,5,4,3,2,1,0,0,1,2,3,4,5,6
!byte 8,10,11,12,13,14,15,16,16,16,15,14,13,12,11,10
cat_bob: !byte 2,1,1,0,0,0,1,1,2,3,3,4,4,4,3,3

confetti_start_x: !byte 2,5,8,11,15,18,22,26,30,34,37,4,9,14,20,25,31,36
confetti_start_y: !byte 3,8,5,11,4,9,6,12,3,8,5,13,7,10,4,12,6,9
confetti_x: !fill 18,0
confetti_y: !fill 18,0
confetti_chars: !byte 42,46,43,42,46,43,42,46,43,42,46,43,42,46,43,42,46,43
confetti_colors: !byte 2,5,7,8,10,13,3,4,1,2,5,7,8,10,13,3,4,1

row_lo: !for i,0,24 { !byte <(SCREEN+i*40) }
row_hi: !for i,0,24 { !byte >(SCREEN+i*40) }
color_row_lo: !for i,0,24 { !byte <(COLOR+i*40) }
color_row_hi: !for i,0,24 { !byte >(COLOR+i*40) }

old_border: !byte 0
old_background: !byte 0
old_d011: !byte 0
old_d016: !byte 0
old_d018: !byte 0
old_sprite_enable: !byte 0
old_sprite_msb: !byte 0
old_sprite_expand_y: !byte 0
old_sprite_expand_x: !byte 0
old_sprite_priority: !byte 0
old_sprite_multicolor: !byte 0
old_sprite_positions: !fill 16,0
old_sprite_colors: !fill 8,0
old_sprite_pointers: !fill 8,0
old_sid: !fill 25,0
paused: !byte 0
music_muted: !byte 0
quit_flag: !byte 0
frame_divider: !byte 0
animation_phase: !byte 0
music_tick: !byte 0
music_index: !byte 0
note_ticks: !byte 0
candle_phase: !byte 0
last_jiffy: !byte 0

; Sprite data at $3800: balloon, white cat head and tabby markings.
* = $3800
balloon_sprite:
!byte $00,$18,$00,$00,$7e,$00,$00,$ff,$00,$01,$ff,$80,$03,$ff,$c0,$03,$ff,$c0
!byte $07,$ff,$e0,$07,$ff,$e0,$07,$ff,$e0,$03,$ff,$c0,$03,$ff,$c0,$01,$ff,$80
!byte $00,$ff,$00,$00,$7e,$00,$00,$3c,$00,$00,$18,$00,$00,$18,$00,$00,$18,$00
!byte $00,$18,$00,$00,$08,$00,$00,$00,$00,0
cat_base_sprite:
!byte $18,$00,$18,$3c,$00,$3c,$7e,$00,$7e,$ff,$00,$ff,$ff,$81,$ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
!byte $7f,$ff,$fe,$3f,$ff,$fc,$1f,$ff,$f8,$0f,$ff,$f0,$07,$ff,$e0,$03,$ff,$c0
!byte $01,$ff,$80,$00,$7e,$00,$00,$00,$00,0
cat_markings_sprite:
!byte $10,$00,$08,$30,$00,$0c,$60,$00,$06,$c0,$00,$03,$c0,$00,$03,$80,$00,$01
!byte $81,$81,$81,$03,$c3,$c0,$03,$c3,$c0,$00,$24,$00,$00,$18,$00,$00,$18,$00
!byte $00,$00,$00,$00,$42,$00,$00,$3c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,0
