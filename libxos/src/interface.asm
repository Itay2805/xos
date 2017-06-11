
;
; libXOS
; Rudimentary custom C library for xOS
; Copyright (C) 2017 by Omar Mohammad.
;
; MIT license
;

format elf

include				"libxos/src/xos.asm"

section ".header"
public __linker_entry
__linker_entry:

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main_stub	; entry point
	.reserved0		dq 0
	.reserved1		dq 0

section ".text"
main_stub:
	mov ebp, esp

	extrn libxos_init
	call libxos_init

	extrn xos_main
	call xos_main

	extrn libxos_windows
	mov eax, [libxos_windows]
	mov ebp, XOS_FREE
	int 0x60

	mov ebp, XOS_TERMINATE
	int 0x60

; int32_t k_create_window(int16_t x, int16_t y, int16_t width, int16_t height, uint16_t flags, const char *title);
public k_create_window
k_create_window:
	pusha

	mov eax, [esp+32+4]		; x
	mov ebx, [esp+32+8]		; y
	mov esi, [esp+32+12]		; width
	mov edi, [esp+32+16]		; height
	mov edx, [esp+32+20]		; flags
	mov ecx, [esp+32+24]		; title
	mov ebp, XOS_WM_CREATE_WINDOW
	int 0x60

	mov [.handle], eax

	popa
	mov eax, [.handle]
	ret

align 4
.handle				dd 0

; void k_yield();
public k_yield
k_yield:
	pusha

	mov ebp, XOS_YIELD
	int 0x60

	popa
	ret

; uint32_t k_pixel_offset(int32_t window, int16_t x, int16_t y);
public k_pixel_offset
k_pixel_offset:
	pusha

	mov eax, [esp+32+4]
	mov ecx, [esp+32+8]
	mov edx, [esp+32+12]
	mov ebp, XOS_WM_PIXEL_OFFSET
	int 0x60

	mov [.offset], eax

	popa
	mov eax, [.offset]
	ret

align 4
.offset				dd 0

; void k_redraw();
public k_redraw
k_redraw:
	pusha

	mov ebp, XOS_WM_REDRAW
	int 0x60

	popa
	ret

; uint16_t k_read_event(int32_t window);
public k_read_event
k_read_event:
	pusha

	mov ebp, XOS_WM_READ_EVENT
	mov eax, [esp+32+4]
	int 0x60

	mov [.event], ax

	popa
	movzx eax, [.event]
	ret

align 2
.event				dw 0

; void k_read_mouse(int32_t window, k_mouse_status *mouse);
public k_read_mouse
k_read_mouse:
	pusha

	mov eax, [esp+32+4]
	mov ebp, XOS_WM_READ_MOUSE
	int 0x60

	mov edi, [esp+32+8]		; *mouse
	mov word[edi], cx
	mov word[edi+2], dx

	popa
	ret

; void k_get_window(int32_t window, k_window *window_info);
public k_get_window
k_get_window:
	pusha

	mov eax, [esp+32+4]
	mov ebp, XOS_WM_GET_WINDOW
	int 0x60

	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.flags], dx
	mov [.canvas], ecx
	mov [.title], ebp

	mov edi, [esp+32+8]		; *window_info
	mov ax, [.x]
	mov [edi], ax
	mov ax, [.y]
	mov [edi+2], ax
	mov ax, [.width]
	mov [edi+4], ax
	mov ax, [.height]
	mov [edi+6], ax

	mov ax, [.flags]
	mov [edi+8], ax

	mov eax, [.canvas]
	mov [edi+10], eax

	mov eax, [.title]
	mov [edi+14], eax

	popa
	ret

align 4
.canvas				dd 0
.title				dd 0
.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.flags				dw 0

; void k_draw_text(int32_t window, int16_t x, int16_t y, uint32_t color, const char *text);
public k_draw_text
k_draw_text:
	pusha

	mov eax, [esp+32+4]
	mov ecx, [esp+32+8]
	mov edx, [esp+32+12]
	mov ebx, [esp+32+16]
	mov esi, [esp+32+20]
	mov ebp, XOS_WM_DRAW_TEXT
	int 0x60

	popa
	ret

; void k_clear(int32_t window, uint32_t color);
public k_clear
k_clear:
	pusha

	mov eax, [esp+32+4]
	mov ebx, [esp+32+8]
	mov ebp, XOS_WM_CLEAR
	int 0x60

	popa
	ret

; void *malloc(size_t size);
public malloc
malloc:
	pusha

	mov ecx, [esp+32+4]
	mov ebp, XOS_MALLOC
	int 0x60
	mov [.return], eax

	popa
	mov eax, [.return]
	ret

align 4
.return				dd 0

; void free(void *memory);
public free
free:
	pusha

	mov eax, [esp+32+4]
	mov ebp, XOS_FREE
	int 0x60

	popa
	ret




