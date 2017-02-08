
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

TIMER_FREQUENCY			= 1000

align 8
timer_ticks			dd 0
task_time			dd 0

; pit_init:
; Initialize the PIT
align 64
pit_init:
	mov esi, .msg
	call kprint

	; install IRQ handler
	mov al, IRQ_BASE+0x00	; irq0
	mov ebp, pit_irq
	call install_isr

	; set frequency and mode
	mov al, 0x36
	out 0x43, al
	call iowait

	mov eax, 1193182/TIMER_FREQUENCY
	out 0x40, al
	call iowait

	mov al, ah
	out 0x40, al
	call iowait

	; unmask IRQ
	mov al, 0
	call irq_unmask

	ret

.msg			db "Setting PIT frequency...",10,0

; pit_irq:
; PIT IRQ Handler
align 64
pit_irq:
	push eax

	inc [timer_ticks]

	cmp [current_task], 0
	je .idle

.non_idle:
	inc [nonidle_time]
	jmp .done

.idle:
	inc [idle_time]

.done:
	mov al, 0x20
	out 0x20, al

	pop eax
	iret

; pit_sleep:
; Sleeps using the PIT
; In\	EAX = 1/100 seconds to wait
; Out\	Nothing

pit_sleep:
	add eax, [timer_ticks]

.loop:
	cmp [timer_ticks], eax
	jge .done

	sti
	hlt
	jmp .loop

.done:
	ret




