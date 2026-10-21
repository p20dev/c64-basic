!cpu 6510

; INFINITE ROAD
; Double-buffered pseudo-3D highway, custom character set and three-voice SID.
; Self-starting BASIC line: 10 SYS4096
* = $0801
!word basic_end
!word 10
!byte $9e
!text "4096"
!byte 0
basic_end: !word 0

* = $1000
GETIN  = $ffe4
CHROUT = $ffd2

start:
    jsr save_state
    lda #0
    sta $d020
    sta $d021
    jsr show_splash
    jsr initialize_demo
    lda #250
    jsr wait_raster

main_loop:
    jsr read_controls
    lda quit_flag
    beq keep_running
    jmp exit_demo
keep_running:
    lda paused
    bne paused_frame
    jsr update_scene
    lda music_muted
    bne skip_music
    jsr update_music
skip_music:
    jsr render_back_buffer
    lda #250
    jsr wait_raster
    jsr flip_buffers
    jmp main_loop
paused_frame:
    lda #250
    jsr wait_raster
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
    lda $dd00
    sta old_dd00
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
    lda $d000
    sta old_sprite_x
    lda $d001
    sta old_sprite_y
    lda $d027
    sta old_sprite_color
    lda $07f8
    sta old_sprite_pointer
    ldx #0
save_sid_loop:
    lda $d400,x
    sta old_sid,x
    inx
    cpx #25
    bne save_sid_loop
    rts

initialize_demo:
    lda #0
    sta $d020
    sta $d021
    sta curve_phase
    sta road_phase
    sta music_tick
    sta music_step
    sta paused
    sta music_muted
    sta quit_flag
    sta front_buffer
    lda #6
    sta view_index
    lda #2
    sta road_speed
    lda #0
    sta palette
    lda old_dd00
    ora #3
    sta $dd00
    lda old_d011
    and #$9f
    ora #$10
    sta $d011
    lda old_d016
    and #$e8
    ora #8
    sta $d016
    lda #136
    sta $d000
    lda #76
    sta $d001
    lda $d010
    and #$fe
    sta $d010
    lda $d017
    ora #1
    sta $d017
    lda $d01d
    ora #1
    sta $d01d
    lda $d01b
    ora #1
    sta $d01b
    lda #$e0
    sta $07f8
    sta $0ff8
    lda #1
    sta $d015
    lda #$1c
    sta $d018
    jsr prepare_buffers
    jsr apply_palette
    jsr initialize_sid
    rts

prepare_buffers:
    lda #$04
    sta screen_base_hi
    jsr clear_buffer
    jsr draw_sky
    lda #$0c
    sta screen_base_hi
    jsr clear_buffer
    jsr draw_sky
    lda #$0c
    sta screen_base_hi
    jsr render_road
    lda #$04
    sta screen_base_hi
    jsr render_road
    lda #$0c
    sta screen_base_hi
    rts

clear_buffer:
    lda #0
    sta $fb
    lda screen_base_hi
    sta $fc
    ldx #3
    ldy #0
clear_full_pages:
    lda #0
    sta ($fb),y
    iny
    bne clear_full_pages
    inc $fc
    dex
    bne clear_full_pages
    ldy #0
clear_tail:
    lda #0
    sta ($fb),y
    iny
    cpy #232
    bne clear_tail
    rts

draw_sky:
    ; Stars, a striped sun and a jagged horizon are identical in both buffers.
    ldx #0
sky_star_loop:
    lda star_rows,x
    tay
    lda row_lo,y
    sta $fb
    lda row_hi,y
    clc
    adc screen_base_hi
    sta $fc
    ldy star_columns,x
    lda #5
    sta ($fb),y
    inx
    cpx #22
    bne sky_star_loop
    ldy #9
    lda row_lo,y
    sta $fb
    lda row_hi,y
    clc
    adc screen_base_hi
    sta $fc
    ldx #0
mountain_loop:
    lda mountain_chars,x
    ldy mountain_columns,x
    sta ($fb),y
    inx
    cpx #40
    bne mountain_loop
    rts

render_back_buffer:
    lda front_buffer
    beq render_to_second
    lda #$04
    bne set_render_base
render_to_second:
    lda #$0c
set_render_base:
    sta screen_base_hi
    jmp render_road

render_road:
    ldx #0
road_row_loop:
    stx row_index
    txa
    clc
    adc #10
    tay
    lda row_lo,y
    sta $fb
    lda row_hi,y
    clc
    adc screen_base_hi
    sta $fc
    ldy #0
