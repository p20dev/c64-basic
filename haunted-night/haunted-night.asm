!cpu 6510

; HAUNTED NIGHT
; Animated Halloween scene with sprites, lightning and a three-voice SID score.
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
    beq wait_frame
    jmp exit_demo
wait_frame:
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
    jsr update_lightning
    inc frame_divider
    lda frame_divider
    cmp animation_speed
    bcc main_loop
    lda #0
    sta frame_divider
    jsr update_sprites
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
save_sprite_registers:
    lda $d000,x
    sta old_sprite_positions,x
    inx
    cpx #16
    bne save_sprite_registers
    ldx #0
save_sprite_colors:
    lda $d027,x
    sta old_sprite_colors,x
    inx
    cpx #8
    bne save_sprite_colors
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
    sta scene_phase
    sta music_tick
    sta music_step
    sta flash_timer
    sta palette_index
    lda #2
    sta animation_speed
    lda $a2
    sta last_jiffy
    lda #0
    sta $d020
    lda #6
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
    lda #147
    jsr CHROUT
    jsr draw_scene
    jsr initialize_sprites
    jsr initialize_sid
    rts

draw_scene:
    ; Deep-blue sky and dark ground.
    ldx #0
clear_screen:
    lda #32
    sta SCREEN,x
    sta SCREEN+256,x
    sta SCREEN+512,x
    sta SCREEN+768,x
    lda #14
    sta COLOR,x
    sta COLOR+256,x
    sta COLOR+512,x
    sta COLOR+768,x
    inx
    bne clear_screen

    ldx #0
draw_stars:
    lda star_lo,x
    sta $fb
    lda star_hi,x
    sta $fc
    ldy #0
    lda star_chars,x
    sta ($fb),y
    lda star_color_lo,x
    sta $fd
    lda star_color_hi,x
    sta $fe
    lda #1
    sta ($fd),y
    inx
    cpx #24
    bne draw_stars

    ; Pale moon assembled from twelve solid character cells.
    ldx #0
moon_loop:
    lda moon_lo,x
    sta $fb
    lda moon_hi,x
    sta $fc
    lda moon_color_lo,x
    sta $fd
    lda moon_color_hi,x
    sta $fe
    ldy #0
    lda #160
    sta ($fb),y
    lda #7
    sta ($fd),y
    inx
    cpx #12
    bne moon_loop

    ; Ground and mist.
    ldx #0
ground_loop:
    lda #160
    sta SCREEN+760,x
    sta SCREEN+800,x
    sta SCREEN+840,x
    sta SCREEN+880,x
    sta SCREEN+920,x
    sta SCREEN+960,x
    lda #11
    sta COLOR+760,x
    sta COLOR+800,x
    sta COLOR+840,x
    sta COLOR+880,x
    sta COLOR+920,x
    sta COLOR+960,x
    inx
    cpx #40
    bne ground_loop

    ; Haunted manor: stepped roof.
    ldx #0
roof_top:
    lda #160
    sta SCREEN+408,x
    lda #11
    sta COLOR+408,x
    inx
    cpx #3
    bne roof_top
    ldx #0
roof_middle:
    lda #160
    sta SCREEN+446,x
    lda #11
    sta COLOR+446,x
    inx
    cpx #7
    bne roof_middle
    ldx #0
roof_bottom:
    lda #160
    sta SCREEN+484,x
    lda #11
    sta COLOR+484,x
    inx
    cpx #11
    bne roof_bottom

    ; Six-row manor facade.
    ldx #0
house_walls:
    lda #160
    sta SCREEN+524,x
    sta SCREEN+564,x
    sta SCREEN+604,x
    sta SCREEN+644,x
    sta SCREEN+684,x
    sta SCREEN+724,x
    lda #11
    sta COLOR+524,x
    sta COLOR+564,x
    sta COLOR+604,x
    sta COLOR+644,x
    sta COLOR+684,x
    sta COLOR+724,x
    inx
    cpx #11
    bne house_walls
    lda #160
    sta SCREEN+566
    sta SCREEN+571
    sta SCREEN+646
    sta SCREEN+651
    lda #7
    sta COLOR+566
    sta COLOR+571
    sta COLOR+646
    sta COLOR+651
    lda #32
    sta SCREEN+648
    sta SCREEN+649
    sta SCREEN+688
    sta SCREEN+689
    sta SCREEN+728
    sta SCREEN+729

    ; Gravestones in front of the manor.
    ldx #0
