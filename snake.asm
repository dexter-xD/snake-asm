; NASM
; nasm -o snake.com -fbin snake.asm


%define VGA_MEM      0A000H                          ; video memory
%define SCR_MEM      09000H                          ; last 64kB segment
%define FONT_SEG     0F000H                          ; ROM-Font segment
%define FONT_OFF     0FA6EH                          ; ROM-Font offset


%define TRANSPARENT_COLOR 0


%define KEY_ESC           1
%define KEY_UP           72
%define KEY_DOWN         80
%define KEY_LEFT         75
%define KEY_RIGHT        77
%define KEY_A            30
%define KEY_P            25


        CPU 186
        BITS 16


        ORG 100H
        JMP main


; keyboard routines
keyboard_int:
        STI
        PUSH AX
        IN AL,60H                                    ; get key from keyboard port
        MOV [CS:lastkey],AL
        POP AX

        PUSH AX
        PUSH CX
        MOV AX,0
        MOV AL,[CS:lastkey]
        CMP AL,128                                   ; check keyboard data (pressed or not)
        JNAE check_keys_1
        SUB AL,128
        MOV CL,0
        JMP check_keys_2
check_keys_1:
        MOV CL,1
check_keys_2:
        MOV BX,key
        ADD BX,AX
        MOV [CS:BX],CL
        POP CX
        POP AX

        PUSH AX
        MOV AL,20H                                   ; send end of irq
        OUT 20H,AL
        POP AX

        CLI
        IRET

install_keyboard:
        MOV AX,3509H                                 ; get old keyboard int proc
        INT 21H
        MOV [CS:old_keyboard_int],BX
        MOV [CS:old_keyboard_int + 2],ES
        MOV AX,2509H                                 ; set new keyboard int proc
        MOV DX,keyboard_int
        PUSH DS
        PUSH CS
        POP DS
        INT 21H
        POP DS
        RET

remove_keyboard:
        MOV AX,2509H                                 ; restore old keyboard proc
        LDS DX,[CS:old_keyboard_int]
        INT 21H
        RET


wait_for_any_key:
        MOV BYTE [lastkey],0
        MOV DL,[lastkey]
wait_for_any_key_1:
        CMP DL,[lastkey]
        JE wait_for_any_key
        RET
;-------


; timer routines
timer_int:
        STI
        MOV BYTE [CS:can_update],1                   ; update game
        INC BYTE [CS:timer_counter]
        CMP BYTE [CS:timer_counter],18
        JE timer_int_reset_delay
        JMP timer_int_end
timer_int_reset_delay:
        MOV BYTE [CS:timer_delay],0
        MOV BYTE [CS:timer_counter],0
timer_int_end:
        CLI
        IRET


install_timer:
        MOV AX,351CH                                 ; get old timer int proc
        INT 21H
        MOV [CS:old_timer_int],BX
        MOV [CS:old_timer_int + 2],ES
        MOV AX,251CH                                 ; set new timer int proc
        MOV DX,timer_int
        PUSH DS
        PUSH CS
        POP DS
        INT 21H
        POP DS
        RET


remove_timer:
        MOV AX,251CH                                 ; restore old timer proc
        LDS DX,[CS:old_timer_int]
        INT 21H
        RET
;-------


; gfx routines
init13h:
        MOV AX,0013H                                   ; set 320x200 8bit video mode
        INT 10H
        RET


close13h:
        MOV AX,0003H                                   ; restore text mode
        INT 10H
        RET


vsync:                                               ; wait for end of screen updating
        PUSH AX
        PUSH DX
        MOV DX,03DAH
vsync_1:
        IN AL,DX
        TEST AL,0
        JNE vsync_1
        POP DX
        POP AX
        RET


set_palette:
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        MOV AX,0
        MOV BX,palette                               ; load palette adress to BX
        MOV CX,256                                   ; 256 colors (8bit)
set_palette_1:
        PUSH AX
        MOV DX,03C8H                                 ; set first VGA DAC port
        OUT DX,AL                                    ; send color num (AL) to VGA DAC
        INC DX                                       ; set next port
        MOV AL,[BX]                                  ; send RGB and increment BX pointer
        OUT DX,AL
        INC BX
        MOV AL,[BX]
        OUT DX,AL
        INC BX
        MOV AL,[BX]
        OUT DX,AL
        INC BX
        POP AX
        INC AL                                       ; increment color num
        LOOP set_palette_1
        POP DX
        POP BX
        POP CX
        POP AX
        RET


draw_screen:                                         ; move data from 9000h to A000h segment
        CALL vsync
        PUSH DS
        PUSH ES
        PUSH AX
        PUSH CX
        PUSH DI
        MOV AX,SCR_MEM
        MOV DS,AX
        MOV AX,VGA_MEM
        MOV ES,AX
        MOV CX,64000
draw_screen_1:
        MOV DI,CX
        DEC DI
        MOV AL,[DS:DI]
        MOV [ES:DI],AL
        LOOP draw_screen_1
        POP DI
        POP CX
        POP AX
        POP ES
        POP DS
        RET


clear_screen:                                        ; clear screen buffer, CL - color
        PUSH ES
        PUSH AX
        PUSH DI
        MOV AX,SCR_MEM
        MOV ES,AX
        MOV AL,CL
        MOV CX,64000
clear_screen_1:
        MOV DI,CX
        DEC DI
        MOV [ES:DI],AL
        LOOP clear_screen_1
        POP DI
        POP AX
        POP ES
        RET


