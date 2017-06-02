
; flat assembler interface for xOS

use32

; init_memory:
; Initializes the memory

init_memory:
	mov ecx, 0x80000*7
	mov ebp, XOS_MALLOC
	int 0x60
	mov [memory_start], eax

	add eax, (0x80000*7) - 1
	mov [memory_end], eax

	mov ecx, 0x80000
	mov ebp, XOS_MALLOC
	int 0x60
	mov [additional_memory], eax

	add eax, 0x7FFFF
	mov [additional_memory_end], eax

	ret

; exit_program:
; Quits the program
; In\	AL = Exit code

exit_program:
	push eax

	mov eax, [window_handle]
	call xwidget_kill_window

	call xwidget_destroy

	pop eax
	mov ebp, XOS_TERMINATE
	int 0x60

; display_block:
; Displays block of string
; In\	ESI = String
; In\	ECX = Size of string
; Out\	Nothing

display_block:
	pusha

	mov edi, [log_ptr]
	rep movsb

	mov [log_ptr], edi

	mov al, 0
	stosb

	mov eax, [window_handle]
	call xwidget_redraw

	popa
	ret

; display_string:
; Displays a string
; In\	ESI = Null-terminated string
; Out\	Nothing

display_string:
	pusha

	mov edi, [log_ptr]

.loop:
	lodsb
	cmp al, 0
	je .done
	stosb
	jmp .loop

.done:
	mov [log_ptr], edi

	mov al, 0
	stosb

	mov eax, [window_handle]
	call xwidget_redraw

	popa
	ret

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

; display_number:
; Displays integer
; In\	EAX = Number
; Out\	Nothing

display_number:
	pusha
	call int_to_string
	call display_string
	popa
	ret

; fatal_error:
; Fatal error handler

fatal_error:
	mov esi, .msg
	call display_string

	mov esi, [esp]
	call display_string

.wait:
	call xwidget_wait_event
	cmp eax, XWIDGET_CLOSE
	jne .wait

	mov al, 0xFF
	call exit_program

.msg			db "fatal error: ",0

; assembler_error:
; Assembler error handler

assembler_error:
	mov esi, .msg
	call display_string

.wait:
	call xwidget_wait_event
	cmp eax, XWIDGET_CLOSE
	jne .wait

	mov al, 2
	call exit_program

.msg			db "assembler error: unimplemented.",0

; create:
; Creates a file
; In\	EDX = Path
; Out\	EFLAGS.CF = 0 on success
; Out\	EBX = File handle

create:
	pusha

	mov esi, edx
	mov edx, 0x80		; file create
	mov ebp, XOS_OPEN
	int 0x60

	cmp eax, -1
	je .error

	mov [.handle], eax

	popa
	clc
	mov ebx, [.handle]
	ret

.error:
	popa
	stc
	ret

align 4
.handle				dd 0

; close:
; Closes a file
; In\	EBX = Handle
; Out\	Nothing

close:
	pusha

	mov eax, ebx
	mov ebp, XOS_CLOSE
	int 0x60

	popa
	ret

; open:
; Opens a file
; In\	EDX = Path
; Out\	EFLAGS.CF = 0 on success
; Out\	EBX = File handle

open:
	pusha

	mov esi, edx
	mov edx, 4		; file read
	mov ebp, XOS_OPEN
	int 0x60

	cmp eax, -1
	je .error

	mov [.handle], eax

	popa
	clc
	mov ebx, [.handle]
	ret

.error:
	popa
	stc
	ret

align 4
.handle				dd 0

; write:
; Writes to file
; In\	EBX = Handle
; In\	ECX = Byte count
; In\	EDX = Buffer
; Out\	EFLAGS.CF = 0 on success

write:
	clc	; for testing if FASM itself works, until I implement "real" write access
	ret

; read:
; Reads from file
; In\	EBX = Handle
; In\	ECX = Byte count
; In\	EDX = Buffer
; Out\	EFLAGS.CF = 0 on success

read:
	pusha

	push ecx

	mov eax, ebx
	mov edi, edx
	mov ebp, XOS_READ
	int 0x60

	pop ecx
	cmp eax, ecx
	jne .error

	popa
	clc
	ret

.error:
	popa
	stc
	ret

; lseek:
; Moves position in file
; In\	EBX = Handle
; In\	EDX = Byte count
; In\	AL = Origin of move
; Out\	EAX = New position

lseek:
	pusha

	mov [.handle], ebx
	mov [.count], edx
	mov [.origin], al

	mov eax, [.handle]
	movzx ebx, [.origin]
	mov ecx, [.count]
	mov ebp, XOS_SEEK
	int 0x60

	mov eax, [.handle]
	mov ebp, XOS_TELL
	int 0x60

	mov [.pos], eax

	popa
	mov eax, [.pos]
	ret

align 4
.handle				dd 0
.count				dd 0
.pos				dd 0
.origin				db 0

; Unimplemented functions...

get_environment_variable:
	ret

make_timestamp:
	mov eax, 0
	ret



