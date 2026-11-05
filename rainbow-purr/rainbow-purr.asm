!cpu 6510
; RAINBOW PURR -- an original Nyan Cat-inspired C64 pixel/sprite drawing.
; Reference/credit: Nyan Cat by Christopher Torres, https://www.nyan.cat/
; New three-voice SID music, not the Nyan Cat song, no samples or lyrics.
; Eight expanded sprites: gray head, white face glints, four pastry quarters,
; animated paws and tail. Four poses are selected in the lower border.
; Custom hires characters form a six-color rainbow and parallax starfield.
; Sprite/character changes start at raster 250; no raster IRQs or CIA changes.
; PAL/NTSC pitch tables and 50 Hz sequencing. SID silenced on exit, since its
; write-only registers cannot recover a previously playing composition.
; Memory: BASIC SYS $1000, charset $2000, poses $3000-$37ff, score/data $4000.
; Stock C64 hardware; no expansion, external artwork or machine-code loader.

* = $0801
!word basic_end,10
!byte $9e
!text "4096"
!byte 0
basic_end: !word 0
* = $1000
start:
    jsr save_state
    lda #0
    sta $d020
    sta $d021
    lda #147
    jsr $ffd2
    jsr show_splash
    jsr initialize
main:
    jsr wait_frame
    jsr controls
    lda quitting
    beq keep_running
    jmp exit
keep_running:
    lda paused
    bne main
    lda $02a6
    bne tick
    inc ntsc_divider
    lda ntsc_divider
    cmp #6
    bcc tick
    lda #0
    sta ntsc_divider
    jmp main
tick:
    jsr music_tick
    ldx speed
    lda phase
    clc
    adc phase_speed,x
    and #63
    sta phase
    jsr update_stars
    jsr rainbow
    jsr animate_cat
    jmp main

save_state:
    ldx #0
save_positions:
    lda $d000,x
    sta old_vic,x
    inx
    cpx #25
    bne save_positions
    ldx #0
save_extra:
    lda $d01b,x
    sta old_extra,x
    inx
    cpx #20
    bne save_extra
    ldx #0
save_pointers:
    lda $07f8,x
    sta old_pointers,x
    inx
    cpx #8
    bne save_pointers
    ldx #0
save_zp:
    lda $f9,x
    sta old_zp,x
    inx
    cpx #6
    bne save_zp
    lda $dd00
    sta old_bank
    lda $0286
    sta old_text_color
    rts




initialize:
    lda #0
    sta $d015
    sta paused
    sta muted
    sta quitting
    sta phase
    sta sky
    sta star_timer
    sta star_offset
    sta star_offset_slow
    sta song_step
    sta unit_tick
    sta ntsc_divider
    lda #1
    sta trail
    sta speed
    lda #4
    sta base_frames
    sta frames_per_unit
    lda old_bank
    ora #3
    sta $dd00
    lda #$1b
    sta $d011
    lda #8
    sta $d016
    lda #$18
    sta $d018
    lda #6
    sta $d021
    ldx #0
clear_screen:
    lda #0
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    lda #1
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne clear_screen
    ldx #31
init_stars:
    lda star_x,x
    sta star_current,x
    dex
    bpl init_stars
    ldx #95
copy_frequencies:
    lda $02a6
    beq ntsc
    lda pal_lo,x
    sta freq_lo,x
    lda pal_hi,x
    sta freq_hi,x
    jmp next_frequency
ntsc:
    lda ntsc_lo,x
    sta freq_lo,x
    lda ntsc_hi,x
    sta freq_hi,x
next_frequency:
    dex
    bpl copy_frequencies
    lda #0
    sta $d010
    sta $d01b
    sta $d025
    lda #10
    sta $d026
    lda #$ff
    sta $d017
    sta $d01d
    lda #$fe
    sta $d01c
    ldx #7
sprite_colors:
    lda cat_colors,x
    sta $d027,x
    dex
    bpl sprite_colors
    jsr initialize_sid
    jsr sequence_step
    jsr update_stars
    jsr rainbow
    jsr animate_cat
    lda #$ff
    sta $d015
    rts

wait_frame:
    lda #250
