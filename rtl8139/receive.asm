
; RTL8139 Network Driver for xOS
; Copyright (c) 2017 by Omar Mohammad

use32

; receive:
; Receives a packet
; In\	EBX = Buffer to receive
; Out\	EAX = Number of bytes received

receive:
	mov [.buffer], ebx

	; is there a packet?
	;mov dx, [io]
	;add dx, RTL8139_INTERRUPT_STATUS
	;in ax, dx
	;test ax, RTL8139_INTERRUPT_RECEIVE_OK
	;jz .empty

	mov dx, [io]
	add dx, RTL8139_COMMAND
	in al, dx
	test al, RTL8139_COMMAND_EMPTY
	jnz .empty

	; is it a good packet?
	mov dx, [io]
	add dx, RTL8139_RX_CURRENT_ADDRESS
	in ax, dx
	add ax, 16
	movzx eax, ax
	mov esi, [rx_buffer]
	add esi, eax

	mov ax, [esi]		; packet status
	test ax, 1
	jz .empty

	mov cx, [esi+2]		; packet size
	sub cx, 4
	mov [.size], cx

	add esi, 4		; skip packet header
	mov edi, [.buffer]
	movzx ecx, cx
	rep movsb

	; update capr
	;mov dx, [io]
	;add dx, RTL8139_RX_COUNT
	;in ax, dx
	;sub ax, 16
	;mov dx, [io]
	;add dx, RTL8139_RX_CURRENT_ADDRESS
	;out dx, ax

	mov dx, [io]
	add dx, RTL8139_RX_CURRENT_ADDRESS
	in ax, dx
	add ax, word[.size]
	add ax, 8 + 3		; skip packet header and ethernet CRC
	and ax, not 3		; must be dword aligned

	add ax, 16
	cmp ax, RX_BUFFER_SIZE-4096
	jge .reset

	sub ax, 16
	out dx, ax

	; clear interrupt
	mov dx, [io]
	add dx, RTL8139_INTERRUPT_STATUS
	in ax, dx
	and ax, RTL8139_INTERRUPT_RECEIVE_OK or RTL8139_INTERRUPT_RECEIVE_ERROR
	out dx, ax

	movzx eax, [.size]
	ret

.reset:
	call driver_reset

	;mov edi, [rx_buffer]
	;mov al, 0
	;mov ecx, RX_BUFFER_SIZE
	;rep stosb

	;mov dx, [io]
	;add dx, RTL8139_RX_CURRENT_ADDRESS
	;mov ax, 0xFFF0
	;out dx, ax

	; clear interrupt
	;mov dx, [io]
	;add dx, RTL8139_INTERRUPT_STATUS
	;in ax, dx
	;and ax, RTL8139_INTERRUPT_RECEIVE_OK or RTL8139_INTERRUPT_RECEIVE_ERROR
	;out dx, ax

	movzx eax, [.size]
	ret

.empty:
	;mov dx, [io]
	;add dx, RTL8139_INTERRUPT_STATUS
	;in ax, dx
	;and ax, RTL8139_INTERRUPT_RECEIVE_OK or RTL8139_INTERRUPT_RECEIVE_ERROR
	;out dx, ax

	mov eax, 0
	ret

align 4
.buffer				dd 0
.size				dw 0