clear_road_row:
    lda #0
    sta ($fb),y
    iny
    cpy #40
    bne clear_road_row

    ldx row_index
    lda curve_offsets,x
    clc
    adc curve_phase
    and #63
    tay
    lda curve_centers,y
    clc
    adc view_index
    sec
    sbc #6
    cmp #8
    bcs center_not_low
    lda #8
center_not_low:
    cmp #32
    bcc center_ready
    lda #31
center_ready:
    sta road_center
    ldx row_index
    sec
    sbc road_half_width,x
    bcs left_ready
    lda #0
left_ready:
    sta road_left
    lda road_center
    clc
    adc road_half_width,x
    cmp #40
    bcc right_ready
    lda #39
right_ready:
    sta road_right

    ldy road_left
    lda #2
    sta ($fb),y
    iny
fill_road_loop:
    cpy road_right
    bcs place_right_edge
    lda row_index
    clc
    adc road_phase
    and #3
    bne road_surface
    tya
    sec
    sbc road_center
    beq center_dash
road_surface:
    lda row_index
    and #1
    clc
    adc #6
    bne store_road_char
center_dash:
    lda #4
store_road_char:
    sta ($fb),y
    iny
    bne fill_road_loop
place_right_edge:
    lda #3
    sta ($fb),y
    ldx row_index
    inx
    cpx #15
    beq road_render_done
    jmp road_row_loop
road_render_done:
    rts

update_scene:
    lda curve_phase
    clc
    adc road_speed
    and #63
    sta curve_phase
    lda road_phase
    clc
    adc road_speed
    and #7
    sta road_phase
    rts

flip_buffers:
    lda front_buffer
    eor #1
    sta front_buffer
    beq show_first
    lda #$3c
    bne store_screen_select
show_first:
    lda #$1c
store_screen_select:
    sta $d018
    rts

read_controls:
    jsr GETIN
    bne control_available
    rts
control_available:
    cmp #81
    bne check_left
    lda #1
    sta quit_flag
    rts
check_left:
    cmp #65
    bne check_right
    lda view_index
    beq controls_done
    dec view_index
    rts
check_right:
    cmp #68
    bne check_color
    lda view_index
    cmp #12
    bcs controls_done
    inc view_index
    rts
check_color:
    cmp #67
    bne check_mute
    inc palette
    lda palette
    cmp #3
    bcc apply_new_palette
    lda #0
    sta palette
apply_new_palette:
    jsr apply_palette
    rts
check_mute:
    cmp #77
    bne check_pause
    lda music_muted
    eor #1
    sta music_muted
    bne mute_now
    jsr initialize_sid
    rts
mute_now:
    jsr silence_sid
    rts
check_pause:
    cmp #32
    bne check_speed_one
    lda paused
    eor #1
    sta paused
    bne pause_now
    lda music_muted
    bne controls_done
    jsr initialize_sid
    rts
pause_now:
    jsr silence_sid
    rts
check_speed_one:
    cmp #49
    bne check_speed_two
    lda #1
    sta road_speed
    rts
check_speed_two:
    cmp #50
    bne check_speed_three
    lda #2
    sta road_speed
    rts
check_speed_three:
    cmp #51
    bne controls_done
    lda #3
    sta road_speed
controls_done:
    rts

apply_palette:
    ; Blank the display while color RAM is refreshed, avoiding a partial frame.
    lda $d011
    sta display_d011
    and #$ef
    sta $d011
    lda palette
    asl
    asl
    tax
    lda palette_colors,x
    sta sky_color
    inx
    lda palette_colors,x
    sta horizon_color
    inx
    lda palette_colors,x
    sta road_color
    inx
    lda palette_colors,x
    sta sun_color
    ldx #0
color_row_loop:
    stx row_index
    cpx #8
    bcc use_sky_color
    cpx #10
    bcc use_horizon_color
    lda road_color
    bne color_selected
use_horizon_color:
    lda horizon_color
    bne color_selected
use_sky_color:
    lda sky_color
color_selected:
    sta row_color
    lda color_row_lo,x
    sta $fb
    lda color_row_hi,x
    sta $fc
    ldy #0
color_columns:
    lda row_color
    sta ($fb),y
    iny
    cpy #40
    bne color_columns
    ldx row_index
    inx
    cpx #25
    bne color_row_loop
    lda sun_color
    sta $d027
    lda display_d011
    sta $d011
    rts