putpixel:                                            ; AX - x, BX - y, CL - color
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DI
        PUSH ES
        PUSH AX
        MOV AX,BX
        MOV BX,320
        MUL BX
        POP BX
        ADD AX,BX
        MOV DI,AX
        MOV AX,SCR_MEM
        MOV ES,AX
        MOV [ES:DI],CL
        POP ES
        POP DI
        POP CX
        POP BX
        POP AX
        RET


getpixel:                                            ; AX - x, BX - y, return: CL - color
        PUSH AX
        PUSH BX
        PUSH DI
        PUSH ES
        PUSH AX
        MOV AX,BX
        MOV BX,320
        MUL BX
        POP BX
        ADD AX,BX
        MOV DI,AX
        MOV AX,SCR_MEM
        MOV ES,AX
        MOV CL,[ES:DI]
        POP ES
        POP DI
        POP BX
        POP AX
        RET


draw_sprite:                                         ; SX - x, SY - y, SW - width, SH - height, BX - data
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH ES
        PUSH DI
        MOV AX,SCR_MEM
        MOV ES,AX
        MOV AX,[SY]
        MOV CX,[SH]
draw_sprite_y_axis:
        PUSH CX
        PUSH AX
        MOV DX,320
        MUL DX
        ADD AX,[SX]
        MOV DI,AX
        MOV CX,[SW]
draw_sprite_x_axis:
        MOV AL,[BX]
        MOV [ES:DI],AL
        INC DI
        INC BX
        LOOP draw_sprite_x_axis
        POP AX
        INC AX
        POP CX
        LOOP draw_sprite_y_axis
        POP DI
        POP ES
        POP DX
        POP CX
        POP BX
        POP AX
        RET


draw_transparent_sprite:                                         ; SX - x, SY - y, SW - width, SH - height, BX - data
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH ES
        PUSH DI
        MOV AX,SCR_MEM
        MOV ES,AX
        MOV AX,[SY]
        MOV CX,[SH]
draw_transparent_sprite_y_axis:
        PUSH CX
        PUSH AX
        MOV DX,320
        MUL DX
        ADD AX,[SX]
        MOV DI,AX
        MOV CX,[SW]
draw_transparent_sprite_x_axis:
        MOV AL,[BX]
        CMP AL,TRANSPARENT_COLOR
        JE draw_transparent_sprite_x_next
        MOV [ES:DI],AL
draw_transparent_sprite_x_next
        INC DI
        INC BX
        LOOP draw_transparent_sprite_x_axis
        POP AX
        INC AX
        POP CX
        LOOP draw_transparent_sprite_y_axis
        POP DI
        POP ES
        POP DX
        POP CX
        POP BX
        POP AX
        RET


hline:                                               ; PX1 - x1, PY1 - y, PX2 - x2, PCL - color
        PUSH ES
        PUSH DI
        PUSH AX
        PUSH BX
        PUSH CX
        MOV AX,SCR_MEM
        MOV ES,AX
        MOV AX,[PY1]
        MOV BX,320
        MUL BX
        ADD AX,[PX1]
        MOV DI,AX
        MOV AL,[PCL]
        MOV CX,[PX2]
        SUB CX,[PX1]
hline_1:
        MOV BYTE [ES:DI],AL
        INC DI
        LOOP hline_1
        POP CX
        POP BX
        POP AX
        POP DI
        POP ES
        RET


vline:                                               ; PX1 - x, PY1 - y1, PY2 - y2, PCL - color
        PUSH ES
        PUSH DI
        PUSH AX
        PUSH BX
        PUSH CX
        MOV AX,SCR_MEM
        MOV ES,AX
        MOV AX,[PY1]
        MOV BX,320
        MUL BX
        ADD AX,[PX1]
        MOV DI,AX
        MOV AL,[PCL]
        MOV CX,[PY2]
        SUB CX,[PY1]
vline_1:
        MOV [ES:DI],AL
        ADD DI,320
        LOOP vline_1
        POP CX
        POP BX
        POP AX
        POP DI
        POP ES
        RET


rect:                                                ; PX1 - x1, PY1 - y1, PX2 - x2, PY2 - y2, PCL - color
        PUSH AX
        PUSH BX
        PUSH CX
        CALL hline
        CALL vline
        MOV AX,[PY1]
        MOV BX,[PY2]
        MOV [PY1],BX
        CALL hline
        MOV [PY1],AX
        MOV AX,[PX1]
        MOV BX,[PX2]
        MOV [PX1],BX
        CALL vline
        MOV [PX1],AX
        MOV AX,[PX2]
        MOV BX,[PY2]
        MOV CL,[PCL]
        CALL putpixel
        POP CX
        POP BX
        POP AX
        RET


rectfill:
        PUSH AX
        PUSH CX
        MOV AX,[PY1]
        MOV CX,[PY2]
        SUB CX,[PY1]
rectfill_1:
        CALL hline
        INC WORD [PY1]
        LOOP rectfill_1
        MOV [PY1],AX
        CALL rect
        POP CX
        POP AX
        RET


draw_char_mask:                                      ; AX - x, BX - y, CL - color, CH - char mask
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        MOV DX,CX
        MOV CX,8
draw_char_mask_1:
        PUSH CX
        SHL DH,1
        JNC draw_char_mask_2
        PUSH DX
        MOV CL,DL
        CALL putpixel
        POP DX
draw_char_mask_2:
        POP CX
        INC AX
        LOOP draw_char_mask_1
        POP DX
        POP CX
        POP BX
        POP AX
        RET


