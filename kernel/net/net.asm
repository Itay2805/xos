
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

ETHERNET_HEADER_SIZE		= 14			; size in bytes

; Network-Specific Driver Requests
NET_SEND_PACKET			= 0x0010
NET_RECEIVE_PACKET		= 0x0011
NET_GET_MAC			= 0x0012

my_mac:				times 6 db 0		; PC's MAC address
my_ip:				times 4 db 0		; PC's IPv4 address
router_mac:			times 6 db 0
router_ip:			times 4 db 0
broadcast_mac:			times 6 db 0xFF		; FF:FF:FF:FF:FF:FF

; net_init:
; Initializes the network stack

net_init:
	; TO-DO: make a configuration file which tells which driver to load
	; TO-DO: auto-detect network cards and load an appropriate driver or give information
	mov esi, .driver_filename
	call load_driver

	cmp eax, 0
	jne .no_driver

	mov [net_mem], ebx
	mov [net_mem_size], ecx
	mov [net_entry], edx

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

	;call dhcp_init

	ret

.no_driver:
	mov esi, .no_driver_msg
	call kprint

	ret

.driver_filename:		db "drivers/rtl8139.sys",0
.no_driver_msg			db "net: failed to load NIC driver, can't initialize network stack...",10,0
.mac_msg			db "net: MAC address is ",0
.colon				db ":",0

test_packet:			times 64 db 0

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

	cmp [.size], 46		; do we need to make a padding
	jl .padding		; yeah we do..

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

	mov eax, STD_DRIVER_RESET
	mov ebp, [net_entry]
	call ebp

	jmp .send_again

.success:
	mov eax, [.packet]
	call kfree

	mov eax, 0
	ret

.give_up:
	push eax

	mov eax, [.packet]
	call kfree

	pop eax
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

	ret



