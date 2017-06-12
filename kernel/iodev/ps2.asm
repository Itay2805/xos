
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
ALT				= 0x38
F4_KEY				= 0x3E

; Keyboard Status Bitfield
KBD_STATUS_SHIFT		= 0x01
KBD_STATUS_CAPS_LOCK		= 0x02
KBD_STATUS_NUM_LOCK		= 0x04
KBD_STATUS_ALT			= 0x08

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

; Scancodes for the arrow keys ;)
PS2_SCANCODE_UP			= 72
PS2_SCANCODE_LEFT		= 75
PS2_SCANCODE_RIGHT		= 77
PS2_SCANCODE_DOWN		= 80

; Keyboard Stuff
kbd_status			db 0
kbd_leds			db 0
last_scancode			db 0
last_character			db 0
old_scancode			db 0

mouse_irq_state			db 0
mouse_id			db 0

ps2_present			db 0	; acpi determines this field using fadt

; wait_ps2_write:
; Waits to write to the PS/2 controller
; In\	Nothing
; Out\	EFLAGS.CF = 1 on timeout

wait_ps2_write:
	mov [.waits], 0
	push eax

.wait:
	pause

	inc [.waits]
	cmp [.waits], 0xFFFFF
	jg .error

	in al, 0x64
	test al, 2
	jnz .wait

	pop eax
	clc
	ret

.error:
	pop eax
	stc
	ret

align 4
.waits				dd 0

; wait_ps2_read:
; Waits to read the PS/2 controller

wait_ps2_read:
	mov [.waits], 0
	push eax

.wait:
	pause

	inc [.waits]
	cmp [.waits], 0xFFFFF
	jge .error

	in al, 0x64
	test al, 1
	jz .wait

	pop eax
	clc
	ret

.error:
	pop eax
	stc
	ret

align 4
.waits				dd 0

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

	cmp al, ALT			; alt?
	je .alt

	cmp al, ALT or 0x80		; alt release?
	je .alt_release

	cmp al, F4_KEY			; F4?
	je .f4

	cmp al, 0xE0
	je .escape_sequence

	; now the key is most likely a letter or number...
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
	add eax, ps2_ascii_codes
	mov al, [eax]
	mov [last_character], al
	jmp .event

.shift:
	add eax, ps2_ascii_codes_shift
	mov al, [eax]
	mov [last_character], al
	jmp .event

.caps_lock:
	add eax, ps2_ascii_codes_caps_lock
	mov al, [eax]
	mov [last_character], al
	jmp .event

.shift_caps_lock:
	add eax, ps2_ascii_codes_shift_caps_lock
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
	jmp .finish

.alt:
	or [kbd_status], KBD_STATUS_ALT
	jmp .finish

.alt_release:
	and [kbd_status], not KBD_STATUS_ALT
	jmp .finish

.f4:
	test [kbd_status], KBD_STATUS_ALT
	jz .finish

	call wm_close_active_window		; send a close event..

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

	mov ecx, 5

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

	; demand the mouse ID again
	mov al, PS2_MOUSE_GET_ID
	call ps2_mouse_send
	;cmp al, 0xFA
	;jne .no_mouse

	call wait_ps2_read
	in al, 0x60
	cmp al, 0
	jne .no_mouse

	mov [mouse_id], 0

	; try to enable scrollwheel mouse
	;mov al, PS2_MOUSE_SET_SPEED
	;call ps2_mouse_send
	;mov al, 200
	;call ps2_mouse_send
	;mov al, PS2_MOUSE_SET_SPEED
	;call ps2_mouse_send
	;mov al, 100
	;call ps2_mouse_send
	;mov al, PS2_MOUSE_SET_SPEED
	;call ps2_mouse_send
	;mov al, 80
	;call ps2_mouse_send

	; check if it worked
	;mov al, PS2_MOUSE_GET_ID
	;call ps2_mouse_send

	;call wait_ps2_read
	;in al, 0x60

	;mov [mouse_id], al

	;mov esi, .mouse_id_msg
	;call kprint
	;movzx eax, [mouse_id]
	;call int_to_string
	;call kprint
	;mov esi, newline
	;call kprint

	; disable mouse packets
	mov al, PS2_MOUSE_DISABLE
	call ps2_mouse_send
	;cmp al, 0xFA
	;jne .no_mouse

	; set default values
	mov al, PS2_MOUSE_DEFAULTS
	call ps2_mouse_send
	;cmp al, 0xFA
	;jne .no_mouse

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
.mouse_id_msg			db "ps2: mouse ID is ",0

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
	cmp dl, 0
	je .data

	cmp dl, 1
	je .x

	cmp dl, 2
	je .y

	cmp dl, 3
	je .scroll

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

	cmp [mouse_id], 0
	jne .wait_scroll

	jmp .handle_packet

.wait_scroll:
	inc [mouse_irq_state]
	jmp .done

.scroll:
	mov [mouse_packet.scroll], al

.handle_packet:
	mov [mouse_irq_state], 0

	call update_mouse

	; check for scroll event
	mov al, [mouse_packet.scroll]
	and al, 0x0F
	cmp al, 0
	je .check_click

	call wm_scroll_event

.check_click:
	; check for click event
	test [mouse_data], MOUSE_LEFT_BTN
	jz .redraw

	call wm_mouse_event
	jmp .done

.redraw:
	call redraw_mouse

.done:
	mov al, 0x20
	out 0xa0, al
	out 0x20, al
	popa
	iret