draw_char:                                           ; AX - x, BX - y, CL - color, CH - char
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH ES
        PUSH DI
        PUSH AX
        MOV AX,FONT_SEG
        MOV ES,AX
        MOV AX,FONT_OFF
        MOV DI,AX
        MOV AX,0
        MOV AL,CH
        SHL AX,3
        ADD DI,AX
        POP AX
        MOV DX,CX
        MOV CX,8
draw_char_1:
        PUSH CX
        MOV CX,DX
        MOV CH,[ES:DI]
        CALL draw_char_mask
        INC DI
        INC BX
        POP CX
        LOOP draw_char_1
        POP DI
        POP ES
        POP DX
        POP CX
        POP BX
        POP AX
        RET


draw_integer:                                        ; AX - x, BX - y, CL - color, DX - integer
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH DI
        MOV DI,10000
        MOV [draw_integer_cl],CL
        MOV CX,5
draw_integer_1:
        PUSH CX
        PUSH AX
        PUSH BX
        PUSH DX
        MOV AX,DX
        XOR DX,DX
        MOV BX,DI
        DIV BX
        MOV CH,AL
        MUL BX
        POP DX
        SUB DX,AX
        POP BX
        POP AX
        ADD CH,'0'
        MOV CL,[draw_integer_cl]
        CALL draw_char
        ADD AX,8
        PUSH AX
        PUSH BX
        PUSH DX
        MOV AX,DI
        MOV BX,10
        XOR DX,DX
        DIV BX
        MOV DI,AX
        POP DX
        POP BX
        POP AX
        POP CX
        LOOP draw_integer_1
        POP DI
        POP DX
        POP CX
        POP BX
        POP AX
        RET


draw_integer_cl                           DB 0          ; color (temp)


draw_text:                                           ; AX - x, BX - y, CL - color, DX - data
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        XCHG BX,DX
draw_text_1:
        MOV CH,[BX]
        INC BX
        XCHG BX,DX
        CALL draw_char
        ADD AX,8
        XCHG BX,DX
        CMP BYTE [BX],0
        JNE draw_text_1
        POP DX
        POP CX
        POP BX
        POP AX
        RET
;-------


; program code
random_init:
        PUSH AX
        PUSH CX
        PUSH DX
        MOV AH,2CH
        INT 21H
        MOV [random_seed],DX
        POP DX
        POP CX
        POP AX
        RET


random_gen:                                          ; return: CL - random byte
        MOV CX,[random_seed]
        IMUL CX,13A7H
        INC CX
        MOV [random_seed],CX
        MOV CL,CH
        MOV CH,0
        RET


random:                                              ; AL - max random number
        CALL random_gen
        CMP CL,AL
        JAE random
        RET


random_seed                            DW 0          ; seed


delay:                                               ; AX - hund. seconds (1/100 s)
        MOV BYTE [timer_delay],1
delay_1:
        CMP BYTE [timer_delay],0
        JNE delay_1
        RET


sound_on:
        PUSH AX
        MOV AL,0B6H
        OUT 43H,AL
        MOV AX,11930
        OUT 42H,AL
        MOV AL,AH
        OUT 42H,AL
        IN AL,61H
        OR AL,3
        OUT 61H,AL
        POP AX
        RET


sound_off:
        PUSH AX
        IN AL,61H
        AND AL,252
        OUT 61H,AL
        POP AX
        RET


move_snake:
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        CMP BYTE [snake_vector],0
        JE move_snake_end
        MOV CX,[snake_len]
        DEC CX
move_snake_1:
        PUSH CX
        DEC CX
        MOV BX,snake
        MOV AX,CX
        MOV CX,4
        MUL CX
        ADD BX,AX
        MOV AX,[BX]
        MOV CX,[BX + 2]
        MOV [BX + 4],AX
        MOV [BX + 6],CX
        POP CX
        LOOP move_snake_1
        CMP BYTE [snake_vector],1
        JE move_snake_up
        CMP BYTE [snake_vector],2
        JE move_snake_down
        CMP BYTE [snake_vector],3
        JE move_snake_left
        CMP BYTE [snake_vector],4
        JE move_snake_right
move_snake_up:
        SUB WORD [snake + 2],5
        JMP move_snake_vector_end
move_snake_down:
        ADD WORD [snake + 2],5
        JMP move_snake_vector_end
move_snake_left:
        SUB WORD [snake],5
        JMP move_snake_vector_end
move_snake_right:
        ADD WORD [snake],5
        JMP move_snake_vector_end
move_snake_vector_end:
move_snake_end:
        POP DX
        POP CX
        POP BX
        POP AX
        RET


set_snakes_vector:
        PUSH AX

        CMP AL,1
        JE set_snakes_vector_up
        CMP AL,2
        JE set_snakes_vector_down
        CMP AL,3
        JE set_snakes_vector_left
        CMP AL,4
        JE set_snakes_vector_right
        JMP set_snakes_vector_end

set_snakes_vector_up:
        CMP BYTE [snake_vector],2                    ; if not down
        JE set_snakes_vector_up_1
        MOV BYTE [snake_vector],1                    ; set up
set_snakes_vector_up_1:
        JMP set_snakes_vector_end

set_snakes_vector_down:
        CMP BYTE [snake_vector],1                    ; if not up
        JE set_snakes_vector_down_1
        MOV BYTE [snake_vector],2                    ; set down
set_snakes_vector_down_1:
        JMP set_snakes_vector_end

