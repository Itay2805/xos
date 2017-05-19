
; xOS System Monitor

use32
org 0x8000000		; programs are loaded to 128 MB, drivers to 2048 MB

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

include				"libxwidget/src/libxwidget.asm"

; main:
; Program entry point

main:
	call xwidget_init

	mov ax, 48
	mov bx, 48
	mov si, 512
	mov di, 480
	mov dx, 0
	mov ecx, window_title
	call xwidget_create_window

	mov [window_handle], eax

	call xwidget_lock

	;mov eax, [window_handle]
	;mov ebx, 0x606060
	;call xwidget_window_set_color

	mov eax, [window_handle]
	mov cx, 8
	mov dx, 8
	mov esi, pid_text
	mov ebx, 0x505050
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 128
	mov dx, 8
	mov esi, filename_text
	mov ebx, 0x505050
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 320
	mov dx, 8
	mov esi, memory_text
	mov ebx, 0x505050
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 7
	mov dx, 7
	mov esi, pid_text
	mov ebx, 0x909090
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 127
	mov dx, 7
	mov esi, filename_text
	mov ebx, 0x909090
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 319
	mov dx, 7
	mov esi, memory_text
	mov ebx, 0x909090
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 8
	mov dx, 360
	mov esi, total_memory_text
	mov ebx, 0x505050
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 8
	mov dx, 376
	mov esi, used_memory_text
	mov ebx, 0x505050
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 8
	mov dx, 392
	mov esi, free_memory_text
	mov ebx, 0x505050
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 7
	mov dx, 359
	mov esi, total_memory_text
	mov ebx, 0x909090
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 7
	mov dx, 375
	mov esi, used_memory_text
	mov ebx, 0x909090
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 7
	mov dx, 391
	mov esi, free_memory_text
	mov ebx, 0x909090
	call xwidget_create_label


	mov eax, [window_handle]
	call xwidget_unlock

	mov eax, [window_handle]
	call xwidget_redraw

.idle:
	call xwidget_wait_event
	cmp eax, XWIDGET_CLOSE
	je close

	jmp .idle

; update_tasks:
; Redraws the tasks screen

update_tasks:
	mov [.pid], 0
	mov [.counted_tasks], 0

.destroy_labels:
	mov edi, task_pid_labels

.destroy_labels_loop:
	mov eax, [window_handle]
	mov ebx, [edi]
	cmp ebx, 0
	je .label_skip

	push edi
	call xwidget_destroy_component
	pop edi

.label_skip:
	add edi, 4
	cmp edi, end_task_labels
	jge .enumerate_tasks_loop

	jmp .destroy_labels_loop

.enumerate_tasks_loop:
	mov eax, [.pid]
	mov edi, task_enum		; kernel returns information here
	mov ebp, XOS_ENUM_TASKS
	int 0x60

	mov [.new_pid], ebx

	mov edi, task_names
	mov eax, [.counted_tasks]
	shl eax, 5		; mul 32
	add edi, eax
	mov esi, task_enum.name
	mov ecx, 32
	rep movsb

	mov eax, [.pid]
	call int_to_string

	mov edi, task_pids
	mov eax, [.counted_tasks]
	shl eax, 2		; mul 4
	add edi, eax
	mov ecx, 4
	rep movsb

	mov eax, [task_enum.memory]
	call int_to_string

	mov edi, task_memory
	mov eax, [.counted_tasks]
	shl eax, 4		; mul 16
	add edi, eax
	mov ecx, 16
	rep movsb

	mov eax, [.counted_tasks]
	shl eax, 4		; mul 16
	add eax, 16+8
	mov [.y], ax

	mov esi, task_pids
	mov eax, [.counted_tasks]
	shl eax, 2
	add esi, eax
	mov cx, 8
	mov dx, [.y]
	mov ebx, 0
	mov eax, [window_handle]
	call xwidget_create_label

	mov edi, task_pid_labels
	mov ecx, [.counted_tasks]
	shl ecx, 2
	add edi, ecx
	stosd

	mov esi, task_names
	mov eax, [.counted_tasks]
	shl eax, 5
	add esi, eax
	mov cx, 128
	mov dx, [.y]
	mov ebx, 0
	mov eax, [window_handle]
	call xwidget_create_label

	mov edi, task_name_labels
	mov ecx, [.counted_tasks]
	shl ecx, 2
	add edi, ecx
	stosd

	mov esi, task_memory
	mov eax, [.counted_tasks]
	shl eax, 4
	add esi, eax
	mov cx, 320
	mov dx, [.y]
	mov ebx, 0
	mov eax, [window_handle]
	call xwidget_create_label

	mov edi, task_memory_labels
	mov ecx, [.counted_tasks]
	shl ecx, 2
	add edi, ecx
	stosd

	inc [.counted_tasks]
	cmp [.counted_tasks], 20
	jge .done

	mov eax, [.new_pid]
	cmp eax, 0
	je .done

	mov [.pid], eax

	jmp .enumerate_tasks_loop

