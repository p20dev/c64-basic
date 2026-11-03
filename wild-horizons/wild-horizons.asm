!cpu 6510
; WILD HORIZONS -- runtime procedural landscape painter, not a frame player.
; Seeded 16-bit Galois LFSR; three independent piecewise-linear ridge walks.
; A 160x200 multicolor bitmap is painted in two-tile slices, leaving time
; for the original 50 Hz SID score and KERNAL keyboard IRQs on PAL/NTSC.
; First image visibly grows; later images render into a hidden 8 KB bitmap.
; A completed scene is published at raster 250, with its own color screen.
; Near ridge silhouettes, snow caps, a disk moon and compressed lake mirror.
; N: fresh seed; R: replay same seed; C: same scene with next palette.
; A: automatic scenes; M: music; SPACE: freeze painter and music; Q: BASIC.
; No IRQ vectors, CIA timers, CPU memory mapping or sprite data are changed.
; Exit restores VIC/bank/zero page and silences SID (registers write-only).
; Memory: launcher $0801, code $1000, bitmaps $2000/$6000, screens $0400/$4400,
; score $4000, ridges $4800, tuning/reflection $4c00. No external assets.

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
    lda pending
    beq no_publish
    jsr publish
no_publish:
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
    lda building
    beq holding
    jsr build_slice
    jmp main
holding:
    lda automatic
    beq main
    lda hold_count
    ora hold_count+1
    beq auto_new
    lda hold_count
    bne dec_low
    dec hold_count+1
dec_low:
    dec hold_count
    jmp main
auto_new:
    jsr new_scene
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
    sta $d011
    sta $d015
    sta paused
    sta muted
    sta quitting
    sta pending
    sta first_ready
    sta palette
    sta target_bank
    sta song_step
    sta unit_tick
    sta ntsc_divider
    lda #1
    sta automatic
    lda #8
    sta frames_per_unit
    lda old_bank
    ora #3
    sta $dd00
    lda #$18
    sta $d018
    sta $d016
    ldx #0
clear_bitmaps:
    lda #0
!for page,0,31 {
    sta $2000+page*256,x
    sta $6000+page*256,x
}
    lda #1
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    beq bitmaps_cleared
    jmp clear_bitmaps
bitmaps_cleared:
    ldx #39
    lda #0
dark_foreground:
!for row,8,16 {
    sta $d800+row*40,x
}
    dex
    bpl dark_foreground
    ldx #95
frequencies:
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
    bpl frequencies
    lda $dc04
    eor $a2
    sta rng_lo
    lda $dc05
    eor $a1
    ora #1
    sta rng_hi
    jsr new_scene
    lda #$3b
    sta $d011
    jsr initialize_sid
    jsr sequence_step
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

; Polynomial $b400, period 65535 for a nonzero state.
random:
    lsr rng_hi
    ror rng_lo
    bcc no_feedback
    lda rng_hi
    eor #$b4
    sta rng_hi
no_feedback:
    lda rng_lo
    eor rng_hi
    rts

new_scene:
    jsr random
    eor $a2
    sta seed_lo
    jsr random
    ora #1
    sta seed_hi
replay_scene:
    lda seed_lo
    sta rng_lo
    lda seed_hi
    sta rng_hi
    lda palette
    sta build_palette
    lda #1
    sta building
    lda #0
    sta pending
    sta stage
    sta tile_x
    sta tile_y
    sta tile_count
    sta tile_count+1
    lda #0
    sta $fd
    lda target_bank
    eor #$20
    sta $fe
    jsr prepare_colors
    rts

; Private screen RAM belongs to the target bank; color RAM is fixed by row.
prepare_colors:
    lda #0
    sta $fb
    lda target_bank
    ora #4
    sta $fc
    ldx #0
color_row:
    stx work_row
    ldy build_palette
    cpx #8
    bcc sky_row
    cpx #17
    bcs water_row
    lda land_colors,y
    jmp row_color