initialize_sid:
    jsr silence_sid
    lda #$08
    sta $d402
    lda #$08
    sta $d403
    lda #$09
    sta $d405
    lda #$88
    sta $d406
    lda #$04
    sta $d40c
    lda #$a6
    sta $d40d
    lda #$02
    sta $d413
    lda #$84
    sta $d414
    lda #$0f
    sta $d418
    rts

update_music:
    inc music_tick
    lda music_tick
    cmp #5
    bcc music_done
    lda #0
    sta music_tick
    ldx music_step
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    lda lead_sequence,x
    tay
    lda note_lo,y
    sta $d400
    lda note_hi,y
    sta $d401
    lda #$41
    sta $d404
    lda bass_sequence,x
    tay
    lda note_hi,y
    lsr
    sta $d408
    lda note_lo,y
    ror
    sta $d407
    lda #$11
    sta $d40b
    lda drum_sequence,x
    beq no_drum
    lda #$26
    sta $d40e
    lda #$19
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

wait_raster:
wait_raster_enter:
    cmp $d012
    bne wait_raster_enter
wait_raster_leave:
    cmp $d012
    beq wait_raster_leave
    rts

show_splash:
    lda #147
    jsr CHROUT
    lda #<splash_text
    sta $fb
    lda #>splash_text
    sta $fc
print_splash:
    ldy #0
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

exit_demo:
    jsr silence_sid
    ldx #0
restore_sid_loop:
    lda old_sid,x
    sta $d400,x
    inx
    cpx #25
    bne restore_sid_loop
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
    lda old_sprite_x
    sta $d000
    lda old_sprite_y
    sta $d001
    lda old_sprite_color
    sta $d027
    lda old_sprite_pointer
    sta $07f8
    lda old_dd00
    sta $dd00
    lda old_d018
    sta $d018
    lda old_d016
    sta $d016
    lda old_d011
    sta $d011
    lda old_border
    sta $d020
    lda old_background
    sta $d021
    lda #147
    jsr CHROUT
    rts

splash_text:
!byte 13,13,13,154
!text "            INFINITE ROAD"
!byte 13,13,5
!text "   AN ENDLESS SYNTHWAVE NIGHT DRIVE"
!byte 13,13,13,153
!text "               CONTROLS"
!byte 13,13,158
!text " A/D"
!byte 5
!text " VIEW  "
!byte 158
!text "1-3"
!byte 5
!text " SPEED  "
!byte 158
!text "C"
!byte 5
!text " COLOR"
!byte 13
!text "       "
!byte 158
!text "M"
!byte 5
!text " MUSIC  "
!byte 158
!text "SPACE"
!byte 5
!text " PAUSE  "
!byte 158
!text "Q"
!byte 5
!text " QUIT"
!byte 13,13,13,5
!text "          HTTPS://C64.P20.DEV"
!byte 13,13,152
!text "        RELEASED 21 OCTOBER 2026"
!byte 13,13,13,158
!text "         PRESS SPACE TO START"
!byte 0

; Perspective and scene tables.
road_half_width: !byte 2,3,4,5,6,7,8,9,10,11,13,15,17,18,19
curve_offsets: !byte 0,1,2,3,5,7,9,12,15,18,21,24,27,30,33
curve_centers:
!byte 20,20,20,21,21,21,22,22,22,23,23,23,23,23,23,23
!byte 23,23,23,23,23,23,23,22,22,22,21,21,21,20,20,20
!byte 20,20,20,19,19,19,18,18,18,17,17,17,17,17,17,17
!byte 17,17,17,17,17,17,17,18,18,18,19,19,19,20,20,20

star_rows: !byte 1,1,2,2,3,3,4,4,5,5,6,6,7,7,2,3,5,6,1,4,6,7
star_columns: !byte 3,34,8,28,16,37,5,31,12,25,2,35,18,38,21,1,33,9,24,19,29,14
mountain_columns:
!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
!byte 20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39
mountain_chars:
!byte 19,19,18,19,18,18,19,19,18,19,19,18,18,18,19,19,18,19,18,19
!byte 19,18,19,19,18,18,19,18,19,19,19,18,18,19,19,18,19,18,19,19

