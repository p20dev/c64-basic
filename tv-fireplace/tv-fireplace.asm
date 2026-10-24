!cpu 6510

; TV FIREPLACE
; A warm PETSCII fireplace with animated flames, embers and SID crackles.
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
    inc frame_divider
    lda frame_divider
    cmp animation_speed
    bcc sound_only
    lda #0
    sta frame_divider
    jsr update_fire
sound_only:
    lda sound_muted
    bne main_loop
    jsr update_sound
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
    sta sound_muted
    sta quit_flag
    sta frame_divider
    sta flame_phase
    sta palette_index
    sta stoke_timer
    sta crackle_timer
    lda #2
    sta animation_speed
    lda #$6d
    sta random_seed
    lda $a2
    sta last_jiffy
    lda #0
    sta $d020
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
    jsr clear_screen
    jsr draw_fireplace
    jsr initialize_sid
    jsr update_fire
    rts

clear_screen:
    ldx #0
clear_loop:
    lda #32
    sta SCREEN,x
    sta SCREEN+256,x
    sta SCREEN+512,x
    sta SCREEN+768,x
    lda #0
    sta COLOR,x
    sta COLOR+256,x
    sta COLOR+512,x
    sta COLOR+768,x
    inx
    bne clear_loop
    rts

draw_fireplace:
    ; Broad wooden mantel on rows 3 and 4.
    ldx #0
mantel_loop:
    lda #160
    sta SCREEN+124,x
    sta SCREEN+164,x
    lda #9
    sta COLOR+124,x
    lda #8
    sta COLOR+164,x
    inx
    cpx #32
    bne mantel_loop

    ; Brick columns frame the firebox.
    lda #5
    sta draw_row
brick_row_loop:
    ldx draw_row
    lda screen_row_lo,x
    sta $fb
    lda screen_row_hi,x
    sta $fc
    lda color_row_lo,x
    sta $fd
    lda color_row_hi,x
    sta $fe
    ldy #5
left_bricks:
    tya
    eor draw_row
    and #1
    tax
    lda brick_chars,x
    sta ($fb),y
    lda palette_index
    asl
    tax
    tya
    and #1
    beq left_color
    inx
left_color:
    lda brick_colors,x
    sta ($fd),y
    iny
    cpy #11
    bne left_bricks
    ldy #29
right_bricks:
    tya
    eor draw_row
    and #1
    tax
    lda brick_chars,x
    sta ($fb),y
    lda palette_index
    asl
    tax
    tya
    and #1
    beq right_color
    inx
right_color:
    lda brick_colors,x
    sta ($fd),y
    iny
    cpy #35
    bne right_bricks
    inc draw_row
    lda draw_row
    cmp #20
    bne brick_row_loop

    ; Stone hearth and warm wooden logs.
    ldx #0
hearth_loop:
    lda #160
    sta SCREEN+804,x
    sta SCREEN+844,x
    lda #11
    sta COLOR+804,x
    lda #12
    sta COLOR+844,x
    inx
    cpx #32
    bne hearth_loop
    ldx #0
logs_loop:
    lda log_chars,x
    sta SCREEN+771,x
    lda log_colors,x
    sta COLOR+771,x
    inx
    cpx #18
    bne logs_loop
    rts

update_fire:
    inc flame_phase
    lda stoke_timer
    beq build_heights
    dec stoke_timer
build_heights:
    ldx #0
height_loop:
    txa
    clc
    adc flame_phase
    and #15
    tay
    lda flame_wave,y
    sta work_value
    jsr random_byte
    and #1
    clc
    adc work_value
    ldy stoke_timer
    beq store_height
    cmp #0
    beq store_height
    clc
    adc #2
    cmp #10
    bcc store_height
    lda #9
store_height:
    sta flame_heights,x
    inx
    cpx #16
    bne height_loop

    lda #0
    sta flame_level
level_loop:
    ldx flame_level
    lda flame_row_lo,x
    sta $fb
    lda flame_row_hi,x
    sta $fc
    lda flame_color_lo,x
    sta $fd
    lda flame_color_hi,x
    sta $fe
    ldx #0