sky_row:
    lda sky_colors,y
    jmp row_color
water_row:
    lda water_colors,y
row_color:
    ldy #39
color_columns:
    sta ($fb),y
    dey
    bpl color_columns
    clc
    lda $fb
    adc #40
    sta $fb
    bcc color_same_page
    inc $fc
color_same_page:
    ldx work_row
    inx
    cpx #25
    bne color_row
    lda build_palette
    tax
    lda sky_background,x
    sta build_background
    ; Only the first scene paints the currently visible bank.
    lda first_ready
    bne colors_done
    lda build_background
    sta $d021
colors_done:
    rts

build_slice:
    lda stage
    cmp #3
    bcs paint_tiles
    tax
    lda ridge_base,x
    sta ridge_min
    lda ridge_mask,x
    sta height_mask
    lda ridge_lo,x
    sta $f9
    lda ridge_hi,x
    sta $fa
    jsr make_ridge
    inc stage
    lda stage
    cmp #3
    bne slice_done
    jsr random
    and #63
    clc
    adc #48
    sta sun_x
    jsr random
    and #7
    clc
    adc #12
    sta sun_y
slice_done:
    rts
paint_tiles:
    lda #2
    sta slice_tiles
next_tile:
    jsr paint_tile
    inc tile_count
    bne tile_count_ok
    inc tile_count+1
tile_count_ok:
    lda tile_count+1
    cmp #3
    bne more_tiles
    lda tile_count
    cmp #$e8
    bne more_tiles
    lda #0
    sta building
    lda #1
    sta pending
    rts
more_tiles:
    dec slice_tiles
    bne next_tile
    rts

; Twenty linear spans per ridge, eight samples per span.
make_ridge:
    jsr random
    and height_mask
    clc
    adc ridge_min
    sta height_now
    ldy #0
ridge_span:
    jsr random
    and height_mask
    clc
    adc ridge_min
    sta height_next
    sec
    sbc height_now
    bpl positive_slope
    eor #$ff
    clc
    adc #1
    ldx #$ff
    bne slope_sign
positive_slope:
    ldx #1
slope_sign:
    stx height_sign
    sta height_delta
    and #7
    sta height_remainder
    lda height_delta
    lsr
    lsr
    lsr
    cpx #1
    beq store_slope
    eor #$ff
    clc
    adc #1
store_slope:
    sta height_step
    lda #0
    sta height_error
    lda #8
    sta span_left
ridge_sample:
    lda height_now
    sta ($f9),y
    clc
    adc height_step
    sta height_now
    lda height_error
    clc
    adc height_remainder
    cmp #8
    bcc keep_fraction
    sbc #8
    sta height_error
    lda height_now
    clc
    adc height_sign
    sta height_now
    jmp sample_done
keep_fraction:
    sta height_error
sample_done:
    iny
    dec span_left
    bne ridge_sample
    lda height_next
    sta height_now
    cpy #160
    beq ridge_done
    jmp ridge_span
ridge_done:
    rts

paint_tile:
    lda #0
    sta scanline
tile_scanline:
    lda tile_y
    clc
    adc scanline
    sta pixel_y
    tay
    lda mirror_y,y
    sta sample_y
    ldx tile_x
    lda #0
    sta packed
    lda #4
    sta pixel_count
four_pixels:
    jsr landscape_pixel
    sta color_temp
    lda packed
    asl
    asl
    ora color_temp
    sta packed
    inx
    dec pixel_count
    bne four_pixels
    ldy scanline
    lda packed
    sta ($fd),y
    inc scanline
    lda scanline
    cmp #8
    bne tile_scanline
    clc
    lda $fd
    adc #8
    sta $fd
    bcc dest_same_page
    inc $fe
dest_same_page:
    lda tile_x
    clc
    adc #4
    cmp #160
    bcc next_column
    lda tile_y
    clc
    adc #8
    sta tile_y
    lda #0
