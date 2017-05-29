
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Type of BOOTP requests
DHCP_BOOT_REQUEST			= 1
DHCP_BOOT_REPLY				= 2

; Types of DHCP options
DHCP_OPTION_PAD				= 0
DHCP_OPTION_SUBNET_MASK			= 1
DHCP_OPTION_ROUTER			= 3
DHCP_OPTION_DOMAIN_NAME_SERVER		= 6
DHCP_OPTION_DOMAIN_NAME			= 15
DHCP_OPTION_REQUESTED_IP		= 50
DHCP_OPTION_IP_LEASE_TIME		= 51
DHCP_OPTION_MESSAGE_TYPE		= 53
DHCP_OPTION_PARAMETERS			= 55
DHCP_OPTION_END				= 255

; For UDP
DHCP_SOURCE_PORT			= 68
DHCP_DESTINATION_PORT			= 67

dhcp_transaction_id			dd "XOS "

; dhcp_init:
; Detects IP information using DHCP

dhcp_init:
	mov ecx, 8192			; much more than enough
	call kmalloc
	mov [.packet], eax

	; make a DHCP packet
	; boot protocol first
	mov edi, [.packet]
	mov al, DHCP_BOOT_REQUEST
	stosb

	mov al, 1		; ethernet
	stosb

	mov al, 6		; MAC address length
	stosb

	mov al, 0		; hops
	stosb

	mov eax, [dhcp_transaction_id]
	stosd

	mov ax, 0		; seconds elapsed
	stosw

	mov ax, 0
	stosw			; boot flags

	mov eax, 0
	stosd			; client IP

	mov eax, 0
	stosd			; my IP

	mov eax, 0
	stosd			; next server IP

	mov eax, 0
	stosd			; relay agent IP

	mov esi, my_mac
	mov ecx, 6
	rep movsb		; my MAC address

	mov al, 0
	mov ecx, 10
	rep stosb		; MAC address padding

	mov al, 0
	mov ecx, 64
	rep stosb		; server host name

	mov al, 0
	mov ecx, 128
	rep stosb		; boot file name

	; DHCP magic number -- we are DHCP not BOOTP
	mov al, 0x63
	stosb
	mov al, 0x82
	stosb
	mov al, 0x53
	stosb
	mov al, 0x63
	stosb

	; options list
	mov al, DHCP_OPTION_MESSAGE_TYPE
	stosb
	mov al, 1		; length
	stosb
	mov al, 1		; discover
	stosb

	mov al, DHCP_OPTION_IP_LEASE_TIME
	stosb
	mov al, 4
	stosb
	mov eax, 0xFFFFFFFF	; infinity
	stosd

	mov al, DHCP_OPTION_REQUESTED_IP
	stosb
	mov al, 4
	stosb

	; 192.168.1.150
	mov al, 192
	stosb
	mov al, 168
	stosb
	mov al, 1
	stosb
	mov al, 150
	stosb

	; parameters requests
	mov al, DHCP_OPTION_PARAMETERS
	stosb
	mov al, 4
	stosb
	mov al, DHCP_OPTION_SUBNET_MASK		; request the subnet mask
	stosb
	mov al, DHCP_OPTION_ROUTER		; request the router's IP
	stosb
	mov al, DHCP_OPTION_DOMAIN_NAME_SERVER
	stosb
	mov al, DHCP_OPTION_DOMAIN_NAME
	stosb

	; end of options
	mov al, DHCP_OPTION_END
	stosb

	sub edi, [.packet]
	mov [.packet_size], edi

	; okay, send the packet
	; DHCP is built on top of UDP, which is built on IP, which is built on link...

	mov eax, 0x00000000		; my IP - we don't have an IP yet...
	mov ebx, 0xFFFFFFFF		; destination IP - we don't have the router's IP yet...
	mov ecx, [.packet_size]
	mov edx, (DHCP_DESTINATION_PORT shl 16) or DHCP_SOURCE_PORT
	mov esi, [.packet]
	mov edi, broadcast_mac		; FF:FF:FF:FF:FF:FF
	call udp_send

	cmp eax, 0
	jne .error

	; clear the packet data
	mov edi, [.packet]
	mov ecx, [.packet_size]
	mov al, 0
	rep stosb

	mov [.packet_count], 0

.receive_start:
	; receive a packet in the same buffer
	mov [.wait_loops], 0
	inc [.packet_count]
	cmp [.packet_count], 32
	jge .error

