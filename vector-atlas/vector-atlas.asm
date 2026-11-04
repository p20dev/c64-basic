!cpu 6510
; VECTOR ATLAS -- live wireframe rasterizer for three regular solids.
; Cube: 8 vertices/12 edges. Octahedron: 6/12. Icosahedron: 12/30.
; Perspective vertex tables come from normalized 3D models rotated about
; two axes. Only vertices are stored, never pre-rendered animated frames.
; A bounded Bresenham rasterizer draws 96 points per tick into a hidden
; multicolor bitmap; completed frames flip at raster 250. Clear/palette work
; is split into separate ticks. KERNAL IRQs and CIA timers are unchanged.
; Z depth selects edge brightness; crossings add light. Static stage pixels
; sit outside the cleared region. PAL/NTSC SID pitch and 50 Hz normalization.
; BASIC ROM is banked out only to read vertex data; CPU port is restored.
; SID is silenced on exit (write-only registers cannot recover a prior tune).
; Memory: code $1000, bitmaps $2000/$6000, screens $0400/$4400, score $4000,
; tuning $4c00, pixel lookup $5000, stage $8000, model poses $a000-$baff.

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
    jsr render_tick
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
    sta palette
    sta phase
    sta pending
    sta stage
    sta song_step
    sta unit_tick
    sta ntsc_divider
    sta tour_count
    lda #2
    sta model
    lda #1
    sta automatic
    sta speed
    lda #5
    sta base_frames
    sta frames_per_unit
    lda #$40
    sta target_bank
    lda old_bank
    ora #3
    sta $dd00
    lda #$18
    sta $d018
    sta $d016
    ldx #0
copy_stage:
!for page,0,31 {
    lda backdrop+page*256,x
    sta $2000+page*256,x
    sta $6000+page*256,x
}
    lda #$6e
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    sta $4400,x
    sta $4500,x
    sta $4600,x
    sta $4700,x
    lda #1
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    beq stage_copied
    jmp copy_stage
stage_copied:
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

render_tick:
    lda stage
    bne not_setup
    jmp setup_frame
not_setup:
    cmp #1
    bne raster_tick
    jmp clear_region
raster_tick:
    lda #96
    sta budget
point_loop:
    lda line_active
    bne have_line
    jsr setup_line
have_line:
    jsr plot
    dec steps
    bne advance
    lda #0
    sta line_active
    inc edge_index
    lda edge_index
    cmp edge_count
    bcc point_done
    lda #1
    sta pending
    rts
advance:
    lda major_axis
    bne y_major
    clc
    lda px
    adc sx
    sta px
    lda error
    sec
    sbc minor
    bcs store_error
    clc
    adc major
    sta error
    clc
    lda py
    adc sy
    sta py
    jmp point_done
y_major:
    clc
    lda py
    adc sy
    sta py
    lda error
    sec
    sbc minor
    bcs store_error
    clc
    adc major
    sta error
    clc
    lda px
    adc sx
    sta px
    jmp point_done
store_error:
    sta error
point_done:
    dec budget
    beq budget_done
    jmp point_loop
budget_done:
    rts

setup_frame:
    lda model
    sta frame_model
    tax
    lda edge_counts,x
    sta edge_count
    lda edges_a_lo,x
    sta read_edge_a+1
    lda edges_a_hi,x
    sta read_edge_a+2
    lda edges_b_lo,x
    sta read_edge_b+1
    lda edges_b_hi,x
    sta read_edge_b+2
    lda phase
    tax
    lda pose_lo,x
    sta $fb
    lda pose_hi,x
    ldx model
    clc
    adc model_hi,x
    sta $fc
    lda $01
    pha
    and #$fe
    sta $01
    ldy #0
copy_vertices:
    lda ($fb),y
    sta vx,y
    iny
    cpy #36
    bne copy_vertices
    pla
    sta $01
    ; Both matrices use private screen RAM; shared color RAM stays unchanged.
    lda target_bank
    beq palette_zero
    lda #$44
    bne palette_base
palette_zero:
    lda #4
palette_base:
    sta palette_a+2
    clc
    adc #1
    sta palette_b+2
    clc
    adc #1
    sta palette_c+2
    clc
    adc #1
    sta palette_d+2
    ldx palette
    lda palette_values,x
    ldx #0
palette_loop:
palette_a: sta $4400,x
palette_b: sta $4500,x
palette_c: sta $4600,x
palette_d: sta $4700,x
    inx
    bne palette_loop
    lda #0
    sta edge_index
    sta line_active
    inc stage
    rts

clear_region:
    lda #0
    ldx #0
    ldy target_bank
    bne clear_bank_one
clear_bank_zero:
!for row,4,19 {
    sta $2000+row*320+12*8,x
}
    inx
    cpx #128
    bne clear_bank_zero
    beq cleared
clear_bank_one:
!for row,4,19 {
    sta $6000+row*320+12*8,x
}
    inx
    cpx #128
    bne clear_bank_one
cleared:
    inc stage
    rts

setup_line:
    ldx edge_index
read_edge_a: lda cube_a,x
    tay
    lda vx,y
    sta px
    lda vy,y
    sta py
    lda vz,y
    sta depth
read_edge_b: lda cube_b,x
    tay
    lda vx,y
    sta end_x
    lda vy,y
    sta end_y
    lda vz,y
    clc
    adc depth
    ; Larger Z is farther from the viewer. Carry means average Z >=128.
    bcs faint_edge
    lda #<bright_bits
    sta color_bits+1
    lda #>bright_bits
    bne edge_color_ready
faint_edge:
    lda #<dim_bits
    sta color_bits+1
    lda #>dim_bits
edge_color_ready:
    sta color_bits+2
    lda #1
    sta sx
    sta sy
    lda end_x
    sec
    sbc px
    bcs positive_x
    eor #$ff
    clc
    adc #1
    ldx #$ff
    stx sx
positive_x:
    sta dx
    lda end_y
    sec
    sbc py
    bcs positive_y
    eor #$ff
    clc
    adc #1
    ldx #$ff
    stx sy
positive_y:
    sta dy
    cmp dx
    bcc use_x_major
    lda #1
    sta major_axis
    lda dy
    sta major
    lda dx
    sta minor
    jmp line_ready
use_x_major:
    lda #0
    sta major_axis
    lda dx
    sta major
    lda dy
    sta minor
line_ready:
    lda major
    lsr
    sta error
    lda major
    clc
    adc #1
    sta steps
    lda #1
    sta line_active
    rts

plot:
    ldx px
    ldy py
    lda row_lo,y
    clc
    adc col_lo,x
    sta $fb
    lda row_hi,y
    adc col_hi,x
    eor target_bank
    sta $fc
    ldy #0
    lda ($fb),y
color_bits: ora bright_bits,x
    sta ($fb),y
    rts

publish:
    lda old_bank
    and #$fc
    ldx target_bank
    beq show_zero
    ora #2
    bne show_bank
show_zero:
    ora #3
show_bank:
    sta $dd00
    lda target_bank
    eor #$40
    sta target_bank
    lda phase
    clc
    adc speed
    and #63
    sta phase
    lda #0
    sta stage
    sta pending
    lda automatic
    beq published
    inc tour_count
    lda tour_count
    cmp #64
    bcc published
    lda #0
    sta tour_count
    inc model
    lda model
    cmp #3
    bcc published
    lda #0
    sta model
published:
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
    ; Original geometric synth theme; alternating five/six 50 Hz ticks.
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
    bne check_shapes
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
check_shapes:
    cmp #49
    bcc check_color
    cmp #52
    bcs check_color
    sec
    sbc #49
    sta model
    lda #0
    sta automatic
    sta tour_count
    sta stage
    sta pending
    rts
check_color:
    cmp #67
    bne check_auto
    inc palette
    lda palette
    cmp #3
    bcc controls_done
    lda #0
    sta palette
    rts
check_auto:
    cmp #65
    bne check_fast
    lda automatic
    eor #1
    sta automatic
    rts
