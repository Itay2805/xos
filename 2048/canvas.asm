
; 2048 Game Clone for xOS

use32

; fill_rect:
; Draws a rectangle
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	EDX = Color
; Out\	Nothing

fill_rect:
	mov [.color], edx
	mov [.width], si
	mov [.height], di
	mov [.current_line], 0

	; get offset in window canvas
	mov cx, ax
	mov dx, bx
	mov eax, [window_handle]
	mov ebp, XOS_WM_PIXEL_OFFSET
	int 0x60

	mov edi, eax

.loop:
	push edi

	movzx ecx, [.width]
	mov eax, [.color]
	rep stosd

	pop edi
	add edi, WINDOW_WIDTH * 4

	inc [.current_line]
	mov cx, [.height]
	cmp [.current_line], cx
	jge .done

	jmp .loop

.done:
	;mov ebp, XOS_WM_REDRAW
	;int 0x60		; -- this redraw will be done manually
	ret

align 4
.color			dd 0
.width			dw 0
.height			dw 0
.current_line		dw 0

; draw_text:
; Draws text
; In\	ESI = String
; In\	EBX = Color
; In\	CX/DX = X/Y pos
; Out\	Nothing

draw_text:
	mov eax, [window_handle]
	mov ebp, XOS_WM_DRAW_TEXT
	int 0x60

	ret



