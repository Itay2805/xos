
;; xOS Shell
;; Copyright (c) 2017 by Omar Mohammad.

use32

; shutdown_dialog:
; Displays the "Shutdown/Restart" dialog prompt and takes action

shutdown_dialog:
	; destroy the menu
	mov eax, [menu_window_handle]
	call xwidget_kill_window

	mov ebp, XOS_FREE
	mov eax, [config_buffer]
	int 0x60

	; make a window
	mov ax, [width]
	mov bx, [height]
	shr ax, 1
	shr bx, 1
	sub ax, 320/2
	sub bx, 128/2

	mov si, 320
	mov di, 128
	mov dx, 0
	mov ecx, shutdown_title
	call xwidget_create_window
	mov [shutdown_handle], eax

	; lock
	mov eax, [shutdown_handle]
	call xwidget_lock

	; set window color
	;mov eax, [shutdown_handle]
	;mov ebx, 0x222222
	;call xwidget_window_set_color

	; make the hint and two buttons
	mov eax, [shutdown_handle]
	mov cx, 8
	mov dx, 8
	mov esi, shutdown_caption
	mov ebx, 0xFFFFFF
	call xwidget_create_label

	mov eax, [shutdown_handle]
	mov cx, 16
	mov dx, 32
	mov bx, 96
	mov di, 32
	mov ebp, shutdown_color
	mov esi, shutdown_text
	call xwidget_create_gbutton
	mov [shutdown_button_handle], eax

	mov eax, [shutdown_handle]
	mov cx, 16
	mov dx, 32+32+4
	mov bx, 96
	mov di, 32
	mov ebp, restart_color
	mov esi, restart_text
	call xwidget_create_gbutton
	mov [restart_button_handle], eax

	; unlock
	mov eax, [shutdown_handle]
	call xwidget_unlock

.wait:
	call xwidget_wait_event

	cmp eax, XWIDGET_CLOSE
	je .close

	cmp eax, XWIDGET_BUTTON
	jne .wait

	cmp ebx, [shutdown_button_handle]
	je .shutdown

	cmp ebx, [restart_button_handle]
	je .restart

	jmp .wait

.close:
	cmp ebx, [shutdown_handle]
	jne .wait

	mov eax, [shutdown_handle]
	call xwidget_kill_window

	jmp main.hang

.shutdown:
	mov ebp, XOS_SHUTDOWN
	int 0x60

.restart:
	mov ebp, XOS_REBOOT
	int 0x60


