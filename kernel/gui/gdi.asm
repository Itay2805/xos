
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; xOS GDI -- An internal graphics library used by the xOS Kernel
; Should be easy to port to other systems

is_redraw_enabled		db 1
align 4
text_background			dd 0x000000
text_foreground			dd 0xFFFFFF
system_font			dd font
current_buffer			db 0		; 0 if the system is using the back buffer
						; 1 if it's using the hardware buffer

; redraw_screen:
; Redraws the screen
align 32
redraw_screen:
	cmp [is_redraw_enabled], 1
	jne .quit
	cmp [current_buffer], 1
	je .quit

	mov esi, VBE_BACK_BUFFER
	mov edi, VBE_PHYSICAL_BUFFER
	mov ecx, [screen.screen_size_dqwords]

.loop:
	;prefetchnta [esi+0x80]
	;prefetchnta [esi+0x100]

	movdqa xmm0, [esi]
	movdqa xmm1, [esi+0x10]
	movdqa xmm2, [esi+0x20]
	movdqa xmm3, [esi+0x30]
	movdqa xmm4, [esi+0x40]
	movdqa xmm5, [esi+0x50]
	movdqa xmm6, [esi+0x60]
	movdqa xmm7, [esi+0x70]

	movdqa [edi], xmm0
	movdqa [edi+0x10], xmm1
	movdqa [edi+0x20], xmm2
	movdqa [edi+0x30], xmm3
	movdqa [edi+0x40], xmm4
	movdqa [edi+0x50], xmm5
	movdqa [edi+0x60], xmm6
	movdqa [edi+0x70], xmm7

	add esi, 128
	add edi, 128
	loop .loop

.quit:
	ret

; get_screen_info:
; Returns the screen information
; In\	Nothing
; Out\	AX/BX = X/Y resolution
; Out\	CL = Bits per pixel (always 32 because xOS only supports 32-bit mode)
align 32
get_screen_info:
	mov eax, [screen.width]
	mov ebx, [screen.height]
	mov ecx, [screen.bpp]
	ret

; use_back_buffer:
; Forces the system to use the back buffer
align 32
use_back_buffer:
	mov [current_buffer], 0
	ret

; use_front_buffer:
; Forces the system to use the hardware framebuffer
align 32
use_front_buffer:
	mov [current_buffer], 1
	ret

; lock_screen:
; Prevents screen redraws while using the back buffer
align 32
lock_screen:
	mov [is_redraw_enabled], 0	
	ret

; unlock_screen:
; Enables screen redraws while using the back buffer
align 32
unlock_screen:
	mov [is_redraw_enabled], 1
	ret

; get_pixel_offset:
; Gets pixel offset
; In\	AX/BX = X/Y pos
; Out\	ESI = Offset within hardware framebuffer
; Out\	EDI = Offset within back buffer
; Note:
; If the system is using the hardware framebuffer (i.e. current_buffer is set to 1), ESI and EDI are swapped.
; This tricks the GDI into writing directly to the hardware framebuffer, and preventing manual screen redraws.
; This is needed for the mouse cursor. ;)
align 32
get_pixel_offset:
	and eax, 0xFFFF
	and ebx, 0xFFFF

	push eax	; x
	mov ax, bx
	mov ebx, [screen.bytes_per_line]
	mul ebx		; y*pitch

	pop ebx		; ebx=x
	shl ebx, 2	; mul 4
	add eax, ebx

	mov esi, eax
	mov edi, eax
	add esi, VBE_PHYSICAL_BUFFER
	add edi, VBE_BACK_BUFFER

	cmp [current_buffer], 1
	je .swap
	ret

.swap:
	xchg esi, edi	; swap ;)
	ret

; put_pixel:
; Puts a pixel
; In\	AX/BX = X/Y pos
; In\	EDX = Color
; Out\	Nothing
align 32
put_pixel:
	push edx
	call get_pixel_offset

	pop eax
	stosd
	call redraw_screen
	ret

; clear_screen:
; Clears the screen
; In\	EBX = Color
; Out\	Nothing
align 32
clear_screen:
	;cli

	;mov [screen.x], 0
	;mov [screen.y], 0

	cmp [current_buffer], 0
	je .back

