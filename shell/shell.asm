
;; xOS Shell
;; Copyright (c) 2017 by Omar Mohammad.

use32
org 0x8000000

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

	title			db "xOS Shell",0

	include			"libxwidget/src/libxwidget.asm"		; widget library ;)
	include			"shell/string.asm"
	include			"shell/menu.asm"
	include			"shell/shutdown.asm"
	include			"shell/notification.asm"

	; For File Access
	FILE_WRITE		= 0x00000002
	FILE_READ		= 0x00000004
	SEEK_SET		= 0x00
	SEEK_CUR		= 0x01
	SEEK_END		= 0x02

; main:
; Shell entry point

main:
	call xwidget_init

	mov ebp, XOS_GET_SCREEN_INFO
	int 0x60
	mov [width], ax
	mov [height], bx

	; the taskbar really is a frameless unmoveable window ;)
	mov ax, 0
	mov bx, [height]
	sub bx, 32
	mov si, [width]
	mov di, 32
	;mov dx, WM_NO_FRAME
	mov dx, WM_TRANSPARENT
	mov ecx, title
	call xwidget_create_window
	mov [window_handle], eax

	mov eax, [window_handle]
	mov ebx, 0xFFFFFFFF		; transparent
	call xwidget_window_set_color

	mov eax, [window_handle]
	mov cx, 0
	mov dx, 0
	mov bx, 48
	mov di, 32
	mov ebp, menu_button_color
	mov esi, menu_text
	call xwidget_create_gbutton
	mov [menu_handle], eax

	call update_time

	mov eax, [window_handle]
	mov cx, [width]
	sub cx, (8*8)
	sub cx, 12
	mov dx, 8
	mov esi, time_text
	mov ebx, 0xFFFFFF
	call xwidget_create_label
	mov [time_handle], eax

.hang:
	call xwidget_wait_event
	cmp eax, XWIDGET_BUTTON
	jne .hang

.button:
	cmp ebx, [menu_handle]
	je open_menu
	cmp ebx, [notification_handle]
	je .close

	jmp .hang

.close:
	call close_notification
	jmp .hang

; config_error:
; Error handler when the configuration file cannot be read

config_error:
	mov ax, [width]
	mov bx, [height]
	shr ax, 1
	shr bx, 1
	sub ax, 320/2
	sub bx, 192/2

	mov si, 320
	mov di, 256
	mov dx, 0
	mov ecx, title
	call xwidget_create_window

	mov cx, 16
	mov dx, 16
	mov ebx, 0x000000
	mov esi, config_error_msg
	call xwidget_create_label

.hang:
	mov ebp, XOS_YIELD
	int 0x60
	jmp .hang

; xwidget_yield_handler:
; This is called by xwidget every time it is idle

xwidget_yield_handler:
	; get network status, show notification if needed
	mov ebp, XOS_NET_GET_CONNECTION
	int 0x60
	cmp eax, [network_status]
	je .time

	mov [network_status], eax
	call network_notification

.time:
	call update_time
	ret

	; screen resolution
	align 2
	width			dw 0
	height			dw 0

	align 4
	window_handle		dd 0
	menu_handle		dd 0
	time_handle		dd 0
	config_handle		dd 0
	config_buffer		dd 0
	config_end		dd 0
	config_size		dd 0
	shutdown_handle		dd 0
	shutdown_button_handle	dd 0
	restart_button_handle	dd 0
	network_status		dd 0

	align 4
	menu_button_color:
		.foreground	dd 0xFFFFFF
		.background	dd 0x008000

	shutdown_color:
		.foreground	dd 0xFFFFFF
		.background	dd 0xC00000

	restart_color:
		.foreground	dd 0xFFFFFF
		.background	dd 0x008000

	menu_text		db "MENU",0
	time_text		db "00:00 AM",0

	config_file		db "shell.cfg",0
	config_error_msg	db "Unable to open file 'shell.cfg' for", 10
				db "reading.",10,0

	shutdown_title		db "Shutdown",0
	shutdown_caption	db "What do you want to do with the PC?",0
	shutdown_text		db "Shutdown",0
	restart_text		db "Restart",0