next_column:
    sta tile_x
    rts

landscape_pixel:
    lda sample_y
    cmp far_ridge,x
    bcc sky_pixel
    cmp middle_ridge,x
    bcc far_pixel
    cmp near_ridge,x
    bcc middle_pixel
    lda #3
    bne reflect_color
middle_pixel:
    lda #2
    bne reflect_color
far_pixel:
    sec
    sbc far_ridge,x
    cmp #2
    bcs plain_far
    lda #3
    bne reflect_color
plain_far:
    lda #1
    bne reflect_color
sky_pixel:
    lda pixel_y
    cmp #132
    bcs water_sky
    sec
    sbc sun_y
    cmp #16
    bcs empty_sky
    tay
    lda sun_x
    sec
    sbc disk_width,y
    sta disk_left
    txa
    cmp disk_left
    bcc empty_sky
    lda sun_x
    clc
    adc disk_width,y
    sta disk_left
    txa
    cmp disk_left
    bcs empty_sky
    lda #3
    rts
empty_sky:
    lda #0
    rts
water_sky:
    lda #0
reflect_color:
    sta scene_color
    lda pixel_y
    cmp #132
    bcc land_color
    and #3
    beq dark_ripple
    lda scene_color
    tay
    lda reflection_colors,y
    sta scene_color
    lda pixel_y
    and #7
    cmp #2
    bcs land_color
    txa
    sec
    sbc sun_x
    clc
    adc #2
    cmp #5
    bcs land_color
    lda #3
    rts
dark_ripple:
    lda #1
    rts
land_color:
    lda scene_color
    rts

publish:
    lda old_bank
    and #$fc
    ldx target_bank
    beq publish_zero
    ora #2
    bne publish_bank
publish_zero:
    ora #3
publish_bank:
    sta $dd00
    lda build_background
    sta $d021
    lda target_bank
    eor #$40
    sta target_bank
    lda #1
    sta first_ready
    lda #0
    sta pending
    lda #<350
    sta hold_count
    lda #>350
    sta hold_count+1
    rts

music_tick:
    inc unit_tick
    lda unit_tick
    cmp frames_per_unit
    bcc shape_notes
    lda #0
    sta unit_tick
    inc song_step
    jsr sequence_step
shape_notes:
    lda muted
    bne music_done
    ; Separate pulse melody, sustained triangle bass and chiming pulse arp.
    lda unit_tick
    cmp #7
    bne pulse_motion
    lda #$40
    sta $d412
    ldx song_step
    inx
    lda melody,x
    beq bass_release
    lda #$40
    sta $d404
bass_release:
    txa
    and #3
    bne pulse_motion
    lda #$10
    sta $d40b
pulse_motion:
    lda song_step
    and #31
    asl
    asl
    sta $d402
music_done:
    rts

sequence_step:
    lda muted
    beq audible
    rts
audible:
    ldx song_step
    lda melody,x
    beq bass_step
    cmp #255
    bne lead_note
    lda #$40
    sta $d404
    jmp bass_step
lead_note:
    tax
    lda freq_lo,x
    sta $d400
    lda freq_hi,x
    sta $d401
    lda #$41
    sta $d404
bass_step:
    lda song_step
    and #3
    bne arp_step
    ldx song_step
    lda bass_notes,x
    tax
    lda freq_lo,x
    sta $d407
    lda freq_hi,x
    sta $d408
    lda #$11
    sta $d40b
arp_step:
    ldx song_step
    lda arp_notes,x
    tax
    lda freq_lo,x
    sta $d40e
    lda freq_hi,x
    sta $d40f
    lda #$41
    sta $d412
    rts

initialize_sid:
    jsr silence_sid
    lda #$29
    sta $d405
    lda #$a9
    sta $d406
    lda #8
    sta $d403
    lda #$18
    sta $d40c
    lda #$88
    sta $d40d
    lda #$03
    sta $d413
    lda #$47
    sta $d414
    lda #$00
    sta $d410
    lda #$03
    sta $d411
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
    bne controls_done
    lda #15
    sta $d418
    rts
