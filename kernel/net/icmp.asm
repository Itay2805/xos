
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Internet Control Message Protocol

ICMP_PROTOCOL_TYPE		= 0x01
ICMP_ECHO_REQUEST		= 0x08
ICMP_ECHO_REPLY			= 0x00

; icmp_handle:
; Handles an incoming ICMP message
; In\	ESI = Packet
; In\	ECX = Size
; Out\	Nothing

icmp_handle:
	mov [.packet], esi
	mov [.packet_size], ecx

	mov esi, [.packet]
	mov eax, [esi+12]		; source IP
	mov [.ip], eax

	xor eax, eax
	mov al, [esi]			; IP header length
	and eax, 0xF
	shl eax, 2
	add [.packet], eax		; skip IP header
	mov bx, [esi+2]
	xchg bl, bh			; big endian
	movzx ebx, bx
	sub ebx, eax
	mov [.payload_size], ebx

	;mov esi, .msg
	;call kprint
	;mov eax, [.payload_size]
	;call int_to_string
	;call kprint
	;mov esi, newline
	;call kprint

	; if it's a ping request, reply
	mov esi, [.packet]
	mov al, [esi]
	cmp al, ICMP_ECHO_REQUEST
	jne .quit

	; allocate space for a reply
	mov ecx, [.payload_size]
	call kmalloc
	mov [.response], eax

	; construct the reply
	mov esi, [.packet]
	mov edi, [.response]
	mov ecx, [.payload_size]
	rep movsb

	mov edi, [.response]
	mov byte[edi], ICMP_ECHO_REPLY
	mov word[edi+2], 0		; checksum, calculate it now

	mov esi, [.response]
	mov ecx, [.payload_size]
	call net_checksum

	mov edi, [.response]
	xchg al, ah
	mov [edi+2], ax			; checksum

	; send the reply
	mov eax, [my_ip]
	mov ebx, [.ip]
	mov ecx, [.payload_size]
	mov dl, ICMP_PROTOCOL_TYPE
	mov esi, [.response]
	mov edi, router_mac
	call ip_send

	mov eax, [.response]
	call kfree

.quit:
	ret

align 4
.packet				dd 0
.packet_size			dd 0
.payload_size			dd 0
.response			dd 0
.ip				dd 0

.msg				db "net-icmp: handle incoming ICMP message, payload size ",0




