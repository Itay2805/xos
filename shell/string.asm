
;; xOS Shell
;; Copyright (c) 2017 by Omar Mohammad.

use32

; strlen:
; Gets length of string
; In\	ESI = String
; Out\	EAX = Length in byte

strlen:
	pusha

	mov ecx, 0

.loop:
	lodsb
	cmp al, 0
	je .done
	inc ecx
	jmp .loop

.done:
	mov [.tmp], ecx
	popa
	mov eax, [.tmp]
	ret

align 4
.tmp			dd 0

; find_byte_in_string:
; Find a byte within a string
; In\	ESI = String
; In\	DL = Byte to find
; In\	ECX = Total bytes to search
; Out\	EFLAGS = Carry clear if byte found
; Out\	ESI = Pointer to byte in string

find_byte_in_string:

.loop:
	lodsb
	cmp al, dl
	je .found
	loop .loop

	stc
	ret

.found:
	dec esi
	clc
	ret

; replace_byte_in_string:
; Replaces a byte in a string
; In\	ECX = Size of string
; In\	ESI = String
; In\	DL = Byte to find
; In\	DH = Byte to replace with
; Out\	Nothing

replace_byte_in_string:
	mov [.byte_to_find], dl
	mov [.byte_to_replace], dh

	;call strlen
	;mov ecx, eax

.loop:
	mov al, [esi]
	cmp al, [.byte_to_find]
	je .found

	inc esi
	dec ecx
	cmp ecx, 0
	je .done
	jmp .loop

.found:
	mov al, [.byte_to_replace]
	mov [esi], al
	inc esi
	dec ecx
	cmp ecx, 0
	je .done
	jmp .loop

.done:
	ret

.byte_to_find			db 0
.byte_to_replace		db 0


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

; update_time:
; Updates the time in the task bar

update_time:
	mov al, [.hour]
	mov [.hour_old], al
	mov al, [.minute]
	mov [.minute_old], al
	mov al, [.second]
	mov [.second_old], al

	mov ebp, XOS_GET_TIME
	int 0x60
	mov [.hour], ah
	mov [.minute], al
	mov [.second], bl

	cmp bl, [.second_old]
	je .no_change

	test [.second], 1
	jz .second_even

.second_odd:
	mov byte[time_text+2], " "
	mov [.changed], 1
	jmp .start

.second_even:
	mov byte[time_text+2], ":"
	mov [.changed], 1

.start:
	cmp ah, [.hour_old]
	jne .do_minute

	cmp al, [.minute_old]
	je .done

.do_minute:
	cmp [.minute], 9
	jle .minute_small

	movzx eax, [.minute]
	call int_to_string
	mov edi, time_text+3
	movsw

	jmp .do_hour

.minute_small:
	movzx eax, [.minute]
	add al, 48	; '0'
	mov byte[time_text+3], "0"
	mov byte[time_text+4], al

.do_hour:
	cmp [.hour], 0
	je .midnight

	cmp [.hour], 9
	jle .hour_small

	cmp [.hour], 12
	jge .pm

.am:
	movzx eax, [.hour]
	call int_to_string
	mov edi, time_text
	movsw
	mov word[time_text+6], "AM"
	jmp .done

.midnight:
	mov word[time_text], "12"
	mov word[time_text+6], "AM"
	jmp .done

.hour_small:
	movzx eax, [.hour]
	add al, 48
	mov byte[time_text], "0"
	mov byte[time_text+1], al
	mov word[time_text+6], "AM"
	jmp .done

.pm:
	movzx eax, [.hour]
	sub eax, 12
	cmp eax, 0
	je .12_pm

	cmp eax, 9
	jle .pm_small

	call int_to_string
	mov edi, time_text
	movsw
	mov word[time_text+6], "PM"
	jmp .done

.pm_small:
	add al, 48
	mov byte[time_text], "0"
	mov byte[time_text+1], al
	mov word[time_text+6], "PM"
	jmp .done

.12_pm:
	mov word[time_text], "12"
	mov word[time_text+6], "PM"
	jmp .done

.no_change:
	mov [.changed], 0
	ret

.done:
	cmp [.changed], 0
	je .quit

	mov eax, [window_handle]
	call xwidget_redraw

	mov [.changed], 0

.quit:
	ret

.hour			db 0xFF
.minute			db 0xFF
.hour_old		db 0
.minute_old		db 0
.second			db 0xFF
.second_old		db 0
.changed		db 0