set_snakes_vector_left:
        CMP BYTE [snake_vector],4                    ; if not right
        JE set_snakes_vector_left_1
        CMP BYTE [snake_vector],0                    ; if not 'no move'
        JE set_snakes_vector_left_1
        MOV BYTE [snake_vector],3                    ; set left
set_snakes_vector_left_1:
        JMP set_snakes_vector_end

set_snakes_vector_right:
        CMP BYTE [snake_vector],3                    ; if not left
        JE set_snakes_vector_right_1
        MOV BYTE [snake_vector],4                    ; set right
set_snakes_vector_right_1:
        JMP set_snakes_vector_end

set_snakes_vector_end:
        POP AX
        RET


reset_snake:
        MOV WORD [snake + 14],60
        MOV WORD [snake + 12],25
        MOV WORD [snake + 10],60
        MOV WORD [snake + 8],30
        MOV WORD [snake + 6],60
        MOV WORD [snake + 4],35
        MOV WORD [snake + 2],60
        MOV WORD [snake],40
        MOV WORD [snake_len],4
        MOV BYTE [snake_vector],0
        RET


reset_food:
        PUSH AX
        PUSH BX
        PUSH CX
; random food x
        MOV AL,58                                    ; max area width / 5
        CALL random
        MOV AH,0
        MOV AL,CL
        MOV BX,5
        MUL BX
        ADD AX,5
        MOV [snakes_food_x],AX
; random food y
        MOV AL,35                                    ; max area height / 5
        CALL random
        MOV AH,0
        MOV AL,CL
        MOV BX,5
        MUL BX
        ADD AX,20
        MOV [snakes_food_y],AX
        POP CX
        POP BX
        POP AX
        RET


increase_snake:                                      ; snake++ :), new head = food position
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        MOV CX,[snake_len]
increase_snake_1:
        PUSH CX
        DEC CX
        MOV BX,snake
        MOV AX,CX
        MOV CX,4
        MUL CX
        ADD BX,AX
        MOV AX,[BX]
        MOV CX,[BX + 2]
        MOV [BX + 4],AX
        MOV [BX + 6],CX
        POP CX
        LOOP increase_snake_1
        MOV AX,[snakes_food_x]
        MOV [snake],AX
        MOV AX,[snakes_food_y]
        MOV [snake + 2],AX
        INC WORD [snake_len]
        MOV AX,[snake_len]
        CMP AX,[snake_max_len]                       ; if snake_len == snake_max_len then print winner msg and quit
        JE increase_snake_max_len
        JMP increase_snake_end
increase_snake_max_len:
        CALL winner
increase_snake_end:
        POP DX
        POP CX
        POP BX
        POP AX
        RET


detect_collisions:                                   ; detect collisions beetwen objects
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
; detect head and food collision
        MOV AX,[snakes_food_x]
        CMP AX,[snake]                               ; compare food x with head x
        JNE detect_collisions_1
        MOV AX,[snakes_food_y]
        CMP AX,[snake + 2]                           ; compare food y with head y
        JNE detect_collisions_1
; add points and increase snake
        ADD WORD [score],10                          ; add 10 points :)
        CALL increase_snake
        CALL reset_food
detect_collisions_1:
; detect collision with border and decrase lives
        CMP WORD [snake],0                           ; coll. with left border
        JE detect_collisions_dead
        CMP WORD [snake],320 - 5                     ; coll. with right border
        JE detect_collisions_dead
        CMP WORD [snake + 2],15                      ; coll. with top border
        JE detect_collisions_dead
        CMP WORD [snake + 2],200 - 5                 ; coll. with bottom border
        JE detect_collisions_dead
; detect head collision with body
        MOV BX,snake
        ADD BX,8                                     ; jump to next x&y
        MOV AX,[snake]
        MOV DX,[snake + 2]
        MOV CX,[snake_len]
        DEC CX
detect_collisions_head_with_body:
        CMP AX,[BX]
        JNE detect_collisions_head_with_body_next
        CMP DX,[BX + 2]
        JE detect_collisions_dead
detect_collisions_head_with_body_next:
        ADD BX,4
        LOOP detect_collisions_head_with_body
; if everything is ok the jump to the end
        JMP detect_collisions_end
detect_collisions_dead:
        CALL reset_snake
        CALL reset_food
        DEC BYTE [live_counter]
        MOV AX,1000
        CALL draw_screen
        CALL sound_on
        CALL delay
        CALL sound_off
detect_collisions_end:
        POP DX
        POP CX
        POP BX
        POP AX
        RET


main:
        CALL init13h
        CALL install_keyboard
        CALL install_timer
        CALL set_palette
        CALL random_init
; setup snake
        CALL reset_snake
        CALL reset_food
game_loop:
; synchronize game
        CMP BYTE [can_update],1
        JNE game_loop
        MOV BYTE [can_update],0
; clear screen buffer
        MOV CL,0
        CALL clear_screen
; draw frame
        MOV BX,sprite_frame_box
        MOV WORD [SW],5
        MOV WORD [SH],5
; draw top frame
        MOV WORD [SX],0
        MOV WORD [SY],0
        MOV CX,320 / 5
draw_frame_top:
        CALL draw_sprite
        ADD WORD [SX],5
        LOOP draw_frame_top
; draw bottom frame
        MOV WORD [SX],0
        MOV WORD [SY],200 - 5
        MOV CX,320 / 5
draw_frame_bottom:
        CALL draw_sprite
        ADD WORD [SX],5
        LOOP draw_frame_bottom