wait_line:
    cmp $d012
    bne wait_line
leave_line:
    cmp $d012
    beq leave_line
    rts

update_stars:
    inc star_timer
    ldx speed
    lda star_timer
    cmp star_intervals,x
    bcc paint_stars
    lda #0
    sta star_timer
    inc star_offset
    lda star_offset
    cmp #40
    bcc star_wrap_done
    lda #0
    sta star_offset
star_wrap_done:
    and #1
    bne paint_stars
    inc star_offset_slow
    lda star_offset_slow
    cmp #40
    bcc paint_stars
    lda #0
    sta star_offset_slow
paint_stars:
    ldx #31
erase_star:
    lda star_y,x
    tay
    lda row_lo,y
    sta $fb
    lda row_hi,y
    sta $fc
    lda star_current,x
    tay
    lda #0
    sta ($fb),y
    dex
    bpl erase_star
    ldx #31
draw_star:
    txa
    and #1
    beq slow_star
    lda star_offset
    jmp star_motion
slow_star:
    lda star_offset_slow
star_motion:
    sta move_offset
    lda star_x,x
    sec
    sbc move_offset
    bcs star_positive
    clc
    adc #40
star_positive:
    sta star_current,x
    lda star_y,x
    tay
    lda row_lo,y
    sta $fb
    sta $fd
    lda row_hi,y
    sta $fc
    clc
    adc #$d4
    sta $fe
    lda star_current,x
    tay
    txa
    clc
    adc phase
    and #3
    clc
    adc #2
    sta ($fb),y
    lda #1
    sta ($fd),y
    dex
    bpl draw_star
    rts

rainbow:
    lda #0
    ldx #18
erase_rainbow:
!for row,8,15 {
    sta $0400+row*40,x
}
    dex
    bpl erase_rainbow
    lda trail
    bne paint_rainbow
    rts
paint_rainbow:
    ldx #0
rainbow_column:
    stx work_col
    txa
    asl
    clc
    adc work_col
    clc
    adc phase
    and #63
    tay
    lda rainbow_wave,y
    cmp #8
    beq wave_8
    cmp #9
    beq wave_9
    jmp wave_10
wave_8:
    lda #1
    sta $540,x
    sta $568,x
    sta $590,x
    sta $5b8,x
    sta $5e0,x
    sta $608,x
    lda #2
    sta $d940,x
    lda #8
    sta $d968,x
    lda #7
    sta $d990,x
    lda #5
    sta $d9b8,x
    lda #14
    sta $d9e0,x
    lda #4
    sta $da08,x
    jmp rainbow_next
wave_9:
    lda #1
    sta $568,x
    sta $590,x
    sta $5b8,x
    sta $5e0,x
    sta $608,x
    sta $630,x
    lda #2
    sta $d968,x
    lda #8
    sta $d990,x
    lda #7
    sta $d9b8,x
    lda #5
    sta $d9e0,x
    lda #14
    sta $da08,x
    lda #4
    sta $da30,x
    jmp rainbow_next
wave_10:
    lda #1
    sta $590,x
    sta $5b8,x
    sta $5e0,x
    sta $608,x
    sta $630,x
    sta $658,x
    lda #2
    sta $d990,x
    lda #8
    sta $d9b8,x
    lda #7
    sta $d9e0,x
    lda #5
    sta $da08,x
    lda #14
    sta $da30,x
    lda #4
    sta $da58,x
    jmp rainbow_next
rainbow_next:
    ldx work_col
    inx
    cpx #19
    beq rainbow_done
    jmp rainbow_column
rainbow_done:
    rts

animate_cat:
    ldx phase
    lda cat_bob,x
    clc
    adc #116
    sta cat_y
    lda cat_sway,x
    clc
    adc #158
    sta cat_x
    lda phase
    lsr
    lsr
    lsr
    and #3
    asl
    asl
    asl
    clc
    adc #$c0
    sta cat_pointer
    ldx #0
cat_piece:
    lda cat_pointer
    sta $07f8,x
    inc cat_pointer
    txa
    asl
    tay
    lda cat_x
    clc
    adc cat_dx,x
    sta $d000,y
    lda cat_y
    clc
    adc cat_dy,x
    sta $d001,y
    inx
    cpx #8
    bne cat_piece
    rts

