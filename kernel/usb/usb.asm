
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

;
; sturct usb_controller
; {
;	u8 type;	// USB_UHCI, USB_OHCI, USB_EHCI, USB_XHCI
;	u8 bus, slot, function;
;	u32 base;
;	u32 addresses;
; }
;
;
; sizeof(usb_controller) = 16;
;
;

USB_CONTROLLER_TYPE		= 0
USB_CONTROLLER_BUS		= 1
USB_CONTROLLER_SLOT		= 2
USB_CONTROLLER_FUNCTION		= 3
USB_CONTROLLER_BASE		= 4
USB_CONTROLLER_ADDRESSES	= 8
USB_CONTROLLER_SIZE		= 16

USB_MAX_CONTROLLERS		= 64	; 64 usb controllers is definitely enough
USB_MAX_ADDRESSES		= 2048	; 2048 devices per controller

; Types of USB host controllers
USB_UHCI			= 1
USB_OHCI			= 2
USB_EHCI			= 3
USB_XHCI			= 4

; USB Setup Request Codes
USB_GET_STATUS			= 0
USB_CLEAR_FEATURE		= 1
USB_SET_FEATURE			= 3
USB_SET_ADDRESS			= 5
USB_GET_DESCRIPTOR		= 6
USB_SET_DESCRIPTOR		= 7
USB_GET_CONFIGURATION		= 8
USB_SET_CONFIGURATION		= 9
USB_GET_INTERFACE		= 10
USB_SET_INTERFACE		= 11
USB_SYNCH_FRAME			= 12

; USB Descriptor Types
USB_DEVICE_DESCRIPTOR		= 1
USB_CONFIGURATION_DESCRIPTOR	= 2
USB_STRING_DESCRIPTOR		= 3
USB_INTERFACE_DESCRIPTOR	= 4
USB_ENDPOINT_DESCRIPTOR		= 5

align 4
usb_controllers			dd 0
usb_controllers_count		dd 0

; usb_init:
; Detects and initializes USB host controllers

usb_init:
	mov esi, .starting
	call kprint

	mov ecx, USB_MAX_CONTROLLERS*USB_CONTROLLER_SIZE
	call kmalloc
	mov [usb_controllers], eax

	; in order...
	call uhci_init
	;call ohci_init
	;call ehci_init
	;call xhci_init

	ret

.starting			db "usb: starting detection of USB host controllers...",10,0

; usb_register:
; Registers a USB host controller
; In\	AL = PCI bus
; In\	AH = PCI slot
; In\	BL = PCI function
; In\	CL = Type of USB controller
; In\	EDX = MMIO or I/O port base
; In\	ESI = Pointer to addresses
; Out\	EAX = USB controller number, -1 on error

usb_register:
	cmp [usb_controllers_count], USB_MAX_CONTROLLERS
	jge .error

	mov [.type], cl

	mov edi, [usb_controllers_count]
	shl edi, 4	; mul 16
	add edi, [usb_controllers]

	mov [edi+USB_CONTROLLER_TYPE], cl
	mov [edi+USB_CONTROLLER_BUS], al
	mov [edi+USB_CONTROLLER_SLOT], ah
	mov [edi+USB_CONTROLLER_FUNCTION], bl
	mov [edi+USB_CONTROLLER_BASE], edx
	mov [edi+USB_CONTROLLER_ADDRESSES], esi

	mov eax, [usb_controllers_count]
	mov [.return], eax

	inc [usb_controllers_count]

	mov esi, .msg
	call kprint

	cmp [.type], USB_UHCI
	je .uhci

	cmp [.type], USB_OHCI
	je .ohci

	cmp [.type], USB_EHCI
	je .ehci

	cmp [.type], USB_XHCI
	je .xhci

	mov esi, .unknown
	call kprint

.done:
	mov esi, .msg2
	call kprint
	mov eax, [.return]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	mov eax, [.return]
	ret

.uhci:
	mov esi, .uhci_msg
	call kprint
	jmp .done

.ohci:
	mov esi, .ohci_msg
	call kprint
	jmp .done

.ehci:
	mov esi, .ehci_msg
	call kprint
	jmp .done

.xhci:
	mov esi, .xhci_msg
	call kprint
	jmp .done

.error:
	mov eax, -1
	ret

align 4
.return				dd 0
.type				db 0

.msg				db "usb: registered ",0
.msg2				db " controller, controller number ",0
.unknown			db "unknown USB",0
.uhci_msg			db "UHCI",0
.ohci_msg			db "OHCI",0
.ehci_msg			db "EHCI",0
.xhci_msg			db "xHCI",0

; usb_reset_controller:
; Resets a USB host controller
; In\	EAX = Controller number
; Out\	Nothing

usb_reset_controller:
	; reset the host controller --
	; -- then detect devices and give them addresses
	mov [.controller], eax

	shl eax, 4
	add eax, [usb_controllers]

	mov cl, [eax+USB_CONTROLLER_TYPE]
	cmp cl, USB_UHCI
	je .uhci

	;cmp cl, USB_OHCI
	;je .ohci

	;cmp cl, USB_EHCI
	;je .ehci

	;cmp cl, USB_XHCI
	;je .xhci

	ret

