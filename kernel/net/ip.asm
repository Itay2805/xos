
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

IP_HEADER_SIZE			= 20
IP_PROTOCOL_TYPE		= 0x0800

; ip_send:
; Sends an IP packet
; In\	EAX = Source IP
; In\	EBX = Destination IP
; In\	ECX = Data payload size
; In\	DL = Protocol type
; In\	ESI = Data payload
; In\	EDI = Destination MAC
; Out\	EAX = 0 on success

ip_send:
	mov [.source], eax
	mov [.destination], ebx
	mov [.size], ecx
	mov [.protocol], dl
	mov [.payload], esi
	mov [.dest_mac], edi

	; allocate memory
	mov ecx, [.size]
	add ecx, IP_HEADER_SIZE
	call kmalloc
	mov [.packet], eax

	; construct the IP header
	mov edi, [.packet]
	mov al, 0x45		; 4 = IP version (IPv4)
				; 5 = size in DWORDs (5*2 = 20 = IP header size)
	stosb

	mov al, 0		; we don't need this
	stosb

	mov eax, [.size]	; total length of the payload including the IP packet
	add ax, IP_HEADER_SIZE
	xchg al, ah

	stosw

	mov ax, 0		; identification
	stosw

	mov ax, 0		; fragment offset
	stosw

	mov al, 80		; time to live
	stosb

	mov al, [.protocol]	; protocol
	stosb

	; checksum, will do this later
	push edi		; keep it for later...

	mov ax, 0
	stosw

	; source IP
	mov eax, [.source]
	stosd

	; destination IP
	mov eax, [.destination]
	stosd

	; make the checksum
	mov esi, [.packet]
	mov ecx, IP_HEADER_SIZE
	call net_checksum

	pop edi			; address of checksum
	xchg al, ah		; big-endian
	stosw

	; actual data payload
	mov edi, [.packet]
	add edi, IP_HEADER_SIZE
	mov esi, [.payload]
	mov ecx, [.size]
	rep movsb

	; okay, send the packet
	mov ebx, [.dest_mac]
	mov ecx, [.size]
	add ecx, IP_HEADER_SIZE		; actual size of packet
	mov dx, IP_PROTOCOL_TYPE
	mov esi, [.packet]
	call net_send

	push eax		; return status
	mov eax, [.packet]
	call kfree

	pop eax
	ret

align 4
.source				dd 0
.destination			dd 0
.size				dd 0
.payload			dd 0
.actual_size			dd 0
.packet				dd 0
.ip_header_end			dd 0
.dest_mac			dd 0
.protocol			db 0



