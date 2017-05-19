
; 2048 Game Clone for xOS

use32
org 0x8000000		; programs are loaded to 128 MB, drivers to 2048 MB

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

; Window Manager Events
WM_LEFT_CLICK			= 0x0001
WM_RIGHT_CLICK			= 0x0002
WM_KEYPRESS			= 0x0004
WM_CLOSE			= 0x0008

; Scancodes for the arrow keys ;)
SCANCODE_UP			= 72
SCANCODE_LEFT			= 75
SCANCODE_RIGHT			= 77
SCANCODE_DOWN			= 80

WINDOW_WIDTH			= 276
WINDOW_HEIGHT			= 300

; Colors
BOARD_BG			= 0xbbada0
TILE0_BG			= 0xccbeb1
TILE2_BG			= 0xeee4da
TILE4_BG			= 0xede0c8
TILE8_BG			= 0xf2b179
TILE16_BG			= 0xf59563
TILE32_BG			= 0xf67c5f
TILE64_BG			= 0xf65e3b
TILE128_BG			= 0xedcf72
TILE256_BG			= 0xedcc61
TILE512_BG			= 0xedc850
TILE1024_BG			= 0xedc53f
TILE2048_BG			= 0xedc22e

include				"2048/xos.asm"		; system calls
include				"2048/canvas.asm"	; window canvas manipulation
include				"2048/rand.asm"		; RNG

; main:
; Game Entry Point

main:
	; create window
	mov ax, 192
	mov bx, 180
	mov si, WINDOW_WIDTH
	mov di, WINDOW_HEIGHT
	mov ecx, game_title
	mov dx, 0
	mov ebp, XOS_WM_CREATE_WINDOW
	int 0x60

	mov [window_handle], eax

; start_game:
; Begins a new game

start_game:
	; clear the board
	mov edi, board
	mov eax, 256
	mov ecx, 0
	rep stosd

	; reset the score
	mov [score], 0

	; initialize the random number generator
	call rand_init

.game_loop:
	; the board always starts with two numbers
	call create_new_number
	call create_new_number
	call redraw_board

.idle:
	mov ebp, XOS_YIELD
	int 0x60

	; wait for event
	mov ebp, XOS_WM_READ_EVENT
	mov eax, [window_handle]
	int 0x60

	test ax, WM_CLOSE
	jnz end_game

	test ax, WM_KEYPRESS
	jnz .keypress

	jmp .idle

.keypress:
	call process_keypress
	jmp .idle

; process_keypress:
; Processes a keypress

process_keypress:
	mov ebp, XOS_READ_KEY
	int 0x60
	mov [.scancode], ah
	mov [.character], al

	cmp ah, SCANCODE_UP
	je .move_up

	;cmp ah, SCANCODE_DOWN
	;je .move_down

	ret

.move_up:
	call move_board_up
	jmp .done

.done:
	call create_new_number
	call redraw_board
	ret

.scancode			db 0
.character			db 0

; move_board_up:
; Moves the board up

move_board_up:
	; first try the move the second row to the first, the third to the second, etc...
	mov ecx, 0
	call move_column_up
	mov ecx, 1
	call move_column_up
	mov ecx, 2
	call move_column_up
	mov ecx, 3
	call move_column_up

	mov ecx, 0
	call add_column
	mov ecx, 1
	call add_column
	mov ecx, 2
	call add_column
	mov ecx, 3
	call add_column

	mov ecx, 0
	call move_column_up
	mov ecx, 1
	call move_column_up
	mov ecx, 2
	call move_column_up
	mov ecx, 3
	call move_column_up

	ret

; add_column:
; Adds a column
; In\	ECX = Column number
; Out\	Nothing

add_column:
	shl ecx, 2
	mov [.col_offset], ecx

.start:
	mov ecx, [.col_offset]
	mov edi, board

.check0:
	mov eax, [edi+ecx]
	cmp eax, [edi+ecx+16]
	je .add0

	jmp .check1

.add0:
	shl eax, 1
	add [score], eax
	mov [edi+ecx], eax
	mov dword[edi+ecx+16], 0

.check1:
	add edi, 16
	mov eax, [edi+ecx]
	cmp eax, [edi+ecx+16]
	je .add1

	jmp .check2

.add1:
	shl eax, 1
	add [score], eax
	mov [edi+ecx], eax
	mov dword[edi+ecx+16], 0

