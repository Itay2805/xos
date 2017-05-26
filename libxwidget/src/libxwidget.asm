
;; xOS -- libxwidget 1
;; Copyright (c) 2017 by Omar Mohammad.

use32

	; Change These Variables To Suit Yourself
	align 4
	xwidget_window_color	dd 0x383838
	xwidget_button_border	dd 0x505060
	xwidget_button_bg	dd 0x202020
	xwidget_button_fg	dd 0xD8D8D8
	xwidget_textbox_bg	dd 0xFFFFFF
	xwidget_textbox_fg	dd 0x000000
	xwidget_outline_focus	dd 0x00A2E8
	xwidget_outline		dd 0x004860

	XWIDGET_MAX_WINDOWS	= 8	; for now

	; Window Event Bitfield from the Kernel
	WM_LEFT_CLICK		= 0x0001
	WM_RIGHT_CLICK		= 0x0002
	WM_KEYPRESS		= 0x0004
	WM_CLOSE		= 0x0008
	WM_GOT_FOCUS		= 0x0010
	WM_LOST_FOCUS		= 0x0020

	; Window Flags
	WM_NO_FRAME		= 0x0002
	WM_TRANSPARENT		= 0x0004

	XWIDGET_BUTTON		= 0x0001	; button click event
	XWIDGET_CLOSE		= 0x0002	; close event
	XWIDGET_LOST_FOCUS	= 0x0004

	xwidget_version		db "libxwidget 1",0

	include			"libxwidget/src/xos.asm"	; api functions
	include			"libxwidget/src/canvas.asm"	; window canvas functions
	include			"libxwidget/src/component.asm"	; components
	include			"libxwidget/src/button.asm"	; button component
	include			"libxwidget/src/label.asm"	; label component
	include			"libxwidget/src/textbox.asm"	; textbox component
	include			"libxwidget/src/gbutton.asm"	; gbutton component

	; typedef struct window_data_t
	; {
	;	u32 window_handle;
	;	component_t* components;	// 256 components
	; } window_data_t;
	;
	; typedef struct component_t
	; {
	;	u8 id;			// defines the component type, one of the values in component.asm
	;	u8 properties[255];	// component-specific data
	; } component_t;
	align 4
	xwidget_windows_count	dd 0
	xwidget_windows_data:	times XWIDGET_MAX_WINDOWS dq 0

; xwidget_init:
; Must be called upon starting the application, before creating any window
align 4
xwidget_init:
	; someday, this function will do stuff...
	ret

; xwidget_destroy:
; Must be called upon exiting the application
align 4
xwidget_destroy:
	; someday, this function will undo anything done in xwidget_init..
	ret

; xwidget_get_version:
; Returns the version string
; In\	Nothing
; Out\	EAX = Pointer to version string
align 4
xwidget_get_version:
	mov eax, xwidget_version
	ret

; xwidget_create_window:
; Creates a window
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	DX = Flags
; In\	ECX = Pointer to title text
; Out\	EAX = xwidget session-specific window handle, -1 on error
; Out\	EBX = Global window handle, -1 on error
align 4
xwidget_create_window:
	cmp [xwidget_windows_count], XWIDGET_MAX_WINDOWS
	jge .no

	; tell the kernel to make a window
	mov ebp, XOS_WM_CREATE_WINDOW
	int 0x60
	cmp eax, -1
	je .no

	push eax

	; save the window data
	mov edi, [xwidget_windows_count]
	shl edi, 3	; mul 8
	add edi, xwidget_windows_data
	mov [edi], eax		; store the window handle

	push edi

	; allocate memory for the components array
	mov ebp, XOS_MALLOC
	mov ecx, 256*256
	int 0x60

	pop edi

	mov [edi+4], eax	; store the window components array
	mov [.component], eax

	mov edi, [.component]
	mov byte[edi], XWIDGET_CPNT_WINDOW
	mov eax, [xwidget_window_color]
	mov dword[edi+1], eax

	inc [xwidget_windows_count]
	pop ebx			; return the window handle
	mov eax, [xwidget_windows_count]
	dec eax

	ret

.no:
	mov eax, -1
	mov ebx, eax
	ret

.component		dd 0

; xwidget_kill_window:
; Kills a window
; In\	EAX = Window handle
; Out\	Nothing
align 4
xwidget_kill_window:
	cmp eax, XWIDGET_MAX_WINDOWS
	jge .done

	mov edi, eax
	shl edi, 3
	add edi, xwidget_windows_data
	mov ebx, [edi]		; window handle
	mov [.handle], ebx

	mov eax, [edi+4]	; components array

	mov dword[edi], 0
	mov dword[edi+4], 0

	mov ebp, XOS_FREE
	int 0x60		; free the memory

	mov eax, [.handle]
	mov ebp, XOS_WM_KILL
	int 0x60

	dec [xwidget_windows_count]

