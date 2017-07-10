
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Type of BOOTP requests
DHCP_BOOT_REQUEST			= 1
DHCP_BOOT_REPLY				= 2

; Type of DHCP messages
DHCP_DISCOVER				= 1
DHCP_OFFER				= 2
DHCP_REQUEST				= 3
DHCP_ACK				= 5

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
; Detects and initializes the network using DHCP

dhcp_init:
	call dhcp_discover

	cmp eax, 0
	je .fail
	cmp eax, 0xFFFFFFFF
	je .fail

	mov [router_ip], ebx
	mov [dns_ip], ecx

	; eax = my IP
	call dhcp_request

	; detect the router MAC
	mov eax, [router_ip]
	mov edi, router_mac
	call arp_request

	cmp eax, 0
	jne .fail

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

	mov esi, .dns_msg
	call kprint
	movzx eax, byte[dns_ip]
	call int_to_string
	call kprint
	mov esi, .dot
	call kprint
	movzx eax, byte[dns_ip+1]
	call int_to_string
	call kprint
	mov esi, .dot
	call kprint
	movzx eax, byte[dns_ip+2]
	call int_to_string
	call kprint
	mov esi, .dot
	call kprint
	movzx eax, byte[dns_ip+3]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	mov [network_available], 1
	ret

.fail:
	mov [network_available], 0
	ret

.ip_msg					db "net-dhcp: client IP is ",0
.dot					db ".",0
.router_msg				db ", router IP is ",0
.dns_msg				db "net-dhcp: DNS server is ",0


; dhcp_discover:
; Detects IP information using DHCP
; In\	Nothing
; Out\	EAX = Client IP address
; Out\	EBX = Router IP address
; Out\	ECX = DNS IP address

dhcp_discover:
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
	mov al, DHCP_DISCOVER	; discover
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

	; start from 192.168.1.2
	mov al, 192
	stosb
	mov al, 168
	stosb
	mov al, 1
	stosb
	mov al, 2
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

	; open a socket and send the message
	mov al, SOCKET_PROTOCOL_UDP
	mov ebx, 0xFFFFFFFF		; broadcast 255.255.255.255
	mov edx, (DHCP_DESTINATION_PORT shl 16) or DHCP_SOURCE_PORT
	call socket_open

	cmp eax, -1
	je .error

	mov [.socket], eax

	; send it
	mov eax, [.socket]
	mov esi, [.packet]
	mov ecx, [.packet_size]
	mov dl, 0
	call socket_write

	cmp eax, 0
	jne .error_close

	; read back a reply
	mov eax, [.socket]
	mov edi, [.packet]
	call socket_read

	cmp eax, 0
	je .error_close

	mov eax, [.socket]
	call socket_close

	; check for DHCP magic number
	mov esi, [.packet]
	cmp byte[esi+236], 0x63
	jne .error

	cmp byte[esi+237], 0x82
	jne .error

	cmp byte[esi+238], 0x53
	jne .error

	cmp byte[esi+239], 0x63
	jne .error

	; our transaction?
	mov eax, [dhcp_transaction_id]
	cmp [esi+4], eax
	jne .error

	; okay, this is our packet

	; it is a reply and not a request?
	mov al, [esi]
	cmp al, DHCP_BOOT_REPLY
	jne .error

	; okay, read our IP address
	mov eax, [esi+16]
	;bswap eax		; big-endian
	mov [.my_ip], eax

	; list of options
	;mov esi, [.packet]
	add esi, 240

.check_offer:
	; this must be a DHCP offer
	lodsb
	cmp al, DHCP_OPTION_PAD
	je .check_offer

	cmp al, DHCP_OPTION_END
	je .error

	cmp al, DHCP_OPTION_MESSAGE_TYPE
	je .found_message_type

	movzx eax, byte[esi]
	add esi, eax
	inc esi
	jmp .check_offer

.found_message_type:
	mov al, [esi+1]
	cmp al, DHCP_OFFER
	jne .error

	mov esi, [.packet]
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

	cmp al, DHCP_OPTION_DOMAIN_NAME_SERVER
	je .dns

	movzx eax, byte[esi]		; length
	add esi, eax
	inc esi
	jmp .options_loop

.router:
	mov eax, [esi+1]
	;bswap eax
	mov [.router_ip], eax

	movzx eax, byte[esi]
	add esi, eax
	inc esi
	jmp .options_loop

