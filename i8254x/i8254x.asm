
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
	include			"i8254x/registers.asm"
	include			"i8254x/transmit.asm"
	include			"i8254x/receive.asm"

; main:
; Driver entry point
; In\	EAX = Request code
; In\	EBX, ECX, EDX, ESI, EDI = Parameters 1, 2, 3, 4, 5
; Out\	EAX = Returned status

main:
	cmp eax, STD_DRIVER_INIT	; detect/initialize?
	je driver_init

	cmp eax, STD_DRIVER_RESET	; reset?
	je driver_reset

	cmp eax, NET_GET_MAC		; get MAC address?
	je get_mac

	cmp eax, NET_SEND_PACKET	; transmit packet?
	je transmit

	cmp eax, NET_RECEIVE_PACKET	; receive packet?
	je receive

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
	mov esi, newline
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

	; map the memory
	mov ebp, XOS_PCI_MAP_MEMORY
	mov al, [pci_bus]
	mov ah, [pci_slot]
	mov bl, [pci_function]
	mov dl, 0		; BAR0
	int 0x61

	cmp eax, 0
	je .memory_error

	mov [mmio], eax

	; enable MMIO, busmaster DMA, disable interrupts
	mov al, [pci_bus]
	mov ah, [pci_slot]
	mov bl, [pci_function]
	mov bh, PCI_STATUS_COMMAND
	mov ebp, XOS_PCI_READ
	int 0x61

	mov edx, eax
	or edx, 0x406
	mov al, [pci_bus]
	mov ah, [pci_slot]
	mov bl, [pci_function]
	mov bh, PCI_STATUS_COMMAND
	mov ebp, XOS_PCI_WRITE
	int 0x61

	mov eax, 0
	mov ecx, (48*1024)/4096
	mov dl, 0x13		; present, read/write, uncacheable
	mov ebp, XOS_VMM_ALLOC
	int 0x61
	mov [rx_buffer], eax

	mov eax, 0
	mov ecx, (48*1024)/4096
	mov dl, 0x13		; present, read/write, uncacheable
	mov ebp, XOS_VMM_ALLOC
	int 0x61
	mov [receive_buffer], eax

	mov eax, 0
	mov ecx, (16*1024)/4096
	mov dl, 0x13		; present, read/write, uncacheable
	mov ebp, XOS_VMM_ALLOC
	int 0x61
	mov [tx_buffer], eax

	; okay, we're finished
	mov eax, 0
	ret

.next_device:
	mov esi, [.tmp]
	jmp .loop

.memory_error:
	mov esi, mmio_error_msg
	mov ebp, XOS_KPRINT
	int 0x61

.no:
	mov eax, 1
	ret

align 4
.tmp				dd 0

; driver_reset:
; Resets the i8254x NIC
; In\	Nothing
; Out\	EAX = 0 on success

driver_reset:
	mov edi, [mmio]

	mov eax, 0xFFFFFFFF
	mov [edi+I8254X_REG_IMC], eax		; disable interrupt causes

	mov eax, [edi+I8254X_REG_ICR]		; clear pending interrupts
	mov eax, 0
	mov [edi+I8254X_REG_ITR], eax		; disable interrupt throttling

	mov eax, 48
	mov [edi+I8254X_REG_PBA], eax		; RX buffer is 48 KB

	mov eax, 0x80008060
	mov [edi+I8254X_REG_TXCW], eax

	mov eax, [edi+I8254X_REG_CTRL]
	btr eax, 3
	bts eax, 6
	bts eax, 5
	btr eax, 31
	btr eax, 30
	btr eax, 7
	mov [edi+I8254X_REG_CTRL], eax

	push edi
	add edi, 0x5200		; MTA reset
	mov eax, 0xFFFFFFFF
	stosd
	stosd
	stosd
	stosd
	pop edi

	; receive buffer base address
	mov eax, [rx_buffer]
	mov ebp, XOS_VIRTUAL_TO_PHYSICAL
	int 0x61

	mov edi, [mmio]
	mov [edi+I8254X_REG_RDBAL], eax
	mov eax, 0
	mov [edi+I8254X_REG_RDBAH], eax

	mov eax, [receive_buffer]
	mov ebp, XOS_VIRTUAL_TO_PHYSICAL
	int 0x61

	mov edi, [rx_buffer]
	stosd
	mov eax, 0
	stosd
	stosd
	stosd

	; receive descriptor length
	mov edi, [mmio]
	mov eax, 32*16
	mov [edi+I8254X_REG_RDLEN], eax

	; head and tail
	mov eax, 0
	mov [edi+I8254X_REG_RDH], eax

	mov eax, 1
	mov [edi+I8254X_REG_RDT], eax

	; enable receive, store bad packets, broadcast
	mov eax, 0x04008006
	mov [edi+I8254X_REG_RCTL], eax

	; transmit descriptor base address
	mov eax, [tx_buffer]
	mov ebp, XOS_VIRTUAL_TO_PHYSICAL
	int 0x61

	mov edi, [mmio]
	mov [edi+I8254X_REG_TDBAL], eax
	mov eax, 0
	mov [edi+I8254X_REG_TDBAH], eax

	; transmit length
	mov eax, 32*16
	mov [edi+I8254X_REG_TDLEN], eax

	; transmit head and tail
	mov eax, 0
	mov [edi+I8254X_REG_TDH], eax
	mov [edi+I8254X_REG_TDT], eax

	mov eax, 0x010400FA
	mov [edi+I8254X_REG_TCTL], eax

	mov eax, 0x0060200A
	mov [edi+I8254X_REG_TIPG], eax

	mov eax, 0
	mov [edi+I8254X_REG_RDTR], eax
	mov [edi+I8254X_REG_RADV], eax
	mov [edi+I8254X_REG_RSRPD], eax

	mov eax, 0
	ret

; get_mac:
; Returns the MAC address
; In\	EBX = Buffer to store MAC address
; Out\	EAX = 0

get_mac:
	mov [.buffer], ebx

	mov edi, [mmio]
	mov eax, [edi+0x5400]
	cmp eax, 0
	je .eeprom

	mov esi, [mmio]
	add esi, 0x5400
	mov edi, [.buffer]
	mov eax, [esi]
	stosd
	mov eax, [esi+4]	; not sure if register access *must* be 32-bit... it doesn't hurt
	stosw

	mov eax, 0
	ret

.eeprom:
	mov edi, [.buffer]
	mov esi, [mmio]
	mov eax, 0x001
	mov [esi+0x14], eax

	pause

	mov eax, [esi+0x14]
	shr eax, 16
	stosw

	pause

	mov eax, 0x101
	mov [esi+0x14], eax

	pause

	mov eax, [esi+0x14]
	shr eax, 16
	stosw

	pause

	mov eax, 0x201
	mov [esi+0x14], eax

	pause

	mov eax, [esi+0x14]
	shr eax, 16
	stosw

	pause

	mov eax, 0
	ret

align 4
.buffer				dd 0

	; Data Area
	newline			db 10,0
	driver_name		db "Intel i8254x-series network driver for xOS",0
	unknown_msg		db "i8254x: unknown request ",0

	found_msg		db "i8254x: found device on PCI slot ",0
	colon			db ":",0
	mmio_error_msg		db "i8254x: unable to map PCI MMIO in virtual address space.",10,0

	pci_bus			db 0
	pci_slot		db 0
	pci_function		db 0

	align 4
	mmio			dd 0
	tx_buffer		dd 0
	rx_buffer		dd 0
	receive_buffer		dd 0