palette_colors: !byte 3,4,11,7,14,6,12,1,10,2,9,8
note_lo: !byte $c4,$22,$81,$e1,$4b,$b8,$2a,$a1
note_hi: !byte $10,$13,$15,$18,$1b,$1e,$22,$26
lead_sequence: !byte 0,2,4,5,4,2,7,5,0,2,4,6,5,4,2,1
bass_sequence: !byte 0,0,0,0,3,3,3,3,5,5,5,5,3,3,1,1
drum_sequence: !byte 1,0,0,0,1,0,1,0,1,0,0,0,1,0,1,0

row_lo:
!for row,0,24 { !byte <(row*40) }
row_hi:
!for row,0,24 { !byte >(row*40) }
color_row_lo:
!for row,0,24 { !byte <($d800+row*40) }
color_row_hi:
!for row,0,24 { !byte >($d800+row*40) }

screen_base_hi: !byte 0
front_buffer: !byte 0
curve_phase: !byte 0
road_phase: !byte 0
road_speed: !byte 0
view_index: !byte 0
palette: !byte 0
paused: !byte 0
music_muted: !byte 0
quit_flag: !byte 0
music_tick: !byte 0
music_step: !byte 0
row_index: !byte 0
road_center: !byte 0
road_left: !byte 0
road_right: !byte 0
sky_color: !byte 0
horizon_color: !byte 0
road_color: !byte 0
sun_color: !byte 0
row_color: !byte 0
display_d011: !byte 0

old_border: !byte 0
old_background: !byte 0
old_d011: !byte 0
old_d016: !byte 0
old_d018: !byte 0
old_dd00: !byte 0
old_sprite_enable: !byte 0
old_sprite_msb: !byte 0
old_sprite_expand_y: !byte 0
old_sprite_expand_x: !byte 0
old_sprite_priority: !byte 0
old_sprite_x: !byte 0
old_sprite_y: !byte 0
old_sprite_color: !byte 0
old_sprite_pointer: !byte 0
old_sid: !fill 25,0

; Custom 8x8 character set at $3000. Only the scene glyphs are populated.
* = $3000
!fill 8,0                         ; 0 blank
!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ; 1 solid
!byte $80,$c0,$e0,$f0,$f8,$fc,$fe,$ff ; 2 left road edge
!byte $01,$03,$07,$0f,$1f,$3f,$7f,$ff ; 3 right road edge
!byte $00,$00,$18,$18,$18,$18,$00,$00 ; 4 lane marker
!byte $00,$10,$54,$38,$fe,$38,$54,$10 ; 5 star
!byte $88,$22,$88,$22,$88,$22,$88,$22 ; 6 road texture A
!byte $22,$88,$22,$88,$22,$88,$22,$88 ; 7 road texture B
!byte $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c ; 8 sun solid
!byte $3c,$7e,$ff,$00,$00,$ff,$7e,$3c ; 9 sun stripe
!byte $00,$00,$01,$03,$07,$0f,$1f,$3f ; 10 sun top left
!byte $00,$00,$ff,$ff,$ff,$ff,$ff,$ff ; 11 sun top middle
!byte $00,$00,$80,$c0,$e0,$f0,$f8,$fc ; 12 sun top right
!byte $3f,$7f,$ff,$ff,$ff,$ff,$7f,$3f ; 13 sun left
!byte $fc,$fe,$ff,$ff,$ff,$ff,$fe,$fc ; 14 sun right
!byte $3f,$1f,$0f,$07,$03,$01,$00,$00 ; 15 sun bottom left
!byte $ff,$ff,$ff,$ff,$ff,$ff,$00,$00 ; 16 sun bottom middle
!byte $fc,$f8,$f0,$e0,$c0,$80,$00,$00 ; 17 sun bottom right
!byte $00,$08,$1c,$3e,$7f,$ff,$ff,$ff ; 18 mountain peak
!byte $00,$00,$00,$08,$1c,$3e,$7f,$ff ; 19 low mountain
!fill 1888,0

; 24x21 striped sun sprite, displayed double width and height.
* = $3800
!byte $00,$7e,$00,$01,$ff,$80,$03,$ff,$c0,$07,$ff,$e0
!byte $0f,$ff,$f0,$1f,$ff,$f8,$3f,$ff,$fc,$3f,$ff,$fc
!byte $00,$00,$00,$3f,$ff,$fc,$00,$00,$00,$1f,$ff,$f8
!byte $00,$00,$00,$0f,$ff,$f0,$00,$00,$00,$07,$ff,$e0
!byte $00,$00,$00,$03,$ff,$c0,$01,$ff,$80,$00,$7e,$00
!byte $00,$3c,$00,$00
