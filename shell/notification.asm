
;; xOS Shell
;; Copyright (c) 2017 by Omar Mohammad.

use32

align 4
notification_handle			dd -1

; network_notification:
; Shows the "network connected" notification

network_notification:
	mov ax, [width]
	sub ax, 256+32
	mov [.x], ax

	mov ax, [.x]
	mov bx, 32
	mov si, 256
	mov di, 64
	mov dx, WM_NO_FRAME
	mov ecx, title
	call xwidget_create_window
	mov [notification_handle], eax

	mov eax, [notification_handle]
	mov ebx, 0x101010
	call xwidget_window_set_color

	mov eax, [notification_handle]
	mov cx, 8
	mov dx, 16
	mov ebx, 0xFFFFFF

	cmp [network_status], 0
	je .no

	mov esi, .connect_text
	jmp .finish

.no:
	mov esi, .no_text

.finish:
	call xwidget_create_label
	ret

align 4
.x				dw 0
.connect_text			db "You are now connected to the",10
				db "internet.",0
.no_text			db "Failed to connect to the",10
				db "internet.",0

; close_notification:
; Closes a notification

close_notification:
	mov eax, [notification_handle]
	call xwidget_kill_window

	mov [notification_handle], -1
	ret

