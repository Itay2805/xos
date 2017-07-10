
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

NET_TIMEOUT			= 0x100000		; times to poll..
NET_BUFFER_SIZE			= 65536

ETHERNET_HEADER_SIZE		= 14			; size in bytes

; Network-Specific Driver Requests
NET_SEND_PACKET			= 0x0010
NET_RECEIVE_PACKET		= 0x0011
NET_GET_MAC			= 0x0012

network_available		db 0
network_driver_available	db 0
my_mac:				times 6 db 0		; PC's MAC address
my_ip:				times 4 db 0		; PC's IPv4 address
router_mac:			times 6 db 0xFF
router_ip:			times 4 db 0
dns_ip:				times 4 db 0		; DNS server
broadcast_mac:			times 6 db 0xFF		; FF:FF:FF:FF:FF:FF

align 4
netstat:
	.sent_bytes		dd 0
	.received_bytes		dd 0

align 4
net_buffer			dd 0

; Free port for TCP/UDP sockets
align 2
local_port			dw 32768

; net_init:
; Initializes the network stack

net_init:
	mov ecx, NET_BUFFER_SIZE
	call kmalloc
	mov [net_buffer], eax

	mov ecx, DNS_MAX_CACHE * DNS_CACHE_SIZE
	call kmalloc
	mov [dns_cache], eax
	add eax, DNS_MAX_CACHE * DNS_CACHE_SIZE
	mov [dns_end_cache], eax

	mov [network_available], 0

	; TO-DO: make a configuration file which tells which driver to load
	; TO-DO: auto-detect network cards and load an appropriate driver or give information
	mov esi, .rtl8139_filename
	call load_driver

	cmp eax, 0
	je .start

	mov esi, .i8254x_filename
	call load_driver

	cmp eax, 0
	jne .no_driver

.start:
	mov [net_mem], ebx
	mov [net_mem_size], ecx
	mov [net_entry], edx
	mov [network_driver_available], 1

	; okay, driver loaded
	; now we need to initialize and reset the device
	mov eax, STD_DRIVER_RESET
	mov ebp, [net_entry]
	call ebp

	cmp eax, 0
	jne .no_driver

	; load the MAC address
	mov eax, NET_GET_MAC
	mov ebx, my_mac
	mov ebp, [net_entry]
	call ebp

	mov esi, .mac_msg
	call kprint

	mov al, [my_mac]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [my_mac+1]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [my_mac+2]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [my_mac+3]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [my_mac+4]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [my_mac+5]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	; allocate memory for the sockets
	mov ecx, MAX_SOCKETS*SOCKET_SIZE
	call kmalloc
	mov [sockets], eax

;.do_dhcp:
	; get ourselves an IP address using DHCP with a timeout
	;inc [.dhcp_tries]
	;cmp [.dhcp_tries], 10
	;jge .dhcp_done

	;call dhcp_init
	;cmp [network_available], 1
	;jne .do_dhcp

;.dhcp_done:
	;call arp_gratuitous

	ret

.no_driver:
	mov esi, .no_driver_msg
	call kprint

	mov [network_available], 0
	mov [network_driver_available], 0
	ret

.rtl8139_filename:		db "drivers/netio/rtl8139.sys",0
.i8254x_filename:		db "drivers/netio/i8254x.sys",0
.no_driver_msg			db "net: failed to load NIC driver, can't initialize network stack...",10,0
.mac_msg			db "net: MAC address is ",0
.colon				db ":",0

align 4
.dhcp_tries			dd 0

; net_get_connection:
; Returns the internet connection status
; In\	Nothing
; Out\	EAX = Status (0 = no connection, 1 = connected)

net_get_connection:
	movzx eax, [network_available]
	ret

; net_checksum:
; Performs the network checksum on data
; In\	ESI = Data
; In\	ECX = Number of bytes
; Out\	AX = Checksum

net_checksum:
	test ecx, 1		; odd?
	jnz .odd

	; even is easier...
	mov ebx, 0
	shr ecx, 1		; div 2

.even_loop:
	lodsw
	xchg al, ah		; big endian!

	and eax, 0xFFFF
	add ebx, eax

	loop .even_loop
	jmp .added

.odd:
	push esi
	add esi, ecx
	dec esi
	mov [.last_byte], esi

	pop esi
	mov ebx, 0
	shr ecx, 1		; div 2

.odd_loop:
	lodsw
	xchg al, ah

	and eax, 0xFFFF
	add ebx, eax

	cmp esi, [.last_byte]
	je .do_last_byte

	loop .odd_loop

.do_last_byte:
	mov ah, [esi]
	and eax, 0xFF00		; keep AH only
	add ebx, eax

.added:
	; now check if the top WORD is zero...
	mov ecx, ebx
	shr ecx, 16
	cmp cx, 0
	je .done

	and ebx, 0xFFFF
	add ebx, ecx
	jmp .added

.done:
	mov ax, bx
	not ax
	ret

align 4
.last_byte			dd 0

; net_send:
; Sends a packet over the network
; In\	EBX = Pointer to destination MAC
; In\	ECX = Size of packet
; In\	DX = Type of packet
; In\	ESI = Data payload
; Out\	EAX = 0 on success

