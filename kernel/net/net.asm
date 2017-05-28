
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Network-Specific Driver Requests
NET_SEND_PACKET			= 0x0010
NET_RECEIVE_PACKET		= 0x0011
NET_GET_MAC			= 0x0012

my_mac:				times 6 db 0		; PC's MAC address
my_ip:				times 4 db 0		; PC's IPv4 address

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

	ret

.no_driver:
	mov esi, .no_driver_msg
	call kprint

	ret

.driver_filename:		db "drivers/rtl8139.sys",0
.no_driver_msg			db "net: failed to load NIC driver, can't initialize network stack...",10,0
.mac_msg			db "net: MAC address is ",0
.colon				db ":",0




