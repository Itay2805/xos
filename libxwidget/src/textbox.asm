
;; xOS -- libxwidget 1
;; Copyright (c) 2017 by Omar Mohammad.

use32

;
; typedef struct textbox_component
; {
;	u8 id;			// XWIDGET_CPNT_TEXTBOX
;	u8 flags;		// described below
;	u16 x;
;	u16 y;
;	u16 width;
;	u16 height;
;	u16 reserved;
;	u32 text;
;	u32 limit;
;	u16 position_x;
;	u16 position_y;
;	u32 text_position;
; } textbox_component;
;

XWIDGET_TEXTBOX_ID		= 0x00
XWIDGET_TEXTBOX_FLAGS		= 0x01
XWIDGET_TEXTBOX_X		= 0x02
XWIDGET_TEXTBOX_Y		= 0x04
XWIDGET_TEXTBOX_WIDTH		= 0x06
XWIDGET_TEXTBOX_HEIGHT		= 0x08
XWIDGET_TEXTBOX_TEXT		= 0x0C
XWIDGET_TEXTBOX_LIMIT		= 0x10
XWIDGET_TEXTBOX_POSITION_X	= 0x14
XWIDGET_TEXTBOX_POSITION_Y	= 0x16
XWIDGET_TEXTBOX_TEXT_POSITION	= 0x18

; Flags
XWIDGET_TEXTBOX_FOCUSED		= 0x01
XWIDGET_TEXTBOX_MULTILINE	= 0x02

; xwidget_create_textbox:
; Creates a textbox
; In\	EAX = Window handle
; In\	CX/DX = X/Y pos
; In\	SI/DI = Width/Height
; In\	BL = Flags
; In\	EBP = Pointer to text and limit
; Out\	EAX = Component handle, -1 on error
align 4
xwidget_create_textbox:
	mov [.window], eax
	mov [.x], cx
	mov [.y], dx
	mov [.width], si
	mov [.height], di
	mov [.flags], bl

	mov eax, [ebp]
	mov [.text], eax
	mov eax, [ebp+4]	; limit in chars
	mov [.limit], eax

	mov eax, [.window]
	call xwidget_find_component	; find a free conponent handle
	cmp eax, -1
	je .error

	mov [.component], eax

	; create the component here
	mov edi, [.component]
	mov byte[edi+XWIDGET_TEXTBOX_ID], XWIDGET_CPNT_TEXTBOX

	mov al, [.flags]
	mov [edi+XWIDGET_TEXTBOX_FLAGS], al

	mov ax, [.x]
	mov [edi+XWIDGET_TEXTBOX_X], ax

	mov ax, [.y]
	mov [edi+XWIDGET_TEXTBOX_Y], ax

	mov ax, [.width]
	mov [edi+XWIDGET_TEXTBOX_WIDTH], ax

	mov ax, [.height]
	mov [edi+XWIDGET_TEXTBOX_HEIGHT], ax

	mov eax, [.text]
	mov [edi+XWIDGET_TEXTBOX_TEXT], eax
	mov [edi+XWIDGET_TEXTBOX_TEXT_POSITION], eax

	mov eax, [.limit]
	mov [edi+XWIDGET_TEXTBOX_LIMIT], eax

	mov word[edi+XWIDGET_TEXTBOX_POSITION_X], 0
	mov word[edi+XWIDGET_TEXTBOX_POSITION_Y], 0

	; request a redraw
	mov eax, [.window]
	call xwidget_redraw

	mov eax, [.component]	; return the component
	ret

.error:
	mov eax, -1
	ret

align 4
.window				dd 0
.text				dd 0
.limit				dd 0
.component			dd 0
.x				dw 0
.y				dw 0
.width				dw 0
.height				dw 0
.flags				db 0

; xwidget_insert_char:
; Inserts a character in a string
; In\	ESI = String
; In\	AL = Character
; Out\	Nothing
align 4
xwidget_insert_char:
	mov [.char], al
	mov [.string], esi

	mov esi, [.string]
	call xwidget_strlen

	mov ecx, eax
	mov esi, [.string]
	mov edi, esi
	inc edi
	rep movsb
	xor al, al
	stosb

	mov edi, [.string]
	mov al, [.char]
	stosb
	ret

align 4
.string				dd 0
.char				db 0

; xwidget_delete_char:
; Deletes a character from a string
; In\	ESI = String
; Out\	AL = Deleted character

