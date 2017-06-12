
;; Calculator application for xOS
;; Copyright (C) 2017 by Omar Mohammad.

use32
org 0x8000000		; programs are loaded to 128 MB, drivers to 2048 MB

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

	include			"libxwidget/src/libxwidget.asm"		; widget library ;)

	; these tell the application what the user wants to do
	PLUS			= 1
	MINUS			= 2
	MULTIPLY		= 3
	DIVIDE			= 4

; main:
; Program entry point

main:
	; we have to call this in the beginning
	call xwidget_init

	; make a window
	mov ax, 300
	mov bx, 64
	mov si, 180
	mov di, 180
	mov dx, 0
	mov ecx, window_text
	call xwidget_create_window
	mov [window_handle], eax

	; lock the interface to prevent flickering
	mov eax, [window_handle]
	call xwidget_lock

	; create the interface
	mov eax, [window_handle]
	mov cx, 4
	mov dx, 32
	mov esi, text7
	call xwidget_create_button
	mov [button7_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4
	mov dx, 32
	mov esi, text8
	call xwidget_create_button
	mov [button8_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4+32+8+4
	mov dx, 32
	mov esi, text9
	call xwidget_create_button
	mov [button9_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4+32+8+4+32+8+4
	mov dx, 32
	mov esi, text_plus
	call xwidget_create_button
	mov [plus_handle], eax

	mov eax, [window_handle]
	mov cx, 4
	mov dx, 32+32+4
	mov esi, text4
	call xwidget_create_button
	mov [button4_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4
	mov dx, 32+32+4
	mov esi, text5
	call xwidget_create_button
	mov [button5_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4+32+8+4
	mov dx, 32+32+4
	mov esi, text6
	call xwidget_create_button
	mov [button6_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4+32+8+4+32+8+4
	mov dx, 32+32+4
	mov esi, text_minus
	call xwidget_create_button
	mov [minus_handle], eax

	mov eax, [window_handle]
	mov cx, 4
	mov dx, 32+32+4+32+4
	mov esi, text1
	call xwidget_create_button
	mov [button1_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4
	mov dx, 32+32+4+32+4
	mov esi, text2
	call xwidget_create_button
	mov [button2_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4+32+8+4
	mov dx, 32+32+4+32+4
	mov esi, text3
	call xwidget_create_button
	mov [button3_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4+32+8+4+32+8+4
	mov dx, 32+32+4+32+4
	mov esi, text_mul
	call xwidget_create_button
	mov [mul_handle], eax

	mov eax, [window_handle]
	mov cx, 4
	mov dx, 32+32+4+32+4+32+4
	mov esi, textc
	call xwidget_create_button
	mov [c_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4
	mov dx, 32+32+4+32+4+32+4
	mov esi, text0
	call xwidget_create_button
	mov [button0_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4+32+8+4
	mov dx, 32+32+4+32+4+32+4
	mov esi, text_equal
	call xwidget_create_button
	mov [equal_handle], eax

	mov eax, [window_handle]
	mov cx, 4+32+8+4+32+8+4+32+8+4
	mov dx, 32+32+4+32+4+32+4
	mov esi, text_div
	call xwidget_create_button
	mov [div_handle], eax

.start:
	mov [num1], 0
	mov [num1_size], 0
	mov [num2], 0
	mov [num2_size], 0

	mov [operation], 0
	mov [number_text_pointer], number_text
	mov [active_number], 0

	mov edi, number_text
	mov al, 0
	mov ecx, 128
	rep stosb

	mov byte[number_text], "0"

	mov eax, [window_handle]
	mov cx, 8
	mov dx, 8
	mov esi, number_text
	mov ebx, 0x000000
	call xwidget_create_label
	mov [label_handle], eax

	; unlock the window
	mov eax, [window_handle]
	call xwidget_unlock

.wait:
	; wait here for event
	call xwidget_wait_event

	cmp eax, XWIDGET_CLOSE
	je .close

	cmp eax, XWIDGET_BUTTON		; buttonclick event
	je .button_click

	jmp .wait

.close:
	call xwidget_destroy

	mov ebp, 0x15
	int 0x60

.button_click:
	; ebx has the button which was pressed
	cmp ebx, [button1_handle]
	je .1
	cmp ebx, [button2_handle]
	je .2
	cmp ebx, [button3_handle]
	je .3
	cmp ebx, [button4_handle]
	je .4
	cmp ebx, [button5_handle]
	je .5
	cmp ebx, [button6_handle]
	je .6
	cmp ebx, [button7_handle]
	je .7
	cmp ebx, [button8_handle]
	je .8
	cmp ebx, [button9_handle]
	je .9
	cmp ebx, [button0_handle]
	je .0

	cmp ebx, [plus_handle]
	je .plus
	cmp ebx, [minus_handle]
	je .minus
	cmp ebx, [mul_handle]
	je .mul
	cmp ebx, [div_handle]
	je .div

	cmp ebx, [c_handle]
	je .clear
	cmp ebx, [equal_handle]
	je .equal

	jmp .wait

.clear:
	mov eax, [window_handle]
	mov ebx, [label_handle]
	call xwidget_destroy_component

	jmp .start

.1:
	mov al, 1
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "1"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.2:
	mov al, 2
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "2"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.3:
	mov al, 3
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "3"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.4:
	mov al, 4
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "4"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.5:
	mov al, 5
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "5"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.6:
	mov al, 6
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "6"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.7:
	mov al, 7
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "7"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.8:
	mov al, 8
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "8"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.9:
	mov al, 9
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "9"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.0:
	mov al, 0
	call input_number
	jc .wait

	mov edi, [number_text_pointer]
	mov al, "0"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.plus:
	cmp [active_number], 1
	je .wait

	inc [active_number]
	mov [operation], PLUS

	mov edi, [number_text_pointer]
	mov al, "+"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.minus:
	cmp [active_number], 1
	je .wait

	inc [active_number]
	mov [operation], MINUS

	mov edi, [number_text_pointer]
	mov al, "-"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.mul:
	cmp [active_number], 1
	je .wait

	inc [active_number]
	mov [operation], MULTIPLY

	mov edi, [number_text_pointer]
	mov al, "*"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.div:
	cmp [active_number], 1
	je .wait

	inc [active_number]
	mov [operation], DIVIDE

	mov edi, [number_text_pointer]
	mov al, "/"
	stosb
	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp .wait

.equal:
	cmp [active_number], 0
	je .wait
	cmp [operation], 0	; this condition should never be true
	je .wait

	mov [active_number], 0

	cmp [operation], PLUS
	je do_add

	cmp [operation], MINUS
	je do_minus

	cmp [operation], MULTIPLY
	je do_multiply

	cmp [operation], DIVIDE
	je do_divide

	jmp .wait

do_add:
	mov eax, [num1]
	mov ebx, [num2]
	add eax, ebx
	mov [num1], eax

	call count_digits
	mov [num1_size], eax

	mov [num2], 0
	mov [num2_size], 0
	mov [operation], 0

	mov edi, number_text
	mov ecx, 128
	xor al,al
	rep stosb

	mov eax, [num1]
	call int_to_string
	call strlen

	mov edi, number_text
	mov ecx, eax
	rep movsb

	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp main.wait

do_minus:
	mov eax, [num1]
	mov ebx, [num2]
	sub eax, ebx
	mov [num1], eax

	call count_digits
	mov [num1_size], eax

	mov [num2], 0
	mov [num2_size], 0
	mov [operation], 0

	mov edi, number_text
	mov ecx, 128
	xor al,al
	rep stosb

	mov eax, [num1]
	call int_to_string
	call strlen

	mov edi, number_text
	mov ecx, eax
	rep movsb

	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp main.wait

do_multiply:
	mov eax, [num1]
	mov ebx, [num2]
	mul ebx
	mov [num1], eax

	call count_digits
	mov [num1_size], eax

	mov [num2], 0
	mov [num2_size], 0
	mov [operation], 0

	mov edi, number_text
	mov ecx, 128
	xor al,al
	rep stosb

	mov eax, [num1]
	call int_to_string
	call strlen

	mov edi, number_text
	mov ecx, eax
	rep movsb

	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp main.wait

do_divide:
	cmp [num2], 0		; check for divide by zero
	je .divide_error

	mov eax, [num1]
	mov ebx, [num2]
	xor edx, edx
	div ebx
	mov [num1], eax

	call count_digits
	mov [num1_size], eax

	mov [num2], 0
	mov [num2_size], 0
	mov [operation], 0

	mov edi, number_text
	mov ecx, 128
	xor al,al
	rep stosb

	mov eax, [num1]
	call int_to_string
	call strlen

	mov edi, number_text
	mov ecx, eax
	rep movsb

	mov [number_text_pointer], edi

	mov eax, [window_handle]
	call xwidget_redraw

	jmp main.wait

.divide_error:
	mov esi, divide_error_text
	mov ecx, divide_error_text_size
	mov edi, number_text
	rep movsb

	mov eax, [window_handle]
	call xwidget_redraw

.hang:
	call xwidget_wait_event
	cmp eax, XWIDGET_CLOSE
	je main.close

	cmp eax, XWIDGET_BUTTON
	jne .hang

	cmp ebx, [c_handle]
	je main.clear

	jmp .hang

; count_digits:
; Counts the digits of a number
; In\	EAX = Number
; Out\	EAX = Digits count
align 4
count_digits:
	cmp eax, 0
	je .zero

	xor ecx, ecx

.loop:
	xor edx, edx
	mov ebx, 10
	div ebx

	cmp eax, 0
	jne .increment
	cmp dl, 0
	jne .increment

	jmp .done

.increment:
	inc ecx
	jmp .loop

.done:
	mov eax, ecx
	ret

.zero:
	xor eax, eax
	ret

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

; strlen:
; Calculates string length
; In\	ESI = String
; Out\	EAX = String size

strlen:
	push esi

	xor ecx, ecx

.loop:
	lodsb
	cmp al, 0
	je .done
	inc ecx
	jmp .loop

.done:
	mov eax, ecx
	pop esi
	ret

; input_number:
; Inputs a number into the current active number
; In\	AL = Number (0-9)
; Out\	Nothing
align 4
input_number:
	cmp [active_number], 0
	je .1

.2:
	cmp [num2_size], 9
	jge .bad

	push eax

	mov eax, [num2]
	mov ebx, 10
	mul ebx

	pop edx
	and edx, 0xFF
	add eax, edx
	mov [num2], eax
	inc [num2_size]

	clc
	ret

.1:
	cmp [num1_size], 9
	jge .bad

	push eax

	mov eax, [num1]
	mov ebx, 10
	mul ebx

	pop edx
	and edx, 0xFF
	add eax, edx
	mov [num1], eax
	inc [num1_size]

	clc
	ret

.bad:
	stc
	ret

; xwidget_yield_handler:
; This is called by xwidget every time it is idle

xwidget_yield_handler:
	ret

	; Data...
	window_text		db "Calculator",0
	text0			db "0",0
	text1			db "1",0
	text2			db "2",0
	text3			db "3",0
	text4			db "4",0
	text5			db "5",0
	text6			db "6",0
	text7			db "7",0
	text8			db "8",0
	text9			db "9",0
	textc			db "C",0
	text_equal		db "=",0
	text_plus		db "+",0
	text_minus		db "-",0
	text_mul		db "*",0
	text_div		db "/",0
	divide_error_text	db "Divide by zero.",0
	divide_error_text_size	= $ - divide_error_text

	active_number		db 0

	number_text:		times 128 db 0
	number_text_pointer	dd number_text

	num1			dd 0
	num1_size		dd 0

	num2			dd 0
	num2_size		dd 0

	operation		db 0

	window_handle		dd 0
	label_handle		dd 0
	button0_handle		dd 0
	button1_handle		dd 0
	button2_handle		dd 0
	button3_handle		dd 0
	button4_handle		dd 0
	button5_handle		dd 0
	button6_handle		dd 0
	button7_handle		dd 0
	button8_handle		dd 0
	button9_handle		dd 0

	plus_handle		dd 0
	minus_handle		dd 0
	mul_handle		dd 0
	div_handle		dd 0

	c_handle		dd 0
	equal_handle		dd 0



