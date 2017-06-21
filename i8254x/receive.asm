
; Intel i8254x-series Network Driver for xOS
; Heavily based on BareMetal i8254x driver, by Ian Seyler
; https://github.com/ReturnInfinity/BareMetal-OS

use32

; receive:
; Receives a packet
; In\	EBX = Buffer to receive
; Out\	EAX = Number of bytes received

receive:
	mov [.buffer], ebx

	mov esi, [rx_buffer]
	mov ax, [esi+12]		; status
	test ax, 1			; DD
	jz .zero

	and word[esi+12], not 1		; clear DD

	mov ecx, 0
	mov esi, [rx_buffer]
	mov cx, [esi+8]		; length
	mov [.length], ecx

	mov esi, [receive_buffer]
	mov edi, [.buffer]
	mov ecx, [.length]
	rep movsb

	mov eax, [receive_buffer]
	mov ebp, XOS_VIRTUAL_TO_PHYSICAL
	int 0x61

	mov edi, [rx_buffer]
	stosd
	mov eax, 0
	stosd
	;stosd
	;stosd

	mov edi, [mmio]
	mov eax, 0
	mov [edi+I8254X_REG_RDH], eax
	inc eax
	mov [edi+I8254X_REG_RDT], eax

	mov eax, [.length]
	ret

.zero:
	mov eax, 0
	ret

align 4
.buffer				dd 0
.length				dd 0

