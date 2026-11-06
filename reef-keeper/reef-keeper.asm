!cpu 6510
; REEF KEEPER -- aquarium care game with original pixel art and SID music.
; Four animated multicolor fish, falling food and three rising bubble sprites.
; Food, water, air and health are game values, not real animal-care advice.
; One simulated second = 100/50/10 normalized ticks in calm/normal/challenge.
; Each second: food -1 (half at night), water -1, oxygen -2. Below 25 in any
; care meter costs 3 health; otherwise health recovers by 1, up to 100.
; Feeding adds 20 food, costs 4 water; overfeeding costs 12 more water and
; 3 health. F has 2-second cooldown. C adds 30 water, costs 5 air (8 s).
; A adds 35 air (6 s). Cooldowns use simulated time and stop during pause.
; Health zero ends the tank; R restarts. Q restores VIC/bank/ZP and BASIC.
; KERNAL IRQs and CIA timers unchanged. PAL/NTSC SID tuning and 50 Hz clock.
; SID registers are write-only; exit deliberately silences the chip.
; Memory: SYS $1000, custom charset $2800, fish/particles $3000-$34ff,
; score $4000, scene screen/colors $4800/$4c00, tables/HUD $5000.

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
    beq continue
    jmp exit
continue:
    lda paused
    bne main
    lda game_over
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
    jsr animate
    jsr care_tick
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
    lda $cc
    sta old_cursor
    rts





initialize:
    lda #1
    sta $cc
    lda #0
    sta $d015
    sta quitting
    lda old_bank
    ora #3
    sta $dd00
    lda #$1b
    sta $d011
    lda #$1b
    sta $d016
    lda #$1a
    sta $d018
    lda #14
    sta $d022
    lda #11
    sta $d023
    ldx #0
copy_scene:
    lda scene_screen,x
    sta $0400,x
    lda scene_screen+256,x
    sta $0500,x
    lda scene_screen+512,x
    sta $0600,x
    lda scene_screen+768,x
    sta $0700,x
    lda scene_colors,x
    sta $d800,x
    lda scene_colors+256,x
    sta $d900,x
    lda scene_colors+512,x
    sta $da00,x
    lda scene_colors+768,x
    sta $db00,x
    inx
    bne copy_scene
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
    lda #$80
    sta $d010
    lda #0
    sta $d01b
    sta $d025
    lda #1
    sta $d026
    lda #0
    sta $d017
    lda #$0f
    sta $d01d
    sta $d01c
    lda #$d0
    sta $07fc
    lda #$d1
    sta $07fd
    lda #$d2
    sta $07fe
    lda #$d3
    sta $07ff
    lda #7
    sta $d02b
    lda #1
    sta $d02c
    lda #14
    sta $d02d
    lda #1
    sta $d02e
    jmp reset_game

reset_game:
    lda #0
    sta paused
    sta muted
    sta game_over
    sta phase
    sta care_clock
    sta food_timer
    sta feed_wait
    sta clean_wait
    sta air_wait
    sta message_timer
    sta action_code
    sta song_step
    sta unit_tick
    sta ntsc_divider
    ldx #3
reset_digits:
    sta age_digits,x
    dex
    bpl reset_digits
    lda #1
    sta lights
    sta pace
    lda #8
    sta frames_per_unit
    lda #80
    sta food
    lda #85
    sta water
    sta air
    lda #100
    sta health
    ldx #3
reset_fish:
    lda fish_start_x,x
    sta fish_x,x
    lda fish_base_y,x
    sta fish_y,x
    txa
    and #1
    sta fish_dir,x
    dex
    bpl reset_fish
    lda #180
    sta bubble_y
    lda #132
    sta bubble_y+1
    lda #84
    sta bubble_y+2
    lda #$ef
    sta $d015
    jsr initialize_sid
    jsr sequence_step
    jsr animate
    jmp draw_hud

wait_frame:
    lda #250
wait_line:
    cmp $d012
    bne wait_line
leave_line:
    cmp $d012
    beq leave_line
    rts

animate:
    inc phase
    jsr animate_plants
    lda phase
    and #1
    bne food_step
    ldx #2
bubble_loop:
    dec bubble_y,x
    lda bubble_y,x
    cmp #68
    bcs bubble_position
    lda #194
    sta bubble_y,x
bubble_position:
    txa
    asl
    tay
    lda bubble_y,x
    sta $d00b,y
    lda bubble_x,x
    sta $d00a,y
    dex
    bpl bubble_loop
food_step:
    lda food_timer
    beq food_hidden
    dec food_timer
    inc food_y
    lda food_y
    sta $d009
    lda #164
    sta $d008
    lda #$ff
    bne food_enable
food_hidden:
    lda #$ef
food_enable:
    sta $d015
    ldx #0
fish_loop:
    stx work_fish
    lda food_timer
    bne seek_food
    lda lights
    beq slow_motion
    lda phase
    and #1
    bne fish_vertical
    jmp cruise
slow_motion:
    lda phase
    and #3
    bne fish_vertical
cruise:
    lda fish_dir,x
    bne swim_left
    inc fish_x,x
    lda fish_x,x
    cmp #242
    bcc fish_vertical
    lda #1
    sta fish_dir,x
    jmp fish_vertical
swim_left:
    dec fish_x,x
    lda fish_x,x
    cmp #40
    bcs fish_vertical
    lda #0
    sta fish_dir,x
    jmp fish_vertical
seek_food:
    lda fish_x,x
    cmp feeding_x,x
    beq fish_vertical
    bcc chase_right
    dec fish_x,x
    lda #1
    sta fish_dir,x
    bne fish_vertical
chase_right:
    inc fish_x,x
    lda #0
    sta fish_dir,x
fish_vertical:
    lda food_timer
    beq normal_depth
    lda food_y
    sec
    sbc #10
    cmp #74
    bcs depth_low_ok
    lda #74
depth_low_ok:
    cmp #157
    bcc set_target_y
    lda #156
    bne set_target_y
normal_depth:
    txa
    asl
    asl
    asl
    asl
    clc
    adc phase
    and #63
    tay
    lda wiggle,y
    clc
    adc fish_base_y,x
