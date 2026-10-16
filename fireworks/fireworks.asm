!cpu 6510

; Fireworks - an animated PETSCII fireworks simulator with SID effects.
; Self-starting BASIC line: 10 SYS2061
* = $0801
!word basic_end
!word 10
!byte $9e
!text "2061"
!byte 0
basic_end: !word 0

* = $080d
SCREEN = $0400
COLOR  = $d800
GETIN  = $ffe4
CHROUT = $ffd2

start:
    lda $d020
    sta old_border
    lda $d021
    sta old_background
    lda $d418
    sta old_volume
    ldx #0
save_sid:
    lda $d400,x
    sta old_sid,x
    inx
    cpx #7
    bne save_sid
    lda #0
    sta $d020
    sta $d021
    jsr show_splash
    lda #147
    jsr CHROUT
    lda #0
    sta $d020
    sta $d021
    sta show_state
    sta palette
    sta auto_show
    sta tick
    sta seed
    lda #3
    sta animation_speed
    lda #18
    sta auto_countdown
    lda $a2
    sta last_jiffy
    jsr draw_skyline
    jsr draw_stars

main_loop:
    jsr GETIN
    beq check_clock
    cmp #81
    bne check_launch
    jmp exit
check_launch:
    cmp #32
    bne check_auto
    jsr launch_rocket
    jmp check_clock
check_auto:
    cmp #65
    bne check_color
    lda auto_show
    eor #1
    sta auto_show
    lda #4
    sta auto_countdown
    jmp check_clock
check_color:
    cmp #67
    bne check_speed_one
    inc palette
    lda palette
    and #3
    sta palette
    jmp check_clock
check_speed_one:
    cmp #49
    bne check_speed_two
    lda #6
    sta animation_speed
    jmp check_clock
check_speed_two:
    cmp #50
    bne check_speed_three
    lda #3
    sta animation_speed
    jmp check_clock
check_speed_three:
    cmp #51
    bne check_clock
    lda #1
    sta animation_speed

check_clock:
    lda $a2
    cmp last_jiffy
    beq main_loop
    sta last_jiffy
    inc tick
    lda tick
    cmp animation_speed
    bcc main_loop
    lda #0
    sta tick
    inc seed
    jsr twinkle_star
    lda show_state
    beq idle_frame
    cmp #1
    bne dispatch_explosion
    jsr update_rocket
    jmp main_loop
dispatch_explosion:
    jsr update_explosion
    jmp main_loop

idle_frame:
    lda auto_show
    bne auto_active
    jmp main_loop
auto_active:
    dec auto_countdown
    beq auto_launch
    jmp main_loop
auto_launch:
    jsr launch_rocket
    jmp main_loop

launch_rocket:
    lda show_state
    bne launch_done
    lda seed
    clc
    adc $d012
    and #31
    cmp #24
    bcc center_ready
    sbc #24
center_ready:
    clc
    adc #8
    sta center_x
    sta rocket_x
    lda #20
    sta rocket_y
    lda #1
    sta show_state
    lda #2
    sta trail_length
    jsr rocket_sound
launch_done:
    rts

update_rocket:
    ; Erase the oldest trail cell.
    lda rocket_x
    sta plot_x
    lda rocket_y
    clc
    adc #2
    cmp #20
    bcs skip_old_trail
    sta plot_y
    lda #32
    ldy #0
    jsr plot_character
skip_old_trail:
    ; Turn the old rocket position into a fading trail.
    lda rocket_y
    sta plot_y
    lda #46
    ldy #7
    jsr plot_character
    dec rocket_y
    lda rocket_y
    cmp #6
    bne draw_rocket
    lda rocket_x
    sta plot_x
    lda #32
    ldy #0
    jsr plot_character
    lda #2
    sta show_state
    lda #0
    sta explosion_stage
    jsr explosion_sound
    jsr draw_explosion
    rts
draw_rocket:
    sta plot_y
    lda rocket_x
    sta plot_x
    lda #94
    ldy #1
    jsr plot_character
    jsr rocket_sound
    rts

update_explosion:
    jsr erase_explosion
    inc explosion_stage
    lda explosion_stage
    cmp #5
    bcs finish_explosion
    jsr explosion_sound
    jsr draw_explosion
    rts
finish_explosion:
    lda #0
    sta show_state
    lda seed
    and #15
    clc
    adc #8
    sta auto_countdown
    jsr silence_sid
    jsr draw_skyline
    jsr draw_stars
    rts

draw_explosion:
    lda #0
    sta particle
draw_particle_loop:
    jsr select_particle_position
    lda explosion_stage
    tax
    lda burst_chars,x
    ldx particle
    ldy particle_colors,x
    ldx palette
    beq color_ready
palette_shift_loop:
    tya
    clc
    adc #3
    and #15
    tay
    dex
    bne palette_shift_loop
color_ready:
    jsr plot_character
    inc particle
    lda particle
    cmp #16
    bne draw_particle_loop
    rts

erase_explosion:
    lda #0
    sta particle
erase_particle_loop:
    jsr select_particle_position
    lda #32
    ldy #0
    jsr plot_character
    inc particle
    lda particle
    cmp #16
    bne erase_particle_loop
    rts

select_particle_position:
    lda explosion_stage
    asl
    asl
    asl
    asl
    clc
    adc particle
    tax
    lda burst_dx,x
    clc
    adc center_x
    sta plot_x
    lda burst_dy,x
    clc
    adc #6
    sta plot_y
    rts

draw_stars:
    ldx #0
star_loop:
    stx object_index
    lda star_x,x
    sta plot_x
    lda star_y,x
    sta plot_y
    txa
    and #1
    beq star_dot
    lda #42
    bne paint_star
star_dot:
    lda #46
