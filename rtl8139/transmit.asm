
; RTL8139 Network Driver for xOS
; Copyright (c) 2017 by Omar Mohammad

use32

transmit_descriptor			db 3

; transmit:
; Sends a packet
; In\	EBX = Packet content
; In\	ECX = Size
; Out\	EAX = 0 on success, 1 on error

transmit:
	mov [.size], ecx

	; for DMA to be happy..
	mov eax, ebx
	mov ebp, XOS_VIRTUAL_TO_PHYSICAL
	int 0x61
	mov [.packet], eax

	inc [transmit_descriptor]
	cmp [transmit_descriptor], 3
	jg .zero_descriptor

	jmp .start

.zero_descriptor:
	mov [transmit_descriptor], 0

.start:
	movzx dx, [transmit_descriptor]
	shl dx, 2		; mul 4
	add dx, RTL8139_TRANSMIT_START
	add dx, [io]
	mov [.transmit_start], dx

	movzx dx, [transmit_descriptor]
	shl dx, 2		; mul 4
	add dx, RTL8139_TRANSMIT_STATUS
	add dx, [io]
	mov [.transmit_status], dx

	; transmit buffer
	mov dx, [.transmit_start]
	;mov eax, 0
	;out dx, eax
	;call iowait

	mov eax, [.packet]
	out dx, eax
	call iowait

	; transmit configuration
	mov dx, [.transmit_status]
	mov eax, [.size]
	and eax, 0x1FFF		; size of packet, clear OWN bit which will clear all other bits
	;or eax, 2 shl 16	; threshold
	out dx, eax
	call iowait

	mov dx, [.transmit_status]
	mov [.poll_times], 0

.dma_loop:
	inc [.poll_times]
	cmp [.poll_times], 0x3FFFF
	jg .timeout

	; poll the card -- wait for the DMA transfer to complete
	in eax, dx
	test eax, RTL8139_TRANSMIT_STATUS_OWN		; DMA completed?
	jnz .dma_complete

	jmp .dma_loop

.dma_complete:
	mov [.poll_times], 0

	mov dx, [.transmit_status]

.ok_loop:
	inc [.poll_times]
	cmp [.poll_times], 0x3FFFF
	jg .timeout

	; poll the card -- wait for the entire network transfer to complete
	in eax, dx
	test eax, RTL8139_TRANSMIT_STATUS_OK	; packet send completed?
	jnz .ok

	jmp .ok_loop

.ok:
	; clean up the transmitter registers
	;mov dx, [io]
	;add dx, RTL8139_TRANSMIT_STATUS
	;mov eax, 0
	;out dx, eax

	;mov dx, [io]
	;add dx, RTL8139_TRANSMIT_START
	;out dx, eax

	mov dx, [io]
	add dx, RTL8139_INTERRUPT_STATUS
	in ax, dx
	and ax, RTL8139_INTERRUPT_TRANSMIT_OK or RTL8139_INTERRUPT_TRANSMIT_ERROR
	out dx, ax

	; and return success
	mov eax, 0
	ret

.timeout:
	mov esi, .timeout_msg
	mov ebp, XOS_KPRINT
	int 0x61

	; clean up the transmitter registers
	;mov dx, [io]
	;add dx, RTL8139_TRANSMIT_STATUS
	;mov eax, 0
	;out dx, eax

	;mov dx, [io]
	;add dx, RTL8139_TRANSMIT_START
	;out dx, eax

	mov dx, [io]
	add dx, RTL8139_INTERRUPT_STATUS
	in ax, dx
	and ax, RTL8139_INTERRUPT_TRANSMIT_OK or RTL8139_INTERRUPT_TRANSMIT_ERROR
	out dx, ax

	; and return failure
	mov eax, 1
	ret

align 4
.packet				dd 0
.size				dd 0
.poll_times			dd 0

.transmit_start			dw 0
.transmit_status		dw 0


.timeout_msg			db "rtl8139: transmit packet timeout.",10,0






