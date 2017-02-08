
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; PS/2 Keyboard Commands
PS2_KBD_RESET			= 0xFF
PS2_KBD_SET_AUTOREPEAT		= 0xF3
PS2_KBD_SET_SCANCODE		= 0xF0
PS2_KBD_ENABLE_MB		= 0xFA
PS2_KBD_ENABLE			= 0xF4
PS2_KBD_DISABLE			= 0xF5
PS2_KBD_SET_LEDS		= 0xED

; PS/2 Keyboard LEDs Bitfield
PS2_KBD_SCROLL_LOCK		= 0x01
PS2_KBD_NUM_LOCK		= 0x02
PS2_KBD_CAPS_LOCK		= 0x04

; Some "Control" Keys
LEFT_SHIFT			= 0x36
RIGHT_SHIFT			= 0x2A
CAPS_LOCK			= 0x3A
NUM_LOCK			= 0x45

; Keyboard Status Bitfield
KBD_STATUS_SHIFT		= 0x01
KBD_STATUS_CAPS_LOCK		= 0x02
KBD_STATUS_NUM_LOCK		= 0x04

; PS/2 Mouse Commands
PS2_MOUSE_COMMAND		= 0xD4
PS2_MOUSE_DEFAULTS		= 0xF6
PS2_MOUSE_ENABLE_AUX		= 0xA8
PS2_MOUSE_DISABLE_AUX		= 0xA9
PS2_MOUSE_GET_ID		= 0xF2
PS2_MOUSE_RESET			= 0xFF
PS2_MOUSE_ENABLE		= 0xF4
PS2_MOUSE_DISABLE		= 0xF5
PS2_MOUSE_SET_RESOLUTION	= 0xE8
PS2_MOUSE_SET_SPEED		= 0xF3

; Format Of PS/2 Mouse Packet Data
MOUSE_LEFT_BTN			= 0x01
MOUSE_RIGHT_BTN			= 0x02
MOUSE_MIDDLE_BTN		= 0x04
MOUSE_X_SIGN			= 0x10
MOUSE_Y_SIGN			= 0x20
MOUSE_X_OVERFLOW		= 0x40
MOUSE_Y_OVERFLOW		= 0x80

; Keyboard Stuff
kbd_status			db 0
kbd_leds			db 0
last_scancode			db 0
last_character			db 0
old_scancode			db 0

; Mouse Speed
mouse_speed			db 0		; 0 normal speed, 1 -> 4 fast speeds

mouse_id			db 0

align 4
mouse_data			dd 0
mouse_x				dd 0
mouse_y				dd 0

mouse_old_data			dd 0
mouse_old_x			dd 0
mouse_old_y			dd 0

align 4
; these contain the initial x/y pos at the moment the button was pressed
mouse_initial_x			dd 0
mouse_initial_y			dd 0

align 4
mouse_x_max			dd 0
mouse_y_max			dd 0

mouse_cursor			dd 0
mouse_width			dd 0
mouse_height			dd 0
mouse_visible			db 0

mouse_packet:
	.data			db 0
	.x			db 0
	.y			db 0
mouse_irq_state			db 0

ps2_present			db 0	; acpi determines this field using fadt

; wait_ps2_write:
; Waits to write to the PS/2 controller

wait_ps2_write:
	push eax

.wait:
	in al, 0x64
	test al, 2
	jnz .wait

	pop eax
	ret

; wait_ps2_read:
; Waits to read the PS/2 controller

wait_ps2_read:
	push eax

.wait:
	in al, 0x64
	test al, 1
	jz .wait

	pop eax
	ret

; ps2_send:
; Sends a PS/2 command
; In\	AL = Command/data byte
; Out\	AL = Returned ACK byte

ps2_send:
	call wait_ps2_write
	out 0x60, al
	call wait_ps2_read
	in al, 0x60
	ret

; ps2_send_noack:
; Sends a PS/2 command without waiting for ack
; In\	AL = Command/data byte
; Out\	Nothing

ps2_send_noack:
	call wait_ps2_write
	out 0x60, al
	ret

; ps2_reset:
; Resets the PC using the PS/2 controller

ps2_reset:
	cli

	mov al, 0xFF
	out 0x21, al
	out 0xA1, al

	mov ecx, 64

.loop:
	mov al, 0xFE
	out 0x64, al
	loop .loop

	ret

; ps2_init:
; Initializes the PS/2 controller & devices

ps2_init:
	cmp [ps2_present], 0
	je .finish

	mov esi, .msg
	call kprint

	call ps2_kbd_init
	call ps2_mouse_init

.finish:
	ret

.msg				db "Initializing PS/2 controller...",10,0

; ps2_kbd_init:
; Initializes the PS/2 keyboard