paint_star:
    ldy #15
    jsr plot_character
    ldx object_index
    inx
    cpx #18
    bne star_loop
    rts

twinkle_star:
    lda seed
    and #15
    tax
    stx object_index
    lda star_x,x
    sta plot_x
    lda star_y,x
    sta plot_y
    lda seed
    and #1
    beq twinkle_dot
    lda #42
    bne twinkle_paint
twinkle_dot:
    lda #46
twinkle_paint:
    ldy #1
    jsr plot_character
    rts

draw_skyline:
    ldx #0
building_loop:
    stx plot_x
    lda building_height,x
    sta height_left
    lda #24
    sta plot_y
building_column:
    lda #160
    ldy #11
    jsr plot_character
    dec plot_y
    dec height_left
    bne building_column
    inx
    cpx #40
    bne building_loop
    ; Warm windows across the skyline.
    ldx #0
window_loop:
    stx object_index
    lda window_x,x
    sta plot_x
    lda window_y,x
    sta plot_y
    lda #81
    ldy #7
    jsr plot_character
    ldx object_index
    inx
    cpx #12
    bne window_loop
    rts

rocket_sound:
    lda rocket_y
    eor #$ff
    sta $d400
    lda #22
    sta $d401
    lda #$11
    sta $d404
    lda #$0f
    sta $d418
    rts

explosion_sound:
    lda #0
    sta $d400
    lda #45
    sta $d401
    lda #$81
    sta $d404
    lda #$08
    sta $d405
    lda #$88
    sta $d406
    lda #$0f
    sta $d418
    rts

silence_sid:
    lda #0
    sta $d404
    sta $d418
    rts

plot_character:
    sta character
    sty character_color
    ldy plot_y
    lda screen_row_lo,y
    sta $fb
    lda screen_row_hi,y
    sta $fc
    lda color_row_lo,y
    sta $fd
    lda color_row_hi,y
    sta $fe
    ldy plot_x
    lda character
    sta ($fb),y
    lda character_color
    sta ($fd),y
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
    cpx #7
    bne restore_sid
    lda old_volume
    sta $d418
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
!text "              FIREWORKS"
!byte 13,13
!byte 5
!text " A PETSCII SKY FULL OF COLOR AND SOUND"
!byte 13,13,13
!byte 153
!text "                CONTROLS"
!byte 13,13
!text "    "
!byte 158
!text "SPACE"
!byte 5
!text " LAUNCH  "
!byte 158
!text "A"
!byte 5
!text " AUTO  "
!byte 158
!text "C"
!byte 5
!text " COLOR"
!byte 13
!text "        "
!byte 158
!text "1-3"
!byte 5
!text " SPEED  "
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

; Five expansion stages, sixteen points per stage. Signed offsets are stored
; as bytes; normal 6502 wrapping performs the addition around the burst center.
burst_dx:
!byte 0,1,1,1,0,$ff,$ff,$ff,0,1,0,$ff,1,1,$ff,$ff
!byte 0,1,2,1,0,$ff,$fe,$ff,2,2,0,$fe,1,1,$ff,$ff
!byte 0,2,3,2,0,$fe,$fd,$fe,3,3,0,$fd,1,1,$ff,$ff
!byte 0,2,4,2,0,$fe,$fc,$fe,4,3,0,$fc,1,1,$ff,$ff
!byte 0,3,5,3,0,$fd,$fb,$fd,5,4,0,$fb,2,2,$fe,$fe
burst_dy:
!byte $ff,$ff,0,1,1,1,0,$ff,$ff,0,1,0,$ff,1,1,$ff
!byte $fe,$ff,0,1,2,1,0,$ff,$fe,0,2,0,$ff,1,1,$ff
!byte $fd,$fe,0,2,3,2,0,$fe,$fd,0,3,0,$ff,1,1,$ff
!byte $fc,$fe,0,2,4,2,0,$fe,$fc,0,4,0,$ff,1,1,$ff
!byte $fb,$fd,0,3,5,3,0,$fd,$fb,0,5,0,$fe,2,2,$fe

burst_chars: !byte 81,42,43,46,46
particle_colors: !byte 1,7,10,8,2,5,3,13,1,7,10,8,2,5,3,13
star_x: !byte 2,5,8,11,14,17,20,23,26,29,32,35,38,4,10,27,34,16
star_y: !byte 3,8,5,12,4,9,3,13,6,10,4,8,12,15,17,16,14,6
building_height:
!byte 3,3,4,4,4,6,6,6,5,5,3,3,7,7,7,7,4,4,5,5
!byte 5,8,8,8,6,6,4,4,4,7,7,7,5,5,6,6,6,3,3,3
window_x: !byte 2,6,9,13,16,19,22,25,29,32,35,38
window_y: !byte 23,21,22,20,23,22,19,21,20,22,21,23

screen_row_lo: !for i,0,24 { !byte <(SCREEN+i*40) }
screen_row_hi: !for i,0,24 { !byte >(SCREEN+i*40) }
color_row_lo:  !for i,0,24 { !byte <(COLOR+i*40) }
color_row_hi:  !for i,0,24 { !byte >(COLOR+i*40) }

show_state: !byte 0
palette: !byte 0
auto_show: !byte 0
auto_countdown: !byte 0
animation_speed: !byte 0
tick: !byte 0
last_jiffy: !byte 0
seed: !byte 0
center_x: !byte 0
rocket_x: !byte 0
rocket_y: !byte 0
trail_length: !byte 0
explosion_stage: !byte 0
particle: !byte 0
plot_x: !byte 0
plot_y: !byte 0
character: !byte 0
character_color: !byte 0
height_left: !byte 0
object_index: !byte 0
old_border: !byte 0
old_background: !byte 0
old_volume: !byte 0
old_sid: !fill 7,0
