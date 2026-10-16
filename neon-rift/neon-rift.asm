!cpu 6510

; NEON RIFT
; Stable extended-color bands, eight sine-orbiting sprites, a character
; scroller and a three-voice SID sequence. All touched state is restored on Q.
; Self-starting BASIC line: 10 SYS2061
* = $0801
!word basic_end
!word 10
!byte $9e
!text "2061"
!byte 0
basic_end: !word 0

* = $080d
GETIN  = $ffe4
CHROUT = $ffd2

start:
    jsr save_state
    lda #0
    sta $d020
    sta $d021
    jsr show_splash
    lda #147
    jsr CHROUT
    jsr initialize_demo

main_loop:
    lda #250
    jsr wait_raster
    jsr read_controls
    lda quit_flag
    beq continue_demo
    jmp exit
continue_demo:
    lda paused
    bne render_frame
    jsr update_motion
    lda music_muted
    bne render_frame
    jsr update_music
render_frame:
    jsr draw_raster_frame
    jmp main_loop

save_state:
    lda $d020
    sta old_border
    lda $d021
    sta old_background
    lda $d015
    sta old_sprite_enable
    lda $d016
    sta old_d016
    lda $d011
    sta old_d011
    lda $d022
    sta old_background_2
    lda $d023
    sta old_background_3
    lda $d024
    sta old_background_4
    lda $d01c
    sta old_multicolor
    lda $d025
    sta old_sprite_mc0
    lda $d026
    sta old_sprite_mc1
    lda $d010
    sta old_sprite_msb
    ldx #0
save_positions:
    lda $d000,x
    sta old_positions,x
    inx
    cpx #16
    bne save_positions
    ldx #0
save_colors:
    lda $d027,x
    sta old_sprite_colors,x
    lda $07f8,x
    sta old_sprite_pointers,x
    inx
    cpx #8
    bne save_colors
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
    sta $d020
    sta $d021
    sta $d010
    sta $d01c
    sta motion_phase
    sta motion_tick
    sta palette
    sta paused
    sta music_muted
    sta quit_flag
    sta scroll_tick
    sta scroll_position
    sta music_tick
    sta music_step
    lda #2
    sta motion_speed
    lda #7
    sta scroll_fine
    lda old_d011
    ora #$40
    sta $d011
    lda old_d016
    and #$f8
    sta $d016
    jsr copy_sprite
    jsr prepare_screen
    jsr apply_palette
    lda #$ff
    sta $d015
    lda #6
    sta $d025
    lda #14
    sta $d026
    ldx #0
sprite_setup_loop:
    lda #$c0
    sta $07f8,x
    lda sprite_colors,x
    sta $d027,x
    inx
    cpx #8
    bne sprite_setup_loop
    jsr initialize_sid
    jsr update_sprites
    rts

copy_sprite:
    ldx #0
copy_sprite_loop:
    lda orb_sprite,x
    sta $3000,x
    inx
    cpx #64
    bne copy_sprite_loop
    rts

prepare_screen:
    ldx #0
clear_pages:
    lda #32
    sta $0400,x
    sta $0500,x
    sta $0600,x
    lda #1
    sta $d800,x
    sta $d900,x
    sta $da00,x
    inx
    bne clear_pages
    ldx #0
clear_last_page:
    lda #32
    sta $0700,x
    lda #1
    sta $db00,x
    inx
    cpx #232
    bne clear_last_page
    ldx #0
paint_band_rows:
    lda band_screen_codes,x
    sta band_code
    lda row_addresses_lo,x
    sta $fb
    lda row_addresses_hi,x
    sta $fc
    ldy #0
paint_band_columns:
    lda band_code
    sta ($fb),y
    iny
    cpy #40
    bne paint_band_columns
    inx
    cpx #24
    bne paint_band_rows
    ldx #0
draw_stars:
    lda star_positions_lo,x
    sta $fb
    lda star_positions_hi,x
    sta $fc
    ldy #0
    lda star_rows,x
    tay
    lda band_screen_codes,y
    sta band_code
    txa
    and #1
    beq use_dot
    lda #42
    bne store_star
use_dot:
    lda #46
store_star:
    ora band_code
    ldy #0
    sta ($fb),y
    inx
    cpx #28
    bne draw_stars
    ldx #0
seed_scroller:
    lda #32
    sta $07c0,x
    lda #7
    sta $dbc0,x
    inx
    cpx #40
    bne seed_scroller
    rts