ps2_kbd_init:
	mov al, IRQ_BASE+0x01
	mov ebp, ps2_kbd_irq		; irq handler
	call install_isr

	mov [kbd_status], 0

.reset_again:
	mov al, PS2_KBD_RESET
	call ps2_send

	cmp al, 0xFF
	je .no_kbd

	cmp al, 0xFC
	je .no_kbd

	cmp al, 0xFD
	je .no_kbd

	cmp al, 0xFE
	je .reset_again

	mov ecx, 3

.wait_for_success:
	call wait_ps2_read
	in al, 0x60
	cmp al, 0xAA
	je .continue

	jmp .wait_for_success

.continue:
	; autorepeat rate
	mov al, PS2_KBD_SET_AUTOREPEAT
	call ps2_send
	mov al, 0x20
	call ps2_send

	; scancode set 2
	mov al, PS2_KBD_SET_SCANCODE
	call ps2_send
	mov al, 2
	call ps2_send

	; turn on the numlock LED
	mov al, PS2_KBD_NUM_LOCK
	call ps2_kbd_set_leds

	; enable numlock by default for comfortability
	mov [kbd_status], KBD_STATUS_NUM_LOCK

	; enable keyboard
	mov al, PS2_KBD_ENABLE
	call ps2_send

	call iowait
	call iowait

	; unmask the PIC IRQ
	mov al, 1
	call irq_unmask
	ret

.no_kbd:
	mov esi, .no_kbd_msg
	call kprint
	ret

.no_kbd_msg			db "ps2: keyboard not present.",10,0

; ps2_kbd_set_leds:
; Sets the LEDs of the PS/2 keyboard
; In\	AL = LED bitfield
; Out\	Nothing
align 32
ps2_kbd_set_leds:
	push eax

	mov al, PS2_KBD_SET_LEDS
	call ps2_send

	pop eax
	push eax
	call ps2_send

	pop eax
	mov [kbd_leds], al
	ret

; ps2_kbd_irq:
; PS/2 Keyboard IRQ Handler
align 32
ps2_kbd_irq:
	pusha

	in al, 0x60		; read the scancode

	; check for control keys
	cmp al, LEFT_SHIFT
	je .turn_on_shift

	cmp al, RIGHT_SHIFT
	je .turn_on_shift

	cmp al, LEFT_SHIFT or 0x80	; was the left shift released?
	je .turn_off_shift

	cmp al, RIGHT_SHIFT or 0x80	; right shift released?
	je .turn_off_shift

	cmp al, CAPS_LOCK		; caps lock?
	je .toggle_caps_lock

	cmp al, NUM_LOCK		; num lock?
	je .toggle_num_lock

	cmp al, 0xE0
	je .escape_sequence

	; now the key is most likely a letter or number...
	; soon I'll add support for NumLock and the numpad
	; but for now, we'll assume it's a "printable" character
	test al, 0x80		; key released?
	jnz .finish		; ignore it

	and eax, 0x7F
	mov [last_scancode], al

	; check if it is an arrow key/numpad key
	cmp [last_scancode], 0x47	; numpad 7/Home
	jl .start

	cmp [last_scancode], 0x52	; numpad 0/Insert
	jg .start

	; was it a gray key or numpad key?
	cmp [old_scancode], 0xE0	; escape sequence
	je .gray_key

	; now we know it was a numpad key -- treat it like a gray key if numpad is off
	test [kbd_status], KBD_STATUS_NUM_LOCK
	jz .gray_key

	; it's a numpad key -- no denying anymore...
	jmp .start

.escape_sequence:
	mov [old_scancode], 0xE0
	jmp .finish

.start:
	mov [old_scancode], 0

	; depending on shift and caps lock state, use the appropriate key mapping
	;cmp [kbd_status], 0
	;je .normal

	test [kbd_status], KBD_STATUS_SHIFT
	jnz .shift

	test [kbd_status], KBD_STATUS_CAPS_LOCK
	jnz .caps_lock

	test [kbd_status], KBD_STATUS_SHIFT or KBD_STATUS_CAPS_LOCK
	jnz .shift_caps_lock

	jmp .normal

.normal:
	add eax, ascii_codes
	mov al, [eax]
	mov [last_character], al
	jmp .event

.shift:
	add eax, ascii_codes_shift
	mov al, [eax]
	mov [last_character], al
	jmp .event

.caps_lock:
	add eax, ascii_codes_caps_lock
	mov al, [eax]
	mov [last_character], al
	jmp .event

.shift_caps_lock:
	add eax, ascii_codes_shift_caps_lock
	mov al, [eax]
	mov [last_character], al
	jmp .event

.gray_key:
	mov [old_scancode], 0
	mov [last_character], 0

.event:
	call wm_kbd_event	; notify the wm which will notify apps waiting for events
	jmp .finish