set_target_y:
    cmp fish_y,x
    beq fish_position
    bcc rise
    inc fish_y,x
    jmp fish_position
rise:
    dec fish_y,x
fish_position:
    txa
    asl
    tay
    lda fish_x,x
    sta $d000,y
    lda fish_y,x
    sta $d001,y
    lda fish_dir,x
    asl
    sta work_dir
    txa
    asl
    asl
    clc
    adc work_dir
    sta work_dir
    lda phase
    lsr
    lsr
    lsr
    and #1
    clc
    adc work_dir
    adc #$c0
    sta $07f8,x
    lda health
    cmp #25
    bcc weak_fish
    lda lights
    beq night_fish
    lda fish_colors,x
    jmp fish_color
night_fish:
    lda fish_night_colors,x
    jmp fish_color
weak_fish:
    lda #15
fish_color:
    sta $d027,x
    ldx work_fish
    inx
    cpx #4
    beq animation_done
    jmp fish_loop
animation_done:
    rts

animate_plants:
    lda phase
    and #7
    beq plant_tick
    rts
plant_tick:
    lda phase
    lsr
    lsr
    lsr
    and #3
    asl
    asl
    asl
    tay
    ldx #0
plant_pixels:
    lda plant_frames,y
    sta $2e98,x
    sta $2ea0,x
    sta $2ea8,x
    sta $2eb0,x
    iny
    inx
    cpx #8
    bne plant_pixels
    rts

care_tick:
    inc care_clock
    ldx pace
    lda care_clock
    cmp care_intervals,x
    bcs care_second
    rts
care_second:
    lda #0
    sta care_clock
    ldx #0
age_carry:
    inc age_digits,x
    lda age_digits,x
    cmp #10
    bcc age_done
    lda #0
    sta age_digits,x
    inx
    cpx #4
    bne age_carry
age_done:
    ldx #2
wait_decay:
    lda feed_wait,x
    beq next_wait
    dec feed_wait,x
next_wait:
    dex
    bpl wait_decay
    lda message_timer
    beq decay_food
    dec message_timer
decay_food:
    lda lights
    bne hunger
    lda age_digits
    and #1
    beq decay_water
hunger:
    lda food
    beq decay_water
    dec food
decay_water:
    lda water
    beq decay_air
    dec water
decay_air:
    ldx #2
    lda #2
    jsr subtract_resource
    ldx #0
check_care:
    lda resources,x
    cmp #25
    bcc unhealthy
    inx
    cpx #3
    bne check_care
    lda health
    cmp #100
    bcs care_hud
    inc health
    jmp care_hud
unhealthy:
    ldx #3
    lda #3
    jsr subtract_resource
    lda health
    bne care_hud
    lda #1
    sta game_over
    lda #0
    sta food_timer
    sta $d418
    lda #$ef
    sta $d015
care_hud:
    jmp draw_hud

add_resource:
    clc
    adc resources,x
    cmp #101
    bcc added
    lda #100
added:
    sta resources,x
    rts
subtract_resource:
    sta amount
    lda resources,x
    sec
    sbc amount
    bcs subtracted
    lda #0
subtracted:
    sta resources,x
    rts

feed:
    lda feed_wait
    beq feed_ready
    lda #6
    jmp action_message
feed_ready:
    lda #2
    sta feed_wait
    lda #100
    sta food_timer
    lda #80
    sta food_y
    lda food
    cmp #85
    bcc normal_feed
    ldx #1
    lda #12
    jsr subtract_resource
    ldx #3
    lda #3
    jsr subtract_resource
    lda #5
    sta action_code
    jmp food_added
normal_feed:
    lda #11
    sta action_code
food_added:
    ldx #0
    lda #20
    jsr add_resource
    ldx #1
    lda #4
    jsr subtract_resource
    lda #3
    sta message_timer
    jmp draw_hud

clean:
    lda clean_wait
    beq clean_ready
    lda #7
    jmp action_message
clean_ready:
    lda #8
    sta clean_wait
    ldx #1
    lda #30
    jsr add_resource
    ldx #2
    lda #5
    jsr subtract_resource
    lda #9
    jmp action_message
aerate:
    lda air_wait
    beq air_ready
    lda #8
    jmp action_message
air_ready:
    lda #6
    sta air_wait
    ldx #2
    lda #35
    jsr add_resource
    lda #10
action_message:
    sta action_code
    lda #3
    sta message_timer
    jmp draw_hud

draw_hud:
    ; Four eight-segment bars, using hires glyphs over multicolor scenery.
    ldx #0
metric_loop:
    stx work_metric
    lda resources,x
    sta metric_value
    cmp #25
    bcc red_bar
    cmp #50
    bcc yellow_bar
    lda #5
    bne bar_color
red_bar:
    lda #2
    bne bar_color
yellow_bar:
    lda #7
bar_color:
    sta metric_color
    lda bar_lo,x
    sta $fb
    sta $fd
    lda bar_hi,x
    sta $fc
    clc
    adc #$d4
    sta $fe
    lda #12
    sta threshold
    ldy #0
bar_column:
    lda metric_value
    cmp threshold
    bcc empty_bar
    lda #253
    bne bar_glyph
empty_bar:
    lda #254
bar_glyph:
    sta ($fb),y
    lda metric_color
    sta ($fd),y
    clc
    lda threshold
    adc #12
    sta threshold
    iny
    cpy #8
    bne bar_column
    ldx work_metric
    inx
    cpx #4
    bne metric_loop
    ; Age and pace occupy reserved custom-font positions in the header.
    ldx #3
    ldy #0
age_display:
    lda age_digits,x
    clc
    adc #241
    sta AGE_TARGET,y
    iny
    dex
    bpl age_display
    lda pace
    clc
    adc #242
    sta PACE_TARGET
    lda game_over
    bne lost_message
    lda health
    cmp #25
    bcc danger_message
    lda air
    cmp #25
    bcc air_message
    lda water
    cmp #25
    bcc water_message
    lda food
    cmp #25
    bcc food_message
    lda message_timer
    beq balanced_message
    lda action_code
    jmp show_message