; draw left frame
        MOV WORD [SX],0
        MOV WORD [SY],0
        MOV CX,200 / 5
draw_frame_left:
        CALL draw_sprite
        ADD WORD [SY],5
        LOOP draw_frame_left
; draw_frame_right
        MOV WORD [SX],320 - 5
        MOV WORD [SY],0
        MOV CX,200 / 5
draw_frame_right:
        CALL draw_sprite
        ADD WORD [SY],5
        LOOP draw_frame_right
; draw top bar
        MOV WORD [PX1],5
        MOV WORD [PY1],5
        MOV WORD [PX2],320 - 5 - 1
        MOV WORD [PY2],5 + 13 + 1
        MOV BYTE [PCL],43
        CALL rectfill
        MOV BYTE [PCL],53
        CALL rect
; draw logo
        MOV BX,sprite_logo
        MOV WORD [SX],320 / 2 - 54 / 2
        MOV WORD [SY],7
        MOV WORD [SW],54
        MOV WORD [SH],11
        CALL draw_transparent_sprite
; draw live counter
        MOV BX,sprite_snake_live_0
        MOV WORD [SW],13
        MOV WORD [SH],11
        MOV WORD [SY],7
        MOV WORD [SX],320 - 5 - 18
        CALL draw_transparent_sprite
        MOV WORD [SX],320 - 5 - 18 - 18
        CALL draw_transparent_sprite
        MOV WORD [SX],320 - 5 - 18 - 18 - 18
        CALL draw_transparent_sprite
        MOV BX,sprite_snake_live_1
        CMP BYTE [live_counter],0                    ; if game over
        JE counter_game_over
        JMP counter_draw_live
counter_game_over:
        CALL game_over
counter_draw_live:
        MOV WORD [SX],320 - 5 - 18
        CALL draw_transparent_sprite
        CMP BYTE [live_counter],2
        JB draw_live_counter_end
        MOV WORD [SX],320 - 5 - 18 - 18
        CALL draw_transparent_sprite
        CMP BYTE [live_counter],3
        JB draw_live_counter_end
        MOV WORD [SX],320 - 5 - 18 - 18 - 18
        CALL draw_transparent_sprite
draw_live_counter_end:
; draw score
        MOV AX,10
        MOV BX,9
        MOV CL,32                                    ; white
        MOV DX,[score]
        CALL draw_integer
; draw snakes food
        MOV AX,[snakes_food_x]
        MOV [SX],AX
        MOV AX,[snakes_food_y]
        MOV [SY],AX
        MOV WORD [SW],5
        MOV WORD [SH],5
        MOV BX,sprite_snakes_food
        CALL draw_transparent_sprite
; draw snake
        MOV BX,sprite_snake
        MOV WORD [SW],5
        MOV WORD [SH],5
        MOV CX,[snake_len]
draw_snake:
        PUSH CX
        DEC CX
        PUSH BX
        MOV BX,snake
        MOV AX,CX
        MOV CX,4
        MUL CX
        ADD BX,AX
        MOV AX,[BX]
        MOV [SX],AX
        MOV AX,[BX + 2]
        MOV [SY],AX
        POP BX
        CALL draw_sprite
        POP CX
        LOOP draw_snake
; check keys
        CMP BYTE [key + KEY_UP],1
        JE key_up
        CMP BYTE [key + KEY_DOWN],1
        JE key_down
        CMP BYTE [key + KEY_LEFT],1
        JE key_left
        CMP BYTE [key + KEY_RIGHT],1
        JE key_right
        CMP BYTE [key + KEY_A],1
        JE key_a
        CMP BYTE [key + KEY_P],1
        JE key_p
        CMP BYTE [key + KEY_ESC],1                   ; if ESC then quit
        JE key_esc
        JMP game_loop_end
key_esc:
        CALL exit
key_up:
        MOV AL,1
        CALL set_snakes_vector
        JMP game_loop_end
key_down:
        MOV AL,2
        CALL set_snakes_vector
        JMP game_loop_end
key_left:
        MOV AL,3
        CALL set_snakes_vector
        JMP game_loop_end
key_right:
        MOV AL,4
        CALL set_snakes_vector
        JMP game_loop_end
key_p:
        CALL game_pause
        JMP game_loop_end
key_a:
; print info
        MOV CL,91
        MOV AX,320 / 2 - 5 * 8 / 2
        MOV BX,80
        MOV DX,text_about1
        CALL draw_text
        MOV CL,32
        MOV AX,320 / 2 - 11 * 8 / 2
        MOV BX,90
        MOV DX,text_about2
        CALL draw_text
        MOV CL,32
        MOV AX,320 / 2 - 12 * 8 / 2
        MOV BX,100
        MOV DX,text_about3
        CALL draw_text
        MOV CL,63
        MOV AX,320 / 2 - 14 * 8 / 2
        MOV BX,110
        MOV DX,text_about4
        CALL draw_text
        JMP game_loop_end
game_loop_end:
; move snake
        CALL move_snake
; detect collisions
        CALL detect_collisions
; redraw screen buffer
        CALL draw_screen
        JMP game_loop
game_pause:
        MOV CL,91
        MOV AX,320 / 2 - 5 * 8 / 2
        MOV BX,95
        MOV DX,text_pause
        CALL draw_text
        CALL draw_screen
        CALL wait_for_any_key
        RET
game_over:
        MOV CL,128
        MOV AX,320 / 2 - 9 * 8 / 2
        MOV BX,95
        MOV DX,text_game_over
        CALL draw_text
        CALL draw_screen
        CALL wait_for_any_key
        JMP exit
