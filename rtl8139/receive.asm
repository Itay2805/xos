
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
	mov dx, [io]
	add dx, RTL8139_INTERRUPT_STATUS
	in ax, dx

	test ax, RTL8139_INTERRUPT_RECEIVE_OK
	jnz .ok

	jmp .empty

.ok:
	; clear the status
	mov dx, [io]
	in ax, dx
	and ax, RTL8139_INTERRUPT_RECEIVE_OK
	out dx, ax

	mov esi, [rx_buffer]
	lodsw

	test ax, 1		; good packet?
	jz .empty

	; okay, copy the packet
	movzx ecx, word[esi]		; packet size
	mov [.size], ecx
	add esi, 2			; actual packet
	mov edi, [.buffer]
	rep movsb

	mov dx, [io]
	add dx, RTL8139_RX_COUNT
	in ax, dx
	and eax, 0xFFFF
	add [rx_buffer], eax

	mov eax, [.size]
	ret

.empty:
	mov eax, 0
	ret

align 4
.buffer				dd 0
.size				dd 0


.msg				db "receive",10,0


