
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
	add dx, RTL8139_INTERRUPT_STATUS
	in ax, dx
	and ax, RTL8139_INTERRUPT_RECEIVE_OK
	out dx, ax

	mov esi, [rx_buffer_current]
	lodsw

	test ax, 1		; good packet?
	jz .empty

	; okay, copy the packet
	movzx ecx, word[esi]		; packet size
	sub ecx, 4
	mov [.size], ecx
	add esi, 2			; actual packet
	mov edi, [.buffer]
	rep movsb

	mov dx, [io]
	add dx, RTL8139_RX_COUNT
	in ax, dx

	cmp ax, 0xF000			; 60 KB
	jge .reset			; yep - reset the descriptor before we overflow

	mov eax, [.size]
	add eax, 4
	add [rx_buffer_current], eax

	mov eax, [.size]
	ret

.empty:
	mov eax, 0
	ret

.reset:
	call driver_reset		; reset everything
	mov eax, [.size]
	ret

align 4
.buffer				dd 0
.size				dd 0



