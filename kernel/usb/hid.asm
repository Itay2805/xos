
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

USB_HID_DEFAULT_INTERVAL		= 10	; if the update interval is invalid..
USB_HID_DESCRIPTOR_SIZE			= 9	; size of HID descriptor

; USB HID-Specific Setup Requests
USB_HID_GET_REPORT			= 0x01	; request a report packet from a HID device
USB_HID_SET_PROTOCOL			= 0x0B

; These variables are used by the timer IRQ to keep track of whether or
; not to update the USB HID device states by polling...
align 4
usb_mouse_time				dd 0
usb_keyboard_time			dd 0

align 4
usb_mouse_controller			dd 0
usb_mouse_interval			dd 0
usb_mouse_address			db 0
usb_mouse_endpoint			db 0

align 4
usb_keyboard_controller			dd 0
usb_keyboard_interval			dd 0
usb_keyboard_address			db 0
usb_keyboard_endpoint			db 0

; usb_hid_init:
; Detects and initializes USB HID devices

usb_hid_init:
	call usb_hid_init_mouse
	;call usb_hid_init_keyboard

	ret

; usb_hid_init_mouse:
; Detects and initializes USB HID mouse

usb_hid_init_mouse:
	; find a HID device, then ensure it is a mouse
	; then save its information..
	mov [.address], 1
	mov [.controller], 0

.loop:
	cmp [.address], 127
	jge .next_controller

	mov eax, [usb_controllers_count]
	cmp [.controller], eax
	jge .no_mouse

	; request a device descriptor
	mov [usb_setup_packet.request_type], 0x80
	mov [usb_setup_packet.request], USB_GET_DESCRIPTOR
	mov [usb_setup_packet.value], USB_DEVICE_DESCRIPTOR shl 8
	mov [usb_setup_packet.index], 0
	mov [usb_setup_packet.length], 18

	mov eax, [.controller]
	mov bl, [.address]
	mov bh, 0
	mov esi, usb_setup_packet
	mov edi, usb_device_descriptor
	mov ecx, 18 or 0x80000000
	call usb_setup

	cmp eax, 0
	jne .next

	; ensure the device class and subclass are zero
	cmp [usb_device_descriptor.class], 0
	jne .next

	cmp [usb_device_descriptor.subclass], 0
	jne .next

	cmp [usb_device_descriptor.protocol], 0
	jne .next

	; at least one configuration!
	cmp [usb_device_descriptor.configurations], 1
	jl .next

	; request configuration descriptor
	mov ecx, 256
	call kmalloc
	mov [.configuration], eax

	mov [usb_setup_packet.request_type], 0x80
	mov [usb_setup_packet.request], USB_GET_DESCRIPTOR
	mov [usb_setup_packet.value], USB_CONFIGURATION_DESCRIPTOR shl 8	; configuration zero
	mov [usb_setup_packet.index], 0
	mov [usb_setup_packet.length], 256

	mov eax, [.controller]
	mov bl, [.address]
	mov bh, 0
	mov esi, usb_setup_packet
	mov edi, [.configuration]
	mov ecx, 256 or 0x80000000
	call usb_setup

	cmp eax, 0
	jne .next

	; check the first interface
	mov esi, [.configuration]
	add esi, USB_CONFIGURATION_SIZE

	cmp byte[esi+USB_INTERFACE_CLASS], 3		; HID?
	jne .next

	cmp byte[esi+USB_INTERFACE_SUBCLASS], 1		; boot protocol?
	jne .next

	cmp byte[esi+USB_INTERFACE_PROTOCOL], 2		; mouse?
	jne .next

	jmp .found

.next:
	inc [.address]
	jmp .loop

.next_controller:
	inc [.controller]
	mov [.address], 1
	jmp .loop

.found:
	mov esi, .found_msg
	call kprint
	movzx eax, [.address]
	call int_to_string
	call kprint
	mov esi, .found_msg2
	call kprint
	mov eax, [.controller]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	mov eax, [.controller]
	mov [usb_mouse_controller], eax
	mov al, [.address]
	mov [usb_mouse_address], al

	mov esi, [.configuration]
	add esi, USB_CONFIGURATION_SIZE

	; does it have endpoints?
	cmp byte[esi+USB_INTERFACE_ENDPOINTS], 0
	je .done

	; check first endpoint
	add esi, USB_INTERFACE_SIZE
	add esi, USB_HID_DESCRIPTOR_SIZE

	test byte[esi+USB_ENDPOINT_ADDRESS], 0x80	; in/out?
	jz .try_next_endpoint

	; save interval
	mov al, [esi+USB_ENDPOINT_INTERVAL]
	and eax, 0xFF
	mov [usb_mouse_interval], eax

	mov al, [esi+USB_ENDPOINT_ADDRESS]
	and al, 0x0F		; endpoint number
	mov [usb_mouse_endpoint], al

	jmp .initialize

.try_next_endpoint:
	add esi, USB_ENDPOINT_SIZE
	test byte[esi+USB_ENDPOINT_ADDRESS], 0x80	; in/out?
	jz .done

	; save interval
	mov al, [esi+USB_ENDPOINT_INTERVAL]
	and eax, 0xFF
	mov [usb_mouse_interval], eax

	mov al, [esi+USB_ENDPOINT_ADDRESS]
	and al, 0x0F		; endpoint number
	mov [usb_mouse_endpoint], al