net_send:
	cmp [network_driver_available], 1
	jne .no_driver

	mov [.destination], ebx
	mov [.size], ecx
	mov [.type], dx
	mov [.payload], esi

	; allocate space for a packet, with the ethernet header
	mov ecx, [.size]
	add ecx, ETHERNET_HEADER_SIZE+64
	call kmalloc
	mov [.packet], eax

	; write the source and destination MAC addresses
	mov edi, [.packet]
	mov esi, [.destination]
	mov ecx, 6
	rep movsb

	mov esi, my_mac
	mov ecx, 6
	rep movsb

	mov ax, [.type]
	xchg al, ah	; network is big-endian...
	stosw

	mov esi, [.payload]
	mov ecx, [.size]
	rep movsb

	;cmp [.size], 46		; do we need to make a padding
	;jl .padding		; yeah we do..

	mov ecx, [.size]
	add ecx, ETHERNET_HEADER_SIZE
	mov [.final_size], ecx
	jmp .send

.padding:
	mov ecx, 46
	mov al, 0
	rep stosb

	mov ecx, [.size]
	add ecx, 46
	mov [.final_size], ecx

.send:
	mov eax, DRIVER_LOAD_ADDRESS
	mov ebx, [net_mem]
	mov ecx, [net_mem_size]
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE
	call vmm_map_memory

	mov [.tries], 0

.send_again:
	inc [.tries]
	cmp [.tries], 16
	jge .give_up

	mov eax, NET_SEND_PACKET
	mov ebx, [.packet]
	mov ecx, [.final_size]
	mov ebp, [net_entry]
	call ebp

	cmp eax, 0
	je .success

	mov edx, eax
	push edx

	mov eax, STD_DRIVER_RESET
	mov ebp, [net_entry]
	call ebp

	pop edx
	jmp .send_again

.success:
	mov eax, [.packet]
	call kfree

	mov eax, [.final_size]
	add [netstat.sent_bytes], eax

	mov eax, 0
	ret

.give_up:
	push edx

	mov eax, [.packet]
	call kfree

	pop eax
	ret

.no_driver:
	mov eax, 1
	ret

align 4
.source				dd 0
.destination			dd 0
.size				dd 0
.payload			dd 0
.packet				dd 0
.final_size			dd 0
.tries				dd 0
.type				dw 0

; net_receive:
; Receives a packet from the network
; In\	EDI = Buffer to receive packet
; Out\	EAX = Byte count received

net_receive:
	cmp [network_driver_available], 1
	jne .no_driver

	push edi

	mov eax, DRIVER_LOAD_ADDRESS
	mov ebx, [net_mem]
	mov ecx, [net_mem_size]
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE
	call vmm_map_memory

	pop ebx
	mov eax, NET_RECEIVE_PACKET
	mov ebp, [net_entry]
	call ebp

	add [netstat.received_bytes], eax
	ret

.no_driver:
	mov eax, 0
	ret

; net_idle:
; Called every time the system is idle, to handle unrequested incoming packets

net_idle:
	cmp [network_driver_available], 1
	jne .really_quit

	cmp [network_available], 1
	je .quit

	; if we don't have a network connection --
	; -- keep polling to try and make a connection here
	inc [.network_timeout]
	cmp [.network_timeout], TIMER_FREQUENCY
	jl .quit

	mov [.network_timeout], 0
	call dhcp_init

	cmp [network_available], 0
	je .quit

	call net_handle
	call arp_gratuitous	; let other PCs know we're alive
	;call icmp_ping		; let the router know we're alive
	call net_handle

.quit:
	call net_handle

.really_quit:
	ret

align 4
.network_timeout		dd 0


; net_handle:
; Handles unrequested incoming packets, from system idle process

net_handle:
	cmp [open_sockets], 0		; so we don't accidentally mess with the socket's stuff
	jne .quit

	mov edi, [net_buffer]
	call net_receive

	cmp eax, 0
	je .quit

	mov ecx, eax		; ecx = size
	call net_handle_packet
	jmp net_handle

.quit:
	ret

; net_handle_packet:
; Handles a single packet
; In\	ECX = Size
; Out\	Nothing

net_handle_packet:
	mov [.size], ecx

	; check packet type
	mov esi, [net_buffer]
	mov ecx, [.size]
	mov ax, [esi+12]
	xchg al, ah

	cmp ax, IP_PROTOCOL_TYPE
	je .ip

	cmp ax, ARP_PROTOCOL_TYPE
	je .arp

	mov [kprint_type], KPRINT_TYPE_WARNING
	mov esi, .dropping_msg
	call kprint
	mov eax, [.size]
	call int_to_string
	call kprint
	mov esi, .dropping_msg2
	call kprint
	mov esi, [net_buffer]
	mov ax, [esi+12]
	xchg al, ah
	call hex_word_to_string
	call kprint
	mov esi, newline
	call kprint
	mov [kprint_type], KPRINT_TYPE_NORMAL
	jmp net_handle

.quit:
	ret

.ip:
	call ip_handle
	ret

.arp:
	call arp_handle
	ret

align 4
.size				dd 0
.dropping_msg			db "net: dropping packet, total size ",0
.dropping_msg2			db ", protocol 0x",0

; net_increment_port:
; Increments the socket port
; In\	Nothing
; Out\	AX = Port number

net_increment_port:
	add [local_port], 2
	cmp [local_port], 65000
	jge .reset

	mov ax, [local_port]
	ret

.reset:
	mov [local_port], 32768
	mov ax, 32768
	ret