.check2:
	add edi, 16
	mov eax, [edi+ecx]
	cmp eax, [edi+ecx+16]
	je .add2

	jmp .done

.add2:
	shl eax, 1
	add [score], eax
	mov [edi+ecx], eax
	mov dword[edi+ecx+16], 0

.done:
	ret

align 4
.col_offset				dd 0

; move_column_up:
; Moves a column up
; In\	ECX = Column number
; Out\	Nothing

move_column_up:
	mov [.col], ecx

	shl ecx, 2
	mov [.col_offset], ecx

	mov [.times], 4

.start:
	mov ecx, [.col_offset]

	mov edi, board
	cmp dword[edi+ecx], 0
	je .move_row1

.check_row2:
	cmp dword[edi+ecx+16], 0
	je .move_row2

.check_row3:
	cmp dword[edi+ecx+32], 0
	je .move_row3

	jmp .done

.move_row1:
	mov eax, [edi+ecx+16]
	mov [edi+ecx], eax
	mov dword[edi+ecx+16], 0
	jmp .check_row2

.move_row2:
	mov eax, [edi+ecx+32]
	mov [edi+ecx+16], eax
	mov dword[edi+ecx+32], 0
	jmp .check_row3

.move_row3:
	mov eax, [edi+ecx+48]
	mov [edi+ecx+32], eax
	mov dword[edi+ecx+48], 0

.done:
	dec [.times]
	cmp [.times], 0
	jne .start

	ret

align 4
.col				dd 0
.col_offset			dd 0
.times				dd 4

; end_game:
; Quits the game

end_game:
	mov ebp, XOS_TERMINATE
	int 0x60

; create_new_number:
; Creates a new number in the board

create_new_number:
	; first check if there are any free slots
	mov ecx, 0
	mov edi, board

.loop:
	cmp dword[edi], 0
	je .okay

	inc ecx
	add edi, 4
	cmp ecx, 15
	jg .ret

	jmp .loop

.okay:
	call rand
	cmp ecx, 15
	jg .okay

	shl eax, 2		; mul 4
	mov edi, board
	add edi, eax
	cmp dword[edi], 0
	jne .okay

	mov dword[edi], 2
	ret

.ret:
	ret

; redraw_board:
; Redraws the board

redraw_board:
	mov ax, 0
	mov bx, 0
	mov si, WINDOW_WIDTH
	mov di, WINDOW_HEIGHT
	mov edx, BOARD_BG
	call fill_rect

	; draw each number in the board
	mov ecx, 0

.loop:
	push ecx
	call redraw_number
	pop ecx
	inc ecx
	cmp ecx, 15
	jle .loop

.done:
	mov ebx, 0
	mov esi, score_text
	mov cx, 4
	mov dx, 276
	call draw_text

	mov eax, [score]
	call int_to_string
	mov ebx, 0
	mov cx, (7*8)+4
	mov dx, 276
	call draw_text

	; request a redraw
	mov ebp, XOS_WM_REDRAW
	int 0x60
	ret

; redraw_number:
; Redraws one number
; In\	ECX = 0-based board position
; Out\	Nothing

redraw_number:
	mov [.number], ecx

	cmp ecx, 15
	jg .done

	; determine the y pos
	cmp ecx, 3
	jle .y_zero

	cmp ecx, 7
	jle .y_one

	cmp ecx, 11
	jle .y_two

	cmp ecx, 15
	jle .y_three

.y_zero:
	mov [.y], 4
	jmp .find_x

.y_one:
	mov [.y], 4+64+4
	sub ecx, 4
	jmp .find_x

.y_two:
	mov [.y], 4+64+4+64+4
	sub ecx, 8
	jmp .find_x

.y_three:
	mov [.y], 4+64+4+64+4+64+4
	sub ecx, 12

.find_x:
	cmp ecx, 0
	je .x_zero

	cmp ecx, 1
	je .x_one

	cmp ecx, 2
	je .x_two

	cmp ecx, 3
	je .x_three

.x_zero:
	mov [.x], 4
	jmp .draw

.x_one:
	mov [.x], 4+64+4
	jmp .draw

.x_two:
	mov [.x], 4+64+4+64+4
	jmp .draw

.x_three:
	mov [.x], 4+64+4+64+4+64+4

