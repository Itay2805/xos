
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; OHCI MMIO Registers (all DWORDs)
OHCI_REVISION				= 0x00
OHCI_CONTROL				= 0x04
OHCI_COMMAND				= 0x08
OHCI_STATUS				= 0x0C
OHCI_INTERRUPT_ENABLE			= 0x10
OHCI_INTERRUPT_DISABLE			= 0x14
OHCI_CONTROL_HEAD_ED			= 0x20
OHCI_CONTROL_CURRENT_ED			= 0x24
OHCI_BULK_HEAD_ED			= 0x28
OHCI_BULK_CURRENT_ED			= 0x2C
OHCI_FM_INTERVAL			= 0x34
OHCI_FM_REMAINING			= 0x38
OHCI_FM_NUMBER				= 0x3C
OHCI_ROOT_DESCRIPTOR_A			= 0x48
OHCI_ROOT_DESCRIPTOR_B			= 0x4C
OHCI_ROOT_STATUS			= 0x50
OHCI_ROOT_PORTS				= 0x54

; OHCI Control Register
OHCI_CONTROL_EXECUTE_CONTROL		= 0x00000010
OHCI_CONTROL_EXECUTE_BULK		= 0x00000020

; OHCI Command Register
OHCI_COMMAND_RESET			= 0x00000001
OHCI_COMMAND_OWNERSHIP_CHANGE		= 0x00000008

; OHCI Status Register
OHCI_STATUS_WRITE_DONE			= 0x00000002
OHCI_STATUS_UNRECOVERABLE_ERROR		= 0x00000010
OHCI_STATUS_FRAME_OVERFLOW		= 0x00000020

; OHCI Root Hub Port Registers
OHCI_PORT_CONNECT			= 0x00000001
OHCI_PORT_ENABLE			= 0x00000002
OHCI_PORT_CLEAR_SUSPEND			= 0x00000008
OHCI_PORT_RESET				= 0x00000010

; OHCI Packet Types
OHCI_PACKET_SETUP			= 0
OHCI_PACKET_OUT				= 1
OHCI_PACKET_IN				= 2
OHCI_PACKET_RESERVED			= 3

; OHCI Communications Area Structure
OHCI_COMM_INTERRUPT_TABLE		= 0x00		; 32 dwords
OHCI_COMM_FRAME_NUMBER			= 0x80		; word
OHCI_COMM_PADDING			= 0x82		; word
OHCI_COMM_DONE_HEAD			= 0x84		; dword
OHCI_COMM_SIZE				= 256		; bytes...

OHCI_DESCRIPTORS_SIZE			= 8		; 32 KB of descriptors is more than enough

align 4
ohci_pci_list				dd 0
ohci_pci_count				dd 0
ohci_framelist				dd 0
ohci_comm				dd 0

; ohci_init:
; Initializes USB OHCI controllers

ohci_init:
	; make a list of OHCI controllers
	mov ah, 0x0C
	mov al, 0x03
	mov bl, 0x10
	call pci_generate_list

	cmp ecx, 0
	je .done

	mov [ohci_pci_list], eax
	mov [ohci_pci_count], ecx

	mov esi, .starting
	call kprint
	mov eax, [ohci_pci_count]
	call int_to_string
	call kprint
	mov esi, .starting2
	call kprint

	; allocate space for endpoint descriptors and transfer descriptors
	mov eax, 0
	mov ecx, OHCI_DESCRIPTORS_SIZE
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE or PAGE_NO_CACHE
	call vmm_alloc
	mov [ohci_framelist], eax

	; more space for communications area
	mov eax, 0
	mov ecx, 1
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE or PAGE_NO_CACHE
	call vmm_alloc
	mov [ohci_comm], eax

.loop:
	mov ecx, [.controller]
	cmp ecx, [ohci_pci_count]
	jge .done

	call ohci_init_controller
	inc [.controller]
	jmp .loop

.done:
	ret

align 4
.controller			dd 0
.starting			db "usb-ohci: found ",0
.starting2			db " OHCI controllers, initialize in order.",10,0

; ohci_init_controller:
; Initializes a single OHCI host controller
; In\	ECX = Controller number
; Out\	Nothing

ohci_init_controller:
	mov [.controller], ecx

	shl ecx, 2		; mul 4
	add ecx, [ohci_pci_list]

	mov al, [ecx+PCI_DEVICE_BUS]
	mov [.bus], al
	mov al, [ecx+PCI_DEVICE_SLOT]
	mov [.slot], al
	mov al, [ecx+PCI_DEVICE_FUNCTION]
	mov [.function], al

	; debug messages are fun ;)
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

	; enable DMA, MMIO and disable interrupt line
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

	; map the controller's MMIO space in memory
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov dl, 0	; BAR0
	call pci_map_memory

	cmp eax, 0
	je .memory_error

	mov [.mmio], eax

	; allocate memory for device addresses
	mov ecx, USB_MAX_ADDRESSES
	call kmalloc
	mov [.memory], eax

	; register the controller
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov cl, USB_OHCI
	mov edx, [.mmio]
	mov esi, [.memory]
	call usb_register

	; controller number is in EAX
	call usb_reset_controller
	ret

.memory_error:
	mov esi, .memory_error_msg
	call kprint
	ret

align 4
.controller			dd 0
.memory				dd 0
.mmio				dd 0	; base of MMIO registers
.bus				db 0
.slot				db 0
.function			db 0

.starting			db "usb-ohci: initialize OHCI controller on PCI slot ",0
.colon				db ":",0
.memory_error_msg		db "usb-ohci: unable to map MMIO into virtual address space, aborting...",10,0

; ohci_reset_controller:
; Resets an OHCI controller
; In\	EAX = Pointer to controller information
; Out\	Nothing

ohci_reset_controller:
	mov [.controller], eax

	; read MMIO base
	mov edx, [eax+USB_CONTROLLER_BASE]
	mov [.mmio], edx

	; reset the host controller
	mov edi, [.mmio]
	mov dword[edi+OHCI_COMMAND], OHCI_COMMAND_RESET

.reset_loop:
	sti
	hlt
	mov edi, [.mmio]
	test dword[edi+OHCI_COMMAND], OHCI_COMMAND_RESET
	jnz .reset_loop

	; disable all interrupts
	mov edi, [.mmio]
	mov dword[edi+OHCI_INTERRUPT_DISABLE], 0xC000007F	; disable everything
	mov dword[edi+OHCI_STATUS], 0xC000007F		; clear status

	; count the downstream ports of the root hub
	mov edi, [.mmio]
	mov eax, [edi+OHCI_ROOT_DESCRIPTOR_A]
	and al, 0x0F
	cmp al, 0		; can't be zero ports!
	je .done

	mov [.port_count], al
	mov [.current_port], 0

.ports_loop:
	; go through the registers of each port, reset and enable everything
	mov al, [.current_port]
	cmp al, [.port_count]
	jge .done

	movzx edi, [.current_port]
	shl edi, 2			; mul 4 (dword)
	add edi, OHCI_ROOT_PORTS
	add edi, [.mmio]

	mov dword[edi], OHCI_PORT_RESET

.wait_for_port:
	test dword[edi], OHCI_PORT_RESET
	jnz .wait_for_port

	or dword[edi], OHCI_PORT_ENABLE		; enable the port

	; give it a little time...
	mov eax, 5
	call pit_sleep

.next_port:
	inc [.current_port]
	jmp .ports_loop

.done:
	ret

align 4
.controller			dd 0
.mmio				dd 0
.port_count			db 0
.current_port			db 0