.done:
	ret

.handle				dd 0

; xwidget_strlen:
; Gets the length of a string
; In\	ESI = String
; Out\	EAX = Length
align 4
xwidget_strlen:
	pusha

	xor ecx, ecx

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
.tmp		dd 0

; xwidget_wait_event:
; Waits for an event
; In\	Nothing
; Out\	EAX = Event type
; Out\	EBX = Component handle of event
align 4
xwidget_wait_event:

.start:
	; run through each of the open windows and check for events
	mov [.current_window], 0

.check_event_loop:
	mov eax, [.current_window]
	shl eax, 3
	add eax, xwidget_windows_data

	cmp dword[eax+4], 0	; components
	je .skip

	mov eax, [eax]			; window handle
	mov ebp, XOS_WM_READ_EVENT
	int 0x60

	test ax, WM_CLOSE
	jnz .close

	test ax, WM_LOST_FOCUS
	jnz .lost_focus

	test ax, WM_LEFT_CLICK
	jnz .clicked

	test ax, WM_KEYPRESS
	jnz .keypress

.skip:
	inc [.current_window]
	cmp [.current_window], XWIDGET_MAX_WINDOWS
	jge .yield

	jmp .check_event_loop

.yield:
	call xwidget_yield_handler
	mov ebp, XOS_YIELD	; cooperative multitasking -- give control to next task
	int 0x60
	jmp .start		; when control comes back to us, continue waiting for event

.close:
	mov eax, XWIDGET_CLOSE
	mov ebx, [.current_window]
	ret

.clicked:
	; read the mouse x/y pos
	mov ebp, XOS_WM_READ_MOUSE
	mov eax, [.current_window]
	shl eax, 3
	add eax, xwidget_windows_data
	mov eax, [eax]		; window handle
	int 0x60

	mov [.x], cx
	mov [.y], dx

	; check which component was pressed
	mov eax, [.current_window]
	shl eax, 3
	add eax, xwidget_windows_data

	mov ebx, [eax+4]
	mov [.components], ebx

	add ebx, 256*256
	mov [.components_end], ebx

	mov esi, [.components]

.clicked_loop:
	cmp esi, [.components_end]
	jge .start

	cmp byte[esi], XWIDGET_CPNT_BUTTON
	je .clicked_button

	cmp byte[esi], XWIDGET_CPNT_GBUTTON
	je .clicked_gbutton

	cmp byte[esi], XWIDGET_CPNT_TEXTBOX	; textboxes can be clicked to "get focused"
	je .clicked_textbox

	add esi, 256
	jmp .clicked_loop

.clicked_button:
	mov [.tmp], esi

	mov cx, [esi+5]
	mov [.button_x], cx
	mov cx, [esi+7]
	mov [.button_y], cx
	add cx, 32
	mov [.button_end_y], cx

	mov esi, [esi+1]
	call xwidget_strlen
	shl eax, 3	; mul 8
	add eax, 32
	add ax, [.button_x]
	mov [.button_end_x], ax

	mov cx, [.x]
	mov dx, [.y]
	cmp cx, [.button_x]
	jl .clicked_continue

	cmp dx, [.button_y]
	jl .clicked_continue

	cmp cx, [.button_end_x]
	jg .clicked_continue

	cmp dx, [.button_end_y]
	jg .clicked_continue

	mov eax, [.current_window]
	call xwidget_remove_focus

	mov eax, XWIDGET_BUTTON
	mov ebx, [.tmp]
	ret

.clicked_gbutton:
	mov [.tmp], esi

	mov cx, [.x]	; mouse pos
	mov dx, [.y]

	cmp cx, [esi+GBUTTON_X]
	jl .clicked_continue

	cmp dx, [esi+GBUTTON_Y]
	jl .clicked_continue

	cmp cx, [esi+GBUTTON_END_X]
	jg .clicked_continue

	cmp dx, [esi+GBUTTON_END_Y]
	jg .clicked_continue

	mov eax, [.current_window]
	call xwidget_remove_focus

	mov eax, XWIDGET_BUTTON
	mov ebx, [.tmp]
	ret