grave_loop:
    lda grave_lo,x
    sta $fb
    lda grave_hi,x
    sta $fc
    ldy #0
    lda #102
    sta ($fb),y
    lda grave_color_lo,x
    sta $fd
    lda grave_color_hi,x
    sta $fe
    lda #12
    sta ($fd),y
    inx
    cpx #8
    bne grave_loop
    rts

initialize_sprites:
    lda #$e0
    sta $07f8
    lda #$e1
    sta $07f9
    sta $07fa
    lda #7
    sta $d015
    lda #0
    sta $d010
    sta $d01c
    sta $d01b
    lda #1
    sta $d017
    sta $d01d
    lda #1
    sta $d027
    lda #0
    sta $d028
    sta $d029
    lda #104
    sta $d000
    lda #118
    sta $d001
    lda #28
    sta $d002
    lda #72
    sta $d003
    lda #206
    sta $d004
    lda #92
    sta $d005
    rts

initialize_sid:
    ldx #0
clear_sid:
    lda #0
    sta $d400,x
    inx
    cpx #25
    bne clear_sid
    lda #$08
    sta $d405
    lda #$a8
    sta $d406
    lda #$04
    sta $d40c
    lda #$98
    sta $d40d
    lda #$03
    sta $d413
    lda #$78
    sta $d414
    lda #$21
    sta $d404
    lda #$41
    sta $d40b
    lda #$81
    sta $d412
    lda #$0f
    sta $d418
    rts

read_controls:
    jsr GETIN
    bne control_has_key
    rts
control_has_key:
    cmp #81
    bne control_pause
    lda #1
    sta quit_flag
    rts
control_pause:
    cmp #32
    bne control_mute
    lda paused
    eor #1
    sta paused
    bne pause_sound
    lda music_muted
    bne controls_done
    lda #$0f
    sta $d418
    rts
pause_sound:
    lda #0
    sta $d418
    rts
control_mute:
    cmp #77
    bne control_lightning
    lda music_muted
    eor #1
    sta music_muted
    bne mute_sid
    lda paused
    bne controls_done
    lda #$0f
    sta $d418
    rts
mute_sid:
    lda #0
    sta $d418
    rts
control_lightning:
    cmp #76
    bne control_color
    jsr trigger_lightning
    rts
control_color:
    cmp #67
    bne control_speed_one
    inc palette_index
    lda palette_index
    and #3
    sta palette_index
    tax
    lda sky_colors,x
    sta $d021
    rts
control_speed_one:
    cmp #49
    bne control_speed_two
    lda #4
    sta animation_speed
    rts
control_speed_two:
    cmp #50
    bne control_speed_three
    lda #2
    sta animation_speed
    rts
control_speed_three:
    cmp #51
    bne controls_done
    lda #1
    sta animation_speed
controls_done:
    rts

update_sprites:
    inc scene_phase
    lda scene_phase
    and #63
    tax
    lda ghost_wave,x
    clc
    adc #92
    sta $d000
    txa
    and #31
    tax
    lda bob_wave,x
    clc
    adc #112
    sta $d001

    lda $d002
    clc
    adc #2
    cmp #246
    bcc store_bat_one_x
    lda #18
store_bat_one_x:
    sta $d002
    lda scene_phase
    and #31
    tax
    lda bat_wave,x
    clc
    adc #58
    sta $d003

    lda $d004
    sec
    sbc #3
    cmp #12
    bcs store_bat_two_x
    lda #238
store_bat_two_x:
    sta $d004
    lda scene_phase
    clc
    adc #13
    and #31
    tax
    lda bat_wave,x
    clc
    adc #78
    sta $d005

    lda scene_phase
    and #$7f
    cmp #$65
    bne sprite_done
    jsr trigger_lightning
sprite_done:
    rts

update_lightning:
    lda flash_timer
    beq lightning_done
    dec flash_timer
    lda flash_timer
    beq restore_sky
    and #1
    beq bright_flash
    lda #15
    sta $d021
    rts
bright_flash:
    lda #1
    sta $d021
    rts
restore_sky:
    ldx palette_index
    lda sky_colors,x
    sta $d021
lightning_done:
    rts

trigger_lightning:
    lda #6
    sta flash_timer
    lda music_muted
    bne no_thunder
    lda #$90
    sta $d40e
    lda #$05
    sta $d40f
    lda #$81
    sta $d412
no_thunder:
    rts

update_music:
    inc music_tick
    lda music_tick
    cmp #6
    bcc music_done
    lda #0
    sta music_tick
    ldx music_step
    lda melody_lo,x
    sta $d400
    lda melody_hi,x
    sta $d401
    txa
    and #3
    bne keep_bass
    txa
    lsr
    lsr
    tay
    lda bass_lo,y
    sta $d407
    lda bass_hi,y
    sta $d408
