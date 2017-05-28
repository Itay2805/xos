
; RTL8139 Network Driver for xOS
; Copyright (c) 2017 by Omar Mohammad

use32

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

	; transmit buffer
	mov dx, [io]
	add dx, RTL8139_TRANSMIT_START
	mov eax, [.packet]
	out dx, eax
	call iowait

	; transmit configuration
	mov dx, [io]
	add dx, RTL8139_TRANSMIT_STATUS
	in eax, dx
	mov eax, [.size]
	and eax, 0x1FFF		; size of packet, clear OWN bit
	out dx, eax
	call iowait

	mov dx, [io]
	add dx, RTL8139_TRANSMIT_STATUS

	mov [.poll_times], 0

.dma_loop:
	inc [.poll_times]
	cmp [.poll_times], 0xFFFFF
	jg .timeout

	; poll the card -- wait for the DMA to complete
	in eax, dx
	test eax, RTL8139_TRANSMIT_STATUS_OWN		; DMA completed?
	jnz .dma_complete

	jmp .dma_loop

.dma_complete:
	mov [.poll_times], 0

	mov dx, [io]
	add dx, RTL8139_TRANSMIT_STATUS

.ok_loop:
	inc [.poll_times]
	cmp [.poll_times], 0xFFFFF
	jg .timeout

	; poll the card -- wait for the entire packet to send
	in eax, dx
	test eax, RTL8139_TRANSMIT_STATUS_OK		; packet send completed?
	jnz .ok

	jmp .ok_loop

.ok:
	; clean up the transmitter registers
	mov dx, [io]
	add dx, RTL8139_TRANSMIT_STATUS
	mov eax, 0
	out dx, eax

	mov dx, [io]
	add dx, RTL8139_TRANSMIT_START
	out dx, eax

	; and return success
	mov eax, 0
	ret

.timeout:
	; clean up the transmitter registers
	mov dx, [io]
	add dx, RTL8139_TRANSMIT_STATUS
	mov eax, 0
	out dx, eax

	mov dx, [io]
	add dx, RTL8139_TRANSMIT_START
	out dx, eax

	; and return failure
	mov eax, 1
	ret

align 4
.packet				dd 0
.size				dd 0
.poll_times			dd 0