winner:
        MOV CL,160
        MOV AX,320 / 2 - 27 * 8 / 2
        MOV BX,90
        MOV DX,text_winner1
        CALL draw_text
        MOV AX,320 / 2 - 26 * 8 / 2
        MOV BX,100
        MOV DX,text_winner2
        CALL draw_text
        CALL draw_screen
        CALL wait_for_any_key
        JMP exit
exit:
        CALL remove_timer
        CALL remove_keyboard
        CALL close13h
        PUSH CS
        POP DS                                       ; DS = CS (09h need it)
        MOV AH,09H
        MOV DX,text_end
        INT 21H
        MOV AX,4C00H
        INT 21H
;-------


; data
old_keyboard_int                       DD 0
old_timer_int                          DD 0

screen_buffer                          DD 0

lastkey                                DB 0
key                                    TIMES 128 DB 0

timer_counter                          DB 0          ; 18 clock ticks
timer_delay                            DB 1          ; 0 when 18 ticks

can_update                             DB 0          ; if 1 then update game
live_counter                           DB 3          ; 3..game over
score                                  DW 0          ; game points

snakes_food_x                          DW 160
snakes_food_y                          DW 100

snake                                  TIMES 120*2 DW 0
snake_len                              DW 4
snake_max_len                          DW 120
snake_vector                           DB 0          ; 0 = no move, 1 = move up, 2 = move down, 3 = move left, 4 = move right

SX                                     DW 0          ; sprite x
SY                                     DW 0          ; sprite y
SW                                     DW 0          ; sprite width
SH                                     DW 0          ; sprite height

PX1                                    DW 0          ; other x1
PY1                                    DW 0          ; other y1
PX2                                    DW 0          ; other x2
PY2                                    DW 0          ; other y2
PCL                                    DB 0          ; other color

text_about1
DB 'SNAKE',0

text_about2
DB 'Version 1.0',0

text_about3
DB 'By dexter-xD',0

text_about4
DB ' Visit github.com/dexter-xD',0

text_pause
DB 'PAUSE',0

text_game_over
DB 'GAME OVER',0

text_winner1
DB '!!! Your Snake is dead !!!',0

text_winner2
DB '!!! It was too big :) !!!',0

text_end
DB 'SNAKE GAME',10,13,'$'


sprite_logo                                          ; 54x11 - main logo
DB   0,  0,158,158,158,158,158,158,  0,  0,  0,158,  0,  0,  0,  0,  0,  0,  0,158,158,  0,  0,  0,  0,  0,158,158,158,158,  0,  0,  0,  0,  0,158,158,  0,  0,  0,  0,158,158,  0,  0,  0,158,158,158,158,158,158,158,158
DB 158,158,158,158,158,158,158,158,  0,  0,  0,158,158,  0,  0,  0,  0,  0,  0,158,158,  0,  0,  0,  0,  0,158,158,158,158,  0,  0,  0,  0,  0,158,158,  0,  0,  0,158,158,158,  0,  0,  0,158,158,158,158,158,158,158,158
DB 158,158,  0,  0,  0,  0,  0,  0,  0,  0,  0,158,158,158,  0,  0,  0,  0,  0,158,158,  0,  0,  0,  0,  0,158,158,  0,158,158,  0,  0,  0,  0,158,158,  0,  0,158,158,158,  0,  0,  0,  0,158,158,  0,  0,  0,  0,  0,  0
DB 158,158,  0,  0,  0,  0,  0,  0,  0,  0,  0,158,158,158,158,158,  0,  0,  0,158,158,  0,  0,  0,  0,158,158,  0,  0,158,158,  0,  0,  0,  0,158,158,  0,  0,158,158,  0,  0,  0,  0,  0,158,158,  0,  0,  0,  0,  0,  0
DB 158,158,158,158,158,158,  0,  0,  0,  0,  0,158,158,158,158,158,158,  0,  0,158,158,  0,  0,  0,  0,158,158,  0,  0,158,158,  0,  0,  0,  0,158,158,  0,158,158,158,  0,  0,  0,  0,  0,158,158,158,158,158,158,  0,  0
DB   0,  0,158,158,158,158,158,158,  0,  0,  0,158,158,  0,158,158,158,158,158,158,158,  0,  0,  0,  0,158,158,  0,  0,  0,158,158,  0,  0,  0,158,158,158,158,158,158,158,  0,  0,  0,  0,158,158,158,158,158,158,  0,  0
DB   0,  0,  0,  0,  0,  0,158,158,158,  0,  0,158,158,  0,  0,  0,158,158,158,158,158,  0,  0,  0,158,158,158,158,158,158,158,158,  0,  0,  0,158,158,158,158,  0,158,158,158,  0,  0,  0,158,158,  0,  0,  0,  0,  0,  0
DB   0,  0,  0,  0,  0,  0,  0,158,158,  0,  0,158,158,  0,  0,  0,  0,158,158,158,158,  0,  0,  0,158,158,158,158,158,158,158,158,  0,  0,  0,158,158,158,  0,  0,  0,158,158,  0,  0,  0,158,158,  0,  0,  0,  0,  0,  0
DB   0,158,  0,  0,  0,  0,158,158,158,  0,  0,158,158,  0,  0,  0,  0,  0,158,158,158,  0,  0,158,158,158,  0,  0,  0,  0,  0,158,158,  0,  0,158,158,  0,  0,  0,  0,158,158,158,  0,  0,158,158,  0,  0,  0,  0,  0,  0
DB 158,158,158,158,158,158,158,158,  0,  0,  0,158,158,  0,  0,  0,  0,  0,  0,158,158,  0,  0,158,158,  0,  0,  0,  0,  0,  0,158,158,  0,  0,158,158,  0,  0,  0,  0,  0,158,158,  0,  0,158,158,158,158,158,158,158,158
DB   0,158,158,158,158,158,158,  0,  0,  0,  0,158,158,  0,  0,  0,  0,  0,  0,  0,158,  0,  0,158,158,  0,  0,  0,  0,  0,  0,158,158,  0,  0,158,158,  0,  0,  0,  0,  0,  0,158,  0,  0,158,158,158,158,158,158,158,158


