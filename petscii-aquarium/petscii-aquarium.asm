!cpu 6510

; PETSCII Aquarium
; F feeds the fish, 1-3 change speed, Q returns to BASIC.
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
    lda #14
    sta $d020
    lda #6
    sta $d021
    lda #147
    jsr CHROUT
    ldx #0
print_title:
    lda title,x
    beq initialize
    jsr CHROUT
    inx
    bne print_title

initialize:
    lda #3
    sta animation_speed
    lda #0
    sta tick
    sta phase
    sta food_active
    lda $a2
    sta last_jiffy
    jsr draw_tank
    jsr draw_all_fish
    jsr draw_all_bubbles

main_loop:
    jsr GETIN
    beq check_clock
    cmp #81
    bne check_feed
    jmp exit
check_feed:
    cmp #70
    bne check_speed_one
    lda food_active
    bne check_clock
    lda #1
    sta food_active
    lda phase
    asl
    asl
    clc
    adc #7
    cmp #36
    bcc save_food_x
    sbc #33
save_food_x:
    sta food_x
    lda #3
    sta food_y
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
    jsr animate_frame
    jmp main_loop

animate_frame:
    jsr erase_all_fish
    jsr erase_all_bubbles
    jsr erase_food
    inc phase
    jsr move_fish
    jsr move_bubbles
    jsr move_food
    jsr draw_all_fish
    jsr draw_all_bubbles
    jsr draw_food
    rts

; Fish are two characters wide. Half move every frame and half every other
; frame, giving the tank a less mechanical look.
erase_all_fish:
    ldx #0
erase_fish_loop:
    stx object_index
    jsr erase_one_fish
    ldx object_index
    inx
    cpx #6
    bne erase_fish_loop
    rts

erase_one_fish:
    lda fish_x,x
    sta plot_x
    lda fish_y,x
    sta plot_y
    lda #32
    ldy #6
    jsr plot_character
    inc plot_x
    lda #32
    ldy #6
    jsr plot_character
    rts

move_fish:
    ldx #0
move_fish_loop:
    stx object_index
    txa
    eor phase
    and #1
    bne next_fish
    lda fish_direction,x
    bmi move_fish_left
move_fish_right:
    inc fish_x,x
    lda fish_x,x
    cmp #37
    bcc next_fish
    lda #36
    sta fish_x,x
    lda #$ff
    sta fish_direction,x
    jmp next_fish
move_fish_left:
    dec fish_x,x
    lda fish_x,x
    cmp #2
    bcs next_fish
    lda #2
    sta fish_x,x
    lda #1
    sta fish_direction,x
next_fish:
    ldx object_index
    inx
    cpx #6
    bne move_fish_loop
    rts

draw_all_fish:
    ldx #0
draw_fish_loop:
    stx object_index
    lda fish_x,x
    sta plot_x
    lda fish_y,x
    sta plot_y
    ldy fish_color,x
    lda fish_direction,x
    bmi draw_left_fish
    lda #62
    jsr plot_character
    inc plot_x
    lda #41
    ldy fish_color,x
    jsr plot_character
    jmp fish_drawn
draw_left_fish:
    lda #40
    jsr plot_character
    inc plot_x
    lda #60
    ldy fish_color,x
    jsr plot_character
fish_drawn:
    ldx object_index
    inx
    cpx #6
    bne draw_fish_loop
    rts

erase_all_bubbles:
    ldx #0
erase_bubble_loop:
    stx object_index
    lda bubble_x,x
    sta plot_x
    lda bubble_y,x
    sta plot_y
    lda #32
    ldy #6
    jsr plot_character
    ldx object_index
    inx
    cpx #5
    bne erase_bubble_loop
    rts

move_bubbles:
    lda phase
    and #1
    bne bubbles_done
    ldx #0
move_bubble_loop:
    dec bubble_y,x
    lda bubble_y,x
    cmp #3
    bcs next_bubble
    lda #21
    sta bubble_y,x
    lda bubble_x,x
    clc
    adc #11
    cmp #37
    bcc store_bubble_x
    sbc #34
store_bubble_x:
    sta bubble_x,x
next_bubble:
    inx
    cpx #5
    bne move_bubble_loop
bubbles_done:
    rts

draw_all_bubbles:
    ldx #0