keep_bass:
    txa
    and #3
    bne close_drum
    lda #$35
    sta $d40e
    lda #$02
    sta $d40f
    lda #$81
    sta $d412
    bne advance_music
close_drum:
    lda #$80
    sta $d412
advance_music:
    inc music_step
    lda music_step
    and #15
    sta music_step
music_done:
    rts

show_splash:
    lda #147
    jsr CHROUT
    lda #<splash_text
    sta $fb
    lda #>splash_text
    sta $fc
    ldy #0
print_splash:
    lda ($fb),y
    beq wait_for_space
    jsr CHROUT
    iny
    bne print_splash
    inc $fc
    jmp print_splash
wait_for_space:
    jsr GETIN
    cmp #32
    bne wait_for_space
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
restore_sprite_registers:
    lda old_sprite_positions,x
    sta $d000,x
    inx
    cpx #16
    bne restore_sprite_registers
    ldx #0
restore_sprite_colors:
    lda old_sprite_colors,x
    sta $d027,x
    inx
    cpx #8
    bne restore_sprite_colors
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
!text "             HAUNTED NIGHT"
!byte 13,13,5
!text "  A MOONLIT MANOR AWAKENS AFTER DARK"
!byte 13,13,13,153
!text "                CONTROLS"
!byte 13,13,158
!text " 1-3"
!byte 5
!text " SPEED   "
!byte 158
!text "L"
!byte 5
!text " LIGHTNING   "
!byte 158
!text "C"
!byte 5
!text " COLOR"
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

sky_colors: !byte 6,11,2,0

; Minor-key melody and bass frequencies.
melody_lo: !byte $18,$8f,$18,$b1,$18,$8f,$56,$8f,$18,$8f,$18,$b1,$56,$3c,$56,$8f
melody_hi: !byte $11,$12,$11,$15,$11,$12,$16,$12,$11,$12,$11,$15,$16,$14,$16,$12
bass_lo:   !byte $0c,$4c,$2b,$9e
bass_hi:   !byte $08,$09,$0b,$0a

bob_wave:
!byte 6,5,4,3,2,1,0,0,0,0,1,2,3,4,5,6
!byte 7,8,9,10,11,12,12,12,12,12,11,10,9,8,7,6
bat_wave:
!byte 4,3,2,1,0,0,1,2,4,6,8,10,12,13,14,15
!byte 16,15,14,13,12,10,8,6,4,2,1,0,0,1,2,3
ghost_wave:
!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
!byte 16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
!byte 32,31,30,29,28,27,26,25,24,23,22,21,20,19,18,17
!byte 16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1

; Scattered star addresses and glyphs.
star_lo:
!byte <(SCREEN+43),<(SCREEN+70),<(SCREEN+96),<(SCREEN+124),<(SCREEN+151),<(SCREEN+178)
!byte <(SCREEN+206),<(SCREEN+234),<(SCREEN+263),<(SCREEN+291),<(SCREEN+318),<(SCREEN+347)
!byte <(SCREEN+375),<(SCREEN+22),<(SCREEN+112),<(SCREEN+188),<(SCREEN+245),<(SCREEN+329)
!byte <(SCREEN+53),<(SCREEN+137),<(SCREEN+219),<(SCREEN+302),<(SCREEN+361),<(SCREEN+394)
star_hi:
!byte >(SCREEN+43),>(SCREEN+70),>(SCREEN+96),>(SCREEN+124),>(SCREEN+151),>(SCREEN+178)
!byte >(SCREEN+206),>(SCREEN+234),>(SCREEN+263),>(SCREEN+291),>(SCREEN+318),>(SCREEN+347)
!byte >(SCREEN+375),>(SCREEN+22),>(SCREEN+112),>(SCREEN+188),>(SCREEN+245),>(SCREEN+329)
!byte >(SCREEN+53),>(SCREEN+137),>(SCREEN+219),>(SCREEN+302),>(SCREEN+361),>(SCREEN+394)
star_color_lo:
!byte <(COLOR+43),<(COLOR+70),<(COLOR+96),<(COLOR+124),<(COLOR+151),<(COLOR+178)
!byte <(COLOR+206),<(COLOR+234),<(COLOR+263),<(COLOR+291),<(COLOR+318),<(COLOR+347)
!byte <(COLOR+375),<(COLOR+22),<(COLOR+112),<(COLOR+188),<(COLOR+245),<(COLOR+329)
!byte <(COLOR+53),<(COLOR+137),<(COLOR+219),<(COLOR+302),<(COLOR+361),<(COLOR+394)
star_color_hi:
!byte >(COLOR+43),>(COLOR+70),>(COLOR+96),>(COLOR+124),>(COLOR+151),>(COLOR+178)
!byte >(COLOR+206),>(COLOR+234),>(COLOR+263),>(COLOR+291),>(COLOR+318),>(COLOR+347)
!byte >(COLOR+375),>(COLOR+22),>(COLOR+112),>(COLOR+188),>(COLOR+245),>(COLOR+329)
!byte >(COLOR+53),>(COLOR+137),>(COLOR+219),>(COLOR+302),>(COLOR+361),>(COLOR+394)
star_chars: !byte 46,42,46,46,42,46,42,46,46,42,46,42,46,42,46,42,46,42,46,46,42,46,42,46

