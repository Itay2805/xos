
; xOS System Monitor

use32

; kill_task:
; Opens the "kill task" window

kill_task:
	; create a window
	mov ax, 160
	mov bx, 160
	mov si, 256
	mov di, 160
	mov dx, 0
	mov ecx, kill_title
	call xwidget_create_window
	mov [kill_handle], eax

	; lock window
	mov eax, [kill_handle]
	call xwidget_lock

	; window components
	mov cx, 8
	mov dx, 8
	mov ebx, 0xFFFFFF
	mov eax, [kill_handle]
	mov esi, kill_caption
	call xwidget_create_label

	mov [kill_text.text_ptr], kill_text.text	; text pointer
	mov [kill_text.limit], 5			; limit

	mov edi, kill_text.text
	mov al, 0
	mov ecx, 6
	rep stosb

	mov cx, 8
	mov dx, 48
	mov si, 256-16
	mov di, 20
	mov bl, XWIDGET_TEXTBOX_FOCUSED
	mov ebp, kill_text
	mov eax, [kill_handle]
	call xwidget_create_textbox

	; redraw
	mov eax, [kill_handle]
	call xwidget_unlock

	mov eax, [kill_handle]
	call xwidget_redraw

.idle:
	call xwidget_wait_event
	cmp eax, XWIDGET_CLOSE
	je .close

	jmp .idle

.close:
	cmp ebx, [kill_handle]
	je .close_kill

	cmp ebx, [window_handle]	; main window
	je close

	jmp .idle

.close_kill:
	mov eax, [kill_handle]
	call xwidget_kill_window
	jmp main.idle

align 4
kill_handle			dd 0
kill_button			dd 0

kill_title			db "Kill a task",0
kill_caption			db "Enter the PID of the task you",10
				db "wish to kill.",0

align 4
kill_text:
	.text_ptr		dd .text
	.limit			dd 5		; limit

	.text:			times 6 db 0