cell_loop:
    lda flame_heights,x
    cmp flame_level
    beq empty_cell
    bcc empty_cell
    stx flame_column
    jsr random_byte
    and #3
    tay
    ldx flame_level
    cpx #3
    bcc choose_body_char
    lda top_chars,y
    bne write_flame_char
choose_body_char:
    lda body_chars,y
write_flame_char:
    sta temp_char
    ldx flame_column
    txa
    clc
    adc #12
    tay
    sta work_column
    lda temp_char
store_flame:
    sta ($fb),y
    ldx palette_index
    lda palette_offsets,x
    clc
    adc flame_level
    tax
    lda flame_colors,x
    sta ($fd),y
    ldx flame_column
    jmp next_cell
empty_cell:
    txa
    clc
    adc #12
    tay
    lda #32
    sta ($fb),y
    lda #0
    sta ($fd),y
next_cell:
    inx
    cpx #16
    bne cell_loop
    inc flame_level
    lda flame_level
    cmp #9
    beq levels_done
    jmp level_loop
levels_done:
    jsr draw_sparks
    jsr draw_embers
    rts

draw_sparks:
    ; Clear the two rows above the flames.
    ldx #0
clear_sparks:
    lda #32
    sta SCREEN+332,x
    sta SCREEN+372,x
    lda #0
    sta COLOR+332,x
    sta COLOR+372,x
    inx
    cpx #16
    bne clear_sparks
    ldx #0
spark_loop:
    jsr random_byte
    and #15
    tay
    lda #46
    sta SCREEN+332,y
    lda spark_colors,x
    sta COLOR+332,y
    jsr random_byte
    and #15
    tay
    lda #42
    sta SCREEN+372,y
    lda spark_colors+1,x
    sta COLOR+372,y
    inx
    cpx #3
    bne spark_loop
    rts

draw_embers:
    ldx #0
ember_loop:
    jsr random_byte
    and #3
    tay
    lda ember_chars,y
    sta SCREEN+732,x
    lda ember_colors,y
    sta COLOR+732,x
    inx
    cpx #16
    bne ember_loop
    rts

random_byte:
    lda random_seed
    asl
    bcc random_no_xor
    eor #$1d
random_no_xor:
    adc #$17
    sta random_seed
    rts

initialize_sid:
    ldx #0
clear_sid:
    lda #0
    sta $d400,x
    inx
    cpx #25
    bne clear_sid
    lda #$40
    sta $d405
    lda #$58
    sta $d406
    lda #$28
    sta $d400
    lda #$03
    sta $d401
    lda #$11
    sta $d404
    lda #$0f
    sta $d418
    rts

update_sound:
    lda crackle_timer
    beq maybe_crackle
    dec crackle_timer
    bne sound_done
    lda #$80
    sta $d412
    rts
maybe_crackle:
    jsr random_byte
    and #31
    bne sound_done
    lda random_seed
    sta $d40e
    and #7
    ora #2
    sta $d40f
    lda #$08
    sta $d413
    lda #$28
    sta $d414
    lda #$81
    sta $d412
    lda #2
    sta crackle_timer
sound_done:
    rts

read_controls:
    jsr GETIN
    beq controls_done
    cmp #81
    bne check_one
    lda #1
    sta quit_flag
    rts
check_one:
    cmp #49
    bne check_two
    lda #4
    sta animation_speed
    rts
check_two:
    cmp #50
    bne check_three
    lda #2
    sta animation_speed
    rts
check_three:
    cmp #51
    bne check_stoke
    lda #1
    sta animation_speed
    rts
check_stoke:
    cmp #70
    bne check_palette
    lda #90
    sta stoke_timer
    rts
check_palette:
    cmp #67
    bne check_sound
    inc palette_index
    lda palette_index
    cmp #3
    bcc redraw_bricks
    lda #0
    sta palette_index
redraw_bricks:
    jsr draw_fireplace
    rts
check_sound:
    cmp #83
    bne check_pause
    lda sound_muted
    eor #1
    sta sound_muted
    beq restore_sound
    lda #0
    sta $d418
    rts