read_controls:
    jsr GETIN
    beq controls_done
    cmp #81
    bne control_color
    lda #1
    sta quit_flag
    rts
control_color:
    cmp #67
    bne control_mute
    inc palette
    lda palette
    and #3
    sta palette
    jsr apply_palette
    jmp controls_done
control_mute:
    cmp #77
    bne control_pause
    lda music_muted
    eor #1
    sta music_muted
    bne mute_music
    jsr initialize_sid
    jmp controls_done
mute_music:
    jsr silence_sid
    jmp controls_done
control_pause:
    cmp #32
    bne control_speed_one
    lda paused
    eor #1
    sta paused
    bne pause_sound
    lda music_muted
    bne controls_done
    jsr initialize_sid
    jmp controls_done
pause_sound:
    jsr silence_sid
    jmp controls_done
control_speed_one:
    cmp #49
    bne control_speed_two
    lda #4
    sta motion_speed
    jmp controls_done
control_speed_two:
    cmp #50
    bne control_speed_three
    lda #2
    sta motion_speed
    jmp controls_done
control_speed_three:
    cmp #51
    bne controls_done
    lda #1
    sta motion_speed
controls_done:
    rts

update_motion:
    inc motion_tick
    lda motion_tick
    cmp motion_speed
    bcc update_scroll
    lda #0
    sta motion_tick
    inc motion_phase
    lda motion_phase
    and #63
    sta motion_phase
    jsr update_sprites
update_scroll:
    inc scroll_tick
    lda scroll_tick
    cmp #4
    bcc motion_done
    lda #0
    sta scroll_tick
    jsr shift_scroller
motion_done:
    rts

update_sprites:
    ldx #0
sprite_motion_loop:
    stx object_index
    txa
    asl
    asl
    asl
    clc
    adc motion_phase
    and #63
    tax
    lda sine_x,x
    sta position_temp
    ldx object_index
    txa
    asl
    tay
    lda position_temp
    sta $d000,y
    ldx object_index
    txa
    asl
    asl
    asl
    clc
    adc motion_phase
    clc
    adc #16
    and #63
    tax
    lda sine_y,x
    sta position_temp
    ldx object_index
    txa
    asl
    tay
    iny
    lda position_temp
    sta $d000,y
    ldx object_index
    inx
    cpx #8
    bne sprite_motion_loop
    rts

shift_scroller:
    ldx #0
scroll_shift_loop:
    lda $07c1,x
    sta $07c0,x
    inx
    cpx #39
    bne scroll_shift_loop
    ldy scroll_position
    lda scroll_message,y
    bne insert_scroll_char
    ldy #0
    sty scroll_position
    lda scroll_message
insert_scroll_char:
    ; The message is stored as portable ASCII.  The VIC-II character screen
    ; uses screen codes, where uppercase A-Z are 1-26 rather than 65-90.
    ; Convert explicitly instead of relying on the assembler's active
    ; conversion table.
    cmp #65
    bcc store_scroll_char
    cmp #91
    bcs store_scroll_char
    and #$1f
store_scroll_char:
    sta $07e7
    inc scroll_position
    lda palette
    asl
    tax
    lda scroller_colors,x
    ldx #0
color_scroller:
    sta $dbc0,x
    inx
    cpx #40
    bne color_scroller
    rts

initialize_sid:
    jsr silence_sid
    lda #$08
    sta $d405
    lda #$88
    sta $d406
    lda #0
    sta $d402
    lda #8
    sta $d403
    lda #$04
    sta $d40c
    lda #$a8
    sta $d40d
    lda #$02
    sta $d413
    lda #$84
    sta $d414
    lda #$00
    sta $d417
    lda #$0f
    sta $d418
    rts

update_music:
    inc music_tick
    lda music_tick
    cmp #6
    bcc music_done
    lda #0
    sta music_tick
    ldx music_step
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    lda lead_notes,x
    tay
    lda note_lo,y
    sta $d400
    lda note_hi,y
    sta $d401
    lda #$41
    sta $d404
    lda bass_notes,x
    tay
    lda note_hi,y
    lsr
    sta $d408
    lda note_lo,y
    ror
    sta $d407
    lda #$11
    sta $d40b
    lda drum_steps,x
    beq no_drum
    lda #$35
    sta $d40e
    lda #$18
    sta $d40f
    lda #$81
    sta $d412
no_drum:
    inc music_step
    lda music_step
    and #15
    sta music_step
music_done:
    rts

silence_sid:
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    sta $d418
    rts