draw_bubble_loop:
    stx object_index
    lda bubble_x,x
    sta plot_x
    lda bubble_y,x
    sta plot_y
    lda phase
    and #2
    beq small_bubble
    lda #81
    bne paint_bubble
small_bubble:
    lda #46
paint_bubble:
    ldy #3
    jsr plot_character
    ldx object_index
    inx
    cpx #5
    bne draw_bubble_loop
    rts

erase_food:
    lda food_active
    beq erase_food_done
    lda food_x
    sta plot_x
    lda food_y
    sta plot_y
    lda #32
    ldy #6
    jsr plot_character
erase_food_done:
    rts

move_food:
    lda food_active
    beq move_food_done
    inc food_y
    lda food_y
    cmp #22
    bcc move_food_done
    lda #0
    sta food_active
move_food_done:
    rts

draw_food:
    lda food_active
    beq draw_food_done
    lda food_x
    sta plot_x
    lda food_y
    sta plot_y
    lda #46
    ldy #8
    jsr plot_character
draw_food_done:
    rts

draw_tank:
    ; Top and bottom glass.
    ldx #0
horizontal_glass:
    stx plot_x
    lda #2
    sta plot_y
    lda #160
    ldy #3
    jsr plot_character
    lda #23
    sta plot_y
    lda #160
    ldy #3
    jsr plot_character
    inx
    cpx #40
    bne horizontal_glass

    ; Side glass.
    ldx #3
vertical_glass:
    stx plot_y
    lda #0
    sta plot_x
    lda #160
    ldy #3
    jsr plot_character
    lda #39
    sta plot_x
    lda #160
    ldy #3
    jsr plot_character
    inx
    cpx #23
    bne vertical_glass

    ; Sandy floor.
    ldx #1
sand_loop:
    stx plot_x
    lda #22
    sta plot_y
    txa
    and #1
    beq sand_dot
    lda #58
    bne sand_plot
sand_dot:
    lda #46
sand_plot:
    ldy #7
    jsr plot_character
    inx
    cpx #39
    bne sand_loop

    ; Five clusters of seaweed.
    ldx #0
plant_loop:
    stx object_index
    lda plant_x,x
    sta plot_x
    lda #21
    sta plot_y
    lda #93
    ldy #5
    jsr plot_character
    dec plot_y
    lda #94
    ldy #5
    jsr plot_character
    dec plot_y
    lda #93
    ldy #5
    jsr plot_character
    ldx object_index
    inx
    cpx #5
    bne plant_loop
    rts

; A = screen code, X/Y are supplied through plot_x/plot_y, Y = color.
plot_character:
    sta character
    sty character_color
    ldy plot_y
    lda screen_row_lo,y
    sta $fb
    lda screen_row_hi,y
    sta $fc
    ldy plot_x
    lda character
    sta ($fb),y
    ; Color RAM uses the same row/column layout as screen RAM.
    ldy plot_y
    lda color_row_lo_table,y
    sta $fd
    lda color_row_hi_table,y
    sta $fe
    lda character_color
    ldy plot_x
    sta ($fd),y
    rts

exit:
    lda old_border
    sta $d020
    lda old_background
    sta $d021
    lda #147
    jsr CHROUT
    rts

title: !byte 147
!text "PETSCII AQUARIUM  F FEED  1-3 SPEED  Q QUIT"
!byte 0

fish_x:         !byte 4,28,12,33,7,23
fish_y:         !byte 5,8,11,14,17,20
fish_direction: !byte 1,$ff,1,$ff,1,$ff
fish_color:     !byte 7,10,8,13,2,15
bubble_x:       !byte 6,14,21,29,35
bubble_y:       !byte 18,12,20,8,16
plant_x:        !byte 5,12,20,28,35

screen_row_lo: !for i,0,24 { !byte <(SCREEN+i*40) }
screen_row_hi: !for i,0,24 { !byte >(SCREEN+i*40) }
color_row_lo_table: !for i,0,24 { !byte <(COLOR+i*40) }
color_row_hi_table: !for i,0,24 { !byte >(COLOR+i*40) }

animation_speed: !byte 0
tick: !byte 0
phase: !byte 0
last_jiffy: !byte 0
food_active: !byte 0
food_x: !byte 0
food_y: !byte 0
plot_x: !byte 0
plot_y: !byte 0
character: !byte 0
character_color: !byte 0
object_index: !byte 0
old_border: !byte 0
old_background: !byte 0