.front:
	mov edi, VBE_PHYSICAL_BUFFER
	mov ecx, [screen.screen_size]
	shr ecx, 2
	mov eax, ebx
	rep stosd
	ret

.back:
	mov edi, VBE_BACK_BUFFER
	mov ecx, [screen.screen_size]
	shr ecx, 2
	mov eax, ebx
	rep stosd

	call redraw_screen
	ret

; render_char:
; Renders a character
; In\	AL = Character
; In\	CX/DX = X/Y pos
; In\	ESI = Font data
; Out\	Nothing
align 32
render_char:
	and eax, 0xFF
	shl eax, 4
	add eax, esi
	mov [.font_data], eax

	mov ax, cx
	mov bx, dx
	call get_pixel_offset

	xor dl, dl
	mov [.row], dl
	mov [.column], dl

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]

.put_column:
	;mov dl, [.byte]
	test dl, 0x80
	jz .background

.foreground:
	mov eax, [text_foreground]
	jmp .put

.background:
	mov eax, [text_background]

.put:
	stosd
	jmp .next_column

.next_column:
	inc [.column]
	cmp [.column], 8
	je .next_row

	shl dl, 1
	jmp .put_column

.next_row:
	mov [.column],0
	inc [.row]
	cmp [.row], 16
	je .done

	mov eax, [screen.bytes_per_pixel]
	shl eax, 3
	sub edi, eax
	add edi, [screen.bytes_per_line]

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]
	jmp .put_column

.done:
	ret

align 32
.font_data			dd 0
.row				db 0
.column				db 0

; render_char_transparent:
; Renders a character with transparent background
; In\	AL = Character
; In\	CX/DX = X/Y pos
; In\	ESI = Font data
; Out\	Nothing
align 32
render_char_transparent:
	and eax, 0xFF
	shl eax, 4
	add eax, esi
	mov [.font_data], eax

	mov ax, cx
	mov bx, dx
	call get_pixel_offset

	xor dl, dl
	mov [.row], dl
	mov [.column], dl

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]

.put_column:
	;mov dl, [.byte]
	test dl, 0x80
	jz .background

.foreground:
	mov eax, [text_foreground]

.put:
	stosd
	jmp .next_column

.background:
	add edi, 4

.next_column:
	inc [.column]
	cmp [.column], 8
	je .next_row

	shl dl, 1
	jmp .put_column

.next_row:
	mov [.column],0
	inc [.row]
	cmp [.row], 16
	je .done

	sub edi, 8*4
	add edi, [screen.bytes_per_line]

	mov esi, [.font_data]
	mov dl, [esi]
	inc [.font_data]
	jmp .put_column

.done:
	ret

align 32
.font_data			dd 0
.row				db 0
.column				db 0

; set_font:
; Sets the system font
; In\	ESI = 4k buffer to use as font
; Out\	Nothing
align 32
set_font:
	mov [system_font], esi
	ret

; set_text_color:
; Sets the text color
; In\	EBX = Background
; In\	ECX = Foreground
; Out\	Nothing
align 32
set_text_color:
	mov [text_background], ebx
	mov [text_foreground], ecx
	ret

; print_string:
; Prints a string
; In\	ESI = String
; In\	CX/DX = X/Y pos
; Out\	Nothing
align 32
print_string:
	;cli
	mov [.x], cx
	mov [.y], dx
	mov [.ox], cx
	mov [.oy], dx

.loop:
	lodsb
	or al, al
	jz .done
	cmp al, 13
	je .carriage
	cmp al, 10
	je .newline

	push esi
	mov cx, [.x]
	mov dx, [.y]
	mov esi, font
	call render_char
	pop esi

	add [.x], 8
	jmp .loop

.carriage:
	mov ax, [.ox]
	mov [.x], ax
	jmp .loop

.newline:
	mov ax, [.ox]
	mov [.x], ax
	add [.y], 16
	jmp .loop

.done:
	call redraw_screen
	ret

align 2
.x				dw 0
.y				dw 0
.ox				dw 0
.oy				dw 0

; print_string_transparent:
; Prints a string with transparent background
; In\	ESI = String
; In\	CX/DX = X/Y pos
; Out\	Nothing
align 32
print_string_transparent:
	;cli
	mov [.x], cx
	mov [.y], dx
	mov [.ox], cx
	mov [.oy], dx