.dns:
	mov eax, [esi+1]
	mov [.dns_ip], eax

	movzx eax, byte[esi]
	add esi, eax
	inc esi
	jmp .options_loop

.finish:
	mov eax, [.packet]
	call kfree

	;mov [network_available], 1	; indicate that we are connected to the network

	mov eax, [.my_ip]
	mov ebx, [.router_ip]
	mov ecx, [.dns_ip]
	ret

.error_close:
	mov eax, [.socket]
	call socket_close

.error:
	;mov esi, .error_msg
	;call kprint

	mov eax, [.packet]
	call kfree

	mov [network_available], 0

	mov eax, 0
	mov ebx, 0
	mov ecx, 0
	ret

align 4
.packet					dd 0
.packet_size				dd 0
.socket					dd 0
.my_ip					dd 0
.router_ip				dd 0
.dns_ip					dd 0

.error_msg				db "net-dhcp: auto-configure failed, network access restricted.",10,0
.ip_msg					db "net-dhcp: client IP is ",0
.dot					db ".",0
.router_msg				db ", router IP is ",0
.dns_msg				db "net-dhcp: DNS server is ",0

; dhcp_request:
; Requests an IP address using DHCP
; In\	EAX = Requested IP
; Out\	EAX = 0 on success

dhcp_request:
	mov [.ip], eax

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
	mov al, DHCP_REQUEST	; request
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

	; our requested IP
	mov eax, [.ip]
	stosd

	; parameters requests -- we already have this from DHCP discover
	;mov al, DHCP_OPTION_PARAMETERS
	;stosb
	;mov al, 4
	;stosb
	;mov al, DHCP_OPTION_SUBNET_MASK		; request the subnet mask
	;stosb
	;mov al, DHCP_OPTION_ROUTER		; request the router's IP
	;stosb
	;mov al, DHCP_OPTION_DOMAIN_NAME_SERVER
	;stosb
	;mov al, DHCP_OPTION_DOMAIN_NAME
	;stosb

	; end of options
	mov al, DHCP_OPTION_END
	stosb

	sub edi, [.packet]
	mov [.packet_size], edi

	; open a socket and send the message
	mov al, SOCKET_PROTOCOL_UDP
	mov ebx, 0xFFFFFFFF		; broadcast 255.255.255.255
	mov edx, (DHCP_DESTINATION_PORT shl 16) or DHCP_SOURCE_PORT
	call socket_open

	cmp eax, -1
	je .error

	mov [.socket], eax

	; send it
	mov eax, [.socket]
	mov esi, [.packet]
	mov ecx, [.packet_size]
	mov dl, 0
	call socket_write

	cmp eax, 0
	jne .error_close

	; read back a reply
	mov eax, [.socket]
	mov edi, [.packet]
	call socket_read

	cmp eax, 0
	je .error_close

	mov eax, [.socket]
	call socket_close

	; check for DHCP magic number
	mov esi, [.packet]
	cmp byte[esi+236], 0x63
	jne .error

	cmp byte[esi+237], 0x82
	jne .error

	cmp byte[esi+238], 0x53
	jne .error

	cmp byte[esi+239], 0x63
	jne .error

	; our transaction?
	mov eax, [dhcp_transaction_id]
	cmp [esi+4], eax
	jne .error

	; okay, this is our packet

	; it is a reply and not a request?
	mov al, [esi]
	cmp al, DHCP_BOOT_REPLY
	jne .error

	; list of options
	;mov esi, [.packet]
	add esi, 240

.check_ack:
	; this must be a DHCP ACK message
	lodsb
	cmp al, DHCP_OPTION_PAD
	je .check_ack

	cmp al, DHCP_OPTION_END
	je .error

	cmp al, DHCP_OPTION_MESSAGE_TYPE
	je .found_message_type

	movzx eax, byte[esi]
	add esi, eax
	inc esi
	jmp .check_ack

.found_message_type:
	mov al, [esi+1]
	cmp al, DHCP_ACK
	jne .error

	mov esi, [.packet]
	mov eax, [esi+16]
	mov [my_ip], eax

	mov eax, [.packet]
	call kfree

	mov [network_available], 1	; indicate that we are connected to the network

	mov eax, 0
	ret

.error_close:
	mov eax, [.socket]
	call socket_close

.error:
	;mov esi, .error_msg
	;call kprint

	mov eax, [.packet]
	call kfree

	mov [network_available], 0

	mov eax, -1
	ret

align 4
.packet					dd 0
.packet_size				dd 0
.socket					dd 0
.ip					dd 0

