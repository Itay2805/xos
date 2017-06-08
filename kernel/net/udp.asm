
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; User Datagram Protocol
UDP_PROTOCOL_TYPE		= 0x11		; for IP header
UDP_PSUEDO_HEADER_SIZE		= 12
UDP_HEADER_SIZE			= 8

; udp_send:
; Sends a UDP packet
; In\	EAX = Source IP
; In\	EBX = Destination IP
; In\	ECX = Data payload size
; In\	EDX = High WORD: destination port, low WORD: source port
; In\	ESI = Data payload
; In\	EDI = Destination MAC
; Out\	EAX = 0 on success

udp_send:
	mov [.source], eax
	mov [.destination], ebx
	mov [.size], ecx
	mov [.source_port], dx
	shr edx, 16
	mov [.destination_port], dx
	mov [.data], esi
	mov [.destination_mac], edi

	; allocate memory
	mov ecx, [.size]
	add ecx, UDP_HEADER_SIZE + UDP_PSUEDO_HEADER_SIZE
	call kmalloc
	mov [.packet], eax

	; create the UDP psuedo-header
	mov edi, [.packet]
	mov eax, [.source]
	stosd
	mov eax, [.destination]
	stosd
	mov al, 0
	stosb
	mov al, UDP_PROTOCOL_TYPE
	stosb
	mov eax, [.size]
	add ax, UDP_HEADER_SIZE
	xchg al, ah
	stosw

	; create the actual UDP header
	mov ax, [.source_port]
	xchg al, ah		; big-endian...
	stosw
	mov ax, [.destination_port]
	xchg al, ah
	stosw

	mov eax, [.size]
	add ax, UDP_HEADER_SIZE
	xchg al, ah
	stosw

	; checksum!
	push edi

	mov ax, 0	; for now -- calculate it later
	stosw

	; the actual data payload
	mov esi, [.data]
	mov ecx, [.size]
	rep movsb

	; calculate the checksum
	mov esi, [.packet]
	mov ecx, [.size]
	add ecx, UDP_HEADER_SIZE + UDP_PSUEDO_HEADER_SIZE
	call net_checksum

	pop edi
	xchg al, ah
	stosw

	; send the packet!
	mov eax, [.source]
	mov ebx, [.destination]
	mov ecx, [.size]
	add ecx, UDP_HEADER_SIZE
	mov dl, UDP_PROTOCOL_TYPE
	mov esi, [.packet]
	add esi, UDP_PSUEDO_HEADER_SIZE
	mov edi, [.destination_mac]
	call ip_send

	push eax

	mov eax, [.packet]
	call kfree

	pop eax
	ret

align 4
.source				dd 0
.destination			dd 0
.size				dd 0
.data_size			dd 0
.data				dd 0
.destination_mac		dd 0
.packet				dd 0

.source_port			dw 0
.destination_port		dw 0