apply_palette:
    lda palette
    asl
    clc
    adc palette
    tax
    lda background_palettes,x
    sta $d022
    inx
    lda background_palettes,x
    sta $d023
    inx
    lda background_palettes,x
    sta $d024
    lda #0
    sta $d021
    rts

draw_raster_frame:
    ; The background is built from VIC-II extended-color character cells.
    ; No registers are changed while the frame is being drawn, so the image
    ; remains stable in browsers, recordings and the built-in pause mode.
    lda old_d011
    ora #$40
    sta $d011
    jsr apply_palette
    rts

wait_raster:
wait_raster_line:
    cmp $d012
    bne wait_raster_line
wait_raster_leave:
    cmp $d012
    beq wait_raster_leave
    rts

show_splash:
    lda #<splash_text
    sta $fb
    lda #>splash_text
    sta $fc
    ldy #0
print_splash:
    lda ($fb),y
    beq wait_for_space
    jsr CHROUT
    inc $fb
    bne print_splash
    inc $fc
    jmp print_splash
wait_for_space:
    jsr GETIN
    cmp #32
    bne wait_for_space
    rts

exit:
    jsr silence_sid
    ldx #0
restore_sid:
    lda old_sid,x
    sta $d400,x
    inx
    cpx #25
    bne restore_sid
    lda old_sprite_enable
    sta $d015
    lda old_d016
    sta $d016
    lda old_d011
    sta $d011
    lda old_background_2
    sta $d022
    lda old_background_3
    sta $d023
    lda old_background_4
    sta $d024
    lda old_multicolor
    sta $d01c
    lda old_sprite_mc0
    sta $d025
    lda old_sprite_mc1
    sta $d026
    lda old_sprite_msb
    sta $d010
    ldx #0
restore_positions:
    lda old_positions,x
    sta $d000,x
    inx
    cpx #16
    bne restore_positions
    ldx #0
restore_sprite_data:
    lda old_sprite_colors,x
    sta $d027,x
    lda old_sprite_pointers,x
    sta $07f8,x
    inx
    cpx #8
    bne restore_sprite_data
    lda old_border
    sta $d020
    lda old_background
    sta $d021
    lda #147
    jsr CHROUT
    rts

splash_text:
!byte 147,13,13,13
!byte 154
!text "              NEON RIFT"
!byte 13,13
!byte 5
!text "   NEON COLOR, SPRITES AND SID MUSIC"
!byte 13,13,13
!byte 153
!text "                CONTROLS"
!byte 13,13
!text " "
!byte 158
!text "1-3"
!byte 5
!text " SPEED  "
!byte 158
!text "C"
!byte 5
!text " COLOR  "
!byte 158
!text "M"
!byte 5
!text " MUSIC"
!byte 13
!text "        "
!byte 158
!text "SPACE"
!byte 5
!text " PAUSE  "
!byte 158
!text "Q"
!byte 5
!text " QUIT"
!byte 13,13,13
!byte 5
!text "          HTTPS://C64.P20.DEV"
!byte 13,13
!byte 152
!text "        RELEASED 16 OCTOBER 2026"
!byte 13,13,13
!byte 158
!text "         PRESS SPACE TO START"
!byte 0

; Shared 24x21 single-color sprite: a ringed neon orb.
orb_sprite:
!byte $00,$18,$00,$00,$7e,$00,$01,$ff,$80,$03,$c3,$c0
!byte $07,$81,$e0,$0f,$00,$f0,$1e,$18,$78,$1c,$3c,$38
!byte $38,$7e,$1c,$38,$ff,$1c,$79,$ff,$9e
!byte $38,$ff,$1c,$38,$7e,$1c,$1c,$3c,$38,$1e,$18,$78
!byte $0f,$00,$f0,$07,$81,$e0,$03,$c3,$c0,$01,$ff,$80
!byte $00,$7e,$00,$00,$18,$00,$00

sine_x:
!byte 136,145,154,163,172,181,189,197,204,211,217,223,228,232,235,238
!byte 239,240,239,238,235,232,228,223,217,211,204,197,189,181,172,163
!byte 154,145,136,127,118,109,101,93,86,79,73,67,62,58,55,52
!byte 51,50,51,52,55,58,62,67,73,79,86,93,101,109,118,127
sine_y:
!byte 126,132,138,144,150,156,161,166,171,175,179,182,185,187,189,190
!byte 190,190,189,187,185,182,179,175,171,166,161,156,150,144,138,132
!byte 126,120,114,108,102,96,91,86,81,77,73,70,67,65,63,62
!byte 62,62,63,65,67,70,73,77,81,86,91,96,102,108,114,120