music_tick:
    inc unit_tick
    lda unit_tick
    cmp frames_per_unit
    bcc instrument_tick
    lda #0
    sta unit_tick
    inc song_step
    jsr sequence_step
instrument_tick:
    lda muted
    bne tick_done
    ; Release the lead just before a new note, but sustain across tied steps.
    lda frames_per_unit
    sec
    sbc #1
    cmp unit_tick
    bne drum_envelope
    ldx song_step
    inx
    lda melody,x
    beq drum_envelope
    lda #$40
    sta $d404
drum_envelope:
    lda frames_per_unit
    sec
    sbc #1
    cmp unit_tick
    bne drum_release
    lda song_step
    and #1
    beq drum_release
    lda #$40
    sta $d40b
drum_release:
    lda unit_tick
    cmp #2
    bne pulse_motion
    lda drum_release_control
    sta $d412
pulse_motion:
    lda drum_release_control
    cmp #$10
    bne lead_motion
    lda unit_tick
    cmp #1
    bne lead_motion
    lda #6
    sta $d40f
lead_motion:
    lda unit_tick
    asl
    asl
    clc
    adc #$40
    sta $d402
tick_done:
    rts

sequence_step:
    ; Original C-major sparkle theme; alternating four/five 50 Hz ticks.
    lda song_step
    and #1
    clc
    adc base_frames
    sta frames_per_unit
    lda muted
    beq audible_step
    jmp sequence_done
audible_step:
    ldx song_step
    lda melody,x
    beq accompaniment
    cmp #255
    bne lead_note
    lda #$40
    sta $d404
    jmp accompaniment
lead_note:
    tax
    lda freq_lo,x
    sta $d400
    lda freq_hi,x
    sta $d401
    lda #$41
    sta $d404
accompaniment:
    lda song_step
    and #1
    bne sequence_done
    ; Syncopated pulse bass, with a separate kick/snare/hi-hat voice.
    ldx song_step
    lda bass_notes,x
    tax
    lda freq_lo,x
    sta $d407
    lda freq_hi,x
    sta $d408
    lda #$41
    sta $d40b
    lda song_step
    and #3
    beq strong_drum
    ; Closed hi-hat on the off-beat.
    lda #$30
    sta $d40e
    lda #$38
    sta $d40f
    lda #$01
    sta $d413
    lda #$81
    bne play_drum
strong_drum:
    lda song_step
    and #7
    beq kick_drum
    lda #$40
    sta $d40e
    lda #$10
    sta $d40f
    lda #$04
    sta $d413
    lda #$81
    bne play_drum
kick_drum:
    lda #0
    sta $d40e
    lda #$0c
    sta $d40f
    lda #$02
    sta $d413
    lda #$11
play_drum:
    sta $d412
    and #$fe
    sta drum_release_control
sequence_done:
    rts

initialize_sid:
    ldx #24
clear_sid:
    lda #0
    sta $d400,x
    dex
    bpl clear_sid
    lda #$08
    sta $d405
    lda #$89
    sta $d406
    lda #$40
    sta $d402
    lda #$08
    sta $d403
    lda #$09
    sta $d40c
    lda #$48
    sta $d40d
    lda #$08
    sta $d40a
    lda #$08
    sta $d414
    lda #15
    sta $d418
    rts



controls:
    jsr $ffe4
    cmp #81
    bne check_pause
    lda #1
    sta quitting
    rts
check_pause:
    cmp #32
    bne check_mute
    lda paused
    eor #1
    sta paused
    bne quiet
    lda muted
    beq resume_sound
    rts
resume_sound:
    lda #15
    sta $d418
    rts
check_mute:
    cmp #77
    bne check_sky
    lda muted
    eor #1
    sta muted
    bne quiet
    lda paused
    bne quiet
    jsr initialize_sid
    jsr sequence_step
    rts
quiet:
    lda #0
    sta $d418
    rts
check_sky:
    cmp #67
    bne check_trail
    inc sky
    lda sky
    cmp #3
    bcc sky_ready
    lda #0
    sta sky