.receive_loop:
	inc [.wait_loops]
	cmp [.wait_loops], 0xFFFF
	jg .error

	mov edi, [.packet]
	call net_receive

	cmp eax, 0
	jne .check_received

	jmp .receive_loop

.check_received:
	cmp eax, 300		; check if the received packet is too small
	jl .receive_start	; try again

	; okay, check if the packet is the DHCP reply
	; destination has to be broadcast
	mov edi, [.packet]
	mov esi, broadcast_mac
	mov ecx, 6
	rep cmpsb
	jne .receive_start		; not our packet -- try again

	; save the source MAC
	mov esi, [.packet]
	add esi, 6
	mov edi, .packet_mac
	mov ecx, 6
	rep movsb

	mov esi, [.packet]
	mov ax, [esi+12]
	xchg al, ah
	cmp ax, IP_PROTOCOL_TYPE	; IP packet?
	jne .receive_start

	; read the IP packet
	mov esi, [.packet]
	add esi, ETHERNET_HEADER_SIZE
	cmp byte[esi+9], UDP_PROTOCOL_TYPE	; UDP?
	jne .receive_start

	;cmp byte[esi+9], TCP_PROTOCOL_TYPE	; big DHCP packets may be sent over DHCP...
	;jne .receive_start

	add esi, IP_HEADER_SIZE			; to UDP header
	mov ax, [esi]		; the reply source must be our destination
	xchg al, ah
	cmp ax, DHCP_DESTINATION_PORT
	jne .receive_start

	mov ax, [esi+2]		; and reply destination must be our source...
	xchg al, ah
	cmp ax, DHCP_SOURCE_PORT
	jne .receive_start

	add esi, UDP_HEADER_SIZE		; to DHCP packet...

	; check for DHCP magic number
	cmp byte[esi+236], 0x63
	jne .receive_start

	cmp byte[esi+237], 0x82
	jne .receive_start

	cmp byte[esi+238], 0x53
	jne .receive_start

	cmp byte[esi+239], 0x63
	jne .receive_start

	; our transaction?
	mov eax, [dhcp_transaction_id]
	cmp [esi+4], eax
	jne .receive_start

	; okay, this is our packet

	; it is a reply and not a request?
	mov al, [esi]
	cmp al, DHCP_BOOT_REPLY
	jne .receive_start

	; okay, read our IP address
	mov eax, [esi+16]
	;bswap eax		; big-endian
	mov dword[my_ip], eax

	; list of options
	;mov esi, [.packet]
	add esi, 240

.options_loop:
	; loop until we find the information we need
	lodsb
	cmp al, DHCP_OPTION_PAD
	je .options_loop

	cmp al, DHCP_OPTION_END
	je .finish

	cmp al, DHCP_OPTION_ROUTER
	je .router

	movzx eax, byte[esi]		; length
	add esi, eax
	inc esi
	jmp .options_loop

.router:
	mov eax, [esi+1]
	;bswap eax
	mov dword[router_ip], eax

	movzx eax, byte[esi]
	add esi, eax
	inc esi
	jmp .options_loop

.finish:
	mov esi, .ip_msg
	call kprint
	movzx eax, byte[my_ip]
	call int_to_string
	call kprint
	mov esi, .dot
	call kprint
	movzx eax, byte[my_ip+1]
	call int_to_string
	call kprint
	mov esi, .dot
	call kprint
	movzx eax, byte[my_ip+2]
	call int_to_string
	call kprint
	mov esi, .dot
	call kprint
	movzx eax, byte[my_ip+3]
	call int_to_string
	call kprint

	mov esi, .router_msg
	call kprint

	movzx eax, byte[router_ip]
	call int_to_string
	call kprint
	mov esi, .dot
	call kprint
	movzx eax, byte[router_ip+1]
	call int_to_string
	call kprint
	mov esi, .dot
	call kprint
	movzx eax, byte[router_ip+2]
	call int_to_string
	call kprint
	mov esi, .dot
	call kprint
	movzx eax, byte[router_ip+3]
	call int_to_string
	call kprint

	mov esi, newline
	call kprint

	mov eax, [.packet]
	call kfree

	ret

.error:
	mov esi, .error_msg
	call kprint

	mov eax, [.packet]
	call kfree
	ret

align 4
.packet					dd 0
.packet_size				dd 0
.wait_loops				dd 0
.packet_count				dd 0

.packet_mac:				times 6 db 0

.error_msg				db "net-dhcp: auto-configure failed, network access restricted.",10,0
.ip_msg					db "net-dhcp: client IP is ",0
.dot					db ".",0
.router_msg				db ", router IP is ",0