.initialize:
	; set the configuration
	mov [usb_setup_packet.request_type], 0x00
	mov [usb_setup_packet.request], USB_SET_CONFIGURATION
	mov esi, [.configuration]
	movzx ax, byte[esi+USB_CONFIGURATION_VALUE]
	mov [usb_setup_packet.value], ax		; configuration value
	mov [usb_setup_packet.index], 0
	mov [usb_setup_packet.length], 0

	mov eax, [.controller]
	mov bl, [.address]
	mov bh, 0
	mov esi, usb_setup_packet
	mov edi, 0		; no data stage
	mov ecx, 0
	call usb_setup

	cmp eax, 0
	jne .done

	; enable boot protocol
	mov [usb_setup_packet.request_type], 0x21
	mov [usb_setup_packet.request], USB_HID_SET_PROTOCOL
	mov [usb_setup_packet.value], 0		; boot
	mov [usb_setup_packet.index], 0
	mov [usb_setup_packet.length], 0

	mov eax, [.controller]
	mov bl, [.address]
	mov bh, 0
	mov esi, usb_setup_packet
	mov edi, 0		; no data stage
	mov ecx, 0
	call usb_setup

	cmp eax, 0
	jne .done

	; free the memory used by the configuration
	mov eax, [.configuration]
	call kfree

	cmp [usb_mouse_interval], 0
	je .default

	jmp .done

.default:
	mov [usb_mouse_interval], USB_HID_DEFAULT_INTERVAL

.done:
	ret

.no_mouse:
	mov [usb_mouse_controller], 0
	mov [usb_mouse_address], 0
	mov [usb_mouse_endpoint], 0
	mov [usb_mouse_interval], 0

	ret

align 4
.controller				dd 0
.configuration				dd 0
.address				db 1

.found_msg				db "usb-hid: found USB mouse at address ",0
.found_msg2				db ", controller ",0

; usb_hid_update_mouse:
; Updates the mouse status

usb_hid_update_mouse:
	; Notice:
	; The USB HID Specification tells us not to use the "get report"
	; request for polling for mouse movement.
	; For this reason, I commented out the code below and implemented
	; USB interrupt transfers instead...

	;mov [usb_setup_packet.request_type], 0xA1
	;mov [usb_setup_packet.request], USB_HID_GET_REPORT
	;mov [usb_setup_packet.value], 0x100
	;mov [usb_setup_packet.index], 0
	;mov [usb_setup_packet.length], 3

	;mov eax, [usb_mouse_controller]
	;mov bl, [usb_mouse_address]
	;mov bh, 0
	;mov esi, usb_setup_packet
	;mov edi, mouse_packet
	;mov ecx, 3 or 0x80000000
	;call usb_setup

	;cmp eax, -1
	;je .done

	; Receive mouse state using interrupt..
	mov edi, mouse_packet
	mov al, 0
	mov ecx, 3
	rep stosb

	mov eax, [usb_mouse_controller]
	mov bl, [usb_mouse_address]
	mov bh, [usb_mouse_endpoint]
	mov esi, mouse_packet
	mov ecx, 3 or 0x80000000	; packet size 3 bytes, bit 31 set to indicate --
					; -- packet is from device to host
	call usb_interrupt

	cmp eax, -1
	je .done

	; update mouse position and inform the window manager if necessary
	call update_usb_mouse

	test [mouse_packet.data], MOUSE_LEFT_BTN
	jz .redraw

	call wm_mouse_event
	jmp .done

.redraw:
	call redraw_mouse

.done:
	ret

; update_usb_mouse:
; Updates the mouse position using USB HID mouse
align 32
update_usb_mouse:
	; save the old mouse state before determining its new state
	mov eax, [mouse_data]
	mov [mouse_old_data], eax

	mov al, [mouse_packet.data]
	mov [mouse_data], eax

	mov eax, [mouse_x]
	mov [mouse_old_x], eax
	mov eax, [mouse_y]
	mov [mouse_old_y], eax

.do_x:
	; do the x pos first
	movzx eax, [mouse_packet.x]
	test [mouse_packet.x], 0x80
	jnz .x_neg

.x_pos:
	add [mouse_x], eax
	jmp .do_y

.x_neg:
	not al
	inc al
	sub [mouse_x], eax
	jns .do_y

	xor eax, eax
	mov [mouse_x], eax

.do_y:
	; do the same for y position
	movzx eax, [mouse_packet.y]
	test [mouse_packet.y], 0x80
	jnz .y_neg

.y_pos:
	add [mouse_y], eax
	jmp .check_x

.y_neg:
	not al
	inc al
	sub [mouse_y], eax
	jns .check_x

	mov [mouse_y], 0

.check_x:
	mov eax, [mouse_x]
	cmp eax, [mouse_x_max]
	jge .x_max

	jmp .check_y

.x_max:
	mov eax, [mouse_x_max]
	mov [mouse_x], eax

.check_y:
	mov eax, [mouse_y]
	cmp eax, [screen.height]
	jge .y_max

	jmp .quit

.y_max:
	mov eax, [screen.height]
	dec eax
	mov [mouse_y], eax

.quit:
	ret


