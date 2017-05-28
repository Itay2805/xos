
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; User Datagram Protocol
UDP_PROTOCOL_TYPE		= 0x11		; for IP header
UDP_PSUEDO_HEADER_SIZE		= 11
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
	; for now...
	mov eax, 1
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