lost_message:
    lda #12
    bne show_message
danger_message:
    lda #4
    bne show_message
air_message:
    lda #3
    bne show_message
water_message:
    lda #2
    bne show_message
food_message:
    lda #1
    bne show_message
balanced_message:
    lda #0
show_message:
    tax
    lda message_lo,x
    sta $fb
    lda message_hi,x
    sta $fc
    ldy #39
message_copy:
    lda ($fb),y
    sta $07c0,y
    lda #1
    ldx game_over
    beq message_color
    lda #2
message_color:
    sta $dbc0,y
    dey
    bpl message_copy
    lda lights
    beq dark_water
    lda water
    cmp #25
    bcc murky_water
    lda #6
    bne water_background
murky_water:
    lda #5
    bne water_background
dark_water:
    lda #0
water_background:
    sta $d021
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
    ; One quiet tick before each arp attack. Lead ties are preserved.
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
    bne check_restart
    lda #1
    sta quitting
    rts
check_restart:
    cmp #82
    bne check_ended
    jmp reset_game
check_ended:
    ldx game_over
    beq check_pause
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
    bne check_feed
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
check_feed:
    cmp #70
    bne check_clean
    jmp feed
check_clean:
    cmp #67
    bne check_air
    jmp clean
check_air:
    cmp #65
    bne check_lights
    jmp aerate
check_lights:
    cmp #76
    bne check_pace
    lda lights
    eor #1
    sta lights
    jmp draw_hud
check_pace:
    cmp #49
    bcc controls_done
    cmp #52
    bcs controls_done
    sec
    sbc #49
    sta pace
    lda #0
    sta care_clock
    jmp draw_hud
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
    lda old_cursor
    sta $cc
    rts
old_vic: !fill 25,0
old_extra: !fill 20,0
old_pointers: !fill 8,0
old_zp: !fill 6,0
old_bank: !byte 0
old_text_color: !byte 0
old_cursor: !byte 0
quitting: !byte 0
paused: !byte 0
muted: !byte 0
game_over: !byte 0
lights: !byte 1
pace: !byte 1
phase: !byte 0
care_clock: !byte 0
resources:
food: !byte 80
water: !byte 85
air: !byte 85
health: !byte 100
feed_wait: !byte 0
clean_wait: !byte 0
air_wait: !byte 0
message_timer: !byte 0
action_code: !byte 0
age_digits: !fill 4,0
food_timer: !byte 0
food_y: !byte 80
fish_x: !fill 4,0
fish_y: !fill 4,0
fish_dir: !fill 4,0
bubble_y: !byte 180,132,84
work_fish: !byte 0
work_dir: !byte 0
work_metric: !byte 0
metric_value: !byte 0
metric_color: !byte 5
threshold: !byte 0
amount: !byte 0
unit_tick: !byte 0
song_step: !byte 0
ntsc_divider: !byte 0
frames_per_unit: !byte 8
freq_lo: !fill 96,0
freq_hi: !fill 96,0
fish_start_x: !byte 60,220,155,100
fish_base_y: !byte 86,108,130,145
feeding_x: !byte 144,160,176,192
fish_colors: !byte 7,3,10,5
fish_night_colors: !byte 8,14,4,11
bubble_x: !byte 70,220,46
care_intervals: !byte 100,50,10
bar_lo: !byte <$0799,<$07a3,<$07ad,<$07b7
bar_hi: !byte >$0799,>$07a3,>$07ad,>$07b7

splash:
!byte 13,13,13,154
!text "              REEF KEEPER"
!byte 13,13,5
!text "  CARE FOR FOUR FISH IN A LIVING TANK."
!byte 13
!text "   FEED, CLEAN, AERATE. KEEP THEM WELL."
!byte 13,13,13,153
!text "                CONTROLS"
!byte 13,13,158
!text " F"
!byte 5
!text " FEED  "
!byte 158
!text "C"
!byte 5
!text " CLEAN  "
!byte 158
!text "A"
!byte 5
!text " AERATE"
!byte 13,158
!text " 1-3"
!byte 5
!text " CARE PACE  "
!byte 158
!text "L"
!byte 5
!text " LIGHTS"
!byte 13,158
!text " M"
!byte 5
!text " MUSIC  "
!byte 158
!text "R"
!byte 5
!text " RESTART"
!byte 13,158
!text " SPACE"
!byte 5
!text " PAUSE  "
!byte 158
!text "Q"
!byte 5
!text " QUIT"
!byte 13,13,5
!text "          HTTPS://C64.P20.DEV"
!byte 13,13,152
!text "        RELEASED 6 NOVEMBER 2026"
!byte 13,13,158
!text "         PRESS SPACE TO START"
!byte 0
!if * > $2800 { !error "Code overlaps charset" }

