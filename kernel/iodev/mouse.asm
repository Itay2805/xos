
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Format Of Mouse Packet Data
MOUSE_LEFT_BTN			= 0x01
MOUSE_RIGHT_BTN			= 0x02
MOUSE_MIDDLE_BTN		= 0x04
MOUSE_X_SIGN			= 0x10
MOUSE_Y_SIGN			= 0x20
MOUSE_X_OVERFLOW		= 0x40
MOUSE_Y_OVERFLOW		= 0x80

align 4
mouse_data			dd 0
mouse_x				dd 0
mouse_y				dd 0

mouse_old_data			dd 0
mouse_old_x			dd 0
mouse_old_y			dd 0

mouse_packet:
	.data			db 0
	.x			db 0
	.y			db 0
	.scroll			db 0

; Mouse Speed
mouse_speed			db 0		; 0 normal speed, 1 -> 4 fast speeds

align 4
; these contain the initial x/y pos at the moment the button was pressed
mouse_initial_x			dd 0
mouse_initial_y			dd 0

align 4
mouse_x_max			dd 0
mouse_y_max			dd 0

mouse_cursor			dd 0
mouse_width			dd 0
mouse_height			dd 0
mouse_visible			db 0

; update_mouse:
; Updates the mouse position
align 32
update_mouse:
	; if the mouse data doesn't have proper alignment, ignore the packet
	;test [mouse_packet.data], 8
	;jz .quit

	; if the overflow bits are set, ignore the packet
	;test [mouse_packet.data], MOUSE_X_OVERFLOW
	;jnz .quit
	;test [mouse_packet.data], MOUSE_Y_OVERFLOW
	;jnz .quit

	; save the old mouse state before determining its new state
	mov eax, [mouse_data]
	mov [mouse_old_data], eax

	mov al, [mouse_packet.data]
	mov [mouse_data], eax

	mov eax, [mouse_x]
	mov [mouse_old_x], eax
	mov eax, [mouse_y]
	mov [mouse_old_y], eax

.do_x:
	; do the x pos first
	movzx eax, [mouse_packet.x]
	test [mouse_packet.data], MOUSE_X_SIGN
	jnz .x_neg

.x_pos:
	add [mouse_x], eax
	jmp .do_y

.x_neg:
	not al
	inc al
	sub [mouse_x], eax
	jns .do_y

	xor eax, eax
	mov [mouse_x], eax

.do_y:
	; do the same for y position
	movzx eax, [mouse_packet.y]
	test [mouse_packet.data], MOUSE_Y_SIGN
	jnz .y_neg

.y_pos:
	sub [mouse_y], eax
	jns .check_x

	xor eax, eax
	mov [mouse_y], eax
	jmp .check_x

.y_neg:
	not al
	inc al
	add [mouse_y], eax

.check_x:
	mov eax, [mouse_x]
	cmp eax, [mouse_x_max]
	jge .x_max

	jmp .check_y

.x_max:
	mov eax, [mouse_x_max]
	mov [mouse_x], eax

.check_y:
	mov eax, [mouse_y]
	cmp eax, [screen.height]
	jge .y_max

	jmp .quit

.y_max:
	mov eax, [screen.height]
	dec eax
	mov [mouse_y], eax

.quit:
	ret

; show_mouse:
; Shows the mouse cursor
align 32
show_mouse:
	mov [mouse_visible], 1
	call redraw_mouse
	ret

; hide_mouse:
; Hides the mouse cursor
align 32
hide_mouse:
	mov [mouse_visible], 0
	call redraw_screen	; redraw screen objects to hide mouse ;)
	ret

; redraw_mouse:
; Redraws the mouse
align 32
redraw_mouse:
	test [mouse_visible], 1
	jz .only_screen

	; only redraw if the mouse has actually been "moved"
	; for click events, don't redraw -- it prevents flickering
	mov eax, [mouse_x]
	cmp eax, [mouse_old_x]
	jne .redraw

	mov eax, [mouse_y]
	cmp eax, [mouse_old_y]
	jne .redraw

	ret

.redraw:
	call use_back_buffer
	call unlock_screen
	call redraw_screen
	call use_front_buffer

	; just for testing ;)
	;mov eax, [mouse_x]
	;mov ebx, [mouse_y]
	;mov esi, 16
	;mov edi, 16
	;mov edx, 0xd8d8d8
	;call fill_rect

	mov eax, [mouse_x]
	mov ebx, [mouse_y]
	mov esi, [mouse_width]
	mov edi, [mouse_height]
	mov ecx, 0xd8d8d8		; transparent color
	mov edx, [mouse_cursor]
	call blit_buffer

	;call use_back_buffer
	;call unlock_screen
	ret

align 32
.only_screen:
	call use_back_buffer
	call unlock_screen
	call redraw_screen
	ret


