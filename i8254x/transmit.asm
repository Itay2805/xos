
; Intel i8254x-series Network Driver for xOS
; Heavily based on BareMetal i8254x driver, by Ian Seyler
; https://github.com/ReturnInfinity/BareMetal-OS

use32

; transmit:
; Sends a packet
; In\	EBX = Packet content
; In\	ECX = Size
; Out\	EAX = 0 on success, 1 on error

transmit:
	mov [.packet], ebx
	mov [.size], ecx

	mov eax, [.packet]
	mov ebp, XOS_VIRTUAL_TO_PHYSICAL
	int 0x61

	mov edi, [tx_buffer]
	stosd
	mov eax, 0
	stosd

	mov eax, [.size]
	bts eax, 24
	bts eax, 25
	bts eax, 27
	stosd

	mov eax, 0
	stosd

	mov edi, [mmio]
	mov eax, 0
	mov [edi+I8254X_REG_TDH], eax
	inc eax
	mov [edi+I8254X_REG_TDT], eax

.loop:
	pause
	mov esi, [tx_buffer]
	mov eax, [esi+3]
	test eax, 1		; descriptor done?
	jz .loop

	mov eax, 0
	ret

align 4
.packet				dd 0
.size				dd 0