sky_ready:
    tax
    lda sky_colors,x
    sta $d021
    rts
check_trail:
    cmp #84
    bne check_speed
    lda trail
    eor #1
    sta trail
    rts
check_speed:
    cmp #49
    bcc controls_done
    cmp #52
    bcs controls_done
    sec
    sbc #49
    sta speed
controls_done:
    rts

silence_sid:
    ldx #24
    lda #0
silence_loop:
    sta $d400,x
    dex
    bpl silence_loop
    rts

show_splash:
    lda #<splash
    sta $fb
    lda #>splash
    sta $fc
print_splash:
    ldy #0
    lda ($fb),y
    beq wait_space
    jsr $ffd2
    inc $fb
    bne print_splash
    inc $fc
    jmp print_splash
wait_space:
    jsr $ffe4
    cmp #32
    bne wait_space
    rts

exit:
    lda #0
    sta $d015
    sta $d418
    jsr silence_sid
    ldx #0
restore_pointers:
    lda old_pointers,x
    sta $07f8,x
    inx
    cpx #8
    bne restore_pointers
    ldx #0
restore_extra:
    lda old_extra,x
    sta $d01b,x
    inx
    cpx #20
    bne restore_extra
    ldx #0
restore_vic:
    lda old_vic,x
    sta $d000,x
    inx
    cpx #25
    bne restore_vic
    lda old_bank
    sta $dd00
    lda old_text_color
    sta $0286
    lda #147
    jsr $ffd2
    ldx #0
restore_zp:
    lda old_zp,x
    sta $f9,x
    inx
    cpx #6
    bne restore_zp
    rts




old_vic: !fill 25,0
old_extra: !fill 20,0
old_pointers: !fill 8,0
old_zp: !fill 6,0
old_bank: !byte 0
old_text_color: !byte 0
paused: !byte 0
muted: !byte 0
quitting: !byte 0
phase: !byte 0
sky: !byte 0
trail: !byte 1
speed: !byte 1
star_timer: !byte 0
star_offset: !byte 0
star_offset_slow: !byte 0
move_offset: !byte 0
work_col: !byte 0
cat_x: !byte 158
cat_y: !byte 116
cat_pointer: !byte $c0
unit_tick: !byte 0
song_step: !byte 0
ntsc_divider: !byte 0
frames_per_unit: !byte 4
base_frames: !byte 4
drum_release_control: !byte $80
freq_lo: !fill 96,0
freq_hi: !fill 96,0
star_current: !fill 32,0
phase_speed: !byte 1,2,3
star_intervals: !byte 8,4,2
sky_colors: !byte 6,0,4
cat_colors: !byte 1,15,8,8,8,8,15,15
cat_dx: !byte 80,80,0,48,0,48,8,220
cat_dy: !byte 30,30,0,0,42,42,72,28

splash:
!byte 13,13,13,154
!text "              RAINBOW PURR"
!byte 13,13,5
!text "   ONE PASTRY CAT. SIX RAINBOW COLORS."
!byte 13
!text "     AN ORIGINAL THREE-VOICE SID SCORE."
!byte 13,13,13,153
!text "                CONTROLS"
!byte 13,13,158
!text " 1-3"
!byte 5
!text " FLIGHT SPEED  "
!byte 158
!text "C"
!byte 5
!text " SKY COLORS"
!byte 13,158
!text " T"
!byte 5
!text " RAINBOW  "
!byte 158
!text "M"
!byte 5
!text " MUSIC"
!byte 13,158
!text " SPACE"
!byte 5
!text " PAUSE  "
!byte 158
!text "Q"
!byte 5
!text " QUIT"
!byte 13,13,13,5
!text "          HTTPS://C64.P20.DEV"
!byte 13,13,152
!text "        RELEASED 5 NOVEMBER 2026"
!byte 13,13,13,158
!text "         PRESS SPACE TO START"
!byte 0
!if * > $2000 { !error "Code overlaps charset" }