background_palettes:
!byte 6,11,4
!byte 9,2,8
!byte 6,14,3
!byte 11,12,15
band_screen_codes:
!byte 96,96,96,160,160,160,224,224
!byte 96,96,160,160,224,224,96,96
!byte 160,160,224,224,96,96,160,160
row_addresses_lo:
!for row,0,23 { !byte <($0400+row*40) }
row_addresses_hi:
!for row,0,23 { !byte >($0400+row*40) }
sprite_colors: !byte 3,14,1,13,7,10,8,2
scroller_colors: !byte 3,14,7,10,13,1,8,2

note_lo: !byte $c4,$22,$81,$e1,$4b,$b8,$2a,$a1
note_hi: !byte $10,$13,$15,$18,$1b,$1e,$22,$26
lead_notes: !byte 0,2,4,2,5,4,2,1,0,2,4,6,5,4,2,1
bass_notes: !byte 0,0,0,0,3,3,3,3,5,5,5,5,3,3,1,1
drum_steps: !byte 1,0,0,0,1,0,1,0,1,0,0,0,1,0,1,0

scroll_message:
!text "   NEON RIFT   NEON COLOR MEETS EIGHT ORBITING SPRITES AND THREE VOICES OF SID   GREETINGS FROM C64.P20.DEV   "
!byte 0

star_positions_lo:
!byte <($0400+2*40+2),<($0400+5*40+7),<($0400+8*40+12),<($0400+11*40+17),<($0400+14*40+22),<($0400+17*40+27),<($0400+20*40+32)
!byte <($0400+3*40+37),<($0400+6*40+4),<($0400+9*40+9),<($0400+12*40+14),<($0400+15*40+19),<($0400+18*40+24),<($0400+21*40+29)
!byte <($0400+4*40+34),<($0400+7*40+6),<($0400+10*40+11),<($0400+13*40+16),<($0400+16*40+21),<($0400+19*40+26),<($0400+22*40+31)
!byte <($0400+2*40+36),<($0400+8*40+5),<($0400+14*40+15),<($0400+20*40+25),<($0400+6*40+35),<($0400+12*40+10),<($0400+18*40+30)
star_positions_hi:
!byte >($0400+2*40+2),>($0400+5*40+7),>($0400+8*40+12),>($0400+11*40+17),>($0400+14*40+22),>($0400+17*40+27),>($0400+20*40+32)
!byte >($0400+3*40+37),>($0400+6*40+4),>($0400+9*40+9),>($0400+12*40+14),>($0400+15*40+19),>($0400+18*40+24),>($0400+21*40+29)
!byte >($0400+4*40+34),>($0400+7*40+6),>($0400+10*40+11),>($0400+13*40+16),>($0400+16*40+21),>($0400+19*40+26),>($0400+22*40+31)
!byte >($0400+2*40+36),>($0400+8*40+5),>($0400+14*40+15),>($0400+20*40+25),>($0400+6*40+35),>($0400+12*40+10),>($0400+18*40+30)
star_rows: !byte 2,5,8,11,14,17,20,3,6,9,12,15,18,21,4,7,10,13,16,19,22,2,8,14,20,6,12,18
star_cols: !byte 2,7,12,17,22,27,32,37,4,9,14,19,24,29,34,6,11,16,21,26,31,36,5,15,25,35,10,30

motion_phase: !byte 0
motion_tick: !byte 0
motion_speed: !byte 0
object_index: !byte 0
position_temp: !byte 0
palette: !byte 0
palette_base: !byte 0
band_index: !byte 0
band_code: !byte 0
scroll_tick: !byte 0
scroll_fine: !byte 0
scroll_position: !byte 0
music_tick: !byte 0
music_step: !byte 0
music_muted: !byte 0
paused: !byte 0
quit_flag: !byte 0

old_border: !byte 0
old_background: !byte 0
old_sprite_enable: !byte 0
old_d016: !byte 0
old_d011: !byte 0
old_background_2: !byte 0
old_background_3: !byte 0
old_background_4: !byte 0
old_multicolor: !byte 0
old_sprite_mc0: !byte 0
old_sprite_mc1: !byte 0
old_sprite_msb: !byte 0
old_positions: !fill 16,0
old_sprite_colors: !fill 8,0
old_sprite_pointers: !fill 8,0
old_sid: !fill 25,0