.loop:
	lodsb
	or al, al
	jz .done
	cmp al, 13
	je .carriage
	cmp al, 10
	je .newline

	push esi
	mov cx, [.x]
	mov dx, [.y]
	mov esi, font
	call render_char_transparent
	pop esi

	add [.x], 8
	jmp .loop

.carriage:
	mov ax, [.ox]
	mov [.x], ax
	jmp .loop

.newline:
	mov ax, [.ox]
	mov [.x], ax
	add [.y], 16
	jmp .loop

.done:
	call redraw_screen
	ret

align 2
.x				dw 0
.y				dw 0
.ox				dw 0
.oy				dw 0

; scroll_screen:
; Scrolls the screen
align 32
scroll_screen:
	pusha

	;cli

	mov esi, [screen.bytes_per_line]
	shl esi, 4		; mul 16
	add esi, VBE_BACK_BUFFER
	mov edi, VBE_BACK_BUFFER
	mov ecx, [screen.screen_size]
	call memcpy

	mov [screen.x], 0
	mov eax, [screen.y_max]
	mov [screen.y], eax

	popa
	ret

; put_char:
; Puts a char at cursor position
; In\	AL = Character
; Out\	Nothing
align 32
put_char:
	;cli

	pusha

	cmp al, 13
	je .carriage
	cmp al, 10
	je .newline

.start:
	mov edx, [screen.x_max]
	cmp [screen.x], edx
	jg .new_y

	mov edx, [screen.y_max]
	cmp [screen.y], edx
	jg .scroll

	mov ecx, [screen.x]
	mov edx, [screen.y]
	shl ecx, 3
	shl edx, 4
	mov esi, [system_font]
	call render_char

	inc [screen.x]

.done:
	call redraw_screen
	popa
	ret

.new_y:
	mov [screen.x], 0
	inc [screen.y]
	mov edx, [screen.y_max]
	cmp [screen.y], edx
	jg .scroll

	jmp .start

.scroll:
	call scroll_screen
	jmp .start

.carriage:
	mov [screen.x], 0
	jmp .done

.newline:
	mov [screen.x], 0
	inc [screen.y]
	mov edx, [screen.y_max]
	cmp [screen.y], edx
	jg .scroll_newline

	jmp .done

.scroll_newline:
	call scroll_screen
	jmp .done

; fill_rect:
; Fills a rectangle
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	EDX = Color
; Out\	Nothing
align 32
fill_rect:
	;cli

	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.color], edx

	movzx eax, [.width]
	mov ebx, [screen.bytes_per_pixel]
	mul ebx
	mov [.bytes_per_line], eax		; one line of rect

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

	mov [.current_line], 0

.loop:
	mov edi, [.offset]
	mov eax, [.color]
	mov ecx, [.bytes_per_line]

	shr ecx, 2
	rep stosd

.next_line:
	inc [.current_line]
	mov cx, [.height]
	cmp [.current_line], cx
	jge .done

	mov eax, [screen.bytes_per_line]
	add [.offset], eax
	jmp .loop

.done:
	call redraw_screen
	ret

align 32
.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.color				dd 0
.offset				dd 0
.bytes_per_line			dd 0
.current_line			dw 0

; blit_buffer:
; Blits a pixel buffer
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	ECX = Transparent color
; In\	EDX = Pixel buffer
; Out\	Nothing
align 32
blit_buffer:
	;cli

	mov [.transparent], ecx
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	;add ax, si
	;add bx, di
	;mov [.end_x], ax
	;mov [.end_y], bx
	mov [.buffer], edx
	mov [.current_line], 0

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

.start:
	mov esi, [.buffer]
	mov edi, [.offset]
	movzx ecx, [.width]
	mov edx, [.transparent]

.loop:
	lodsd
	cmp eax, edx
	je .skip
	stosd
	loop .loop

	jmp .line_done

.skip:
	add edi, 4
	loop .loop

.line_done:
	mov [.buffer], esi

	mov eax, [screen.bytes_per_line]
	add [.offset], eax
	inc [.current_line]
	movzx eax, [.height]
	cmp [.current_line], eax
	jge .done

	jmp .start