* = $2000
; Original character pixels, not PETSCII glyphs.
!byte 0,0,0,0,0,0,0,0,255,255,255,255,255,255,255,255
!byte 0,0,0,16,0,0,0,0,0,0,16,56,16,0,0,0
!byte 0,16,16,124,16,16,0,0,0,0,40,16,40,0,0,0
!fill 2048-48,0
* = $3000
; Four original eight-sprite poses: eye glints, head, pastry, paws, tail.
; Multicolor codes: 01 shared black, 10 individual color, 11 shared pink.
; Pose 0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,2,0,128,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,16,0,4,20,0,20,25,0,100,26,65,164,26
!byte 65,164,26,65,164,26,150,164,26,170,164,25,106,84,25,106
!byte 84,25,106,84,26,170,164,31,166,188,31,170,188,26,106,100
!byte 26,85,100,26,170,164,22,170,148,1,85,64,0,0,0,0
!byte 5,85,85,6,170,170,106,170,170,106,170,170,111,239,251,111
!byte 255,255,111,255,255,111,127,255,111,255,255,111,255,255,111,255
!byte 255,111,255,255,111,255,223,111,255,255,111,253,255,111,127,255
!byte 111,255,255,111,255,255,111,255,253,111,255,255,111,255,223,0
!byte 85,85,80,170,170,144,170,170,169,170,170,169,254,255,185,255
!byte 255,249,255,255,249,255,255,249,255,255,249,255,247,249,253,255
!byte 249,127,255,249,255,255,249,255,255,249,255,255,249,255,255,249
!byte 255,223,249,247,255,249,255,255,249,255,255,249,255,255,249,0
!byte 111,247,255,111,255,255,111,255,255,111,255,255,111,255,255,111
!byte 255,253,111,255,127,111,223,255,111,255,255,111,255,255,111,255
!byte 255,111,255,255,111,255,247,111,253,255,111,255,255,111,255,255
!byte 111,254,255,106,170,170,106,170,170,10,170,170,5,85,85,0
!byte 255,255,249,255,253,249,255,127,249,255,255,249,255,255,249,255
!byte 255,249,255,255,249,255,255,249,255,247,249,255,255,249,255,127
!byte 249,223,255,249,255,255,249,255,255,249,255,255,249,255,255,249
!byte 251,255,233,170,170,169,170,170,169,170,170,160,85,85,80,0
!byte 0,0,0,0,0,0,21,64,0,26,64,0,26,64,0,26
!byte 65,84,26,65,164,26,65,164,26,65,164,26,65,164,26,65
!byte 164,21,65,164,21,65,164,0,1,164,0,1,84,0,1,84
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,21,0,0,25,0,0,25,0,0,25,0
!byte 0,25,85,84,26,170,164,22,170,164,22,170,164,1,85,84
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
; Pose 1
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,2,0,128,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,16,0,4,20,0,20,25,0,100,26,65,164,26
!byte 65,164,26,65,164,26,150,164,26,170,164,25,106,84,25,106
!byte 84,25,106,84,26,170,164,31,166,188,31,170,188,26,106,100
!byte 26,85,100,26,170,164,22,170,148,1,85,64,0,0,0,0
!byte 5,85,85,6,170,170,106,170,170,106,170,170,111,239,251,111
!byte 255,255,111,255,255,111,127,255,111,255,255,111,255,255,111,255
!byte 255,111,255,255,111,255,223,111,255,255,111,253,255,111,127,255
!byte 111,255,255,111,255,255,111,255,253,111,255,255,111,255,223,0
!byte 85,85,80,170,170,144,170,170,169,170,170,169,254,255,185,255
!byte 255,249,255,255,249,255,255,249,255,255,249,255,247,249,253,255
!byte 249,127,255,249,255,255,249,255,255,249,255,255,249,255,255,249
!byte 255,223,249,247,255,249,255,255,249,255,255,249,255,255,249,0
!byte 111,247,255,111,255,255,111,255,255,111,255,255,111,255,255,111
!byte 255,253,111,255,127,111,223,255,111,255,255,111,255,255,111,255
!byte 255,111,255,255,111,255,247,111,253,255,111,255,255,111,255,255
!byte 111,254,255,106,170,170,106,170,170,10,170,170,5,85,85,0
!byte 255,255,249,255,253,249,255,127,249,255,255,249,255,255,249,255
!byte 255,249,255,255,249,255,255,249,255,247,249,255,255,249,255,127
!byte 249,223,255,249,255,255,249,255,255,249,255,255,249,255,255,249
!byte 251,255,233,170,170,169,170,170,169,170,170,160,85,85,80,0
!byte 0,0,0,0,0,0,0,1,84,0,1,164,0,1,164,21
!byte 65,164,26,65,164,26,65,164,26,65,164,26,65,164,26,65
!byte 164,26,65,84,26,65,84,26,64,0,21,64,0,21,64,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,21,0,0,25,0
!byte 0,25,0,0,25,0,0,25,85,84,26,170,164,22,170,164
!byte 22,170,164,1,85,84,0,0,0,0,0,0,0,0,0,0
; Pose 2
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,2,0,128,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,16,0,4,20,0,20,25,0,100,26,65,164,26
!byte 65,164,26,65,164,26,150,164,26,170,164,25,106,84,25,106
!byte 84,25,106,84,26,170,164,31,166,188,31,170,188,26,106,100
!byte 26,85,100,26,170,164,22,170,148,1,85,64,0,0,0,0
!byte 5,85,85,6,170,170,106,170,170,106,170,170,111,239,251,111
!byte 255,255,111,255,255,111,127,255,111,255,255,111,255,255,111,255
!byte 255,111,255,255,111,255,223,111,255,255,111,253,255,111,127,255
!byte 111,255,255,111,255,255,111,255,253,111,255,255,111,255,223,0
!byte 85,85,80,170,170,144,170,170,169,170,170,169,254,255,185,255
!byte 255,249,255,255,249,255,255,249,255,255,249,255,247,249,253,255
!byte 249,127,255,249,255,255,249,255,255,249,255,255,249,255,255,249
!byte 255,223,249,247,255,249,255,255,249,255,255,249,255,255,249,0
!byte 111,247,255,111,255,255,111,255,255,111,255,255,111,255,255,111
!byte 255,253,111,255,127,111,223,255,111,255,255,111,255,255,111,255
!byte 255,111,255,255,111,255,247,111,253,255,111,255,255,111,255,255
!byte 111,254,255,106,170,170,106,170,170,10,170,170,5,85,85,0
!byte 255,255,249,255,253,249,255,127,249,255,255,249,255,255,249,255
!byte 255,249,255,255,249,255,255,249,255,247,249,255,255,249,255,127
!byte 249,223,255,249,255,255,249,255,255,249,255,255,249,255,255,249
!byte 251,255,233,170,170,169,170,170,169,170,170,160,85,85,80,0
!byte 0,0,0,0,0,0,21,64,0,26,64,0,26,64,0,26
!byte 65,84,26,65,164,26,65,164,26,65,164,26,65,164,26,65
!byte 164,21,65,164,21,65,164,0,1,164,0,1,84,0,1,84
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,21,0,0,25,0,0,25,0
!byte 0,25,0,0,25,85,84,26,170,164,22,170,164,22,170,164
!byte 1,85,84,0,0,0,0,0,0,0,0,0,0,0,0,0
; Pose 3
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,2,0,128,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,16,0,4,20,0,20,25,0,100,26,65,164,26
!byte 65,164,26,65,164,26,150,164,26,170,164,25,106,84,25,106
!byte 84,25,106,84,26,170,164,31,166,188,31,170,188,26,106,100
!byte 26,85,100,26,170,164,22,170,148,1,85,64,0,0,0,0
!byte 5,85,85,6,170,170,106,170,170,106,170,170,111,239,251,111
!byte 255,255,111,255,255,111,127,255,111,255,255,111,255,255,111,255
!byte 255,111,255,255,111,255,223,111,255,255,111,253,255,111,127,255
!byte 111,255,255,111,255,255,111,255,253,111,255,255,111,255,223,0
!byte 85,85,80,170,170,144,170,170,169,170,170,169,254,255,185,255
!byte 255,249,255,255,249,255,255,249,255,255,249,255,247,249,253,255
!byte 249,127,255,249,255,255,249,255,255,249,255,255,249,255,255,249
!byte 255,223,249,247,255,249,255,255,249,255,255,249,255,255,249,0
!byte 111,247,255,111,255,255,111,255,255,111,255,255,111,255,255,111
!byte 255,253,111,255,127,111,223,255,111,255,255,111,255,255,111,255
!byte 255,111,255,255,111,255,247,111,253,255,111,255,255,111,255,255
!byte 111,254,255,106,170,170,106,170,170,10,170,170,5,85,85,0
!byte 255,255,249,255,253,249,255,127,249,255,255,249,255,255,249,255
!byte 255,249,255,255,249,255,255,249,255,247,249,255,255,249,255,127
!byte 249,223,255,249,255,255,249,255,255,249,255,255,249,255,255,249
!byte 251,255,233,170,170,169,170,170,169,170,170,160,85,85,80,0
!byte 0,0,0,0,0,0,0,1,84,0,1,164,0,1,164,21
!byte 65,164,26,65,164,26,65,164,26,65,164,26,65,164,26,65
!byte 164,26,65,84,26,65,84,26,64,0,21,64,0,21,64,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,21,0,0,25,0,0,25,0,0,25,0,0,25,85
!byte 84,26,170,164,22,170,164,22,170,164,1,85,84,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!if * != $3800 { !error "Unexpected sprite data size" }
* = $4000
; Original Cmaj7/Am7/Fmaj7/G7 sparkle tune, pulse lead and bass, SID drums.
melody:
!byte 72,79,76,79,83,0,72,76,79,76,83,79,72,79,76,83
!byte 69,76,72,76,79,0,69,72,76,72,79,76,69,76,72,255
!byte 77,84,81,84,88,0,77,81,84,81,88,84,77,84,81,88
!byte 79,86,83,86,89,0,79,83,86,83,89,86,79,86,83,255
!byte 72,79,76,79,83,0,72,76,79,76,83,79,72,79,76,83
!byte 69,76,72,76,79,0,69,72,76,72,79,76,69,76,72,255
!byte 77,84,81,84,88,0,77,81,84,81,88,84,77,84,81,88
!byte 79,86,83,86,89,0,79,83,86,83,89,86,79,86,83,255
!byte 83,79,76,83,79,0,76,79,76,83,79,76,72,76,79,83
!byte 79,76,72,79,76,0,72,76,72,79,76,72,69,72,76,255
!byte 88,84,81,88,84,0,81,84,81,88,84,81,77,81,84,88
!byte 89,86,83,89,86,0,83,86,83,89,86,83,79,83,86,255
!byte 83,79,76,83,79,0,76,79,76,83,79,76,72,76,79,83
!byte 79,76,72,79,76,0,72,76,72,79,76,72,69,72,76,255
!byte 88,84,81,88,84,0,81,84,81,88,84,81,77,81,84,88
!byte 89,86,83,89,86,0,83,86,83,89,86,83,79,83,86,255
bass_notes:
!byte 36,36,36,36,36,36,48,36,36,36,36,36,36,36,48,36
!byte 33,33,33,33,33,33,45,33,33,33,33,33,33,33,45,33
!byte 41,41,41,41,41,41,53,41,41,41,41,41,41,41,53,41
!byte 43,43,43,43,43,43,55,43,43,43,43,43,43,43,55,43
!byte 36,36,36,36,36,36,48,36,36,36,36,36,36,36,48,36
!byte 33,33,33,33,33,33,45,33,33,33,33,33,33,33,45,33
!byte 41,41,41,41,41,41,53,41,41,41,41,41,41,41,53,41
!byte 43,43,43,43,43,43,55,43,43,43,43,43,43,43,55,43
!byte 36,36,36,36,36,36,48,36,36,36,36,36,36,36,48,36
!byte 33,33,33,33,33,33,45,33,33,33,33,33,33,33,45,33
!byte 41,41,41,41,41,41,53,41,41,41,41,41,41,41,53,41
!byte 43,43,43,43,43,43,55,43,43,43,43,43,43,43,55,43
!byte 36,36,36,36,36,36,48,36,36,36,36,36,36,36,48,36
!byte 33,33,33,33,33,33,45,33,33,33,33,33,33,33,45,33
!byte 41,41,41,41,41,41,53,41,41,41,41,41,41,41,53,41
!byte 43,43,43,43,43,43,55,43,43,43,43,43,43,43,55,43
pal_lo:
!byte 139,147,156,166,175,186,197,209,221,234,248,7,22,39,57,75
!byte 95,116,138,161,186,212,240,14,45,78,113,150,190,231,20,66
!byte 116,169,224,27,90,156,226,45,123,207,39,133,232,81,193,55
!byte 180,56,196,89,247,157,78,10,208,162,129,109,103,112,137,178
!byte 237,59,156,19,160,69,2,218,206,224,17,100,218,118,57,38
!byte 64,137,4,180,156,192,35,200,180,235,114,76,128,18,8,104
pal_hi:
!byte 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1
!byte 1,1,1,1,1,1,1,2,2,2,2,2,2,2,3,3
!byte 3,3,3,4,4,4,4,5,5,5,6,6,6,7,7,8
!byte 8,9,9,10,10,11,12,13,13,14,15,16,17,18,19,20
!byte 21,23,24,26,27,29,31,32,34,36,39,41,43,46,49,52
!byte 55,58,62,65,69,73,78,82,87,92,98,104,110,117,124,131
ntsc_lo:
!byte 134,142,151,159,169,179,190,201,213,226,239,253,12,28,45,63
!byte 82,102,123,146,170,195,222,250,24,56,90,126,164,204,247,36
!byte 84,134,188,245,49,113,180,252,72,152,237,72,167,12,120,233
!byte 98,226,105,248,144,48,219,143,78,25,240,211,196,195,209,240
!byte 31,97,182,30,157,50,223,166,136,134,163,224,63,194,107,61
!byte 58,100,190,76,15,12,70,191,125,132,214,122,115,200,125,151
ntsc_hi:
!byte 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1
!byte 1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,3
!byte 3,3,3,3,4,4,4,4,5,5,5,6,6,7,7,7
!byte 8,8,9,9,10,11,11,12,13,14,14,15,16,17,18,19
!byte 21,22,23,25,26,28,29,31,33,35,37,39,42,44,47,50
!byte 53,56,59,63,67,71,75,79,84,89,94,100,106,112,119,126
row_lo:
!byte 0,40,80,120,160,200,240,24,64,104,144,184,224,8,48,88
!byte 128,168,208,248,32,72,112,152,192
row_hi:
!byte 4,4,4,4,4,4,4,5,5,5,5,5,5,6,6,6
!byte 6,6,6,6,7,7,7,7,7
star_x:
!byte 22,31,14,7,33,21,39,30,34,5,7,33,30,13,4,21
!byte 6,23,8,16,13,24,17,8,30,11,3,10,19,35,12,12
star_y:
!byte 7,20,0,19,6,19,6,24,3,24,7,23,3,19,2,18
!byte 4,18,1,17,4,22,2,24,2,21,6,20,2,22,5,17
cat_bob:
!byte 0,0,1,1,1,1,2,2,2,2,2,3,3,3,3,3
!byte 3,3,3,3,3,3,2,2,2,2,2,1,1,1,1,0
!byte 0,0,255,255,255,255,254,254,254,254,254,253,253,253,253,253
!byte 253,253,253,253,253,253,254,254,254,254,254,255,255,255,255,0
cat_sway:
!byte 3,3,3,3,3,3,2,2,2,2,2,1,1,1,1,0
!byte 0,0,255,255,255,255,254,254,254,254,254,253,253,253,253,253
!byte 253,253,253,253,253,253,254,254,254,254,254,255,255,255,255,0
!byte 0,0,1,1,1,1,2,2,2,2,2,3,3,3,3,3
rainbow_wave:
!byte 9,9,9,9,9,10,10,10,10,10,10,10,10,10,10,10
!byte 10,10,10,10,10,10,10,10,10,10,10,10,9,9,9,9
!byte 9,9,9,9,9,8,8,8,8,8,8,8,8,8,8,8
!byte 8,8,8,8,8,8,8,8,8,8,8,8,9,9,9,9

