
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Address Resolution Protocol..
ARP_PROTOCOL_TYPE		= 0x0806
ARP_REQUEST			= 0x0001
ARP_REPLY			= 0x0002

; arp_gratuitous:
; Sends a gratuitous ARP request

arp_gratuitous:
	cmp [network_available], 0
	je .done

	mov ecx, 8192
	call kmalloc
	mov [.packet], eax

	mov edi, [.packet]
	mov ax, 0x0001
	xchg al, ah
	stosw			; hardware type - ethernet

	mov ax, IP_PROTOCOL_TYPE
	xchg al, ah
	stosw			; IP protocol

	mov al, 6		; MAC address size
	stosb

	mov al, 4		; IP address size
	stosb

	mov ax, ARP_REQUEST
	xchg al, ah
	stosw			; opcode

	; sender MAC address, that's us
	mov esi, my_mac
	mov ecx, 6
	rep movsb

	; my IP address
	mov esi, my_ip
	movsd

	; target MAC address - broadcast
	mov esi, broadcast_mac
	mov ecx, 6
	rep movsb

	; target IP address -- it's us again
	mov esi, my_ip
	movsd

	sub edi, [.packet]
	mov [.packet_size], edi

	; send the packet
	mov ebx, broadcast_mac
	mov ecx, [.packet_size]
	mov dx, ARP_PROTOCOL_TYPE	; type of packet
	mov esi, [.packet]
	call net_send

	push eax
	mov eax, [.packet]
	call kfree
	pop eax

.done:
	ret

align 4
.packet				dd 0
.packet_size			dd 0

; arp_request:
; Gets the MAC address from an IP address
; In\	EAX = IP address
; In\	EDI = 6-byte buffer to store MAC address
; Out\	EAX = 0 on success, EDI filled

arp_request:
	cmp [network_available], 0
	je .error

	mov [.ip], eax
	mov [.buffer], edi

	mov ecx, 8192
	call kmalloc
	mov [.packet], eax

	mov edi, [.packet]
	mov ax, 0x0001
	xchg al, ah
	stosw			; hardware type - ethernet

	mov ax, IP_PROTOCOL_TYPE
	xchg al, ah
	stosw			; IP protocol

	mov al, 6		; MAC address size
	stosb

	mov al, 4		; IP address size
	stosb

	mov ax, ARP_REQUEST
	xchg al, ah
	stosw			; opcode

	; sender MAC address, that's us
	mov esi, my_mac
	mov ecx, 6
	rep movsb

	; my IP address
	mov esi, my_ip
	movsd

	; target MAC address - broadcast
	mov esi, broadcast_mac
	mov ecx, 6
	rep movsb

	; target IP address, the IP we want
	mov eax, [.ip]
	stosd

	sub edi, [.packet]
	mov [.packet_size], edi

	; send the packet
	mov ebx, broadcast_mac
	mov ecx, [.packet_size]
	mov dx, ARP_PROTOCOL_TYPE	; type of packet
	mov esi, [.packet]
	call net_send

	cmp eax, 0
	jne .error

	; clear the buffer
	mov edi, [.packet]
	mov al, 0
	mov ecx, 8192
	rep stosb

.receive_start:
	; receive a packet in the same buffer
	mov [.wait_loops], 0
	inc [.packet_count]
	cmp [.packet_count], NET_TIMEOUT
	jge .error

.receive_loop:
	inc [.wait_loops]
	cmp [.wait_loops], NET_TIMEOUT
	jg .error

	mov edi, [.packet]
	call net_receive

	cmp eax, 0
	jne .check_received

	jmp .receive_loop

.check_received:
	; destination is us?
	mov esi, [.packet]
	mov edi, my_mac
	mov ecx, 6
	rep cmpsb
	jne .receive_start

	; is it an ARP packet?
	mov esi, [.packet]
	mov ax, [esi+12]
	xchg al, ah
	cmp ax, ARP_PROTOCOL_TYPE
	jne .receive_start

	; is it an ARP reply?
	add esi, ETHERNET_HEADER_SIZE
	mov ax, [esi+6]
	xchg al, ah
	cmp ax, ARP_REPLY
	jne .receive_start

	; copy the MAC address
	add esi, 8
	mov edi, [.buffer]
	mov ecx, 6
	rep movsb

	; finished..
	mov eax, [.packet]
	call kfree

	mov eax, 0
	ret

.error:
	mov eax, 1
	ret

align 4
.packet				dd 0
.packet_size			dd 0
.ip				dd 0
.buffer				dd 0
.wait_loops			dd 0
.packet_count			dd 0