xwidget_delete_char:
	mov al, [esi]
	push eax

	mov [.string], esi
	call xwidget_strlen
	mov ecx, eax
	dec ecx
	mov esi, [.string]
	mov edi, esi
	inc esi
	rep movsb
	xor al, al
	stosb

	pop eax
	ret

align 4
.string				dd 0

; xwidget_get_focused_textbox:
; Returns the current focused textbox
; In\	EAX = Window handle
; Out\	EAX = Textbox component handle, -1 if none
align 4
xwidget_get_focused_textbox:
	shl eax, 3
	add eax, xwidget_windows_data
	mov edi, [eax+4]	; components array
	mov [.components], edi

	add edi, 256*256
	mov [.components_end], edi

	mov esi, [.components]

.loop:
	cmp esi, [.components_end]
	jge .no

	cmp byte[esi], XWIDGET_CPNT_TEXTBOX
	jne .next

	test byte[esi+XWIDGET_TEXTBOX_FLAGS], XWIDGET_TEXTBOX_FOCUSED
	jnz .finish

.next:
	add esi, 256
	jmp .loop

.finish:
	mov eax, esi	; component handle
	ret

.no:
	mov eax, -1
	ret

align 4
.components			dd 0
.components_end			dd 0

; xwidget_get_textbox_line:
; Returns a line of text in a textbox
; In\	EBX = Textbox component handle
; In\	EAX = Line number
; Out\	ESI = Pointer to text
; Out\	EAX = Size of line in bytes
align 4
xwidget_get_textbox_line:
	cmp eax, 0
	je .zero

	mov [.line], eax
	mov [.current_line], 0
	mov [.line_size], 0

	mov esi, [ebx+XWIDGET_TEXTBOX_TEXT]

.find_line_loop:
	lodsb
	cmp al, 10
	je .newline

	jmp .find_line_loop

.newline:
	inc [.current_line]
	mov eax, [.line]
	cmp eax, [.current_line]
	je .found_line

	jmp .find_line_loop

.zero:
	mov esi, [ebx+XWIDGET_TEXTBOX_TEXT]
	mov [.line_size], 0

.found_line:
	mov [.return], esi

.count_size_loop:
	lodsb
	cmp al, 0
	je .done

	cmp al, 10
	je .done

	inc [.line_size]
	jmp .count_size_loop

.done:
	mov esi, [.return]
	mov eax, [.line_size]
	ret


align 4
.line				dd 0
.current_line			dd 0
.line_size			dd 0
.return				dd 0

; xwidget_remove_focus:
; Removes focus from all textboxes in a window
; In\	EAX = Window handle
; Out\	Nothing
align 4
xwidget_remove_focus:
	push eax

	shl eax, 3
	add eax, xwidget_windows_data
	mov edi, [eax+4]	; components array
	mov [.components], edi

	add edi, 256*256
	mov [.components_end], edi

	mov esi, [.components]

.loop:
	cmp esi, [.components_end]
	jge .done

	cmp byte[esi], XWIDGET_CPNT_TEXTBOX
	jne .next

	and byte[esi+XWIDGET_TEXTBOX_FLAGS], not XWIDGET_TEXTBOX_FOCUSED

.next:
	add esi, 256
	jmp .loop

.done:
	pop eax
	call xwidget_redraw
	ret

align 4
.components			dd 0
.components_end			dd 0
	
; xwidget_remove_all_focus:
; Unfocuses all textboxes
; In\	EAX = Window handle
; Out\	Nothing

xwidget_remove_all_focus:
	shl eax, 3
	add eax, xwidget_windows_data
	mov edi, [eax+4]	; components array
	mov [.components], edi

	add edi, 256*256
	mov [.components_end], edi

	mov esi, [.components]

.loop:
	cmp esi, [.components_end]
	jge .finish

	cmp byte[esi], XWIDGET_CPNT_TEXTBOX
	jne .next

	test byte[esi+XWIDGET_TEXTBOX_FLAGS], XWIDGET_TEXTBOX_FOCUSED
	jnz .unfocus

.next:
	add esi, 256
	jmp .loop

.unfocus:
	and byte[esi+XWIDGET_TEXTBOX_FLAGS], not XWIDGET_TEXTBOX_FOCUSED

.finish:
	ret

align 4
.components			dd 0
.components_end			dd 0