.turn_on_shift:
	or [kbd_status], KBD_STATUS_SHIFT
	jmp .finish

.turn_off_shift:
	and [kbd_status], not KBD_STATUS_SHIFT
	jmp .finish

.toggle_caps_lock:
	test [kbd_status], KBD_STATUS_CAPS_LOCK
	jz .turn_on_caps_lock

.turn_off_caps_lock:
	and [kbd_status], not KBD_STATUS_CAPS_LOCK
	mov al, [kbd_leds]
	and al, not PS2_KBD_CAPS_LOCK
	call ps2_kbd_set_leds
	jmp .finish

.turn_on_caps_lock:
	or [kbd_status], KBD_STATUS_CAPS_LOCK
	mov al, [kbd_leds]
	or al, PS2_KBD_CAPS_LOCK
	call ps2_kbd_set_leds
	jmp .finish

.toggle_num_lock:
	test [kbd_status], KBD_STATUS_NUM_LOCK
	jz .turn_on_num_lock

.turn_off_num_lock:
	and [kbd_status], not KBD_STATUS_NUM_LOCK
	mov al, [kbd_leds]
	and al, not PS2_KBD_NUM_LOCK
	call ps2_kbd_set_leds
	jmp .finish

.turn_on_num_lock:
	or [kbd_status], KBD_STATUS_NUM_LOCK
	mov al, [kbd_leds]
	or al, PS2_KBD_NUM_LOCK
	call ps2_kbd_set_leds

.finish:
	mov al, 0x20
	out 0x20, al
	popa
	iret

; ps2_kbd_read:
; Reads from the PS/2 keyboard
; In\	Nothing
; Out\	AH = ASCII Scancode
; Out\	AL = ASCII Character

ps2_kbd_read:
	mov ah, [last_scancode]
	mov al, [last_character]
	ret

; ps2_mouse_send:
; Sends mouse data to the PS/2 mouse
; In\	AL = Data
; Out\	AL = ACK byte

ps2_mouse_send:
	push eax

	call wait_ps2_write
	mov al, PS2_MOUSE_COMMAND
	out 0x64, al

	call wait_ps2_write
	pop eax
	out 0x60, al

	call wait_ps2_read
	in al, 0x60
	ret

; ps2_mouse_init:
; Initializes the PS/2 Mouse

ps2_mouse_init:
	mov al, IRQ_BASE+12
	mov ebp, ps2_mouse_irq
	call install_isr

	; NOTE: At least in QEMU, PS/2 mouse initialision fails if the keyboard can send IRQs
	; The work-arounds are either CLI or Masking the PS/2 keyboard IRQ
	; If someone knows, is there is a reason for this or is it a bug in QEMU?
	; This doesn't happen in VBox, Bochs or in two real PCs.

	call iowait
	call iowait
	mov al, 1
	call irq_mask

	; enable auxiliary mouse device
	call wait_ps2_write
	mov al, PS2_MOUSE_ENABLE_AUX
	out 0x64, al
	call iowait	; this command doesn't generate an ack, so wait for it to finish

	; reset the mouse
	mov al, PS2_MOUSE_RESET
	call ps2_mouse_send

	mov ecx, 3

.loop:
	cmp al, 0
	je .no_mouse

	cmp al, 0xFF
	je .no_mouse

	cmp al, 0xFC
	je .no_mouse

	cmp al, 0xFD
	je .no_mouse

	cmp al, 0xAA
	je .reset_finish

	call wait_ps2_read
	in al, 0x60
	loop .loop
	jmp .no_mouse

.reset_finish:
	; read mouseID byte
	call wait_ps2_read
	in al, 0x60
	cmp al, 0
	jne .no_mouse
	mov [mouse_id], al

	; demand the mouse ID again
	mov al, PS2_MOUSE_GET_ID
	call ps2_mouse_send
	cmp al, 0xFA
	jne .no_mouse

	call wait_ps2_read
	in al, 0x60
	cmp al, 0
	jne .no_mouse

	; disable mouse packets
	mov al, PS2_MOUSE_DISABLE
	call ps2_mouse_send
	cmp al, 0xFA
	jne .no_mouse

	; set default values
	mov al, PS2_MOUSE_DEFAULTS
	call ps2_mouse_send
	cmp al, 0xFA
	jne .no_mouse

	; set resolution
	;mov al, PS2_MOUSE_SET_RESOLUTION
	;call ps2_mouse_send
	;mov al, 0
	;call ps2_mouse_send

	; set packets per second
	;mov al, PS2_MOUSE_SET_SPEED
	;call ps2_mouse_send
	;mov al, 200
	;call ps2_mouse_send

	; some mice don't support 200 packets/second
	; on those mice, use the default rate 100 packets
	;cmp al, 0xFA
	;je .after

	;mov esi, .100_msg
	;call kprint

	;mov al, PS2_MOUSE_SET_SPEED
	;call ps2_mouse_send
	;mov al, 100
	;call ps2_mouse_send