moon_lo: !byte <(SCREEN+111),<(SCREEN+112),<(SCREEN+150),<(SCREEN+151),<(SCREEN+152),<(SCREEN+153),<(SCREEN+190),<(SCREEN+191),<(SCREEN+192),<(SCREEN+193),<(SCREEN+231),<(SCREEN+232)
moon_hi: !byte >(SCREEN+111),>(SCREEN+112),>(SCREEN+150),>(SCREEN+151),>(SCREEN+152),>(SCREEN+153),>(SCREEN+190),>(SCREEN+191),>(SCREEN+192),>(SCREEN+193),>(SCREEN+231),>(SCREEN+232)
moon_color_lo: !byte <(COLOR+111),<(COLOR+112),<(COLOR+150),<(COLOR+151),<(COLOR+152),<(COLOR+153),<(COLOR+190),<(COLOR+191),<(COLOR+192),<(COLOR+193),<(COLOR+231),<(COLOR+232)
moon_color_hi: !byte >(COLOR+111),>(COLOR+112),>(COLOR+150),>(COLOR+151),>(COLOR+152),>(COLOR+153),>(COLOR+190),>(COLOR+191),>(COLOR+192),>(COLOR+193),>(COLOR+231),>(COLOR+232)

; Eight tombstone cells.
grave_lo: !byte <(SCREEN+704),<(SCREEN+710),<(SCREEN+717),<(SCREEN+723),<(SCREEN+730),<(SCREEN+735),<(SCREEN+748),<(SCREEN+753)
grave_hi: !byte >(SCREEN+704),>(SCREEN+710),>(SCREEN+717),>(SCREEN+723),>(SCREEN+730),>(SCREEN+735),>(SCREEN+748),>(SCREEN+753)
grave_color_lo: !byte <(COLOR+704),<(COLOR+710),<(COLOR+717),<(COLOR+723),<(COLOR+730),<(COLOR+735),<(COLOR+748),<(COLOR+753)
grave_color_hi: !byte >(COLOR+704),>(COLOR+710),>(COLOR+717),>(COLOR+723),>(COLOR+730),>(COLOR+735),>(COLOR+748),>(COLOR+753)

; Runtime state.
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
old_sid: !fill 25,0
paused: !byte 0
music_muted: !byte 0
quit_flag: !byte 0
frame_divider: !byte 0
animation_speed: !byte 0
scene_phase: !byte 0
music_tick: !byte 0
music_step: !byte 0
flash_timer: !byte 0
palette_index: !byte 0
last_jiffy: !byte 0

; Sprite data at pointers $e0 and $e1 in VIC bank zero.
* = $3800
ghost_sprite:
!byte $00,$18,$00,$00,$3c,$00,$00,$7e,$00,$00,$ff,$00,$01,$ff,$80,$03,$ff,$c0
!byte $03,$bd,$c0,$07,$ff,$e0,$07,$ff,$e0,$07,$db,$e0,$07,$ff,$e0,$07,$ff,$e0
!byte $07,$ff,$e0,$07,$ff,$e0,$07,$ff,$e0,$07,$ff,$e0,$07,$ff,$e0,$06,$db,$60
!byte $04,$92,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,0
bat_sprite:
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$02,$e0,$00,$07,$f8,$18,$1f
!byte $7c,$3c,$3e,$3f,$7e,$fc,$1f,$ff,$f8,$0f,$ff,$f0,$07,$ff,$e0,$03,$ff,$c0
!byte $01,$ff,$80,$00,$ff,$00,$00,$7e,$00,$00,$3c,$00,$00,$18,$00,$00,$00,$00
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,0