.done:
	ret

align 4
.pid				dd 0
.new_pid			dd 0
.counted_tasks			dd 0
.y				dw 0

; update_memory:
; Updates the memory usage counters

update_memory:
	mov ebp, XOS_GET_MEMORY_USAGE
	int 0x60

	shr eax, 8
	shr ebx, 8
	mov [total_memory_mb], eax
	mov [used_memory_mb], ebx

	sub eax, ebx
	mov [free_memory_mb], eax

	mov eax, [total_memory_mb]
	call int_to_string
	mov edi, total_memory_number
	mov ecx, 16
	rep movsb

	mov eax, [used_memory_mb]
	call int_to_string
	mov edi, used_memory_number
	mov ecx, 16
	rep movsb

	mov eax, [free_memory_mb]
	call int_to_string
	mov edi, free_memory_number
	mov ecx, 16
	rep movsb

	cmp [total_memory_label], 0
	je .destroy_used

	mov eax, [window_handle]
	mov ebx, [total_memory_label]
	call xwidget_destroy_component

.destroy_used:
	cmp [used_memory_label], 0
	je .destroy_free

	mov eax, [window_handle]
	mov ebx, [used_memory_label]
	call xwidget_destroy_component

.destroy_free:
	cmp [free_memory_label], 0
	je .make_labels

	mov eax, [window_handle]
	mov ebx, [free_memory_label]
	call xwidget_destroy_component

.make_labels:
	mov eax, [window_handle]
	mov cx, 8+(19*8)
	mov dx, 360
	mov esi, total_memory_number
	mov ebx, 0
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 8+(18*8)
	mov dx, 376
	mov esi, used_memory_number
	mov ebx, 0
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 8+(18*8)
	mov dx, 392
	mov esi, free_memory_number
	mov ebx, 0
	call xwidget_create_label

	ret

; close:
; Exits the application

close:
	mov eax, [window_handle]
	call xwidget_kill_window

	call xwidget_destroy

	mov ebp, XOS_TERMINATE
	int 0x60

; int_to_string:
; Converts an unsigned integer to a string
; In\	EAX = Integer
; Out\	ESI = ASCIIZ string

int_to_string:
	push eax
	mov [.counter], 10

	mov edi, .string
	mov ecx, 10
	mov eax, 0
	rep stosb

	mov esi, .string
	add esi, 9
	pop eax

.loop:
	cmp eax, 0
	je .done2
	mov ebx, 10
	mov edx, 0
	div ebx

	add dl, 48
	mov byte[esi], dl
	dec esi

	sub byte[.counter], 1
	cmp byte[.counter], 0
	je .done
	jmp .loop

.done:
	mov esi, .string
	ret

.done2:
	cmp byte[.counter], 10
	je .zero
	mov esi, .string

.find_string_loop:
	lodsb
	cmp al, 0
	jne .found_string
	jmp .find_string_loop

.found_string:
	dec esi
	ret

.zero:
	mov edi, .string
	mov al, '0'
	stosb
	mov al, 0
	stosb
	mov esi, .string

	ret

.string:		times 11 db 0
.counter		db 0

; xwidget_yield_handler:
; Called every time the program is idle

xwidget_yield_handler:
	mov ebp, XOS_GET_TIME
	int 0x60

	cmp bl, [.second]
	je .return

	mov [.second], bl

	mov eax, [window_handle]
	call xwidget_lock

	call update_tasks
	call update_memory

	mov eax, [window_handle]
	call xwidget_unlock

	mov eax, [window_handle]
	call xwidget_redraw

.return:
	ret

.second			db 0xFF

; Data..

align 4
task_enum:
	.state			dw 0
	.parent			dw 0
	.memory			dd 0
	.name:			times 32 db 0

align 4
window_handle			dd 0

task_pid_labels:		times 20 dd 0
task_name_labels:		times 20 dd 0
task_memory_labels:		times 20 dd 0
end_task_labels:

task_pids:			times 20*4 db 0
task_names:			times 20*32 db 0
task_memory:			times 20*16 db 0

window_title			db "System Monitor",0
pid_text			db "PID",0
filename_text			db "File name",0
memory_text			db "Binary memory (KB)",0

total_memory_text		db "Total memory (MB): ",0
used_memory_text		db "Used memory (MB): ",0
free_memory_text		db "Free memory (MB): ",0

total_memory_mb			dd 0
used_memory_mb			dd 0
free_memory_mb			dd 0

total_memory_number:		times 16 db 0
used_memory_number:		times 16 db 0
free_memory_number:		times 16 db 0

total_memory_label		dd 0
used_memory_label		dd 0
free_memory_label		dd 0






