
; Intel i8254x-series Network Driver for xOS
; Heavily based on BareMetal i8254x driver, by Ian Seyler
; https://github.com/ReturnInfinity/BareMetal-OS

use32
org 0x80000000		; drivers loaded at 2 GB

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 1		; driver
	.entry			dd main		; entry point
	.pci_ids		dd pci_ids	; list of supported PCI IDs
	.driver_name		dd driver_name
	.reserved0		dq 0

pci_ids:			; list of valid vendor/device combinations
	dd 0x10008086		; 82542 (Fiber)
	dd 0x10018086		; 82543GC (Fiber)
	dd 0x10048086		; 82543GC (Copper)
	dd 0x10088086		; 82544EI (Copper)
	dd 0x10098086		; 82544EI (Fiber)
	dd 0x100A8086		; 82540EM
	dd 0x100C8086		; 82544GC (Copper)
	dd 0x100D8086		; 82544GC (LOM)
	dd 0x100E8086		; 82540EM
	dd 0x100F8086		; 82545EM (Copper)
	dd 0x10108086		; 82546EB (Copper)
	dd 0x10118086		; 82545EM (Fiber)
	dd 0x10128086		; 82546EB (Fiber)
	dd 0x10138086		; 82541EI
	dd 0x10148086		; 82541ER
	dd 0x10158086		; 82540EM (LOM)
	dd 0x10168086		; 82540EP (Mobile)
	dd 0x10178086		; 82540EP
	dd 0x10188086		; 82541EI
	dd 0x10198086		; 82547EI
	dd 0x101a8086		; 82547EI (Mobile)
	dd 0x101d8086		; 82546EB
	dd 0x101e8086		; 82540EP (Mobile)
	dd 0x10268086		; 82545GM
	dd 0x10278086		; 82545GM
	dd 0x10288086		; 82545GM
	dd 0x105b8086		; 82546GB (Copper)
	dd 0x10758086		; 82547GI
	dd 0x10768086		; 82541GI
	dd 0x10778086		; 82541GI
	dd 0x10788086		; 82541ER
	dd 0x10798086		; 82546GB
	dd 0x107a8086		; 82546GB
	dd 0x107b8086		; 82546GB
	dd 0x107c8086		; 82541PI
	dd 0x10b58086		; 82546GB (Copper)
	dd 0x11078086		; 82544EI
	dd 0x11128086		; 82544GC
	dd 0xFFFFFFFF		; terminate list

; Standard Driver Requests
; Requests 2 to 15 are reserved for future expansion
; Device-specific requests range from 16 to infinity..
STD_DRIVER_INIT			= 0x0000
STD_DRIVER_RESET		= 0x0001

; Network-Specific Driver Requests
NET_SEND_PACKET			= 0x0010
NET_RECEIVE_PACKET		= 0x0011
NET_GET_MAC			= 0x0012

	include			"i8254x/driver.asm"
	include			"i8254x/string.asm"

; main:
; Driver entry point

main:
	cmp eax, STD_DRIVER_INIT
	je driver_init

	push eax

	mov esi, unknown_msg
	mov ebp, XOS_KPRINT
	int 0x61

	pop eax
	call int_to_string
	mov ebp, XOS_KPRINT
	int 0x61

	mov esi, newline
	mov ebp, XOS_KPRINT
	int 0x61

	mov eax, -1
	ret

; driver_init:
; Initializes the driver
; In\	Nothing
; Out\	EAX = 0 on success

driver_init:
	; scan the PCI bus
	mov esi, pci_ids

.loop:
	lodsd
	cmp eax, 0xFFFFFFFF		; end of list
	je .no

	mov [.tmp], esi

	mov ebp, XOS_PCI_GET_VENDOR
	int 0x61

	cmp al, 0xFF
	je .next_device

	mov [pci_bus], al
	mov [pci_slot], ah
	mov [pci_function], bl

	mov esi, driver_name
	mov ebp, XOS_KPRINT
	int 0x61

	mov esi, found_msg
	mov ebp, XOS_KPRINT
	int 0x61
	mov al, [pci_bus]
	call hex_byte_to_string
	mov ebp, XOS_KPRINT
	int 0x61
	mov esi, colon
	mov ebp, XOS_KPRINT
	int 0x61
	mov al, [pci_slot]
	call hex_byte_to_string
	mov ebp, XOS_KPRINT
	int 0x61
	mov esi, colon
	mov ebp, XOS_KPRINT
	int 0x61
	mov al, [pci_function]
	call hex_byte_to_string
	mov ebp, XOS_KPRINT
	int 0x61
	mov esi, newline
	mov ebp, XOS_KPRINT
	int 0x61

	mov eax, 0
	ret		; for now...

.next_device:
	mov esi, [.tmp]
	jmp .loop

.no:
	mov eax, 1
	ret


.tmp				dd 0

	; Data Area
	newline			db 10,0
	driver_name		db "Intel i8254x-series network driver for xOS",10,0
	unknown_msg		db "i8254x: unknown request ",0

	found_msg		db "i8254x: found device on PCI slot ",0
	colon			db ":",0

	pci_bus			db 0
	pci_slot		db 0
	pci_function		db 0

	align 4
	mmio			dd 0