.draw:
	mov ecx, [.number]
	shl ecx, 2		; mul 4
	add ecx, board
	mov ecx, [ecx]		; actual number

	mov ax, [.x]
	mov bx, [.y]
	mov si, 64
	mov di, 64

	cmp ecx, 0
	je .draw0

	cmp ecx, 2
	je .draw2

	cmp ecx, 4
	je .draw4

	cmp ecx, 8
	je .draw8

	cmp ecx, 16
	je .draw16

	cmp ecx, 32
	je .draw32

	cmp ecx, 64
	je .draw64

	cmp ecx, 128
	je .draw128

	cmp ecx, 256
	je .draw256

	cmp ecx, 512
	je .draw512

	cmp ecx, 1024
	je .draw1024

	cmp ecx, 2048
	je .draw2048

	jmp .done

.draw0:
	mov edx, TILE0_BG
	call fill_rect

	jmp .done

.draw2:
	mov edx, TILE2_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-4
	add dx, 32-8
	mov ebx, 0
	mov esi, string2
	call draw_text

	jmp .done

.draw4:
	mov edx, TILE4_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-4
	add dx, 32-8
	mov ebx, 0
	mov esi, string4
	call draw_text

	jmp .done

.draw8:
	mov edx, TILE8_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-4
	add dx, 32-8
	mov ebx, 0
	mov esi, string8
	call draw_text

	jmp .done

.draw16:
	mov edx, TILE16_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-8
	add dx, 32-8
	mov ebx, 0
	mov esi, string16
	call draw_text

	jmp .done

.draw32:
	mov edx, TILE32_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-8
	add dx, 32-8
	mov ebx, 0
	mov esi, string32
	call draw_text

	jmp .done

.draw64:
	mov edx, TILE64_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-8
	add dx, 32-8
	mov ebx, 0
	mov esi, string64
	call draw_text

	jmp .done

.draw128:
	mov edx, TILE128_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-12
	add dx, 32-8
	mov ebx, 0
	mov esi, string128
	call draw_text

	jmp .done

.draw256:
	mov edx, TILE256_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-12
	add dx, 32-8
	mov ebx, 0
	mov esi, string256
	call draw_text

	jmp .done

.draw512:
	mov edx, TILE512_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-12
	add dx, 32-8
	mov ebx, 0
	mov esi, string512
	call draw_text

	jmp .done

.draw1024:
	mov edx, TILE1024_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-16
	add dx, 32-8
	mov ebx, 0
	mov esi, string1024
	call draw_text

	jmp .done

.draw2048:
	mov edx, TILE2048_BG
	call fill_rect

	mov cx, [.x]
	mov dx, [.y]
	add cx, 32-16
	add dx, 32-8
	mov ebx, 0
	mov esi, string2048
	call draw_text

	jmp .done

.done:
	ret

align 4
.number				dd 0
.y				dw 0
.x				dw 0

; int_to_string:
; Converts an unsigned integer to a string
; In\	EAX = Integer
; Out\	ESI = ASCIIZ string

int_to_string:
	push eax
	mov [.counter], 10

	mov edi, .string
	mov ecx, 10
	mov eax, 0
	rep stosb

	mov esi, .string
	add esi, 9
	pop eax

.loop:
	cmp eax, 0
	je .done2
	mov ebx, 10
	mov edx, 0
	div ebx

	add dl, 48
	mov byte[esi], dl
	dec esi

	sub byte[.counter], 1
	cmp byte[.counter], 0
	je .done
	jmp .loop

.done:
	mov esi, .string
	ret

.done2:
	cmp byte[.counter], 10
	je .zero
	mov esi, .string

.find_string_loop:
	lodsb
	cmp al, 0
	jne .found_string
	jmp .find_string_loop

.found_string:
	dec esi
	ret

.zero:
	mov edi, .string
	mov al, '0'
	stosb
	mov al, 0
	stosb
	mov esi, .string

	ret

.string:		times 11 db 0
.counter		db 0

; Data

align 4
board:
	dd 0,0,0,0
	dd 0,0,0,0
	dd 0,0,0,0
	dd 0,0,0,0

align 4
window_handle			dd 0
score				dd 0

game_title			db "2048",0
string2				db "2",0
string4				db "4",0
string8				db "8",0
string16			db "16",0
string32			db "32",0
string64			db "64",0
string128			db "128",0
string256			db "256",0
string512			db "512",0
string1024			db "1024",0
string2048			db "2048",0

score_text			db "Score: ",0