.done:
	call redraw_screen
	ret

align 4
.transparent			dd 0
.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.end_x				dw 0
.end_y				dw 0
align 4
.buffer				dd 0
.offset				dd 0
.current_line			dd 0

; blit_buffer_no_transparent:
; Blits a pixel buffer (same as above, but without support for transparent colors)
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	EDX = Pixel buffer
; Out\	Nothing
align 32
blit_buffer_no_transparent:
	;cli

	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	;add ax, si
	;add bx, di
	;mov [.end_x], ax
	;mov [.end_y], bx
	mov [.buffer], edx
	mov [.current_line], 0

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

.start:
	mov esi, [.buffer]
	mov edi, [.offset]
	movzx ecx, [.width]

.loop:
	shl ecx, 2
	call memcpy	; SSE memcpy

.line_done:
	mov [.buffer], esi

	mov eax, [screen.bytes_per_line]
	add [.offset], eax
	inc [.current_line]
	movzx eax, [.height]
	cmp [.current_line], eax
	jge .done

	jmp .start

.done:
	call redraw_screen
	ret

align 32
.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.end_x				dw 0
.end_y				dw 0
align 32
.buffer				dd 0
.offset				dd 0
.current_line			dd 0

; decode_bmp:
; Decodes a 24-bit BMP image
; In\	EDX = Pointer to image data
; In\	EBX = Pointer to memory location to store raw pixel buffer
; Out\	ECX = Size of raw pixel buffer in bytes, -1 on error
; Out\	SI/DI = Width/Height of image
align 32
decode_bmp:
	;cli

	mov [.image], edx
	mov [.memory], ebx

	mov esi, [.image]
	cmp word[esi], "BM"	; bmp image signature
	jne .bad

	mov esi, [.image]
	mov eax, [esi+18]
	mov [.width], eax
	mov eax, [esi+22]
	mov [.height], eax

	mov eax, [.width]
	mov ebx, [.height]
	mul ebx
	mov [.size_pixels], eax
	shl eax, 2
	mov [.buffer_size], eax

	mov esi, [.image]
	add esi, 10
	mov esi, [esi]
	add esi, [.image]
	mov edi, [.memory]
	mov ecx, [.size_pixels]

.copy_loop:
	movsw
	movsb
	mov al, 0
	stosb
	loop .copy_loop

.done:
	mov edx, [.memory]
	mov esi, [.width]
	mov edi, [.height]
	call invert_buffer_vertically

	mov esi, [.width]
	mov edi, [.height]
	mov ecx, [.buffer_size]
	ret

.bad:
	mov ecx, -1
	mov esi, 0
	mov edi, 0
	ret

align 32
.image				dd 0
.memory				dd 0
.width				dd 0
.height				dd 0
.size_pixels			dd 0
.buffer_size			dd 0

; invert_buffer_vertically:
; Inverts a pixel buffer vertically
; In\	EDX = Pointer to pixel data
; In\	SI/DI = Width/Height
; Out\	Buffer inverted
align 32
invert_buffer_vertically:
	;cli

	mov [.buffer], edx
	mov [.width], si
	mov [.height], di

	movzx eax, [.width]
	shl eax, 2
	mov [.bytes_per_line], eax

	movzx eax, [.height]
	dec eax
	mov ebx, [.bytes_per_line]
	mul ebx
	add eax, [.buffer]
	mov [.last_line], eax

	mov esi, [.buffer]
	mov edi, [.last_line]

.loop:
	cmp esi, edi
	jge .done

	mov ecx, [.bytes_per_line]
	call memxchg

	add esi, [.bytes_per_line]
	sub edi, [.bytes_per_line]
	jmp .loop

.done:
	ret

align 32
.buffer					dd 0
.width					dw 0
.height					dw 0
align 32
.current_row				dd 0
.current_line				dd 0
.bytes_per_line				dd 0
.last_line				dd 0

; stretch_buffer:
; Stretches a pixel buffer
; In\	EDX = Pointer to image data
; In\	AX/BX = Current width/height
; In\	SI/DI = New width/height
; Out\	EAX = Pointer to pixel buffer