.uhci:
	call uhci_reset_controller
	jmp .next

.next:
	mov eax, [.controller]
	call usb_assign_addresses
	ret

align 4
.controller			dd 0

; usb_setup:
; Sends a setup packet
; In\	EAX = Controller number
; In\	BL = Device address
; In\	ESI = Setup packet data
; In\	EDI = Data stage, if present
; In\	ECX = Size of data stage, zero if not present
; Out\	EAX = 0 on success

usb_setup:
	shl eax, 4		; mul 16
	add eax, [usb_controllers]

	cmp byte[eax+USB_CONTROLLER_TYPE], USB_UHCI
	je .uhci

	;cmp byte[eax+USB_CONTROLLER_TYPE], USB_OHCI
	;je .ohci

	;cmp byte[eax+USB_CONTROLLER_TYPE], USB_EHCI
	;je .ehci

	;cmp byte[eax+USB_CONTROLLER_TYPE], USB_XHCI
	;je .xhci

	mov eax, -1
	ret

.uhci:
	call uhci_setup
	ret

; usb_assign_addresses:
; Assigns addresses to USB devices
; In\	EAX = Controller number
; Out\	Nothing

usb_assign_addresses:
	mov [.controller], eax

	shl eax, 4
	add eax, [usb_controllers]
	mov edi, [eax+USB_CONTROLLER_ADDRESSES]
	mov [.addresses], edi

	; clear all addresses
	mov ecx, USB_MAX_ADDRESSES
	xor al, al
	rep stosb

	mov [.current_address], 1	; 0 is special value
					; valid values are 1 to 127

.loop:
	cmp [.current_address], 127
	jge .done

	; try to receive descriptor from default address 0
	mov edi, usb_device_descriptor
	mov ecx, 18
	xor al, al
	rep stosb

	mov [usb_setup_packet.request_type], 0x80
	mov [usb_setup_packet.request], USB_GET_DESCRIPTOR
	mov [usb_setup_packet.value], USB_DEVICE_DESCRIPTOR shl 8	; device descriptor #0
	mov [usb_setup_packet.index], 0
	mov [usb_setup_packet.length], 18	; size of device descriptor

	mov eax, [.controller]
	mov bl, 0		; device address 0
	mov esi, usb_setup_packet
	mov edi, usb_device_descriptor
	mov ecx, 18
	call usb_setup

	cmp eax, 0
	jne .done

	; ensure a valid descriptor
	cmp [usb_device_descriptor.type], USB_DEVICE_DESCRIPTOR
	jne .done

	; okay, assign a device address!
	mov [usb_setup_packet.request_type], 0x00
	mov [usb_setup_packet.request], USB_SET_ADDRESS
	movzx ax, [.current_address]
	mov [usb_setup_packet.value], ax
	mov [usb_setup_packet.index], 0
	mov [usb_setup_packet.length], 0

	mov eax, [.controller]
	mov bl, 0		; old address
	mov esi, usb_setup_packet
	mov edi, 0		; no data stage
	mov ecx, 0
	call usb_setup

	cmp eax, 0
	jne .done

	; try to access the device using the new device address to ensure it worked
	mov edi, usb_device_descriptor
	mov ecx, 18
	xor al, al
	rep stosb

	mov [usb_setup_packet.request_type], 0x80
	mov [usb_setup_packet.request], USB_GET_DESCRIPTOR
	mov [usb_setup_packet.value], USB_DEVICE_DESCRIPTOR shl 8	; device descriptor #0
	mov [usb_setup_packet.index], 0
	mov [usb_setup_packet.length], 18	; size of device descriptor

	mov eax, [.controller]
	mov bl, [.current_address]	; new address
	mov esi, usb_setup_packet
	mov edi, usb_device_descriptor
	mov ecx, 18
	call usb_setup

	cmp eax, 0
	jne .done

	; valid descriptor?
	cmp [usb_device_descriptor.type], USB_DEVICE_DESCRIPTOR
	jne .done

	; success!
	mov esi, .msg
	call kprint
	movzx eax, [.current_address]
	call int_to_string
	call kprint
	mov esi, .msg2
	call kprint
	mov eax, [.controller]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	; store the address
	mov edi, [.addresses]
	mov al, [.current_address]
	stosb
	mov [.addresses], edi

	cmp [usb_device_descriptor.class], USB_HUB_CLASS	; USB hub?
	jne .next

	mov eax, [.controller]
	mov bl, [.current_address]
	call usb_hub_init

.next:
	inc [.current_address]
	jmp .loop

.done:
	ret

align 4
.controller			dd 0
.addresses			dd 0
.current_address		db 1

.msg				db "usb: assigned device address ",0
.msg2				db " on USB host controller ",0

align 4
usb_setup_packet:
	.request_type		db 0
	.request		db 0
	.value			dw 0
	.index			dw 0
	.length			dw 0

align 4
usb_device_descriptor:
	.length			db 0
	.type			db 0
	.version		dw 0
	.class			db 0
	.subclass		db 0
	.protocol		db 0
	.max_packet		db 0
	.vendor			dw 0
	.product		dw 0
	.device_version		dw 0
	.manufacturer		db 0
	.iproduct		db 0
	.serial			db 0
	.configurations		db 0