check_fast:
    cmp #43
    bne check_slow
    lda speed
    cmp #3
    bcs controls_done
    inc speed
    rts
check_slow:
    cmp #45
    bne controls_done
    lda speed
    cmp #2
    bcc controls_done
    dec speed
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
old_vic: !fill 25,0
old_extra: !fill 20,0
old_pointers: !fill 8,0
old_zp: !fill 6,0
old_bank: !byte 0
old_text_color: !byte 0
paused: !byte 0
muted: !byte 0
quitting: !byte 0
stage: !byte 0
pending: !byte 0
phase: !byte 0
model: !byte 2
frame_model: !byte 2
automatic: !byte 1
tour_count: !byte 0
speed: !byte 1
palette: !byte 0
target_bank: !byte $40
budget: !byte 0
edge_index: !byte 0
edge_count: !byte 0
line_active: !byte 0
px: !byte 0
py: !byte 0
end_x: !byte 0
end_y: !byte 0
sx: !byte 1
sy: !byte 1
dx: !byte 0
dy: !byte 0
major: !byte 0
minor: !byte 0
major_axis: !byte 0
error: !byte 0
steps: !byte 0
depth: !byte 0
unit_tick: !byte 0
song_step: !byte 0
ntsc_divider: !byte 0
frames_per_unit: !byte 5
base_frames: !byte 5
drum_release_control: !byte $80
freq_lo: !fill 96,0
freq_hi: !fill 96,0
vx: !fill 12,0
vy: !fill 12,0
vz: !fill 12,0
edge_counts: !byte 12,12,30
model_hi: !byte $a0,$a9,$b2
palette_values: !byte $6e,$28,$5d

splash:
!byte 13,13,13,154
!text "              VECTOR ATLAS"
!byte 13,13,5
!text " THREE SOLIDS. PERSPECTIVE. PURE LINES."
!byte 13
!text "     AN ORIGINAL THREE-VOICE SID SCORE."
!byte 13,13,13,153
!text "                CONTROLS"
!byte 13,13,158
!text " 1/2/3"
!byte 5
!text " CUBE / OCTAHEDRON / ICOSAHEDRON"
!byte 13,158
!text " +/-"
!byte 5
!text " SPEED  "
!byte 158
!text "C"
!byte 5
!text " COLORS  "
!byte 158
!text "A"
!byte 5
!text " AUTO SHAPES"
!byte 13,158
!text " M"
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
!text "        RELEASED 4 NOVEMBER 2026"
!byte 13,13,13,158
!text "         PRESS SPACE TO START"
!byte 0
!if * > $2000 { !error "Code overlaps bitmap" }