stretch_buffer:
	;cli

	mov [.old_buffer], edx
	mov [.old_width], ax
	mov [.old_height], bx
	mov [.new_width], si
	mov [.new_height], di

	movzx eax, [.new_width]
	movzx ebx, [.new_height]
	mul ebx
	mov ecx, eax
	shl ecx, 2
	call kmalloc
	mov [.new_buffer], eax

	mov [.i], 0
	mov [.j], 0

	movzx eax, [.old_width]
	shl eax, 16
	movzx ebx, [.new_width]
	mov edx, 0
	div ebx
	inc eax
	mov [.x_ratio], eax

	movzx eax, [.old_height]
	shl eax, 16
	movzx ebx, [.new_height]
	mov edx, 0
	div ebx
	inc eax
	mov [.y_ratio], eax

.loop:
	mov edx, [.j]
	cmp dx, [.new_width]
	jge .loop_finish

	mov eax, [.j]
	mov ebx, [.x_ratio]
	mul ebx
	shr eax, 16
	mov [.x2], eax

	mov eax, [.i]
	mov ebx, [.y_ratio]
	mul ebx
	shr eax, 16
	mov [.y2], eax

	mov eax, [.y2]
	movzx ebx, [.old_width]
	mul ebx
	add eax, [.x2]
	shl eax, 2
	add eax, [.old_buffer]
	mov [.source], eax

	mov eax, [.i]
	movzx ebx, [.new_width]
	mul ebx
	add eax, [.j]
	shl eax, 2
	add eax, [.new_buffer]
	mov [.dest], eax

	mov esi, [.source]
	mov edi, [.dest]
	movsd

	inc [.j]
	jmp .loop

.loop_finish:
	mov [.j], 0
	inc [.i]
	mov edx, [.i]
	cmp dx, [.new_height]
	jge .finish

	jmp .loop

.finish:
	mov eax, [.new_buffer]
	ret

align 2
.old_width				dw 0
.old_height				dw 0
.new_width				dw 0
.new_height				dw 0
align 4
.old_buffer				dd 0
.new_buffer				dd 0
.i					dd 0
.j					dd 0
.x_ratio				dd 0
.y_ratio				dd 0
.x2					dd 0
.y2					dd 0
.source					dd 0
.dest					dd 0

; alpha_blend_colors:
; Blends two colors smoothly
; In\	EAX = Foreground
; In\	EBX = Background
; In\	DL = Alpha intensity (1 = less transparent, 4 = most transparent)
; Out\	EAX = New color
; Out\	EBX is destroyed
align 64
alpha_blend_colors:
	xchg ecx, edx
	and eax, 0xF0F0F0
	and ebx, 0xF0F0F0

	;mov cl, dl
	shr eax, cl
	shr ebx, 1

	and eax, 0x7F7F7F
	and ebx, 0x7F7F7F

	add eax, ebx
	xchg ecx, edx
	ret

; alpha_fill_rect_no_sse:
; Fills a rectangle will alpha blending, without SSE
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	CL = Alpha intensity
; In\	EDX = Color
; Out\	Nothing
align 64
alpha_fill_rect_no_sse:
	; ensure a valid alpha intensity
	cmp cl, 1
	jl fill_rect
	cmp cl, 4
	jg fill_rect

	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.intensity], cl
	mov [.color], edx
	mov [.current_line], 0

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

	;movzx eax, [.width]
	;shl eax, 2	; mul 4
	;mov [.bytes_per_line], eax

.start:
	mov edi, [.offset]
	mov esi, [.color]	; avoid reading from memory too much for performance
	movzx ecx, [.width]	; counter

.loop:
	mov ebx, [edi]		; background is the already-existing pixel
	mov eax, esi
	mov dl, [.intensity]
	call alpha_blend_colors
	stosd

	loop .loop

.next_line:
	inc [.current_line]
	mov cx, [.height]
	cmp [.current_line], cx
	jge .done

	; next offset
	mov edi, [screen.bytes_per_line]
	add [.offset], edi
	jmp .start

.done:
	ret

align 2
.x			dw 0
.y			dw 0
.width			dw 0
.height			dw 0
.intensity		db 0
align 8
.color			dd 0
.offset			dd 0
.bytes_per_line		dd 0
.current_line		dw 0


