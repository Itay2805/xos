
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; EHCI Capability MMIO Registers
EHCI_CAPLENGTH			= 0x0000	; byte
EHCI_VERSION			= 0x0002	; word
EHCI_STRUCTURAL_PARAMETERS	= 0x0004	; dword
EHCI_CAPABILITY_PARAMETERS	= 0x0008	; dword
EHCI_COMPANION_ROUTE		= 0x000C	; qword

; EHCI Operational MMIO Registers
EHCI_USBCMD			= 0x0000	; dword
EHCI_USBSTS			= 0x0004	; dword
EHCI_USBINTR			= 0x0008	; dword
EHCI_FRINDEX			= 0x000C	; dword
EHCI_CTRLDSSEGMENT		= 0x0010	; dword
EHCI_PERIODICLISTBASE		= 0x0014	; dword
EHCI_ASYNCLISTADDR		= 0x0018	; dword
EHCI_CONFIGFLAG			= 0x0040	; dword
EHCI_PORTSC			= 0x0044	; dword

; EHCI Command Register
EHCI_USBCMD_RUN			= 0x00000001
EHCI_USBCMD_HCRESET		= 0x00000002

EHCI_DESCRIPTORS_SIZE		= 8	; 8*4 KB much more than enough

align 4
ehci_pci_list			dd 0
ehci_pci_count			dd 0
ehci_descriptors		dd 0

; ehci_init:
; Detects and initializes USB EHCI host controllers

ehci_init:
	; generate a list of PCI devices
	mov ah, 0x0C
	mov al, 0x03
	mov bl, 0x20
	call pci_generate_list

	; no EHCI?
	cmp ecx, 0
	je .done

	mov [ehci_pci_list], eax
	mov [ehci_pci_count], ecx

	mov esi, .starting
	call kprint
	mov eax, [ehci_pci_count]
	call int_to_string
	call kprint
	mov esi, .starting2
	call kprint

	; allocate memory
	mov eax, 0
	mov ecx, EHCI_DESCRIPTORS_SIZE
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE or PAGE_NO_CACHE
	call vmm_alloc
	mov [ehci_descriptors], eax

.loop:
	mov ecx, [.controller]
	cmp ecx, [ehci_pci_count]
	jge .done

	call ehci_init_controller
	inc [.controller]
	jmp .loop

.done:
	ret

align 4
.controller			dd 0
.starting			db "usb-ehci: found ",0
.starting2			db " EHCI controllers, initializing in order...",10,0

; ehci_init_controller:
; Initializes a single EHCI controller
; In\	ECX = Controller index
; Out\	Nothing

ehci_init_controller:
	mov [.controller], ecx

	shl ecx, 2		; mul 4
	add ecx, [ehci_pci_list]
	mov al, [ecx+PCI_DEVICE_BUS]
	mov [.bus], al
	mov al, [ecx+PCI_DEVICE_SLOT]
	mov [.slot], al
	mov al, [ecx+PCI_DEVICE_FUNCTION]
	mov [.function], al

	mov esi, .starting
	call kprint
	mov al, [.bus]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [.slot]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [.function]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	; map the I/O memory
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov dl, 0		; bar0
	call pci_map_memory

	cmp eax, 0
	je .memory_error

	mov [.mmio], eax

	; enable MMIO and DMA, disable interrupt line
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov bh, PCI_STATUS_COMMAND
	call pci_read_dword

	or eax, 0x406

	mov edx, eax
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov bh, PCI_STATUS_COMMAND
	call pci_write_dword

	; allocate memory for the device addresses
	mov ecx, USB_MAX_ADDRESSES
	call kmalloc
	mov [.memory], eax

	; register the controller...
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov cl, USB_EHCI
	mov edx, [.mmio]
	mov esi, [.memory]
	call usb_register

	; usb controller is now in eax
	call usb_reset_controller
	ret

.memory_error:
	mov [kprint_type], KPRINT_TYPE_WARNING
	mov esi, .memory_error_msg
	call kprint
	mov [kprint_type], KPRINT_TYPE_NORMAL

	ret

align 4
.controller			dd 0
.mmio				dd 0
.memory				dd 0

.bus				db 0
.slot				db 0
.function			db 0

.starting			db "usb-ehci: initialize EHCI controller on PCI slot ",0
.colon				db ":",0
.memory_error_msg		db "usb-ehci: unable to map MMIO memory in virtual address space.",10,0

; ehci_reset_controller:
; Resets an EHCI controller
; In\	EAX = Pointer to controller information
; Out\	Nothing

ehci_reset_controller:
	mov [.controller], eax

	mov edx, [eax+USB_CONTROLLER_BASE]
	mov [.mmio_cap], edx

	mov eax, [edx]
	add edx, eax
	mov [.mmio_op], edx

	ret		; for now

align 4
.controller			dd 0
.mmio_cap			dd 0		; capability registers
.mmio_op			dd 0		; operational registers