* = $4000
; Original sixteen-bar Bm7/Gmaj7/Dmaj7/Aadd9 score.
melody:
!byte 59,66,62,69,66,0,59,62,69,66,62,66,59,0,66,69
!byte 55,62,59,66,62,0,55,59,66,62,59,62,55,0,62,255
!byte 62,69,66,73,69,0,62,66,73,69,66,69,62,0,69,73
!byte 57,64,61,71,64,0,57,61,71,64,61,64,57,0,64,255
!byte 69,66,62,59,62,0,66,62,66,59,62,66,69,0,66,62
!byte 66,62,59,55,59,0,62,59,62,55,59,62,66,0,62,255
!byte 73,69,66,62,66,0,69,66,69,62,66,69,73,0,69,66
!byte 71,64,61,57,61,0,64,61,64,57,61,64,71,0,64,255
!byte 59,62,69,66,62,0,59,62,66,69,59,66,62,0,66,62
!byte 55,59,66,62,59,0,55,59,62,66,55,62,59,0,62,255
!byte 62,66,73,69,66,0,62,66,69,73,62,69,66,0,69,66
!byte 57,61,71,64,61,0,57,61,64,71,57,64,61,0,64,255
!byte 66,62,66,59,62,0,69,59,66,62,69,66,62,0,62,69
!byte 62,59,62,55,59,0,66,55,62,59,66,62,59,0,59,255
!byte 69,66,69,62,66,0,73,62,69,66,73,69,66,0,66,73
!byte 64,61,64,57,61,0,71,57,64,61,71,64,61,0,61,255
bass_notes:
!byte 35,35,35,35,35,35,47,35,35,35,35,35,35,35,47,35
!byte 31,31,31,31,31,31,43,31,31,31,31,31,31,31,43,31
!byte 38,38,38,38,38,38,50,38,38,38,38,38,38,38,50,38
!byte 33,33,33,33,33,33,45,33,33,33,33,33,33,33,45,33
!byte 35,35,35,35,35,35,47,35,35,35,35,35,35,35,47,35
!byte 31,31,31,31,31,31,43,31,31,31,31,31,31,31,43,31
!byte 38,38,38,38,38,38,50,38,38,38,38,38,38,38,50,38
!byte 33,33,33,33,33,33,45,33,33,33,33,33,33,33,45,33
!byte 35,35,35,35,35,35,47,35,35,35,35,35,35,35,47,35
!byte 31,31,31,31,31,31,43,31,31,31,31,31,31,31,43,31
!byte 38,38,38,38,38,38,50,38,38,38,38,38,38,38,50,38
!byte 33,33,33,33,33,33,45,33,33,33,33,33,33,33,45,33
!byte 35,35,35,35,35,35,47,35,35,35,35,35,35,35,47,35
!byte 31,31,31,31,31,31,43,31,31,31,31,31,31,31,43,31
!byte 38,38,38,38,38,38,50,38,38,38,38,38,38,38,50,38
!byte 33,33,33,33,33,33,45,33,33,33,33,33,33,33,45,33
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
pose_lo:
!byte 0,36,72,108,144,180,216,252,32,68,104,140,176,212,248,28
!byte 64,100,136,172,208,244,24,60,96,132,168,204,240,20,56,92
!byte 128,164,200,236,16,52,88,124,160,196,232,12,48,84,120,156
!byte 192,228,8,44,80,116,152,188,224,4,40,76,112,148,184,220
pose_hi:
!byte 0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,2
!byte 2,2,2,2,2,2,3,3,3,3,3,3,3,4,4,4
!byte 4,4,4,4,5,5,5,5,5,5,5,6,6,6,6,6
!byte 6,6,7,7,7,7,7,7,7,8,8,8,8,8,8,8
cube_a:
!byte 0,0,0,1,1,2,2,3,4,4,5,6
cube_b:
!byte 1,2,4,3,5,3,6,7,5,6,7,7
octa_a:
!byte 0,0,0,0,1,1,1,1,2,2,3,3
octa_b:
!byte 2,3,4,5,2,3,4,5,4,5,4,5
icosa_a:
!byte 0,0,0,0,0,1,1,1,1,2,2,2,3,3,3,3
!byte 4,4,4,4,5,5,5,5,6,7,8,9,9,10
icosa_b:
!byte 1,2,5,6,7,2,3,7,8,4,6,8,7,8,9,11
!byte 6,8,9,10,6,7,10,11,10,11,9,10,11,11
edges_a_lo: !byte <cube_a,<octa_a,<icosa_a
edges_a_hi: !byte >cube_a,>octa_a,>icosa_a
edges_b_lo: !byte <cube_b,<octa_b,<icosa_b
edges_b_hi: !byte >cube_b,>octa_b,>icosa_b
!if * > $5000 { !error "Model metadata overlaps pixel lookup" }
* = $5000
row_lo:
!byte 0,1,2,3,4,5,6,7,64,65,66,67,68,69,70,71
!byte 128,129,130,131,132,133,134,135,192,193,194,195,196,197,198,199
!byte 0,1,2,3,4,5,6,7,64,65,66,67,68,69,70,71
!byte 128,129,130,131,132,133,134,135,192,193,194,195,196,197,198,199
!byte 0,1,2,3,4,5,6,7,64,65,66,67,68,69,70,71
!byte 128,129,130,131,132,133,134,135,192,193,194,195,196,197,198,199
!byte 0,1,2,3,4,5,6,7,64,65,66,67,68,69,70,71
!byte 128,129,130,131,132,133,134,135,192,193,194,195,196,197,198,199
!byte 0,1,2,3,4,5,6,7,64,65,66,67,68,69,70,71
!byte 128,129,130,131,132,133,134,135,192,193,194,195,196,197,198,199
!byte 0,1,2,3,4,5,6,7,64,65,66,67,68,69,70,71
!byte 128,129,130,131,132,133,134,135,192,193,194,195,196,197,198,199
!byte 0,1,2,3,4,5,6,7
row_hi:
!byte 32,32,32,32,32,32,32,32,33,33,33,33,33,33,33,33
!byte 34,34,34,34,34,34,34,34,35,35,35,35,35,35,35,35
!byte 37,37,37,37,37,37,37,37,38,38,38,38,38,38,38,38
!byte 39,39,39,39,39,39,39,39,40,40,40,40,40,40,40,40
!byte 42,42,42,42,42,42,42,42,43,43,43,43,43,43,43,43
!byte 44,44,44,44,44,44,44,44,45,45,45,45,45,45,45,45
!byte 47,47,47,47,47,47,47,47,48,48,48,48,48,48,48,48
!byte 49,49,49,49,49,49,49,49,50,50,50,50,50,50,50,50
!byte 52,52,52,52,52,52,52,52,53,53,53,53,53,53,53,53
!byte 54,54,54,54,54,54,54,54,55,55,55,55,55,55,55,55
!byte 57,57,57,57,57,57,57,57,58,58,58,58,58,58,58,58
!byte 59,59,59,59,59,59,59,59,60,60,60,60,60,60,60,60
!byte 62,62,62,62,62,62,62,62
col_lo:
!byte 0,0,0,0,8,8,8,8,16,16,16,16,24,24,24,24
!byte 32,32,32,32,40,40,40,40,48,48,48,48,56,56,56,56
!byte 64,64,64,64,72,72,72,72,80,80,80,80,88,88,88,88
!byte 96,96,96,96,104,104,104,104,112,112,112,112,120,120,120,120
!byte 128,128,128,128,136,136,136,136,144,144,144,144,152,152,152,152
!byte 160,160,160,160,168,168,168,168,176,176,176,176,184,184,184,184
!byte 192,192,192,192,200,200,200,200,208,208,208,208,216,216,216,216
!byte 224,224,224,224,232,232,232,232,240,240,240,240,248,248,248,248
!byte 0,0,0,0,8,8,8,8,16,16,16,16,24,24,24,24
!byte 32,32,32,32,40,40,40,40,48,48,48,48,56,56,56,56
col_hi:
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
!byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
dim_bits:
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
!byte 64,16,4,1,64,16,4,1,64,16,4,1,64,16,4,1
bright_bits:
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!byte 192,48,12,3,192,48,12,3,192,48,12,3,192,48,12,3
!if * > $6000 { !error "Pixel tables overlap bitmap" }
* = $8000
; Original static stars and perspective stage; animated area stays black.
backdrop:
!byte 2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,128,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 128,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,32,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,32,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,32,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,8,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,128,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0
!byte 0,0,0,0,0,0,48,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,32,0,0,12,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,8,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,8,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,128,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,130,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,32,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,128,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,12,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,128,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,12,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,128,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,48,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,32,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,32,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,2,0,0,0,0,0,0,0,8,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,128
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,128,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,21,0,0,0,0,0,0,85,85
!byte 0,0,0,0,0,0,85,85,0,0,0,0,0,0,85,85
!byte 0,0,0,0,0,0,85,21,0,0,0,0,0,0,85,85
!byte 0,0,0,0,0,0,85,85,0,0,0,0,0,0,85,85
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,0,0,0,0,85,0,0,0,0,0,0,0,85,0
!byte 0,0,85,0,0,1,84,85,0,0,85,0,0,85,5,80
!byte 0,0,85,0,0,85,85,0,0,0,85,0,21,65,84,85
!byte 0,0,85,0,85,85,1,84,0,0,85,1,85,84,85,0
!byte 0,0,85,85,85,9,84,2,0,0,85,85,85,85,0,149
!byte 0,0,85,85,5,80,21,64,0,0,85,85,85,1,84,0
!byte 0,0,85,85,64,85,0,1,0,85,85,85,85,0,1,84
!byte 0,85,85,5,80,1,84,0,1,85,85,84,1,84,0,0
!byte 85,85,85,1,84,0,0,5,85,85,85,84,0,1,84,0
!byte 85,85,85,1,20,64,0,0,85,84,85,80,0,0,0,0
!byte 85,84,85,0,1,4,4,16,68,4,85,64,0,0,0,0
!byte 4,4,85,0,0,0,0,0,85,5,85,64,16,4,4,1
!byte 85,69,85,1,0,0,0,0,85,85,85,80,5,0,0,0
!byte 85,85,85,5,0,80,5,0,85,85,85,80,5,0,64,20
!byte 80,85,85,5,80,5,0,0,0,85,85,84,1,80,5,0
!byte 0,85,85,21,85,0,80,5,0,64,85,85,64,21,0,80
!byte 0,0,85,85,85,80,5,0,0,0,85,85,84,1,85,0
!byte 0,0,85,85,21,85,0,85,0,0,85,85,85,88,5,160
!byte 0,0,85,80,85,5,85,0,0,0,85,0,85,85,80,5
!byte 0,0,85,0,85,80,5,85,0,0,85,0,0,85,85,64
!byte 0,0,85,0,0,85,84,1,0,0,85,0,0,80,5,85
!byte 0,85,0,0,85,0,0,0,21,85,0,21,64,0,0,0
!byte 85,85,1,84,0,0,0,1,0,85,85,0,0,0,1,84
!byte 0,85,0,0,0,1,84,0,5,85,0,0,1,84,0,0
!byte 84,85,0,1,84,0,0,0,40,86,1,84,0,0,0,0
!byte 0,165,90,0,0,0,0,0,1,85,160,10,0,0,0,1
!byte 84,85,0,168,2,1,20,64,0,85,0,0,170,80,0,0
!byte 0,85,1,84,168,2,0,0,1,85,64,0,0,170,0,0
!byte 80,85,0,0,0,170,0,0,0,85,0,0,0,168,2,0
!byte 0,85,0,0,0,0,170,4,0,85,4,4,16,64,170,0
!byte 64,85,0,0,0,0,170,0,0,85,0,0,0,0,170,0
!byte 0,85,0,0,0,0,170,0,0,85,0,0,0,0,170,0
!byte 64,85,4,4,1,0,170,0,0,85,0,0,0,64,170,4
!byte 0,85,0,0,0,10,160,0,1,85,0,0,0,170,0,0
!byte 80,85,0,0,0,170,0,0,0,85,80,5,10,160,0,0
!byte 0,85,0,64,170,1,0,0,5,85,0,10,160,80,5,0
!byte 80,85,2,168,0,0,0,80,0,86,169,0,0,0,0,0
!byte 10,165,80,5,0,0,0,0,5,85,0,80,5,0,0,0
!byte 84,85,0,0,80,5,0,0,0,85,0,0,0,80,5,0
!byte 0,85,21,0,0,0,80,5,21,85,80,5,0,0,0,80
!byte 85,85,0,85,0,0,0,0,0,85,0,0,85,0,0,0
!byte 0,1,84,0,0,85,0,0,1,84,0,0,0,85,0,0
!byte 84,0,0,0,0,85,0,0,0,0,0,0,0,85,0,0
!byte 0,0,0,0,0,85,0,0,0,0,0,0,0,85,5,80
!byte 0,0,0,0,1,85,0,0,0,0,1,20,64,85,0,0
!byte 0,5,80,0,0,85,0,0,84,0,0,0,0,85,0,0
!byte 0,0,0,0,0,85,0,0,0,0,0,0,0,85,0,0
!byte 0,0,0,0,0,85,0,0,0,0,0,0,0,85,0,0
!byte 0,0,0,0,0,85,0,0,0,0,0,1,4,85,16,64
!byte 4,16,64,0,0,85,0,0,0,0,0,0,0,85,0,0
!byte 0,0,0,0,0,85,0,0,0,0,0,0,0,85,0,0
!byte 0,0,0,0,0,85,0,0,0,0,0,0,0,85,0,0
!byte 0,0,0,0,0,85,0,0,4,1,0,0,0,85,0,0
!byte 0,0,64,16,4,85,1,0,0,0,0,0,0,85,0,64
!byte 0,0,0,0,0,85,0,0,0,0,0,0,0,85,0,0
!byte 0,0,0,0,0,85,0,0,0,0,0,0,0,85,0,0
!byte 5,0,0,0,0,85,0,0,64,20,1,0,0,85,0,0
!byte 0,0,80,5,0,85,0,0,0,0,0,0,80,85,0,0
!byte 0,0,0,0,0,85,20,1,0,0,0,0,0,85,0,64
!byte 0,0,0,0,0,85,0,0,5,0,0,0,0,85,0,0
!byte 80,5,0,0,0,85,0,0,0,80,5,0,0,85,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
* = $a000
; Cube: 64 poses, 12 X / 12 Y / 12 Z bytes per pose.
!byte 59,65,63,67,101,95,97,93,80,80,80,80,82,55,142,104
!byte 82,55,142,104,96,96,96,96,53,146,110,203,53,146,110,203
!byte 128,128,128,128,58,67,61,69,99,98,94,94,80,80,80,80
!byte 81,52,138,101,88,56,146,105,96,96,96,96,56,147,118,208
!byte 48,138,109,200,128,128,128,128,57,70,60,70,97,100,91,95
!byte 80,80,80,80,80,49,134,97,95,58,148,107,96,96,96,96
!byte 61,146,127,213,43,129,110,195,128,128,128,128,56,72,59,72
!byte 94,102,89,96,80,80,80,80,78,47,129,94,100,61,151,108
!byte 96,96,96,96,65,145,135,216,40,121,111,191,128,128,128,128
!byte 56,75,58,74,91,104,86,97,80,80,80,80,75,45,124,91
!byte 105,65,152,110,96,96,96,96,69,144,143,218,38,113,112,187
!byte 128,128,128,128,56,78,58,75,88,105,83,97,80,80,80,80
!byte 73,44,119,88,110,69,153,113,96,96,96,96,73,142,151,219
!byte 37,105,114,183,128,128,128,128,56,80,58,77,85,107,80,98
!byte 80,80,80,80,70,43,115,86,113,74,153,115,96,96,96,96
!byte 77,139,158,220,36,98,117,179,128,128,128,128,56,83,58,79
!byte 81,107,77,98,80,80,80,80,67,43,110,85,116,78,152,118
!byte 96,96,96,96,81,136,165,220,36,91,120,175,128,128,128,128
!byte 57,85,59,81,78,108,75,98,80,80,80,80,64,43,106,84
!byte 117,83,151,120,96,96,96,96,85,133,171,219,37,85,123,171
!byte 128,128,128,128,57,87,60,83,75,107,73,98,80,80,80,80
!byte 62,43,102,83,118,88,149,123,96,96,96,96,88,130,177,218
!byte 38,79,126,168,128,128,128,128,58,89,61,85,72,107,71,98
!byte 80,80,80,80,60,44,99,83,119,92,148,125,96,96,96,96
!byte 91,126,182,216,40,74,130,165,128,128,128,128,59,91,62,86
!byte 69,107,70,97,80,80,80,80,58,44,96,83,118,96,146,127
!byte 96,96,96,96,94,123,186,215,41,70,133,162,128,128,128,128
!byte 59,92,63,88,67,106,68,97,80,80,80,80,56,45,93,83
!byte 118,100,144,129,96,96,96,96,97,119,190,213,43,66,137,159
!byte 128,128,128,128,60,94,64,89,65,105,67,97,80,80,80,80
!byte 54,46,91,84,117,103,142,131,96,96,96,96,100,116,194,210
!byte 46,62,140,156,128,128,128,128,61,95,65,90,63,103,67,96
!byte 80,80,80,80,52,47,89,84,115,106,140,133,96,96,96,96
!byte 102,113,197,208,48,59,143,154,128,128,128,128,62,96,66,92
!byte 61,102,66,96,80,80,80,80,51,49,88,85,113,109,139,135
!byte 96,96,96,96,105,110,200,205,51,56,146,151,128,128,128,128
!byte 63,97,67,93,59,101,65,95,80,80,80,80,50,50,86,86
!byte 111,111,137,137,96,96,96,96,108,108,203,203,53,53,148,148
!byte 128,128,128,128,64,98,68,94,58,99,64,94,80,80,80,80
!byte 49,51,85,88,109,113,135,139,96,96,96,96,110,105,205,200
!byte 56,51,151,146,128,128,128,128,65,99,70,95,57,97,64,93
!byte 80,80,80,80,47,52,84,89,106,115,133,140,96,96,96,96
!byte 113,102,208,197,59,48,154,143,128,128,128,128,66,100,71,96
!byte 55,95,63,93,80,80,80,80,46,54,84,91,103,117,131,142
!byte 96,96,96,96,116,100,210,194,62,46,156,140,128,128,128,128
!byte 68,101,72,97,54,93,63,92,80,80,80,80,45,56,83,93
!byte 100,118,129,144,96,96,96,96,119,97,213,190,66,43,159,137
!byte 128,128,128,128,69,101,74,98,53,91,63,90,80,80,80,80
!byte 44,58,83,96,96,118,127,146,96,96,96,96,123,94,215,186
!byte 70,41,162,133,128,128,128,128,71,102,75,99,53,88,62,89
!byte 80,80,80,80,44,60,83,99,92,119,125,148,96,96,96,96
!byte 126,91,216,182,74,40,165,130,128,128,128,128,73,103,77,100
!byte 53,85,62,87,80,80,80,80,43,62,83,102,88,118,123,149
!byte 96,96,96,96,130,88,218,177,79,38,168,126,128,128,128,128
!byte 75,103,79,101,52,82,62,85,80,80,80,80,43,64,84,106
!byte 83,117,120,151,96,96,96,96,133,85,219,171,85,37,171,123
!byte 128,128,128,128,77,104,81,102,53,79,62,83,80,80,80,80
!byte 43,67,85,110,78,116,118,152,96,96,96,96,136,81,220,165
!byte 91,36,175,120,128,128,128,128,80,104,83,102,53,75,62,80
!byte 80,80,80,80,43,70,86,115,74,113,115,153,96,96,96,96
!byte 139,77,220,158,98,36,179,117,128,128,128,128,82,104,85,102
!byte 55,72,63,77,80,80,80,80,44,73,88,119,69,110,113,153
!byte 96,96,96,96,142,73,219,151,105,37,183,114,128,128,128,128
!byte 85,104,86,102,56,69,63,74,80,80,80,80,45,75,91,124
!byte 65,105,110,152,96,96,96,96,144,69,218,143,113,38,187,112
!byte 128,128,128,128,88,104,88,101,58,66,64,71,80,80,80,80
!byte 47,78,94,129,61,100,108,151,96,96,96,96,145,65,216,135
!byte 121,40,191,111,128,128,128,128,90,103,90,100,60,63,65,69
!byte 80,80,80,80,49,80,97,134,58,95,107,148,96,96,96,96
!byte 146,61,213,127,129,43,195,110,128,128,128,128,93,102,91,99
!byte 62,61,66,66,80,80,80,80,52,81,101,138,56,88,105,146
!byte 96,96,96,96,147,56,208,118,138,48,200,109,128,128,128,128
!byte 95,101,93,97,65,59,67,63,80,80,80,80,55,82,104,142
!byte 55,82,104,142,96,96,96,96,146,53,203,110,146,53,203,110
!byte 128,128,128,128,97,99,94,95,68,58,68,61,80,80,80,80
!byte 58,83,109,146,54,76,104,139,96,96,96,96,145,49,198,102
!byte 154,58,207,111,128,128,128,128,99,97,95,92,70,58,70,59
!byte 80,80,80,80,61,82,113,148,54,71,104,135,96,96,96,96
!byte 143,46,191,94,162,65,210,113,128,128,128,128,101,95,96,90
!byte 73,57,71,58,80,80,80,80,64,81,117,150,55,66,105,131
!byte 96,96,96,96,140,44,183,87,169,73,212,116,128,128,128,128
!byte 102,93,97,87,75,58,73,57,80,80,80,80,67,78,121,150
!byte 56,62,106,127,96,96,96,96,137,42,175,80,176,81,214,119
!byte 128,128,128,128,103,91,97,84,77,58,74,56,80,80,80,80
!byte 69,76,125,150,57,59,108,124,96,96,96,96,132,40,166,74
!byte 182,90,216,124,128,128,128,128,104,88,98,81,79,59,75,56
!byte 80,80,80,80,71,73,128,149,59,57,109,121,96,96,96,96
!byte 128,40,157,69,187,99,216,128,128,128,128,128,105,85,98,78
!byte 81,59,77,56,80,80,80,80,72,69,131,147,61,56,111,119
!byte 96,96,96,96,123,40,148,66,190,108,216,133,128,128,128,128
!byte 106,83,99,76,83,60,78,56,80,80,80,80,73,66,133,145
!byte 63,56,113,118,96,96,96,96,117,41,139,63,193,117,215,139
!byte 128,128,128,128,106,80,99,73,85,61,80,57,80,80,80,80
!byte 73,63,135,143,65,56,115,117,96,96,96,96,112,43,129,61
!byte 195,127,213,144,128,128,128,128,106,77,99,71,86,61,82,57
!byte 80,80,80,80,72,60,136,141,67,57,117,117,96,96,96,96
!byte 106,45,120,60,196,136,211,150,128,128,128,128,106,74,100,68
!byte 88,62,84,58,80,80,80,80,70,58,137,139,68,59,119,118
!byte 96,96,96,96,100,48,112,60,196,144,208,156,128,128,128,128
!byte 105,71,100,66,89,63,85,60,80,80,80,80,68,57,137,137
!byte 69,61,120,118,96,96,96,96,94,52,103,61,195,153,204,162
!byte 128,128,128,128,104,68,100,65,90,64,87,61,80,80,80,80
!byte 66,56,137,136,69,62,121,119,96,96,96,96,88,56,95,64
!byte 192,161,200,168,128,128,128,128,103,66,100,63,91,64,89,63
!byte 80,80,80,80,64,57,137,136,69,64,122,120,96,96,96,96
!byte 82,60,88,67,189,168,196,174,128,128,128,128,101,63,100,62
!byte 93,65,91,65,80,80,80,80,61,58,136,135,68,66,122,121
!byte 96,96,96,96,76,65,82,71,185,174,191,180,128,128,128,128
!byte 99,61,99,61,94,66,93,67,80,80,80,80,59,59,136,136
!byte 67,67,122,122,96,96,96,96,70,70,76,76,180,180,186,186
!byte 128,128,128,128,97,59,98,60,95,67,95,69,80,80,80,80
!byte 58,61,135,136,66,68,121,122,96,96,96,96,65,76,71,82
!byte 174,185,180,191,128,128,128,128,94,57,97,60,96,69,97,71
!byte 80,80,80,80,57,64,136,137,64,69,120,122,96,96,96,96
!byte 60,82,67,88,168,189,174,196,128,128,128,128,92,56,95,60
!byte 96,70,99,73,80,80,80,80,56,66,136,137,62,69,119,121
!byte 96,96,96,96,56,88,64,95,161,192,168,200,128,128,128,128
!byte 89,55,94,60,97,71,100,75,80,80,80,80,57,68,137,137
!byte 61,69,118,120,96,96,96,96,52,94,61,103,153,195,162,204
!byte 128,128,128,128,86,54,92,60,98,72,102,76,80,80,80,80
!byte 58,70,139,137,59,68,118,119,96,96,96,96,48,100,60,112
!byte 144,196,156,208,128,128,128,128,83,54,89,61,99,74,103,78
!byte 80,80,80,80,60,72,141,136,57,67,117,117,96,96,96,96
!byte 45,106,60,120,136,196,150,211,128,128,128,128,80,54,87,61
!byte 99,75,103,80,80,80,80,80,63,73,143,135,56,65,117,115
!byte 96,96,96,96,43,112,61,129,127,195,144,213,128,128,128,128
!byte 77,54,84,61,100,77,104,82,80,80,80,80,66,73,145,133
!byte 56,63,118,113,96,96,96,96,41,117,63,139,117,193,139,215
!byte 128,128,128,128,75,55,82,62,101,79,104,83,80,80,80,80
!byte 69,72,147,131,56,61,119,111,96,96,96,96,40,123,66,148
!byte 108,190,133,216,128,128,128,128,72,56,79,62,101,81,104,85
!byte 80,80,80,80,73,71,149,128,57,59,121,109,96,96,96,96
!byte 40,128,69,157,99,187,128,216,128,128,128,128,69,57,76,63
!byte 102,83,104,86,80,80,80,80,76,69,150,125,59,57,124,108
!byte 96,96,96,96,40,132,74,166,90,182,124,216,128,128,128,128
!byte 67,58,73,63,102,85,103,87,80,80,80,80,78,67,150,121
!byte 62,56,127,106,96,96,96,96,42,137,80,175,81,176,119,214
!byte 128,128,128,128,65,59,70,64,103,87,102,89,80,80,80,80
!byte 81,64,150,117,66,55,131,105,96,96,96,96,44,140,87,183
!byte 73,169,116,212,128,128,128,128,63,61,68,65,102,90,101,90
!byte 80,80,80,80,82,61,148,113,71,54,135,104,96,96,96,96
!byte 46,143,94,191,65,162,113,210,128,128,128,128,61,63,65,66
!byte 102,92,99,92,80,80,80,80,83,58,146,109,76,54,139,104
!byte 96,96,96,96,49,145,102,198,58,154,111,207,128,128,128,128
* = $a900
; Octahedron: 64 poses, 12 X / 12 Y / 12 Z bytes per pose.
!byte 108,53,80,80,80,80,80,80,80,80,80,80,96,96,137,41
!byte 73,134,96,96,96,96,96,96,128,128,178,78,209,47,128,128
!byte 128,128,128,128,108,53,79,81,83,76,80,80,80,80,80,80
!byte 101,91,135,42,71,136,96,96,96,96,96,96,120,136,182,74
!byte 206,50,128,128,128,128,128,128,108,54,79,82,85,72,80,80
!byte 80,80,80,80,107,86,133,43,70,137,96,96,96,96,96,96
!byte 113,143,185,71,202,54,128,128,128,128,128,128,107,56,78,83
!byte 88,68,80,80,80,80,80,80,113,82,131,44,70,137,96,96
!byte 96,96,96,96,107,149,189,67,198,58,128,128,128,128,128,128
!byte 106,58,78,83,91,64,80,80,80,80,80,80,118,77,130,46
!byte 70,135,96,96,96,96,96,96,101,155,192,64,193,63,128,128
!byte 128,128,128,128,105,59,78,84,93,61,80,80,80,80,80,80
!byte 124,73,128,47,71,133,96,96,96,96,96,96,96,160,195,61
!byte 187,69,128,128,128,128,128,128,103,61,77,84,95,59,80,80
!byte 80,80,80,80,129,69,126,49,72,130,96,96,96,96,96,96
!byte 92,164,198,58,181,75,128,128,128,128,128,128,101,63,77,84
!byte 97,57,80,80,80,80,80,80,134,66,125,51,74,126,96,96
!byte 96,96,96,96,89,167,200,56,176,80,128,128,128,128,128,128
!byte 99,65,78,84,99,55,80,80,80,80,80,80,138,63,123,52
!byte 76,123,96,96,96,96,96,96,86,170,203,53,170,86,128,128
!byte 128,128,128,128,96,68,78,84,101,54,80,80,80,80,80,80
!byte 142,61,122,54,78,119,96,96,96,96,96,96,84,172,205,51
!byte 164,92,128,128,128,128,128,128,94,70,78,83,103,53,80,80
!byte 80,80,80,80,145,59,121,55,80,115,96,96,96,96,96,96
!byte 83,173,206,50,158,98,128,128,128,128,128,128,91,71,78,83
!byte 104,52,80,80,80,80,80,80,147,57,120,56,83,111,96,96
!byte 96,96,96,96,82,174,207,49,153,103,128,128,128,128,128,128
!byte 89,73,79,82,105,52,80,80,80,80,80,80,149,56,119,57
!byte 85,108,96,96,96,96,96,96,81,175,209,47,147,109,128,128
!byte 128,128,128,128,87,75,79,82,106,52,80,80,80,80,80,80
!byte 150,55,119,58,88,105,96,96,96,96,96,96,81,175,209,47
!byte 142,114,128,128,128,128,128,128,84,77,79,81,106,52,80,80
!byte 80,80,80,80,151,55,118,59,91,102,96,96,96,96,96,96
!byte 81,175,210,46,137,119,128,128,128,128,128,128,82,78,80,81
!byte 107,52,80,80,80,80,80,80,152,54,118,59,93,99,96,96
!byte 96,96,96,96,81,175,210,46,133,123,128,128,128,128,128,128
!byte 80,80,80,80,108,53,80,80,80,80,80,80,152,54,118,59
!byte 96,96,96,96,96,96,96,96,81,175,210,46,128,128,128,128
!byte 128,128,128,128,78,82,80,79,108,53,80,80,80,80,80,80
!byte 152,54,118,59,99,93,96,96,96,96,96,96,81,175,210,46
!byte 123,133,128,128,128,128,128,128,76,83,81,79,108,54,80,80
!byte 80,80,80,80,151,55,118,59,102,91,96,96,96,96,96,96
!byte 81,175,210,46,119,137,128,128,128,128,128,128,73,85,81,78
!byte 108,54,80,80,80,80,80,80,150,55,119,58,105,88,96,96
!byte 96,96,96,96,81,175,209,47,114,142,128,128,128,128,128,128
!byte 71,87,81,78,108,55,80,80,80,80,80,80,149,56,119,57
!byte 108,85,96,96,96,96,96,96,81,175,209,47,109,147,128,128
!byte 128,128,128,128,69,89,82,77,108,56,80,80,80,80,80,80
!byte 147,57,120,56,111,83,96,96,96,96,96,96,82,174,207,49
!byte 103,153,128,128,128,128,128,128,66,90,82,77,107,57,80,80
!byte 80,80,80,80,145,59,121,55,115,80,96,96,96,96,96,96
!byte 83,173,206,50,98,158,128,128,128,128,128,128,64,92,82,76
!byte 106,59,80,80,80,80,80,80,142,61,122,54,119,78,96,96
!byte 96,96,96,96,84,172,205,51,92,164,128,128,128,128,128,128
!byte 61,95,82,76,105,61,80,80,80,80,80,80,138,63,123,52
!byte 123,76,96,96,96,96,96,96,86,170,203,53,86,170,128,128
!byte 128,128,128,128,59,97,83,76,103,63,80,80,80,80,80,80
!byte 134,66,125,51,126,74,96,96,96,96,96,96,89,167,200,56
!byte 80,176,128,128,128,128,128,128,57,99,83,76,101,65,80,80
!byte 80,80,80,80,129,69,126,49,130,72,96,96,96,96,96,96
!byte 92,164,198,58,75,181,128,128,128,128,128,128,55,101,82,76
!byte 99,67,80,80,80,80,80,80,124,73,128,47,133,71,96,96
!byte 96,96,96,96,96,160,195,61,69,187,128,128,128,128,128,128
!byte 54,102,82,77,96,69,80,80,80,80,80,80,118,77,130,46
!byte 135,70,96,96,96,96,96,96,101,155,192,64,63,193,128,128
!byte 128,128,128,128,53,104,82,77,92,72,80,80,80,80,80,80
!byte 113,82,131,44,137,70,96,96,96,96,96,96,107,149,189,67
!byte 58,198,128,128,128,128,128,128,52,106,81,78,88,75,80,80
!byte 80,80,80,80,107,86,133,43,137,70,96,96,96,96,96,96
!byte 113,143,185,71,54,202,128,128,128,128,128,128,52,107,81,79
!byte 84,77,80,80,80,80,80,80,101,91,135,42,136,71,96,96
!byte 96,96,96,96,120,136,182,74,50,206,128,128,128,128,128,128
!byte 53,108,80,80,80,80,80,80,80,80,80,80,96,96,137,41
!byte 134,73,96,96,96,96,96,96,128,128,178,78,47,209,128,128
!byte 128,128,128,128,53,108,79,81,76,83,80,80,80,80,80,80
!byte 92,101,138,40,131,75,96,96,96,96,96,96,136,120,174,82
!byte 45,211,128,128,128,128,128,128,55,108,78,82,72,85,80,80
!byte 80,80,80,80,88,105,140,39,127,78,96,96,96,96,96,96
!byte 145,111,170,86,44,212,128,128,128,128,128,128,56,108,78,83
!byte 68,87,80,80,80,80,80,80,85,108,141,39,122,81,96,96
!byte 96,96,96,96,153,103,165,91,44,212,128,128,128,128,128,128
!byte 58,108,77,84,64,89,80,80,80,80,80,80,84,111,142,39
!byte 116,84,96,96,96,96,96,96,162,94,161,95,46,210,128,128
!byte 128,128,128,128,59,107,76,84,61,91,80,80,80,80,80,80
!byte 83,113,143,39,111,87,96,96,96,96,96,96,171,85,157,99
!byte 48,208,128,128,128,128,128,128,61,106,76,85,59,93,80,80
!byte 80,80,80,80,82,115,144,39,105,90,96,96,96,96,96,96
!byte 179,77,154,102,52,204,128,128,128,128,128,128,63,105,76,85
!byte 57,95,80,80,80,80,80,80,83,115,145,39,101,93,96,96
!byte 96,96,96,96,187,69,150,106,57,199,128,128,128,128,128,128
!byte 65,103,75,85,55,96,80,80,80,80,80,80,84,114,146,40
!byte 97,96,96,96,96,96,96,96,194,62,147,109,62,194,128,128
!byte 128,128,128,128,66,101,75,85,54,98,80,80,80,80,80,80
!byte 85,113,147,40,94,98,96,96,96,96,96,96,200,56,143,113
!byte 69,187,128,128,128,128,128,128,68,99,76,85,53,100,80,80
!byte 80,80,80,80,87,111,148,40,92,99,96,96,96,96,96,96
!byte 206,50,141,115,76,180,128,128,128,128,128,128,70,97,76,84
!byte 52,101,80,80,80,80,80,80,89,108,148,40,91,100,96,96
!byte 96,96,96,96,211,45,138,118,83,173,128,128,128,128,128,128
!byte 72,94,77,84,51,103,80,80,80,80,80,80,90,106,149,40
!byte 91,100,96,96,96,96,96,96,215,41,136,120,92,164,128,128
!byte 128,128,128,128,74,91,77,83,51,104,80,80,80,80,80,80
!byte 92,103,149,40,91,100,96,96,96,96,96,96,219,37,135,121
!byte 100,156,128,128,128,128,128,128,76,87,78,82,51,105,80,80
!byte 80,80,80,80,93,102,150,40,93,99,96,96,96,96,96,96
!byte 221,35,134,122,109,147,128,128,128,128,128,128,78,84,79,81
!byte 52,107,80,80,80,80,80,80,94,100,150,40,94,98,96,96
!byte 96,96,96,96,222,34,133,123,119,137,128,128,128,128,128,128
!byte 80,80,80,80,53,108,80,80,80,80,80,80,94,100,150,40
!byte 96,96,96,96,96,96,96,96,223,33,133,123,128,128,128,128
!byte 128,128,128,128,82,76,81,79,53,108,80,80,80,80,80,80
!byte 94,100,150,40,98,94,96,96,96,96,96,96,222,34,133,123
!byte 137,119,128,128,128,128,128,128,84,73,82,78,55,109,80,80
!byte 80,80,80,80,93,102,150,40,99,93,96,96,96,96,96,96
!byte 221,35,134,122,147,109,128,128,128,128,128,128,86,69,83,77
!byte 56,109,80,80,80,80,80,80,92,103,149,40,100,91,96,96
!byte 96,96,96,96,219,37,135,121,156,100,128,128,128,128,128,128
!byte 88,66,83,76,57,109,80,80,80,80,80,80,90,106,149,40
!byte 100,91,96,96,96,96,96,96,215,41,136,120,164,92,128,128
!byte 128,128,128,128,90,63,84,76,59,108,80,80,80,80,80,80
!byte 89,108,148,40,100,91,96,96,96,96,96,96,211,45,138,118
!byte 173,83,128,128,128,128,128,128,92,61,84,75,60,107,80,80
!byte 80,80,80,80,87,111,148,40,99,92,96,96,96,96,96,96
!byte 206,50,141,115,180,76,128,128,128,128,128,128,94,59,85,75
!byte 62,106,80,80,80,80,80,80,85,113,147,40,98,94,96,96
!byte 96,96,96,96,200,56,143,113,187,69,128,128,128,128,128,128
!byte 95,57,85,75,64,105,80,80,80,80,80,80,84,114,146,40
!byte 96,97,96,96,96,96,96,96,194,62,147,109,194,62,128,128
!byte 128,128,128,128,97,55,84,75,65,103,80,80,80,80,80,80
!byte 83,115,145,39,93,101,96,96,96,96,96,96,187,69,150,106
!byte 199,57,128,128,128,128,128,128,99,54,84,75,67,101,80,80
!byte 80,80,80,80,82,115,144,39,90,105,96,96,96,96,96,96
!byte 179,77,154,102,204,52,128,128,128,128,128,128,101,53,84,76
!byte 69,99,80,80,80,80,80,80,83,113,143,39,87,111,96,96
!byte 96,96,96,96,171,85,157,99,208,48,128,128,128,128,128,128
!byte 102,52,83,76,71,96,80,80,80,80,80,80,84,111,142,39
!byte 84,116,96,96,96,96,96,96,162,94,161,95,210,46,128,128
!byte 128,128,128,128,104,52,82,77,73,92,80,80,80,80,80,80
!byte 85,108,141,39,81,122,96,96,96,96,96,96,153,103,165,91
!byte 212,44,128,128,128,128,128,128,105,52,82,78,75,88,80,80
!byte 80,80,80,80,88,105,140,39,78,127,96,96,96,96,96,96
!byte 145,111,170,86,212,44,128,128,128,128,128,128,107,52,81,79
!byte 77,84,80,80,80,80,80,80,92,101,138,40,75,131,96,96
!byte 96,96,96,96,136,120,174,82,211,45,128,128,128,128,128,128
* = $b200
; Icosahedron: 64 poses, 12 X / 12 Y / 12 Z bytes per pose.
!byte 80,63,53,80,67,107,80,97,59,80,93,101,96,50,113,53
!byte 131,113,153,50,83,96,131,83,33,86,85,171,170,85,85,86
!byte 171,223,170,171,77,64,52,83,67,105,76,98,61,82,92,103
!byte 99,49,109,51,127,120,153,53,78,94,133,85,33,86,93,166
!byte 178,80,90,78,176,223,170,163,73,65,52,86,67,103,73,99
!byte 63,84,91,104,102,47,105,51,123,126,152,57,74,93,134,89
!byte 35,87,102,161,185,76,95,71,180,221,169,154,70,67,51,89
!byte 67,100,70,99,66,86,90,105,103,46,100,51,119,132,150,62
!byte 70,92,135,93,37,87,109,155,191,73,101,65,183,219,169,147
!byte 67,68,52,91,68,97,67,99,68,87,89,106,104,45,95,51
!byte 115,137,147,66,67,92,136,97,39,88,117,149,197,71,107,59
!byte 185,217,168,139,64,69,52,94,68,94,65,99,71,89,88,107
!byte 103,43,90,52,112,142,144,71,64,92,137,102,42,87,124,143
!byte 202,70,113,54,186,214,169,132,62,71,53,96,69,90,63,98
!byte 73,91,87,107,102,42,86,54,109,145,140,75,62,92,138,107
!byte 46,87,130,137,206,70,119,50,186,210,169,126,60,72,54,99
!byte 70,86,61,97,76,92,86,107,101,42,81,56,106,147,137,80
!byte 60,93,138,111,50,87,136,130,210,70,126,46,186,206,169,120
!byte 58,73,56,100,71,83,60,95,78,94,85,107,99,41,77,58
!byte 103,149,133,84,59,94,138,116,53,86,142,124,213,71,132,43
!byte 185,203,170,114,56,74,57,102,72,80,59,94,80,95,84,106
!byte 96,41,74,61,101,150,129,87,58,96,139,121,57,86,146,118
!byte 216,72,138,40,184,199,170,110,55,75,58,103,73,77,59,92
!byte 82,96,84,105,94,40,71,64,99,150,125,90,58,97,139,125
!byte 61,85,150,112,218,74,144,38,182,195,171,106,54,76,60,105
!byte 75,74,58,90,84,97,83,104,92,40,68,66,98,149,122,93
!byte 57,99,139,129,65,85,154,107,220,76,149,36,180,191,171,102
!byte 54,77,61,105,76,71,58,88,86,98,82,102,89,40,66,69
!byte 97,149,119,95,57,101,139,132,69,84,157,102,221,78,154,35
!byte 178,187,172,99,53,78,63,106,77,69,58,86,88,99,82,101
!byte 87,40,64,72,96,147,116,97,58,103,139,135,73,83,160,97
!byte 222,81,159,34,175,183,173,96,53,79,64,107,78,67,59,84
!byte 90,100,81,100,84,40,62,74,95,146,113,98,58,105,138,138
!byte 77,83,163,93,222,83,163,34,173,179,173,93,53,79,66,107
!byte 79,65,59,82,91,100,80,98,82,40,61,77,95,144,111,98
!byte 59,107,138,140,81,83,166,89,223,85,167,33,171,175,173,90
!byte 53,80,67,107,80,63,59,80,93,101,80,97,79,40,60,79
!byte 95,142,109,99,60,109,138,142,85,83,168,85,223,88,171,33
!byte 168,171,173,88,53,81,69,107,81,62,60,78,94,101,80,95
!byte 77,40,59,82,95,140,107,98,61,111,138,144,89,83,171,81
!byte 223,90,175,33,166,167,173,85,53,81,70,107,82,60,60,76
!byte 96,101,79,93,74,40,58,84,95,138,105,98,62,113,138,146
!byte 93,83,173,77,222,93,179,34,163,163,173,83,54,82,72,107
!byte 83,59,61,74,97,102,78,91,72,40,58,87,96,135,103,97
!byte 64,116,139,147,97,83,175,73,222,96,183,34,160,159,173,81
!byte 55,83,74,106,84,58,62,72,99,102,78,89,69,40,57,89
!byte 97,132,101,95,66,119,139,149,102,84,178,69,221,99,187,35
!byte 157,154,172,78,55,84,76,106,85,56,63,70,100,102,77,86
!byte 66,40,57,92,98,129,99,93,68,122,139,149,107,85,180,65
!byte 220,102,191,36,154,149,171,76,57,85,78,105,87,55,64,68
!byte 102,101,76,83,64,40,58,94,99,125,97,90,71,125,139,150
!byte 112,85,182,61,218,106,195,38,150,144,171,74,58,86,80,104
!byte 88,54,65,66,103,101,76,80,61,41,58,96,101,121,96,87
!byte 74,129,139,150,118,86,184,57,216,110,199,40,146,138,170,72
!byte 60,87,82,102,89,53,66,65,104,100,75,77,58,41,59,99
!byte 103,116,94,84,77,133,138,149,124,86,185,53,213,114,203,43
!byte 142,132,170,71,61,88,84,100,90,53,68,63,106,99,74,74
!byte 56,42,60,101,106,111,93,80,81,137,138,147,130,87,186,50
!byte 210,120,206,46,136,126,169,70,64,89,87,98,91,53,69,62
!byte 107,97,73,70,54,42,62,102,109,107,92,75,86,140,138,145
!byte 137,87,186,46,206,126,210,50,130,119,169,70,66,91,89,96
!byte 92,53,71,61,108,95,72,66,52,43,64,103,112,102,92,71
!byte 90,144,137,142,143,87,186,42,202,132,214,54,124,113,169,70
!byte 69,92,92,93,92,54,73,61,108,93,71,63,51,45,67,104
!byte 115,97,92,66,95,147,136,137,149,88,185,39,197,139,217,59
!byte 117,107,168,71,71,93,94,90,93,55,74,61,109,90,70,60
!byte 51,46,70,103,119,93,92,62,100,150,135,132,155,87,183,37
!byte 191,147,219,65,109,101,169,73,74,95,97,87,93,56,76,61
!byte 108,87,69,57,51,47,74,102,123,89,93,57,105,152,134,126
!byte 161,87,180,35,185,154,221,71,102,95,169,76,77,96,99,83
!byte 93,57,78,62,108,84,68,55,51,49,78,99,127,85,94,53
!byte 109,153,133,120,166,86,176,33,178,163,223,78,93,90,170,80
!byte 80,97,101,80,93,59,80,63,107,80,67,53,53,50,83,96
!byte 131,83,96,50,113,153,131,113,171,86,171,33,170,171,223,86
!byte 85,85,170,85,83,97,102,77,92,61,82,65,106,76,67,52
!byte 54,51,87,92,135,81,98,47,117,152,130,107,175,85,165,33
!byte 163,179,223,93,77,81,171,91,85,98,104,74,92,63,83,66
!byte 104,73,66,51,57,52,92,87,139,80,101,45,119,150,129,101
!byte 177,84,158,35,155,186,221,101,70,79,172,98,88,98,105,71
!byte 91,66,85,68,102,69,66,51,59,53,96,82,142,80,104,44
!byte 121,147,128,96,179,83,150,37,147,193,219,109,63,77,173,106
!byte 90,98,106,69,90,68,86,69,99,66,66,52,62,54,100,77
!byte 145,80,107,44,121,143,128,92,180,82,142,41,138,200,215,118
!byte 56,76,174,114,92,98,107,67,89,70,88,71,97,63,66,52
!byte 65,54,103,72,148,81,110,44,121,140,127,89,180,81,134,45
!byte 131,206,211,125,50,76,175,122,94,98,107,65,88,72,89,72
!byte 94,61,67,53,67,53,106,68,150,82,113,44,119,136,127,86
!byte 179,80,125,50,123,211,206,133,45,77,176,131,95,97,108,63
!byte 87,74,91,74,91,59,67,54,69,53,108,64,151,84,116,45
!byte 116,132,128,85,177,79,116,56,116,215,200,140,41,79,177,140
!byte 97,96,108,62,86,76,92,75,87,57,68,56,71,51,109,62
!byte 152,86,119,46,113,129,128,85,174,78,107,62,109,219,194,147
!byte 37,82,178,149,98,95,108,61,85,78,93,76,84,56,69,57
!byte 73,50,109,60,153,88,121,47,110,126,129,85,170,77,98,69
!byte 103,221,187,153,35,86,179,158,100,94,108,60,84,80,95,77
!byte 80,55,70,58,73,48,109,59,153,90,123,49,107,125,130,86
!byte 166,76,89,77,98,222,179,158,34,90,180,167,101,92,107,59
!byte 83,82,96,77,77,55,71,60,74,47,108,59,153,92,124,50
!byte 104,123,131,87,160,75,81,85,93,222,171,163,34,96,181,175
!byte 102,90,106,58,83,84,98,78,73,55,73,61,73,45,106,60
!byte 153,93,125,51,101,123,132,89,154,75,73,93,89,221,163,167
!byte 35,102,181,183,102,88,105,57,82,86,99,78,70,55,75,63
!byte 72,44,104,61,153,94,126,52,99,123,133,90,148,75,65,101
!byte 86,220,155,170,36,108,181,191,103,85,104,57,81,88,101,79
!byte 67,55,76,65,71,43,102,63,152,95,126,53,98,123,134,92
!byte 141,74,59,109,84,217,147,172,39,115,182,197,103,83,102,56
!byte 81,90,102,80,64,56,78,67,69,42,101,65,152,95,125,54
!byte 98,124,135,93,133,74,53,117,83,213,139,173,43,123,182,203
!byte 104,80,99,56,80,92,103,80,61,57,80,68,67,42,99,67
!byte 152,94,125,54,99,125,135,94,126,74,47,126,82,209,130,174
!byte 47,130,182,209,104,77,96,57,79,93,104,80,58,58,82,70
!byte 65,42,98,69,152,93,124,54,101,125,135,95,117,74,43,133
!byte 83,203,123,173,53,139,182,213,103,75,93,57,79,95,105,81
!byte 56,59,84,72,63,43,98,71,152,92,123,53,102,126,134,95
!byte 109,74,39,141,84,197,115,172,59,147,182,217,103,72,90,58
!byte 78,97,105,82,55,61,85,74,61,44,99,72,153,90,123,52
!byte 104,126,133,94,101,75,36,148,86,191,108,170,65,155,181,220
!byte 102,70,87,58,77,99,105,82,54,62,87,76,60,45,101,73
!byte 153,89,123,51,106,125,132,93,93,75,35,154,89,183,102,167
!byte 73,163,181,221,101,68,83,59,77,100,105,83,53,64,89,78
!byte 59,47,104,74,153,87,123,50,108,124,131,92,85,75,34,160
!byte 93,175,96,163,81,171,181,222,100,66,80,60,76,102,105,83
!byte 52,65,90,80,59,48,107,73,153,86,125,49,109,123,130,90
!byte 77,76,34,166,98,167,90,158,89,179,180,222,99,65,76,62
!byte 75,103,104,84,52,67,91,82,60,50,110,73,153,85,126,47
!byte 109,121,129,88,69,77,35,170,103,158,86,153,98,187,179,221
!byte 98,64,73,63,74,104,103,85,52,68,92,84,62,51,113,71
!byte 152,85,129,46,109,119,128,86,62,78,37,174,109,149,82,147
!byte 107,194,178,219,97,63,69,65,73,106,101,86,52,69,93,86
!byte 64,53,116,69,151,85,132,45,108,116,128,84,56,79,41,177
!byte 116,140,79,140,116,200,177,215,95,62,66,66,72,107,99,88
!byte 53,71,93,88,68,53,119,67,150,86,136,44,106,113,127,82
!byte 50,80,45,179,123,131,77,133,125,206,176,211,93,62,63,68
!byte 71,108,97,89,53,72,94,90,72,54,121,65,148,89,140,44
!byte 103,110,127,81,45,81,50,180,131,122,76,125,134,211,175,206
!byte 91,62,61,70,70,108,94,91,54,74,94,92,77,54,121,62
!byte 145,92,143,44,100,107,128,80,41,82,56,180,138,114,76,118
!byte 142,215,174,200,89,62,58,72,69,109,91,92,55,75,94,94
!byte 82,53,121,59,142,96,147,44,96,104,128,80,37,83,63,179
!byte 147,106,77,109,150,219,173,193,86,62,56,75,68,109,87,94
!byte 56,77,94,97,87,52,119,57,139,101,150,45,92,101,129,80
!byte 35,84,70,177,155,98,79,101,158,221,172,186,83,63,54,77
!byte 68,108,84,95,58,78,93,99,92,51,117,54,135,107,152,47
!byte 87,98,130,81,33,85,77,175,163,91,81,93,165,223,171,179
!if * != $bb00 { !error "Unexpected model data size" }