check_mute:
    cmp #77
    bne check_new
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
check_new:
    cmp #78
    bne check_replay
    jmp new_scene
check_replay:
    cmp #82
    bne check_palette
    jmp replay_scene
check_palette:
    cmp #67
    bne check_auto
    inc palette
    lda palette
    cmp #3
    bcc palette_ready
    lda #0
    sta palette
palette_ready:
    jmp replay_scene
check_auto:
    cmp #65
    bne controls_done
    lda automatic
    eor #1
    sta automatic
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
automatic: !byte 1
building: !byte 0
pending: !byte 0
first_ready: !byte 0
palette: !byte 0
build_palette: !byte 0
build_background: !byte 14
target_bank: !byte 0
hold_count: !word 0
rng_lo: !byte 1
rng_hi: !byte 1
seed_lo: !byte 1
seed_hi: !byte 1
stage: !byte 0
tile_x: !byte 0
tile_y: !byte 0
tile_count: !word 0
slice_tiles: !byte 0
scanline: !byte 0
pixel_y: !byte 0
sample_y: !byte 0
packed: !byte 0
color_temp: !byte 0
pixel_count: !byte 0
scene_color: !byte 0
disk_left: !byte 0
sun_x: !byte 80
sun_y: !byte 12
work_row: !byte 0
ridge_min: !byte 32
height_mask: !byte 31
height_now: !byte 0
height_next: !byte 0
height_step: !byte 0
height_sign: !byte 1
height_delta: !byte 0
height_remainder: !byte 0
height_error: !byte 0
span_left: !byte 0
unit_tick: !byte 0
song_step: !byte 0
ntsc_divider: !byte 0
frames_per_unit: !byte 8
freq_lo: !fill 96,0
freq_hi: !fill 96,0
ridge_base: !byte 32,64,100
ridge_mask: !byte 31,31,15
ridge_lo: !byte <far_ridge,<middle_ridge,<near_ridge
ridge_hi: !byte >far_ridge,>middle_ridge,>near_ridge
sky_background: !byte 14,4,0
sky_colors: !byte $6e,$28,$bc
land_colors: !byte $65,$28,$bc
water_colors: !byte $6e,$6a,$6c
reflection_colors: !byte 1,1,2,1
disk_width: !byte 0,2,3,4,5,5,6,6,6,6,5,5,4,3,2,0

splash:
!byte 13,13,13,154
!text "             WILD HORIZONS"
!byte 13,13,5
!text "  RANDOM RIDGES, STILL WATER, NEW VIEWS."
!byte 13
!text "     AN ORIGINAL THREE-VOICE SID SCORE."
!byte 13,13,13,153
!text "                CONTROLS"
!byte 13,13,158
!text " N"
!byte 5
!text " NEW VIEW  "
!byte 158
!text "R"
!byte 5
!text " REPLAY  "
!byte 158
!text "C"
!byte 5
!text " COLORS"
!byte 13,158
!text " A"
!byte 5
!text " AUTO VIEWS  "
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
!text "        RELEASED 3 NOVEMBER 2026"
!byte 13,13,13,158
!text "         PRESS SPACE TO START"
!byte 0
!if * > $2000 { !error "Code overlaps bitmap" }

