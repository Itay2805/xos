
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

MAXIMUM_FUNCTION		= 0x0027

; Function Table ;)
align 16
api_table:
	dd wm_create_window	; 0x0000
	dd yield		; 0x0001
	dd wm_pixel_offset	; 0x0002
	dd wm_redraw		; 0x0003
	dd wm_read_event	; 0x0004
	dd wm_read_mouse	; 0x0005
	dd wm_get_window	; 0x0006
	dd wm_draw_text		; 0x0007
	dd wm_clear		; 0x0008
	dd malloc		; 0x0009
	dd free			; 0x000A
	dd vfs_open		; 0x000B
	dd vfs_close		; 0x000C
	dd vfs_seek		; 0x000D
	dd vfs_tell		; 0x000E
	dd vfs_read		; 0x000F
	dd vfs_write		; 0x0010
	dd wm_render_char	; 0x0011
	dd wm_kill		; 0x0012
	dd get_screen_info	; 0x0013
	dd ps2_kbd_read		; 0x0014
	dd terminate		; 0x0015
	dd create_task		; 0x0016
	dd cmos_get_time	; 0x0017
	dd shutdown		; 0x0018
	dd reboot		; 0x0019
	dd get_memory_usage	; 0x001A
	dd enum_tasks		; 0x001B
	dd get_uptime		; 0x001C
	dd net_get_connection	; 0x001D
	dd net_send		; 0x001E
	dd net_receive		; 0x001F
	dd http_head		; 0x0020
	dd http_get		; 0x0021
	dd socket_open		; 0x0022
	dd socket_close		; 0x0023
	dd socket_read		; 0x0024
	dd socket_write		; 0x0025
	dd realloc		; 0x0026
	dd kprint		; 0x0027

; syscall_init:
; Installs the kernel API interrupt vector

syscall_init:
	mov al, 0x60		; int 0x60
	mov ebp, kernel_api
	call install_isr

	mov al, 0x60
	mov dl, 0xEE		; set interrupt privledge to userspace
	call set_isr_privledge

	mov al, 0x61		; int 0x61 driver API
	mov ebp, driver_api
	call install_isr

	ret

; kernel_api:
; INT 0x60 Handler
; In\	EBP = Function code
; In\	All other registers = Depends on function input
; Out\	All registers = Depends on function output; all undefined registers destroyed
align 32
kernel_api:
	cmp ebp, MAXIMUM_FUNCTION
	jg .done

	sti

	shl ebp, 2	; mul 4
	add ebp, api_table
	mov ebp, [ebp]
	call ebp

.done:
	iret




