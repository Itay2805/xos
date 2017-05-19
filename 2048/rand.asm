
; 2048 Game Clone for xOS
; Psuedo-random number generator

use32

align 4
rand_next			dd 0
rand_times			dd 0

; rand_init:
; Initializes the random number generator

rand_init:
	mov ebp, XOS_GET_TIME
	int 0x60

	and eax, 0xFFFF		; hours and mins
	and ebx, 0xFF		; seconds

	shr eax, 24
	add eax, ebx
	shl ebx, 16
	add eax, ebx
	inc eax
	mov [rand_next], eax

	ret

; rand:
; Generates a number between 0 and 16
; In\	Nothing
; Out\	EAX = Random number

rand:
	mov eax, [rand_next]
	mov ebx, 1103515245
	mul ebx
	add eax, 12345
	mov [rand_next], eax

	xor edx, edx
	mov eax, [rand_next]
	mov ebx, 32
	div ebx

	xor edx, edx
	mov ebx, 16
	div ebx

	mov eax, edx
	ret