;
; EXPERIMENTAL SECTION: SSE-optimized alpha blending functions
;

; alpha_blend_colors_packed:
; Blends 8 colors in one SSE operation
; In\	XMM0 = Foreground 1, 4 pixels
; In\	XMM1 = Background 1, 4 pixels
; In\	XMM2 = Color mask
; In\	XMM6 = Foreground 2, 4 pixels
; In\	XMM7 = Background 2, 4 pixels
; In\	DL = Intensity
; Out\	XMM0 = New color, 4 pixels
; Out\	XMM6 = New color, 4 pixels
align 32
alpha_blend_colors_packed:
	mov byte[.intensity], dl

	;movdqa xmm2, dqword[.mask]
	pand xmm0, xmm2
	pand xmm1, xmm2
	pand xmm6, xmm2
	pand xmm7, xmm2

	psrld xmm0, [.intensity]	; shift foreground by intensity
	psrld xmm6, [.intensity]
	psrld xmm1, 1
	psrld xmm7, 1
	paddd xmm0, xmm1
	paddd xmm6, xmm7

	ret

align 8
.intensity:			dq 0

; alpha_fill_rect:
; Fills a rectangle with alpha blending, using SSE for acceleration
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	CL = Alpha intensity
; In\	EDX = Color
; Out\	Nothing
align 32
alpha_fill_rect:
	;cli

	test si, 7		; must be multiple of 8, because the SSE function works on 8 pixels at a time
	jnz alpha_fill_rect_no_sse

	cmp cl, 1
	jl fill_rect
	cmp cl, 4
	jg fill_rect

	mov [.x], ax
	mov [.y], bx
	shr si, 3		; div 8; because we'll work on 8 pixels at the same time
	mov [.width], si
	mov [.height], di
	mov [.alpha], cl

	mov dword[.color], edx
	mov dword[.color+4], edx
	mov dword[.color+8], edx
	mov dword[.color+12], edx

	mov ax, [.x]
	mov bx, [.y]
	call get_pixel_offset
	mov [.offset], edi

	mov [.current_line], 0
	movdqa xmm3, dqword[.color]		; will use XMM3 to store the color
	movdqa xmm2, dqword[.mask]		; and XMM2 for the mask

.start:
	test [.offset], 0x0F
	jnz .unaligned_start

.aligned_start:
	mov edi, [.offset]
	movzx ecx, [.width]

.aligned_loop:
	movdqa xmm0, xmm3	; foreground
	movdqa xmm1, [edi]	; background
	movdqa xmm6, xmm3
	movdqa xmm7, [edi+16]
	mov dl, [.alpha]
	call alpha_blend_colors_packed		; sse alpha blending

	movdqa [edi], xmm0
	movdqa [edi+16], xmm6
	add edi, 32
	loop .aligned_loop

.aligned_next_line:
	inc [.current_line]
	mov cx, [.height]
	cmp [.current_line], cx
	jge .done

	; next offset
	mov edi, [screen.bytes_per_line]
	add [.offset], edi
	jmp .start

.unaligned_start:
	mov edi, [.offset]
	movzx ecx, [.width]

.unaligned_loop:
	movdqa xmm0, xmm3	; foreground
	movdqu xmm1, [edi]	; background
	movdqa xmm6, xmm3
	movdqu xmm7, [edi+16]
	mov dl, [.alpha]
	call alpha_blend_colors_packed		; sse alpha blending

	movdqu [edi], xmm0
	movdqu [edi+16], xmm6
	add edi, 32
	loop .unaligned_loop

.unaligned_next_line:
	inc [.current_line]
	mov cx, [.height]
	cmp [.current_line], cx
	jge .done

	; next offset
	mov edi, [screen.bytes_per_line]
	add [.offset], edi
	jmp .start

.done:
	ret


align 4
.x			dw 0
.y			dw 0
.width			dw 0
.height			dw 0
.alpha			db 0
align 16
.color:			times 2 dq 0		; sse stuff ;)
.offset			dd 0
.current_line		dw 0
align 16
.mask			dq 0x00F0F0F000F0F0F0
			dq 0x00F0F0F000F0F0F0