sprite_frame_box                                     ; 5x5 - main frame box
DB  48, 48, 48, 48, 48
DB  48, 53, 53, 53, 41
DB  48, 53, 43, 53, 41
DB  48, 53, 53, 53, 41
DB  41, 41, 41, 41, 41


sprite_snakes_food                                   ; 5x5 - snakes food :)
DB   0,155,155,155,  0
DB 155,157,157,157,151
DB 155,157,161,154,151
DB 155,157,154,154,151
DB   0,151,151,151,  0


sprite_snake                                         ; 5x5 - snakes body
DB  97, 76, 83, 76, 97
DB  76, 88, 88, 88, 76
DB  83, 88, 88, 88, 83
DB  76, 88, 88, 88, 76
DB  97, 76, 83, 76, 97


sprite_snake_live_1                                  ; 13x11 - live set
DB   0,  0, 85, 85, 85, 90,  0,  0,  0,  0,  0,  0,  0
DB   0, 85, 64, 85, 64, 85, 90,  0,  0,  0,  0,  0,  0
DB   0,  0, 85, 85,  0,  0, 85, 90,  0,  0,  0,  0,  0
DB   0,  0,161,  0,  0,  0, 85, 90,  0,  0,  0,  0,  0
DB   0,157,  0,157,  0,  0, 85, 90,  0,  0,  0,  0,129
DB   0,  0,  0,  0,  0, 85, 90,  0,  0,  0,  0,  0,146
DB   0,  0,  0,  0, 85, 90,  0,  0,  0,  0,  0,  0,146
DB   0,  0,  0, 85, 90,  0,  0,  0,  0,  0, 90, 90,  0
DB   0,  0, 85, 90, 90,  0,  0,  0,  0, 90, 85, 85,  0
DB   0,  0, 85, 90, 90, 90, 90, 90, 90, 85, 85,  0,  0
DB   0,  0,  0, 85, 85, 85, 85, 85, 85, 85,  0,  0,  0


sprite_snake_live_0                                  ; 13x11 - live reset
DB   0,  0, 16, 16, 16, 23,  0,  0,  0,  0,  0,  0,  0
DB   0, 16, 30, 16, 30, 16, 23,  0,  0,  0,  0,  0,  0
DB   0,  0, 16, 16,  0,  0, 16, 23,  0,  0,  0,  0,  0
DB   0,  0, 21,  0,  0,  0, 16, 23,  0,  0,  0,  0,  0
DB   0, 21,  0, 21,  0,  0, 16, 23,  0,  0,  0,  0, 30
DB   0,  0,  0,  0,  0, 16, 23,  0,  0,  0,  0,  0, 11
DB   0,  0,  0,  0, 16, 23,  0,  0,  0,  0,  0,  0, 11
DB   0,  0,  0, 16, 23,  0,  0,  0,  0,  0, 23, 23,  0
DB   0,  0, 16, 23, 23,  0,  0,  0,  0, 23, 16, 16,  0
DB   0,  0, 16, 23, 23, 23, 23, 23, 23, 16, 16,  0,  0
DB   0,  0,  0, 16, 16, 16, 16, 16, 16, 16,  0,  0,  0


