
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Transmission Control Protocol
TCP_PROTOCOL_TYPE			= 0x06
TCP_PSUEDO_HEADER_SIZE			= 12
TCP_HEADER_SIZE				= 32

; TCP Flags
TCP_FIN					= 0x01
TCP_SYN					= 0x02
TCP_PST					= 0x04
TCP_PSH					= 0x08
TCP_ACK					= 0x10
TCP_URG					= 0x20

; tcp_send:
; Sends a TCP packet
; In\	EAX = Source IP
; In\	EBX = Destination IP
; In\	ECX = Data payload size
; In\	EDX = High WORD: destination port, low WORD: source port
; In\	ESI = Sequence and ACK numbers and flags and window size, followed by data payload
; In\	EDI = Destination MAC
; Out\	EAX = 0 on success

tcp_send:
	mov [.source], eax
	mov [.destination], ebx
	mov [.size], ecx
	mov [.source_port], dx
	shr edx, 16
	mov [.destination_port], dx
	mov eax, [esi]
	mov [.sequence], eax
	mov eax, [esi+4]
	mov [.ack], eax
	mov eax, [esi+8]
	mov [.flags], eax
	mov eax, [esi+12]
	mov [.window], eax

	add esi, 16
	mov [.data], esi
	mov [.destination_mac], edi

	; allocate memory
	mov ecx, [.size]
	add ecx, TCP_HEADER_SIZE + TCP_PSUEDO_HEADER_SIZE
	call kmalloc
	mov [.packet], eax

	; create the TCP psuedo-header
	mov edi, [.packet]
	mov eax, [.source]
	stosd
	mov eax, [.destination]
	stosd
	mov al, 0
	stosb
	mov al, TCP_PROTOCOL_TYPE
	stosb
	mov eax, [.size]
	add ax, TCP_HEADER_SIZE
	xchg al, ah
	stosw

	; create the actual TCP header
	mov ax, [.source_port]
	xchg al, ah		; big-endian...
	stosw
	mov ax, [.destination_port]
	xchg al, ah
	stosw

	mov eax, [.sequence]
	bswap eax
	stosd

	mov eax, [.ack]
	bswap eax
	stosd

	mov al, 0x80			; header size
	stosb

	mov eax, [.flags]		; TCP flags
	and eax, 0x3F
	stosb

	mov eax, [.window]		; window size
	xchg al, ah
	stosw

	; checksum
	push edi			; calculate later
	mov ax, 0
	stosw

	mov ax, 0			; urgent pointer
	stosw

	; options and padding
	mov eax, 0
	stosd

	mov edi, [.packet]
	add edi, TCP_HEADER_SIZE + TCP_PSUEDO_HEADER_SIZE

	mov esi, [.data]		; actual data payload
	mov ecx, [.size]
	rep movsb

	; calculate the checksum
	mov esi, [.packet]
	mov ecx, [.size]
	add ecx, TCP_HEADER_SIZE + TCP_PSUEDO_HEADER_SIZE
	call net_checksum

	pop edi
	xchg al, ah
	stosw

	; send the packet!
	mov eax, [.source]
	mov ebx, [.destination]
	mov ecx, [.size]
	add ecx, TCP_HEADER_SIZE
	mov dl, TCP_PROTOCOL_TYPE
	mov esi, [.packet]
	add esi, TCP_PSUEDO_HEADER_SIZE
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
.sequence			dd 0
.ack				dd 0
.flags				dd 0
.window				dd 0

.source_port			dw 0
.destination_port		dw 0


