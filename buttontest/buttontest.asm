
;; Sample Application That Uses libxwidget
;; It creates a window with a button, and when the button is clicked creates a label in the window

use32
org 0x8000000		; programs are loaded to 128 MB, drivers to 2048 MB

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

	include			"libxwidget/src/libxwidget.asm"		; widget library ;)

; main:
; Program entry point

main:
	; have to run this...
	call xwidget_init

	; ask libxwidget for a window
	mov ax, 128
	mov bx, 128
	mov si, 256
	mov di, 192
	mov dx, 0
	mov ecx, window_title
	call xwidget_create_window
	mov [window_handle], eax

	; make a button in the window
	mov eax, [window_handle]
	mov esi, button_text
	mov cx, 4
	mov dx, 4
	call xwidget_create_button
	mov [button_handle], eax

.wait:
	; wait here for event
	call xwidget_wait_event
	cmp eax, XWIDGET_CLOSE		; close event?
	je .close

	cmp eax, XWIDGET_BUTTON		; button click event?
	jne .wait

	cmp ebx, [button_handle]	; our button was pressed
	jne .wait

	; create a label
	mov eax, [window_handle]
	mov esi, pressed_text
	mov cx, 4
	mov dx, 48
	mov ebx, 0x000000
	call xwidget_create_label

.hang:
	; there's not much left to do...
	call xwidget_wait_event
	cmp eax, XWIDGET_CLOSE		; close event?
	je .close
	jmp .hang

.close:
	mov ebp, 0x15		; terminate..
	int 0x60

; xwidget_yield_handler:
; This is called by xwidget every time it is idle

xwidget_yield_handler:
	ret

	; Data...
	window_title			db "Button Demo",0
	button_text			db "Click Me!",0
	pressed_text			db "Button has been pressed!",0
	window_handle			dd 0
	button_handle			dd 0