palette                                              ; game palette
DB   0,  0,  0
DB   0,  0,  0
DB   2,  2,  2
DB   4,  4,  4
DB   6,  6,  6
DB   8,  8,  8
DB  10, 10, 10
DB  12, 12, 12
DB  14, 14, 14
DB  16, 16, 16
DB  18, 18, 18
DB  20, 20, 20
DB  22, 22, 22
DB  24, 24, 24
DB  26, 26, 26
DB  28, 28, 28
DB  30, 30, 30
DB  32, 32, 32
DB  34, 34, 34
DB  36, 36, 36
DB  38, 38, 38
DB  40, 40, 40
DB  42, 42, 42
DB  44, 44, 44
DB  46, 46, 46
DB  48, 48, 48
DB  50, 50, 50
DB  52, 52, 52
DB  54, 54, 54
DB  56, 56, 56
DB  58, 58, 58
DB  60, 60, 60
DB  62, 62, 62
DB   0,  0,  0
DB   0,  0,  2
DB   0,  0,  4
DB   0,  0,  6
DB   0,  0,  8
DB   0,  0, 10
DB   0,  0, 12
DB   0,  0, 14
DB   0,  0, 16
DB   0,  0, 18
DB   0,  0, 20
DB   0,  0, 22
DB   0,  0, 24
DB   0,  0, 26
DB   0,  0, 28
DB   0,  0, 30
DB   0,  0, 32
DB   0,  0, 34
DB   0,  0, 36
DB   0,  0, 38
DB   0,  0, 40
DB   0,  0, 42
DB   0,  0, 44
DB   0,  0, 46
DB   0,  0, 48
DB   0,  0, 50
DB   0,  0, 52
DB   0,  0, 54
DB   0,  0, 56
DB   0,  0, 58
DB   0,  0, 60
DB   0,  0, 62
DB   0,  0,  0
DB   0,  0,  0
DB   0,  2,  0
DB   0,  4,  0
DB   0,  6,  0
DB   0,  8,  0
DB   0, 10,  0
DB   0, 12,  0
DB   0, 14,  0
DB   0, 16,  0
DB   0, 18,  0
DB   0, 20,  0
DB   0, 22,  0
DB   0, 24,  0
DB   0, 26,  0
DB   0, 28,  0
DB   0, 30,  0
DB   0, 32,  0
DB   0, 34,  0
DB   0, 36,  0
DB   0, 38,  0
DB   0, 40,  0
DB   0, 42,  0
DB   0, 44,  0
DB   0, 46,  0
DB   0, 48,  0
DB   0, 50,  0
DB   0, 52,  0
DB   0, 54,  0
DB   0, 56,  0
DB   0, 58,  0
DB   0, 60,  0
DB   0, 62,  0
DB   0,  0,  0
DB   2,  0,  0
DB   4,  0,  0
DB   6,  0,  0
DB   8,  0,  0
DB  10,  0,  0
DB  12,  0,  0
DB  14,  0,  0
DB  16,  0,  0
DB  18,  0,  0
DB  20,  0,  0
DB  22,  0,  0
DB  24,  0,  0
DB  26,  0,  0
DB  28,  0,  0
DB  30,  0,  0
DB  32,  0,  0
DB  34,  0,  0
DB  36,  0,  0
DB  38,  0,  0
DB  40,  0,  0
DB  42,  0,  0
DB  44,  0,  0
DB  46,  0,  0
DB  48,  0,  0
DB  50,  0,  0
DB  52,  0,  0
DB  54,  0,  0
DB  56,  0,  0
DB  58,  0,  0
DB  60,  0,  0
DB  62,  0,  0
DB   0,  0,  0
DB   2,  2,  0
DB   4,  4,  0
DB   6,  6,  0
DB   8,  8,  0
DB  10, 10,  0
DB  12, 12,  0
DB  14, 14,  0
DB  16, 16,  0
DB  18, 18,  0
DB  20, 20,  0
DB  22, 22,  0
DB  24, 24,  0
DB  26, 26,  0
DB  28, 28,  0
DB  30, 30,  0
DB  32, 32,  0
DB  34, 34,  0
DB  36, 36,  0
DB  38, 38,  0
DB  40, 40,  0
DB  42, 42,  0
DB  44, 44,  0
DB  46, 46,  0
DB  48, 48,  0
DB  50, 50,  0
DB  52, 52,  0
DB  54, 54,  0
DB  56, 56,  0
DB  58, 58,  0
DB  60, 60,  0
DB  62, 62,  0
DB   0,  0,  0
DB   2,  0,  2
DB   4,  0,  4
DB   6,  0,  6
DB   8,  0,  8
DB  10,  0, 10
DB  12,  0, 12
DB  14,  0, 14
DB  16,  0, 16
DB  18,  0, 18
DB  20,  0, 20
DB  22,  0, 22
DB  24,  0, 24
DB  26,  0, 26
DB  28,  0, 28
DB  30,  0, 30
DB  32,  0, 32
DB  34,  0, 34
DB  36,  0, 36
DB  38,  0, 38
DB  40,  0, 40
DB  42,  0, 42
DB  44,  0, 44
DB  46,  0, 46
DB  48,  0, 48
DB  50,  0, 50
DB  52,  0, 52
DB  54,  0, 54
DB  56,  0, 56
DB  58,  0, 58
DB  60,  0, 60
DB  62,  0, 62
DB   0,  0,  0
DB   0,  2,  2
DB   0,  4,  4
DB   0,  6,  6
DB   0,  8,  8
DB   0, 10, 10
DB   0, 12, 12
DB   0, 14, 14
DB   0, 16, 16
DB   0, 18, 18
DB   0, 20, 20
DB   0, 22, 22
DB   0, 24, 24
DB   0, 26, 26
DB   0, 28, 28
DB   0, 30, 30
DB   0, 32, 32
DB   0, 34, 34
DB   0, 36, 36
DB   0, 38, 38
DB   0, 40, 40
DB   0, 42, 42
DB   0, 44, 44
DB   0, 46, 46
DB   0, 48, 48
DB   0, 50, 50
DB   0, 52, 52
DB   0, 54, 54
DB   0, 56, 56
DB   0, 58, 58
DB   0, 60, 60
DB   0, 62, 62
DB   0,  0, 32
DB   2,  1, 33
DB   4,  2, 34
DB   6,  3, 35
DB   8,  4, 36
DB  10,  5, 37
DB  12,  6, 38
DB  14,  7, 39
DB  16,  8, 40
DB  18,  9, 41
DB  20, 10, 42
DB  22, 11, 43
DB  24, 12, 44
DB  26, 13, 45
DB  28, 14, 46
DB  30, 15, 47
DB  32, 16, 48
DB  34, 17, 49
DB  36, 18, 50
DB  38, 19, 51
DB  40, 20, 52
DB  42, 21, 53
DB  44, 22, 54
DB  46, 23, 55
DB  48, 24, 56
DB  50, 25, 57
DB  52, 26, 58
DB  54, 27, 59
DB  56, 28, 60
DB  58, 29, 61
;-------


; EOF