; Original Ebmaj7/Cm7/Abmaj7/Bb theme: all three voices are tonal.
* = $4000
melody:
!byte 74,0,0,0,70,0,67,0,63,0,0,0,67,0,70,0
!byte 74,0,0,0,70,0,67,0,63,0,0,0,67,0,70,0
!byte 74,0,0,0,70,0,67,0,63,0,0,0,67,0,70,0
!byte 74,0,0,0,70,0,67,0,63,0,0,0,67,0,70,0
!byte 72,0,0,0,67,0,70,0,75,0,0,0,74,0,70,0
!byte 72,0,0,0,67,0,70,0,75,0,0,0,74,0,70,0
!byte 72,0,0,0,67,0,70,0,75,0,0,0,74,0,70,0
!byte 72,0,0,0,67,0,70,0,75,0,0,0,74,0,70,0
!byte 67,0,0,0,63,0,65,0,70,0,0,0,67,0,63,0
!byte 67,0,0,0,63,0,65,0,70,0,0,0,67,0,63,0
!byte 67,0,0,0,63,0,65,0,70,0,0,0,67,0,63,0
!byte 67,0,0,0,63,0,65,0,70,0,0,0,67,0,63,0
!byte 70,0,0,0,74,0,77,0,75,0,74,0,70,0,0,0
!byte 70,0,0,0,74,0,77,0,75,0,74,0,70,0,0,0
!byte 70,0,0,0,74,0,77,0,75,0,74,0,70,0,0,0
!byte 70,0,0,0,74,0,77,0,75,0,74,0,70,0,0,255
bass_notes:
!byte 39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39
!byte 39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39
!byte 36,36,36,36,36,36,36,36,36,36,36,36,36,36,36,36
!byte 36,36,36,36,36,36,36,36,36,36,36,36,36,36,36,36
!byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
!byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
!byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
!byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
!byte 39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39
!byte 39,39,39,39,39,39,39,39,39,39,39,39,39,39,39,39
!byte 36,36,36,36,36,36,36,36,36,36,36,36,36,36,36,36
!byte 36,36,36,36,36,36,36,36,36,36,36,36,36,36,36,36
!byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
!byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
!byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
!byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
arp_notes:
!byte 63,70,67,74,67,70,63,74,63,70,67,74,67,70,63,74
!byte 63,70,67,74,67,70,63,74,63,70,67,74,67,70,63,74
!byte 60,67,63,70,63,67,60,70,60,67,63,70,63,67,60,70
!byte 60,67,63,70,63,67,60,70,60,67,63,70,63,67,60,70
!byte 56,63,60,67,60,63,56,67,56,63,60,67,60,63,56,67
!byte 56,63,60,67,60,63,56,67,56,63,60,67,60,63,56,67
!byte 58,65,62,70,62,65,58,70,58,65,62,70,62,65,58,70
!byte 58,65,62,70,62,65,58,70,58,65,62,70,62,65,58,70
!byte 63,70,67,74,67,70,63,74,63,70,67,74,67,70,63,74
!byte 63,70,67,74,67,70,63,74,63,70,67,74,67,70,63,74
!byte 60,67,63,70,63,67,60,70,60,67,63,70,63,67,60,70
!byte 60,67,63,70,63,67,60,70,60,67,63,70,63,67,60,70
!byte 56,63,60,67,60,63,56,67,56,63,60,67,60,63,56,67
!byte 56,63,60,67,60,63,56,67,56,63,60,67,60,63,56,67
!byte 58,65,62,70,62,65,58,70,58,65,62,70,62,65,58,70
!byte 58,65,62,70,62,65,58,70,58,65,62,70,62,65,58,70
!if * > $4400 { !error "Score overlaps second screen" }
* = $4c00
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
mirror_y:
!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
!byte 16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
!byte 32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47
!byte 48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63
!byte 64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79
!byte 80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95
!byte 96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111
!byte 112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127
!byte 128,129,130,131,131,129,127,125,123,121,119,117,115,113,111,109
!byte 107,105,103,101,99,97,95,93,91,89,87,85,83,81,79,77
!byte 75,73,71,69,67,65,63,61,59,57,55,53,51,49,47,45
!byte 43,41,39,37,35,33,31,29,27,25,23,21,19,17,15,13
!byte 11,9,7,5,3,1,0,0
!if * > $5000 { !error "Unexpected table size" }
* = $4800
far_ridge: !fill 160,0
middle_ridge: !fill 160,0
near_ridge: !fill 160,0

