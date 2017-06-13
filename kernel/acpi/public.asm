
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; shutdown:
; Shuts down the PC

shutdown:
	cmp [current_task], 1
	jg .no		; only the kernel and the shell can shut down the PC
			; when I support IPC, other programs can request shutdowns by sending --
			; -- a message to the shell

	call kill_all

	mov eax, [screen.width]
	mov ebx, [screen.height]
	shr eax, 1
	shr ebx, 1
	sub ax, 320/2
	sub bx, 96/2
	mov si, 320
	mov di, 96
	mov dx, 0
	mov ecx, .title
	call wm_create_window

	mov esi, .text
	mov cx, 16
	mov dx, 16
	mov ebx, 0x000000
	call wm_draw_text

	call wm_redraw

	mov al, 5
	call acpi_sleep

.hang:
	sti
	hlt
	jmp .hang

.no:
	mov esi, .no_msg
	call kprint

	ret

.no_msg			db "acpi: application requested shut down; refused...",10,0
.title			db "xOS",0
.text			db "It's now safe to power off your PC.",10,0

; reboot:
; Reboots the PC

reboot:
	cmp [current_task], 1
	jg .no

	call kill_all		; terminate all applications
	;call acpi_reboot	; TO-DO!

.hang:
	mov al, 0xFE
	out 0x64, al
	call iowait

	mov al, 3
	out 0x92, al
	call iowait

	lgdt [.dt]
	lidt [.dt]
	int 0

.no:
	mov esi, .no_msg
	call kprint

	ret

.no_msg			db "acpi: application requested reboot; refused...",10,0
.dt:			dw 0	; null gdt/idt
			dd 0