.clicked_textbox:
	mov [.tmp], esi

	mov cx, [.x]	; mouse pos
	mov dx, [.y]

	cmp cx, [esi+XWIDGET_TEXTBOX_X]
	jl .clicked_continue

	cmp dx, [esi+XWIDGET_TEXTBOX_Y]
	jl .clicked_continue

	mov ax, [esi+XWIDGET_TEXTBOX_WIDTH]
	add ax, [esi+XWIDGET_TEXTBOX_X]

	mov bx, [esi+XWIDGET_TEXTBOX_HEIGHT]
	add bx, [esi+XWIDGET_TEXTBOX_Y]

	cmp cx, ax
	jg .clicked_continue

	cmp dx, bx
	jg .clicked_continue

	; give the textbox focus
	or byte[esi+XWIDGET_TEXTBOX_FLAGS], XWIDGET_TEXTBOX_FOCUSED

	mov eax, [.current_window]
	call xwidget_redraw	; redraw to "show" the focus

	jmp .clicked_continue

.clicked_continue:
	mov esi, [.tmp]
	add esi, 256
	jmp .clicked_loop

.lost_focus:
	mov eax, [.current_window]
	call xwidget_remove_focus

	mov eax, XWIDGET_LOST_FOCUS
	mov ebx, [.current_window]
	ret

.keypress:
	mov ebp, XOS_READ_KEY
	int 0x60

	; ah = scancode, al = character
	mov [.char], al

	mov eax, [.current_window]
	call xwidget_get_focused_textbox
	cmp eax, -1
	je .start

	mov [.textbox_handle], eax

	cmp [.char], 0		; unprintable character?
	je .start
	;je .textbox_check_arrows	; TO-DO!

	cmp [.char], 8		; backspace?
	je .textbox_backspace

	cmp [.char], 13		; enter?
	je .textbox_enter

	; before adding the character, ensure there is space
	mov eax, [.textbox_handle]
	mov esi, [eax+XWIDGET_TEXTBOX_TEXT]
	call xwidget_strlen

	mov esi, [.textbox_handle]
	cmp eax, [esi+XWIDGET_TEXTBOX_LIMIT]
	jge .start

	mov eax, [.textbox_handle]
	mov esi, [eax+XWIDGET_TEXTBOX_TEXT_POSITION]
	inc dword[eax+XWIDGET_TEXTBOX_TEXT_POSITION]

	add word[eax+XWIDGET_TEXTBOX_POSITION_X], 8

	mov al, [.char]
	call xwidget_insert_char

	mov eax, [.current_window]
	call xwidget_redraw
	jmp .start

.textbox_backspace:
	mov eax, [.textbox_handle]
	mov esi, [eax+XWIDGET_TEXTBOX_TEXT_POSITION]
	cmp esi, [eax+XWIDGET_TEXTBOX_TEXT]
	je .start

	dec esi
	dec dword[eax+XWIDGET_TEXTBOX_TEXT_POSITION]
	call xwidget_delete_char
	cmp al, 10	; did we delete a new line?
	je .textbox_deleted_newline

	mov eax, [.textbox_handle]
	sub word[eax+XWIDGET_TEXTBOX_POSITION_X], 8

	mov eax, [.current_window]
	call xwidget_redraw
	jmp .start

.textbox_deleted_newline:
	mov eax, [.textbox_handle]
	sub word[eax+XWIDGET_TEXTBOX_POSITION_Y], 16

	movzx eax, word[eax+XWIDGET_TEXTBOX_POSITION_Y]
	shr eax, 4	; div 16
	mov ebx, [.textbox_handle]
	call xwidget_get_textbox_line

	shl eax, 3	; mul 8

	mov edi, [.textbox_handle]
	mov word[edi+XWIDGET_TEXTBOX_POSITION_X], ax

	mov eax, [.current_window]
	call xwidget_redraw
	jmp .start

.textbox_enter:
	mov eax, [.textbox_handle]
	test byte[eax+XWIDGET_TEXTBOX_FLAGS], XWIDGET_TEXTBOX_MULTILINE	; are newlines allowed?
	jz .start

	mov esi, [eax+XWIDGET_TEXTBOX_TEXT_POSITION]
	inc dword[eax+XWIDGET_TEXTBOX_TEXT_POSITION]

	mov word[eax+XWIDGET_TEXTBOX_POSITION_X], 0
	add word[eax+XWIDGET_TEXTBOX_POSITION_Y], 16

	mov al, 10		; newline
	call xwidget_insert_char

	mov eax, [.current_window]
	call xwidget_redraw
	jmp .start

.textbox_tab:
	mov al, "	"
	call xwidget_insert_char

	;mov eax, [.textbox_handle]

	mov eax, [.current_window]
	call xwidget_redraw
	jmp .start

align 4
.current_window			dd 0
.components			dd 0
.components_end			dd 0
.tmp				dd 0
.textbox_handle			dd 0
.x				dw 0
.y				dw 0
.button_x			dw 0
.button_y			dw 0
.button_end_x			dw 0 
.button_end_y			dw 0
.char				db 0