AGE_TARGET = $75a
PACE_TARGET = $766
* = $2800
; Original multicolor tank artwork, plus custom hires HUD alphabet/digits.
!byte 0,0,0,0,0,0,0,0,170,170,85,170,170,170,170,0
!byte 152,152,152,152,152,152,152,152,42,42,42,42,42,42,42,42
!byte 170,170,170,170,170,170,170,170,64,0,0,0,64,0,0,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,1,0,0
!byte 0,1,4,0,0,1,4,16,0,1,4,16,64,0,4,16
!byte 0,0,0,0,0,85,0,0,0,0,85,0,0,0,0,0
!byte 0,1,4,16,0,1,4,16,64,0,4,16,64,0,0,16
!byte 0,1,0,0,0,1,4,0,64,0,0,16,64,0,0,0
!byte 64,0,0,0,0,0,0,0,247,170,170,170,170,170,170,170
!byte 64,0,0,16,64,0,0,16,0,1,4,0,0,1,4,0
!byte 85,85,85,85,85,85,170,170,223,170,170,170,170,170,170,170
!byte 253,170,170,170,170,170,170,170,0,0,0,0,21,64,0,0
!byte 0,0,5,80,0,0,0,0,0,0,0,84,1,0,0,0
!byte 0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,192
!byte 85,85,85,85,85,85,85,170,127,170,170,170,170,170,170,170
!byte 234,170,170,170,170,170,170,170,0,0,0,21,64,0,0,0
!byte 0,0,80,5,0,0,0,0,0,0,0,0,84,1,0,0
!byte 0,0,0,0,0,3,63,0,0,0,0,0,15,252,0,0
!byte 0,0,0,0,0,0,15,252,15,0,0,0,0,0,0,0
!byte 0,15,252,0,0,0,0,0,0,0,0,3,255,192,0,0
!byte 0,0,0,0,0,0,255,255,255,255,0,0,0,0,0,0
!byte 85,85,85,85,85,170,170,170,222,170,170,170,170,170,170,170
!byte 171,170,170,170,170,170,170,170,125,170,170,170,170,170,170,170
!byte 183,170,170,170,170,170,170,170,175,170,170,170,170,170,170,170
!byte 154,154,85,154,154,154,154,152,170,170,85,170,170,170,170,42
!byte 0,0,0,5,80,0,0,0,0,0,84,1,0,0,0,0
!byte 0,0,4,16,64,0,4,16,0,0,0,16,64,0,0,16
!byte 0,0,4,0,0,1,4,0,0,0,0,0,64,0,0,0
!byte 0,0,4,16,0,1,4,16,0,0,0,0,240,0,0,255
!byte 0,0,0,0,15,63,255,3,0,0,0,0,0,192,0,192
!byte 169,253,173,247,183,246,223,218,64,240,63,223,234,223,170,127
!byte 127,169,253,173,247,183,246,223,240,63,0,234,255,235,253,253
!byte 0,192,252,218,223,106,127,170,234,223,170,127,171,125,173,253
!byte 60,61,244,240,240,255,247,208,160,160,160,160,149,160,240,167
!byte 15,15,15,175,223,159,126,127,170,222,127,122,125,234,253,170
!byte 223,175,127,191,126,253,250,247,64,64,64,104,88,104,168,168
!byte 15,3,3,247,167,247,159,222,240,255,243,240,60,61,60,252
!byte 79,60,60,60,252,60,60,63,253,234,247,170,247,171,223,175
!byte 247,183,222,223,218,127,106,125,122,253,234,247,170,247,171,223
!byte 67,255,195,15,15,15,15,15,0,0,255,255,255,255,255,255
!byte 0,0,1,5,21,85,85,170,170,247,171,223,175,223,191,126
!byte 0,1,4,80,80,85,127,250,0,0,0,127,173,253,189,246
!byte 0,0,0,95,170,170,170,170,170,170,126,173,253,189,246,247
!byte 170,170,170,167,159,222,223,122,223,122,127,106,253,170,247,171
!byte 243,240,240,60,60,255,252,15,252,240,244,255,243,240,192,208
!byte 240,240,192,192,192,252,207,0,5,5,5,165,165,165,170,170
!byte 3,0,0,246,247,218,223,234,252,255,240,251,255,191,255,191
!byte 0,192,252,127,122,125,234,253,170,170,170,175,122,125,234,253
!byte 252,207,192,240,240,240,252,60,192,15,15,31,79,15,7,19
!byte 15,15,15,252,60,60,63,240,0,0,0,1,5,42,42,42
!byte 168,168,168,171,170,171,218,223,240,63,0,223,171,223,239,255
!byte 175,127,191,126,253,250,247,234,247,250,223,234,223,170,127,169
!byte 170,250,182,246,247,218,223,234,240,63,0,192,192,192,240,240
!byte 192,195,252,207,192,192,192,192,127,243,3,19,67,3,3,3
!byte 192,192,192,252,207,240,240,240,0,3,255,195,3,15,15,15
!byte 192,192,196,208,192,192,252,223,168,169,168,168,168,169,88,168
!byte 42,42,42,106,250,170,247,171,127,170,125,169,253,167,247,183
!byte 253,183,246,247,218,223,234,127,170,170,170,234,170,247,171,247
!byte 170,170,170,170,222,175,223,191,253,254,253,250,247,234,223,170
!byte 15,15,15,3,3,3,15,252,15,255,60,60,63,60,240,240
!byte 3,3,3,63,243,3,3,3,15,15,15,15,15,63,243,3
!byte 192,253,4,16,64,0,63,240,60,60,60,60,60,255,207,15
!byte 0,0,0,247,170,247,171,223,160,160,85,85,170,170,170,170
!byte 15,207,255,191,223,223,219,127,247,175,223,159,126,127,122,253
!byte 234,127,170,125,169,253,167,247,170,170,170,170,170,126,127,122
!byte 170,159,171,127,173,253,189,246,253,169,247,167,247,159,222,223
!byte 60,63,15,15,15,15,15,63,63,240,0,240,63,0,0,0
!byte 60,61,63,60,60,61,60,60,192,192,192,0,240,63,0,0
!byte 0,0,3,63,0,192,252,0,240,1,4,0,3,255,196,16
!byte 170,170,149,170,162,160,160,160,15,15,15,223,159,127,127,122
!byte 240,255,192,234,247,250,255,251,154,155,154,155,154,153,153,155
!byte 127,125,250,253,234,247,170,223,183,170,247,170,223,171,127,175
!byte 223,218,223,106,127,170,253,169,191,126,125,250,253,234,247,170
!byte 107,125,170,253,171,247,167,223,0,1,63,240,0,1,244,16
!byte 67,3,3,255,207,15,15,15,192,192,192,192,0,0,240,63
!byte 240,240,240,192,192,192,192,252,160,160,160,160,160,160,96,160
!byte 0,80,85,85,85,85,85,171,252,15,0,0,0,0,63,240
!byte 170,170,170,170,170,171,125,173,0,192,255,3,0,0,0,192
!byte 243,3,3,3,3,3,3,3,0,0,240,63,0,0,192,192
!byte 64,0,192,255,3,0,0,0,0,0,0,0,240,15,15,15
!byte 63,243,3,3,3,15,15,15,0,15,252,0,240,63,4,0
!byte 63,243,3,3,3,192,0,0,0,0,0,3,192,255,3,0
!byte 3,255,207,15,15,15,60,60,240,240,240,240,255,243,240,240
!byte 0,0,0,3,63,0,192,252,60,60,252,60,240,255,243,240
!byte 60,60,60,60,255,252,60,15,64,0,7,19,67,3,3,19
!byte 3,3,3,3,15,253,4,0,63,0,0,0,0,15,252,0
!byte 64,80,84,85,85,170,170,170,0,0,0,0,64,160,160,160
!byte 170,170,170,170,106,170,247,171,0,0,0,250,223,234,223,170
!byte 170,170,170,170,170,223,170,223,170,223,171,223,175,127,189,254
!byte 255,175,125,189,254,247,250,247,3,3,3,0,0,0,3,255
!byte 64,0,252,31,64,0,0,0,192,192,192,252,207,0,0,0
!byte 15,252,0,0,0,0,3,3,42,42,42,42,250,63,42,42
!byte 0,0,63,240,0,0,0,0,42,42,42,42,42,254,47,42
!byte 0,0,0,63,240,0,0,0,0,1,15,252,64,0,4,16
!byte 0,0,63,243,3,3,3,15,42,42,42,42,42,42,250,63
!byte 0,1,0,0,63,241,4,0,0,0,0,0,0,63,240,0
!byte 192,192,192,208,240,240,240,255,0,0,0,3,63,243,3,3
!byte 63,0,0,0,0,192,192,195,0,21,85,85,85,170,170,170
!byte 15,207,15,15,15,255,207,15,152,152,152,153,155,155,154,155
!byte 0,0,0,0,5,0,0,246,42,42,42,170,106,170,106,234
!byte 170,170,170,170,170,250,247,234,170,170,170,170,170,167,223,159
!byte 234,234,234,234,170,234,170,106,155,154,154,154,154,154,154,154
!byte 0,240,63,0,0,0,0,0,64,192,252,16,64,0,0,16
!byte 0,1,4,0,0,1,4,255,0,0,0,192,252,0,0,0
!byte 0,0,0,0,0,192,252,0,240,192,192,192,192,240,63,0
!byte 64,0,0,0,0,0,252,15,48,48,240,240,240,60,60,48
!byte 48,48,240,240,240,60,60,48,48,48,240,240,240,60,60,48
!byte 48,48,240,240,240,60,60,48,0,56,68,68,124,68,68,68
!byte 0,120,68,68,120,68,68,120,0,60,64,64,64,64,64,60
!byte 0,120,68,68,68,68,68,120,0,124,64,64,120,64,64,124
!byte 0,124,64,64,120,64,64,64,0,60,64,64,92,68,68,56
!byte 0,68,68,68,124,68,68,68,0,124,16,16,16,16,16,124
!byte 0,28,8,8,8,8,72,48,0,68,72,80,96,80,72,68
!byte 0,64,64,64,64,64,64,124,0,68,108,84,84,68,68,68
!byte 0,68,100,84,76,68,68,68,0,56,68,68,68,68,68,56
!byte 0,120,68,68,120,64,64,64,0,56,68,68,68,84,72,52
!byte 0,120,68,68,120,80,72,68,0,60,64,64,56,4,4,120
!byte 0,124,16,16,16,16,16,16,0,68,68,68,68,68,68,56
!byte 0,68,68,68,68,68,40,16,0,68,68,68,84,84,84,40
!byte 0,68,68,40,16,40,68,68,0,68,68,40,16,16,16,16
!byte 0,124,4,8,16,32,64,124,0,56,68,76,84,100,68,56
!byte 0,16,48,16,16,16,16,56,0,56,68,4,8,16,32,124
!byte 0,120,4,4,56,4,4,120,0,8,24,40,72,124,8,8
!byte 0,124,64,64,120,4,4,120,0,56,64,64,120,68,68,56
!byte 0,124,4,8,16,32,32,32,0,56,68,68,56,68,68,56
!byte 0,56,68,68,60,4,4,56,0,0,0,0,0,0,0,0
!byte 0,0,24,24,0,24,24,0,0,126,126,126,126,126,126,0
!byte 0,126,66,66,66,66,126,0,0,0,0,126,0,0,0,0
* = $3000
; Four fish species, each with right/left direction and two fin poses.
; Sprite pair codes: 01 shared black, 10 individual color, 11 shared white.
!byte 0,0,0,0,0,0,0,21,0,0,0,0,64,21,80,80
!byte 110,180,100,110,180,105,174,185,107,174,153,107,174,185,107,174
!byte 185,107,174,185,107,174,185,105,174,185,100,110,180,80,110,180
!byte 64,21,80,0,0,0,0,21,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,21,0,0,0,0,0,21,80,80
!byte 110,180,100,110,180,105,174,185,107,174,153,107,174,185,107,174
!byte 185,107,174,185,107,174,185,105,174,185,100,110,180,80,110,180
!byte 0,21,80,0,0,0,0,21,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,84,0,0,0,0,5,84,1,30
!byte 185,5,30,185,25,110,186,105,102,186,233,110,186,233,110,186
!byte 233,110,186,233,110,186,233,110,186,105,30,185,25,30,185,5
!byte 5,84,1,0,0,0,0,84,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,84,0,0,0,0,5,84,0,30
!byte 185,5,30,185,25,110,186,105,102,186,233,110,186,233,110,186
!byte 233,110,186,233,110,186,233,110,186,105,30,185,25,30,185,5
!byte 5,84,0,0,0,0,0,84,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,21,0,0,0,0,64,21,80,80
!byte 106,164,100,106,164,105,170,169,127,255,221,106,170,185,106,170
!byte 169,106,170,169,127,255,253,105,170,169,100,106,164,80,106,164
!byte 64,21,80,0,0,0,0,21,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,21,0,0,0,0,0,21,80,80
!byte 106,164,100,106,164,105,170,169,127,255,221,106,170,185,106,170
!byte 169,106,170,169,127,255,253,105,170,169,100,106,164,80,106,164
!byte 0,21,80,0,0,0,0,21,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,84,0,0,0,0,5,84,1,26
!byte 169,5,26,169,25,106,170,105,119,255,253,110,170,169,106,170
!byte 169,106,170,169,127,255,253,106,170,105,26,169,25,26,169,5
!byte 5,84,1,0,0,0,0,84,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,84,0,0,0,0,5,84,0,26
!byte 169,5,26,169,25,106,170,105,119,255,253,110,170,169,106,170
!byte 169,106,170,169,127,255,253,106,170,105,26,169,25,26,169,5
!byte 5,84,0,0,0,0,0,84,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,21,0,0,0,0,64,21,80,80
!byte 122,164,100,106,180,105,170,233,110,171,153,122,174,185,106,186
!byte 173,106,234,185,107,170,233,109,171,169,116,110,164,80,122,164
!byte 64,21,80,0,0,0,0,21,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,21,0,0,0,0,0,21,80,80
!byte 122,164,100,106,180,105,170,233,110,171,153,122,174,185,106,186
!byte 173,106,234,185,107,170,233,109,171,169,116,110,164,80,122,164
!byte 0,21,80,0,0,0,0,21,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,84,0,0,0,0,5,84,1,26
!byte 173,5,30,169,25,107,170,105,102,234,185,110,186,173,122,174
!byte 169,110,171,169,107,170,233,106,234,121,26,185,29,26,173,5
!byte 5,84,1,0,0,0,0,84,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,84,0,0,0,0,5,84,0,26
!byte 173,5,30,169,25,107,170,105,102,234,185,110,186,173,122,174
!byte 169,110,171,169,107,170,233,106,234,121,26,185,29,26,173,5
!byte 5,84,0,0,0,0,0,84,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,21,0,0,0,0,64,21,80,80
!byte 110,164,100,110,164,105,174,169,106,174,153,106,174,185,106,174
!byte 169,106,174,169,106,174,169,105,174,169,100,110,164,80,110,164
!byte 64,21,80,0,0,0,0,21,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,21,0,0,0,0,0,21,80,80
!byte 110,164,100,110,164,105,174,169,106,174,153,106,174,185,106,174
!byte 169,106,174,169,106,174,169,105,174,169,100,110,164,80,110,164
!byte 0,21,80,0,0,0,0,21,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,84,0,0,0,0,5,84,1,26
!byte 185,5,26,185,25,106,186,105,102,186,169,110,186,169,106,186
!byte 169,106,186,169,106,186,169,106,186,105,26,185,25,26,185,5
!byte 5,84,1,0,0,0,0,84,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,84,0,0,0,0,5,84,0,26
!byte 185,5,26,185,25,106,186,105,102,186,169,110,186,169,106,186
!byte 169,106,186,169,106,186,169,106,186,105,26,185,25,26,185,5
!byte 5,84,0,0,0,0,0,84,0,0,0,0,0,0,0,0
!byte 12,0,0,12,0,0,12,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,6,0,0,6,0,0,6,0,0,0
!byte 0,0,0,0,0,0,0,0,0,12,0,0,12,0,0,12
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,28,0,0,54,0,0,34
!byte 0,0,54,0,0,28,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,62,0,0,99,0,0,65,0,0,65
!byte 0,0,65,0,0,99,0,0,62,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,62,0,0,99,0,0,193,128,0,128,128,0,128
!byte 128,0,128,128,0,193,128,0,99,0,0,62,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!if * != $3500 { !error "Unexpected sprite size" }
* = $4000
; Original Fmaj7/Dm7/Bbmaj7/C7 aquarium score; pulse/triangle/pulse.
melody:
!byte 72,0,0,0,69,0,65,0,64,0,0,0,65,0,69,0
!byte 72,0,0,0,69,0,65,0,64,0,0,0,65,0,69,0
!byte 72,0,0,0,69,0,65,0,64,0,0,0,65,0,69,0
!byte 72,0,0,0,69,0,65,0,64,0,0,0,65,0,69,0
!byte 74,0,0,0,72,0,69,0,65,0,0,0,69,0,72,0
!byte 74,0,0,0,72,0,69,0,65,0,0,0,69,0,72,0
!byte 74,0,0,0,72,0,69,0,65,0,0,0,69,0,72,0
!byte 74,0,0,0,72,0,69,0,65,0,0,0,69,0,72,0
!byte 70,0,0,0,69,0,65,0,62,0,0,0,65,0,69,0
!byte 70,0,0,0,69,0,65,0,62,0,0,0,65,0,69,0
!byte 70,0,0,0,69,0,65,0,62,0,0,0,65,0,69,0
!byte 70,0,0,0,69,0,65,0,62,0,0,0,65,0,69,0
!byte 72,0,0,0,76,0,74,0,72,0,69,0,0,0,0,0
!byte 72,0,0,0,76,0,74,0,72,0,69,0,0,0,0,0
!byte 72,0,0,0,76,0,74,0,72,0,69,0,0,0,0,0
!byte 72,0,0,0,76,0,74,0,72,0,69,0,0,0,0,255
bass_notes:
!byte 41,41,41,41,41,41,41,41,41,41,41,41,41,41,41,41
!byte 41,41,41,41,41,41,41,41,41,41,41,41,41,41,41,41
!byte 38,38,38,38,38,38,38,38,38,38,38,38,38,38,38,38
!byte 38,38,38,38,38,38,38,38,38,38,38,38,38,38,38,38
!byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
!byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
!byte 36,36,36,36,36,36,36,36,36,36,36,36,36,36,36,36
!byte 36,36,36,36,36,36,36,36,36,36,36,36,36,36,36,36
!byte 41,41,41,41,41,41,41,41,41,41,41,41,41,41,41,41
!byte 41,41,41,41,41,41,41,41,41,41,41,41,41,41,41,41
!byte 38,38,38,38,38,38,38,38,38,38,38,38,38,38,38,38
!byte 38,38,38,38,38,38,38,38,38,38,38,38,38,38,38,38
!byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
!byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
!byte 36,36,36,36,36,36,36,36,36,36,36,36,36,36,36,36
!byte 36,36,36,36,36,36,36,36,36,36,36,36,36,36,36,36
arp_notes:
!byte 65,72,69,76,69,72,65,76,65,72,69,76,69,72,65,76
!byte 65,72,69,76,69,72,65,76,65,72,69,76,69,72,65,76
!byte 62,69,65,72,65,69,62,72,62,69,65,72,65,69,62,72
!byte 62,69,65,72,65,69,62,72,62,69,65,72,65,69,62,72
!byte 58,65,62,69,62,65,58,69,58,65,62,69,62,65,58,69
!byte 58,65,62,69,62,65,58,69,58,65,62,69,62,65,58,69
!byte 60,67,64,70,64,67,60,70,60,67,64,70,64,67,60,70
!byte 60,67,64,70,64,67,60,70,60,67,64,70,64,67,60,70
!byte 65,72,69,76,69,72,65,76,65,72,69,76,69,72,65,76
!byte 65,72,69,76,69,72,65,76,65,72,69,76,69,72,65,76
!byte 62,69,65,72,65,69,62,72,62,69,65,72,65,69,62,72
!byte 62,69,65,72,65,69,62,72,62,69,65,72,65,69,62,72
!byte 58,65,62,69,62,65,58,69,58,65,62,69,62,65,58,69
!byte 58,65,62,69,62,65,58,69,58,65,62,69,62,65,58,69
!byte 60,67,64,70,64,67,60,70,60,67,64,70,64,67,60,70
!byte 60,67,64,70,64,67,60,70,60,67,64,70,64,67,60,70
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
!if * > $4800 { !error "Music overlaps tank screen data" }
* = $4800
scene_screen:
!byte 48,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,49,2,10,6,6,6,10,23,31
!byte 24,11,11,32,25,33,10,6,6,6,10,23,31,24,11,11
!byte 32,25,33,10,6,6,6,10,23,50,24,11,11,51,25,3
!byte 2,0,0,0,0,0,0,0,0,52,0,0,0,0,0,0
!byte 0,0,7,53,0,0,0,0,0,0,0,0,54,55,0,0
!byte 0,0,0,0,0,0,56,3,2,0,0,0,0,0,0,0
!byte 14,15,0,0,0,0,0,0,0,0,8,5,0,0,0,0
!byte 0,0,0,0,12,0,0,0,0,0,0,0,0,0,13,3
!byte 2,0,0,0,0,0,0,0,8,16,0,0,0,0,0,0
!byte 0,0,9,0,0,0,0,0,0,0,0,7,13,0,0,0
!byte 0,0,0,0,0,14,15,3,2,0,0,0,0,0,0,0
!byte 9,0,0,0,0,0,0,0,0,7,18,0,0,0,0,0
!byte 0,0,0,19,5,0,0,0,0,0,0,0,0,12,16,3
!byte 2,0,0,0,0,0,0,14,15,0,0,0,0,0,0,0
!byte 0,8,5,0,0,0,0,0,0,0,0,12,0,0,0,0
!byte 0,0,0,0,0,13,0,3,2,0,0,0,0,0,0,8
!byte 16,0,0,0,0,0,0,0,0,9,0,0,0,0,0,0
!byte 0,0,7,13,0,0,0,0,34,35,213,0,14,15,0,3
!byte 2,36,58,211,0,0,0,9,0,0,0,0,0,0,0,0
!byte 7,18,0,0,0,0,0,0,0,0,19,5,0,0,0,0
!byte 26,36,88,41,12,16,0,3,2,0,179,96,204,0,14,15
!byte 0,0,0,0,0,0,0,0,8,5,0,0,0,0,0,0
!byte 0,0,12,0,0,0,0,0,0,26,118,105,205,0,0,3
!byte 2,37,0,132,155,0,206,16,0,0,0,0,0,0,0,0
!byte 9,0,0,0,0,0,0,0,0,7,13,0,0,0,0,0
!byte 0,37,26,73,180,0,0,3,2,0,182,156,106,133,212,157
!byte 207,0,0,0,0,0,0,7,18,0,0,0,0,0,0,0
!byte 0,19,5,0,0,0,0,0,0,0,37,134,158,214,0,3
!byte 2,0,38,160,181,161,107,108,135,0,0,0,0,0,0,8
!byte 5,0,0,0,0,0,0,0,0,12,0,0,0,0,0,0
!byte 0,38,182,89,161,162,108,183,2,0,38,119,163,147,78,135
!byte 208,0,0,0,0,0,0,9,0,0,0,0,0,0,0,0
!byte 7,13,0,0,0,0,0,0,0,184,164,135,136,38,165,185
!byte 2,186,109,209,166,187,167,210,27,0,0,0,0,0,7,18
!byte 0,0,0,0,0,0,0,0,19,5,0,0,0,0,0,0
!byte 39,184,66,210,186,188,90,189,2,39,98,40,190,148,149,27
!byte 0,0,0,0,0,0,8,5,0,0,91,20,20,20,20,71
!byte 12,0,132,40,40,0,0,0,35,120,110,27,39,98,40,3
!byte 2,191,168,36,137,74,27,0,0,0,0,0,0,0,9,0
!byte 0,0,4,138,4,138,4,111,169,79,79,41,41,0,0,0
!byte 34,170,192,171,193,150,0,3,2,36,121,194,122,123,37,0
!byte 0,99,195,42,42,42,172,173,0,0,4,151,16,0,46,111
!byte 5,0,132,80,28,28,28,28,152,82,123,153,196,37,41,3
!byte 197,124,92,93,61,139,63,94,83,112,4,4,4,4,125,125
!byte 125,84,4,67,26,198,174,100,124,175,68,4,4,4,4,4
!byte 4,4,72,140,126,101,64,199,141,102,113,142,60,75,114,81
!byte 103,127,65,69,85,115,200,201,176,86,143,76,177,144,70,128
!byte 145,62,77,104,116,176,129,154,95,130,87,178,146,117,131,202
!byte 203,17,43,44,21,29,4,45,22,30,46,17,30,47,21,43
!byte 44,29,45,4,22,17,30,46,21,30,47,29,29,4,22,22
!byte 4,17,17,30,21,21,4,4,232,219,219,220,251,225,219,219
!byte 230,219,232,251,251,251,215,221,219,251,241,241,241,241,251,251
!byte 251,230,215,217,219,251,243,251,251,251,251,251,251,251,251,251
!byte 251,220,229,229,218,251,251,251,251,251,251,237,215,234,219,232
!byte 251,251,251,251,251,215,223,232,251,251,251,251,251,251,251,222
!byte 219,215,226,234,222,251,251,251,251,251,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251,251,251,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251,251,251,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251,251,251,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251,251,251,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251,251,251,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251,251,251,251,251,251,251,251,251
* = $4c00
scene_colors:
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,13,13,13,11,11,11,11,11
!byte 11,13,13,13,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 13,13,13,13,13,11,11,11,11,11,13,13,13,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,13,13,13,13,11,11,11
!byte 11,13,13,13,13,13,13,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,13,13,13,13,13,11,11,11,11,13,13,13,13,13,13
!byte 13,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,13,13,13,13,13,11,11
!byte 11,11,13,13,13,13,13,13,13,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,13,13,13,13,13,13,13,11,13,13,13,13,13,13,13
!byte 13,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,13,13,13,13,13,13,13,13
!byte 13,13,13,13,13,13,13,13,13,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,10,10,10,11,11,11,13,13,13,13,13,13,13,11
!byte 13,13,13,13,13,13,13,13,11,11,11,11,11,11,11,11
!byte 11,11,11,11,11,11,11,11,10,10,10,10,10,11,11,11
!byte 13,13,13,13,13,13,13,13,11,13,13,13,13,13,13,13
!byte 11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11
!byte 11,11,10,11,11,11,11,11,13,13,13,13,13,13,13,11
!byte 15,15,15,13,15,13,13,15,15,15,15,11,11,11,11,11
!byte 11,15,15,15,15,15,15,15,15,15,10,11,11,11,11,11
!byte 11,15,15,13,13,15,15,15,15,15,15,15,15,15,15,15
!byte 15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15
!byte 15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15
!byte 15,15,15,15,15,15,11,15,15,15,15,15,15,15,15,15
!byte 15,15,15,11,15,15,15,15,15,15,15,15,15,11,15,15
!byte 11,15,15,15,15,15,15,11,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
* = $5000
wiggle:
!byte 0,1,2,3,4,5,6,6,7,8,8,9,9,10,10,10
!byte 10,10,10,10,9,9,8,8,7,6,6,5,4,3,2,1
!byte 0,255,254,253,252,251,250,250,249,248,248,247,247,246,246,246
!byte 246,246,246,246,247,247,248,248,249,250,250,251,252,253,254,255
message_0:
!byte 216,215,226,215,228,217,219,218,251,255,251,225,219,219,230,251
!byte 234,222,219,251,234,215,228,225,251,222,219,215,226,234,222,239
!byte 251,251,251,251,251,251,251,251
message_1:
!byte 222,235,228,221,232,239,251,220,223,233,222,251,255,251,215,218
!byte 218,251,215,251,226,223,234,234,226,219,251,220,229,229,218,251
!byte 251,251,251,251,251,251,251,251
message_2:
!byte 218,223,232,234,239,251,237,215,234,219,232,251,255,251,217,226
!byte 219,215,228,251,234,222,219,251,234,215,228,225,251,251,251,251
!byte 251,251,251,251,251,251,251,251
message_3:
!byte 226,229,237,251,229,238,239,221,219,228,251,255,251,215,219,232
!byte 215,234,219,251,234,222,219,251,237,215,234,219,232,251,251,251
!byte 251,251,251,251,251,251,251,251
message_4:
!byte 220,223,233,222,251,223,228,251,218,215,228,221,219,232,251,255
!byte 251,217,222,219,217,225,251,217,215,232,219,251,227,219,234,219
!byte 232,233,251,251,251,251,251,251
message_5:
!byte 234,229,229,251,227,235,217,222,251,220,229,229,218,251,230,229
!byte 226,226,235,234,219,233,251,234,222,219,251,237,215,234,219,232
!byte 251,251,251,251,251,251,251,251
message_6:
!byte 237,215,223,234,251,215,251,227,229,227,219,228,234,251,216,219
!byte 220,229,232,219,251,220,219,219,218,223,228,221,251,215,221,215
!byte 223,228,251,251,251,251,251,251
message_7:
!byte 237,215,234,219,232,251,217,222,215,228,221,219,251,232,219,217
!byte 229,236,219,232,223,228,221,251,251,251,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251
message_8:
!byte 215,219,232,215,234,229,232,251,232,219,217,222,215,232,221,223
!byte 228,221,251,251,251,251,251,251,251,251,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251
message_9:
!byte 220,232,219,233,222,251,237,215,234,219,232,251,222,219,226,230
!byte 233,251,234,222,219,251,237,222,229,226,219,251,234,215,228,225
!byte 251,251,251,251,251,251,251,251
message_10:
!byte 216,235,216,216,226,219,233,251,216,232,223,228,221,251,220,232
!byte 219,233,222,251,229,238,239,221,219,228,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251
message_11:
!byte 215,251,226,223,234,234,226,219,251,220,229,229,218,251,227,215
!byte 225,219,233,251,222,215,230,230,239,251,220,223,233,222,251,251
!byte 251,251,251,251,251,251,251,251
message_12:
!byte 234,215,228,225,251,226,229,233,234,251,255,251,232,251,234,229
!byte 251,232,219,233,234,215,232,234,251,251,251,251,251,251,251,251
!byte 251,251,251,251,251,251,251,251
plant_frames:
!byte 48,48,240,240,240,60,60,48,12,12,60,60,60,15,15,12
!byte 12,12,15,15,15,60,60,12,48,48,60,60,60,240,240,48
message_lo: !byte <message_0,<message_1,<message_2,<message_3,<message_4,<message_5,<message_6,<message_7,<message_8,<message_9,<message_10,<message_11,<message_12
message_hi: !byte >message_0,>message_1,>message_2,>message_3,>message_4,>message_5,>message_6,>message_7,>message_8,>message_9,>message_10,>message_11,>message_12