restore_sound:
    jsr initialize_sid
    rts
check_pause:
    cmp #32
    bne controls_done
    lda paused
    eor #1
    sta paused
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
    ldx #0
restore_sid:
    lda old_sid,x
    sta $d400,x
    inx
    cpx #25
    bne restore_sid
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
!text "              TV FIREPLACE"
!byte 13,13,5
!text "   A WARM HEARTH OF FLAME AND EMBERS"
!byte 13,13,13,153
!text "                CONTROLS"
!byte 13,13,158
!text " 1-3"
!byte 5
!text " SPEED   "
!byte 158
!text "F"
!byte 5
!text " STOKE   "
!byte 158
!text "C"
!byte 5
!text " PALETTE"
!byte 13,158
!text " SPACE"
!byte 5
!text " PAUSE   "
!byte 158
!text "S"
!byte 5
!text " SOUND   "
!byte 158
!text "Q"
!byte 5
!text " QUIT"
!byte 13,13,13,5
!text "          HTTPS://C64.P20.DEV"
!byte 13,13,152
!text "        RELEASED 24 OCTOBER 2026"
!byte 13,13,13,158
!text "         PRESS SPACE TO START"
!byte 0

brick_chars: !byte 160,102
brick_colors: !byte 9,8,2,9,12,15
palette_offsets: !byte 0,9,18
flame_colors:
!byte 7,7,7,8,8,8,2,2,2
!byte 1,7,7,7,8,8,10,2,2
!byte 7,7,3,3,14,14,6,6,6
body_chars: !byte 160,160,102,160
top_chars: !byte 102,46,42,102
flame_wave: !byte 0,2,4,1,3,0,5,2,0,4,1,3,5,0,2,4
spark_colors: !byte 7,8,2,7
ember_chars: !byte 46,42,102,160
ember_colors: !byte 2,8,9,7
log_chars: !byte 109,109,109,110,110,110,109,109,110,110,109,109,110,110,109,109,110,110
log_colors: !byte 9,9,8,9,8,9,9,8,9,8,9,9,8,9,8,9,9,8

screen_row_lo:
!for row,0,24 { !byte <(SCREEN + row*40) }
screen_row_hi:
!for row,0,24 { !byte >(SCREEN + row*40) }
color_row_lo:
!for row,0,24 { !byte <(COLOR + row*40) }
color_row_hi:
!for row,0,24 { !byte >(COLOR + row*40) }
flame_row_lo:
!byte <(SCREEN+720),<(SCREEN+680),<(SCREEN+640),<(SCREEN+600),<(SCREEN+560),<(SCREEN+520),<(SCREEN+480),<(SCREEN+440),<(SCREEN+400)
flame_row_hi:
!byte >(SCREEN+720),>(SCREEN+680),>(SCREEN+640),>(SCREEN+600),>(SCREEN+560),>(SCREEN+520),>(SCREEN+480),>(SCREEN+440),>(SCREEN+400)
flame_color_lo:
!byte <(COLOR+720),<(COLOR+680),<(COLOR+640),<(COLOR+600),<(COLOR+560),<(COLOR+520),<(COLOR+480),<(COLOR+440),<(COLOR+400)
flame_color_hi:
!byte >(COLOR+720),>(COLOR+680),>(COLOR+640),>(COLOR+600),>(COLOR+560),>(COLOR+520),>(COLOR+480),>(COLOR+440),>(COLOR+400)

old_border: !byte 0
old_background: !byte 0
old_d011: !byte 0
old_d016: !byte 0
old_d018: !byte 0
old_sid: !fill 25,0
paused: !byte 0
sound_muted: !byte 0
quit_flag: !byte 0
frame_divider: !byte 0
animation_speed: !byte 0
flame_phase: !byte 0
palette_index: !byte 0
stoke_timer: !byte 0
crackle_timer: !byte 0
random_seed: !byte 0
last_jiffy: !byte 0
draw_row: !byte 0
flame_level: !byte 0
flame_column: !byte 0
flame_heights: !fill 16,0
work_value: !byte 0
work_column: !byte 0
temp_char: !byte 0