.after:
	; enable packets
	mov al, PS2_MOUSE_ENABLE
	call ps2_mouse_send
	cmp al, 0xFA
	jne .no_mouse

	; enable irq12
	call wait_ps2_write
	mov al, 0x20
	out 0x64, al

	call wait_ps2_read
	in al, 0x60
	or al, 2
	push eax

	call wait_ps2_write
	mov al, 0x60
	out 0x64, al

	call wait_ps2_write
	pop eax
	out 0x60, al

	; apparantly delays here are needed in some hardware
	; it doesn't hurt anyway ;)
	call iowait
	call iowait
	call iowait
	call iowait

	; unmask the mouse irq
	mov al, 12
	call irq_unmask

	; and keyboard irq also
	mov al, 1
	call irq_unmask

	ret

.no_mouse:
	mov esi, .no_mouse_msg
	call kprint

	ret

.no_mouse_msg			db "ps2: mouse not present.",10,0
.100_msg			db "ps2: mouse doesn't support 200 packets/sec, using default...",10,0

; ps2_mouse_irq:
; PS/2 Mouse IRQ Handler
align 32
ps2_mouse_irq:
	pusha

	; is the byte from the mouse or keyboard?
	in al, 0x64
	test al, 0x20
	jz .done

	in al, 0x60

	mov dl, [mouse_irq_state]
	or dl, dl
	jz .data

	cmp dl, 1
	je .x

	cmp dl, 2
	je .y

	mov [mouse_irq_state], 0
	jmp .done

.data:
	;test al, MOUSE_X_OVERFLOW OR MOUSE_Y_OVERFLOW
	;jnz .done
	test al, 8	; align
	jz .done

	mov [mouse_packet.data], al
	inc [mouse_irq_state]
	jmp .done

.x:
	mov [mouse_packet.x], al
	inc [mouse_irq_state]
	jmp .done

.y:
	mov [mouse_packet.y], al
	xor dl, dl
	mov [mouse_irq_state], dl
	call update_mouse

	test [mouse_data], MOUSE_LEFT_BTN
	jz .redraw

	call wm_mouse_event
	jmp .done

.redraw:
	call redraw_mouse
	jmp .done

.done:
	mov al, 0x20
	out 0xa0, al
	out 0x20, al
	popa
	iret

; update_mouse:
; Updates the mouse position
align 32
update_mouse:
	; if the mouse data doesn't have proper alignment, ignore the packet
	;test [mouse_packet.data], 8
	;jz .quit

	; if the overflow bits are set, ignore the packet
	;test [mouse_packet.data], MOUSE_X_OVERFLOW
	;jnz .quit
	;test [mouse_packet.data], MOUSE_Y_OVERFLOW
	;jnz .quit

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
	test [mouse_packet.data], MOUSE_X_SIGN
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
	test [mouse_packet.data], MOUSE_Y_SIGN
	jnz .y_neg

.y_pos:
	sub [mouse_y], eax
	jns .check_x

	xor eax, eax
	mov [mouse_y], eax
	jmp .check_x

.y_neg:
	not al
	inc al
	add [mouse_y], eax

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

; show_mouse:
; Shows the mouse cursor
align 32
show_mouse:
	mov [mouse_visible], 1
	call redraw_mouse
	ret

; hide_mouse:
; Hides the mouse cursor
align 32
hide_mouse:
	mov [mouse_visible], 0
	call redraw_screen	; redraw screen objects to hide mouse ;)
	ret

; redraw_mouse:
; Redraws the mouse
align 32
redraw_mouse:
	test [mouse_visible], 1
	jz .only_screen

	; only redraw if the mouse has actually been "moved"
	; for click events, don't redraw -- it prevents flickering
	mov eax, [mouse_x]
	cmp eax, [mouse_old_x]
	jne .redraw

	mov eax, [mouse_y]
	cmp eax, [mouse_old_y]
	jne .redraw

	ret

.redraw:
	call use_back_buffer
	call unlock_screen
	call redraw_screen
	call use_front_buffer

	; just for testing ;)
	;mov eax, [mouse_x]
	;mov ebx, [mouse_y]
	;mov esi, 16
	;mov edi, 16
	;mov edx, 0xd8d8d8
	;call fill_rect

	mov eax, [mouse_x]
	mov ebx, [mouse_y]
	mov esi, [mouse_width]
	mov edi, [mouse_height]
	mov ecx, 0xd8d8d8		; transparent color
	mov edx, [mouse_cursor]
	call blit_buffer

	;call use_back_buffer
	;call unlock_screen
	ret

align 32
.only_screen:
	call use_back_buffer
	call unlock_screen
	call redraw_screen
	ret




