
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; USB Hub-Specific Stuff
USB_HUB_CLASS			= 0x09
USB_HUB_DESCRIPTOR		= 0x29

; USB Hub Feature Selectors
USB_HUB_FEATURE_PORT_ENABLE	= 1
USB_HUB_FEATURE_PORT_RESET	= 4
USB_HUB_FEATURE_PORT_POWER	= 8
USB_HUB_FEATURE_LOCAL_POWER	= 0

; USB Hub Port Status
USB_HUB_PORT_CONNECT		= 0x0001
USB_HUB_PORT_ENABLED		= 0x0002
USB_HUB_PORT_RESET		= 0x0010

; usb_hub_init:
; Initializes a non-root USB hub
; In\	EAX = Controller number
; In\	BL = Hub address
; Out\	Nothing

usb_hub_init:
	mov [.controller], eax
	mov [.address], bl

	mov esi, .msg
	call kprint
	mov eax, [.controller]
	call int_to_string
	call kprint
	mov esi, .msg2
	call kprint
	movzx eax, [.address]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	; request the hub descriptor
	mov edi, usb_hub_descriptor
	mov ecx, 7
	mov al, 0
	rep stosb

	mov [usb_setup_packet.request_type], 0xA0
	mov [usb_setup_packet.request], USB_GET_DESCRIPTOR
	mov [usb_setup_packet.value], USB_HUB_DESCRIPTOR shl 8
	mov [usb_setup_packet.index], 0
	mov [usb_setup_packet.length], 7

	mov eax, [.controller]
	mov bl, [.address]
	mov bh, 0			; USB hubs can only have one endpoint
	mov esi, usb_setup_packet
	mov edi, usb_hub_descriptor
	mov ecx, 7 or 0x80000000	; request 7 bytes only
	call usb_setup

	; check for errors...
	cmp eax, 0
	jne .error

	cmp [usb_hub_descriptor.type], USB_HUB_DESCRIPTOR
	jne .error

	mov al, [usb_hub_descriptor.ports]	; downstream port count
	mov [.ports], al

	; enable local power for the hub
	mov [usb_setup_packet.request_type], 0x20
	mov [usb_setup_packet.request], USB_SET_FEATURE
	mov [usb_setup_packet.value], USB_HUB_FEATURE_LOCAL_POWER
	mov [usb_setup_packet.index], 0
	mov [usb_setup_packet.length], 0

	mov eax, [.controller]
	mov bl, [.address]
	mov bh, 0
	mov esi, usb_setup_packet
	mov edi, 0
	mov ecx, 0
	call usb_setup

	cmp eax, 0
	jne .error

	; reset all downstream ports on the hub
	mov [.current_port], 1		; one-based and not zero!

.ports_loop:
	mov al, [.current_port]
	cmp al, [.ports]
	jg .done

	; reset the port
	mov [usb_setup_packet.request_type], 0x23
	mov [usb_setup_packet.request], USB_SET_FEATURE
	mov [usb_setup_packet.value], USB_HUB_FEATURE_PORT_RESET
	movzx ax, [.current_port]
	mov [usb_setup_packet.index], ax
	mov [usb_setup_packet.length], 0

	mov eax, [.controller]
	mov bl, [.address]
	mov bh, 0
	mov esi, usb_setup_packet
	mov edi, 0
	mov ecx, 0
	call usb_setup

	cmp eax, 0
	jne .error

.wait_reset:
	; poll the port, wait for the reset to complete
	mov [.port_status], 0

	mov [usb_setup_packet.request_type], 0xA3
	mov [usb_setup_packet.request], USB_GET_STATUS
	mov [usb_setup_packet.value], 0
	movzx ax, [.current_port]
	mov [usb_setup_packet.index], ax
	mov [usb_setup_packet.length], 2

	mov eax, [.controller]
	mov bl, [.address]
	mov bh, 0
	mov esi, usb_setup_packet
	mov edi, .port_status
	mov ecx, 2 or 0x80000000	; device to host
	call usb_setup

	cmp eax, 0
	jne .error

	test [.port_status], USB_HUB_PORT_RESET
	jnz .wait_reset

	; if the port has a device attached, ensure it is enabled
	mov [.port_status], 0

	mov [usb_setup_packet.request_type], 0xA3
	mov [usb_setup_packet.request], USB_GET_STATUS
	mov [usb_setup_packet.value], 0
	movzx ax, [.current_port]
	mov [usb_setup_packet.index], ax
	mov [usb_setup_packet.length], 2

	mov eax, [.controller]
	mov bl, [.address]
	mov bh, 0
	mov esi, usb_setup_packet
	mov edi, .port_status
	mov ecx, 2 or 0x80000000
	call usb_setup

	cmp eax, 0
	jne .error

	; connected?
	test [.port_status], USB_HUB_PORT_CONNECT
	jz .next_port

	; yes -- enabled?
	test [.port_status], USB_HUB_PORT_ENABLED
	jz .error

.next_port:
	inc [.current_port]
	jmp .ports_loop

.done:
	ret

.error:
	mov esi, .error_msg
	call kprint

	ret

align 4
.controller			dd 0
.ports				db 0
.current_port			db 0
.address			db 0

align 2
.port_status			dw 0

.msg				db "usb-hub: initialize USB hub on controller ",0
.msg2				db ", address ",0
.error_msg			db "usb-hub: failed to initialize USB hub.",10,0

; Hub Descriptor..
align 4
usb_hub_descriptor:
	.length			db 0
	.type			db 0
	.ports			db 0
	.characteristics	dw 0
	.power_good_time	db 0
	.max_current		db 0




