
;; xOS Shell
;; Copyright (c) 2017 by Omar Mohammad.

use32

MAX_MENU_ENTRIES	= 16

align 4
menu_entries		dd 0
menu_window_handle	dd 0
menu_height		dw 0

align 4
menu_entries_handles:	times MAX_MENU_ENTRIES dd -1
menu_shutdown_handle	dd 0

align 4
menu_color:
	.foreground	dd 0x000000
	.background	dd 0xb8b8b8

; open_menu:
; Opens the menu

open_menu:
	; do the configuration stuff
	mov esi, config_file
	mov edx, FILE_READ
	mov ebp, XOS_OPEN
	int 0x60

	cmp eax, -1
	je config_error

	mov [config_handle], eax

	mov ebp, XOS_MALLOC
	mov ecx, 1024	; much much more than enough
	int 0x60
	mov [config_buffer], eax

	; get config size
	mov ebp, XOS_SEEK
	mov eax, [config_handle]
	mov ebx, SEEK_END
	mov ecx, 0
	int 0x60

	cmp eax, 0
	jne config_error

	mov ebp, XOS_TELL
	mov eax, [config_handle]
	int 0x60

	cmp eax, -1
	je config_error

	cmp eax, 0
	je config_error

	mov [config_size], eax

	mov [config_end], eax
	mov eax, [config_buffer]
	add [config_end], eax

	mov ebp, XOS_SEEK
	mov eax, [config_handle]
	mov ebx, SEEK_SET
	mov ecx, 0
	int 0x60

	cmp eax, 0
	jne config_error

	; read the config
	mov ebp, XOS_READ
	mov eax, [config_handle]
	mov ecx, [config_size]
	mov edi, [config_buffer]
	int 0x60

	cmp eax, [config_size]		; did all bytes read successfully?
	jne config_error

	mov ebp, XOS_CLOSE		; close the file
	mov eax, [config_handle]
	int 0x60

	mov edi, menu_entries_handles
	mov eax, -1
	mov ecx, MAX_MENU_ENTRIES
	rep stosd

	mov [menu_entries], 1	; at least one entry for shutdown

	; first count the entries
	mov esi, [config_buffer]

.count_loop:
	cmp esi, [config_end]
	jge .counted

	lodsb
	cmp al, 10
	je .newline
	cmp al, 0
	je .counted

	jmp .count_loop

.newline:
	inc [menu_entries]
	jmp .count_loop

.counted:
	; make a window
	mov eax, [menu_entries]
	mov ebx, 36
	mul ebx
	add eax, 4
	mov [menu_height], ax

	mov ax, 0
	mov bx, [height]
	sub bx, 32
	sub bx, [menu_height]
	mov si, 128
	mov di, [menu_height]
	mov dx, WM_TRANSPARENT
	mov ecx, title
	call xwidget_create_window
	mov [menu_window_handle], eax

	; lock
	mov eax, [menu_window_handle]
	call xwidget_lock

	mov eax, [menu_window_handle]
	mov cx, 4
	mov dx, [menu_height]
	sub dx, 36
	mov esi, shutdown_text
	mov bx, 120
	mov di, 32
	mov ebp, menu_color
	call xwidget_create_gbutton
	mov [menu_shutdown_handle], eax

	; draw the menu
	mov esi, [config_buffer]
	mov ecx, [config_size]
	mov dl, 10
	mov dh, 0
	call replace_byte_in_string

	mov esi, [config_buffer]
	mov ecx, [config_size]
	mov dl, '='
	mov dh, 0
	call replace_byte_in_string

	mov [.current_entry], 0

.draw_loop:
	mov ecx, [.current_entry]
	mov edx, [menu_entries]
	sub edx, 2
	cmp ecx, edx
	jg .draw_finish

	mov ecx, [.current_entry]
	call draw_menu_entry
	inc [.current_entry]
	jmp .draw_loop

.draw_finish:
	; unlock
	mov eax, [menu_window_handle]
	call xwidget_unlock

.hang:
	call xwidget_wait_event

	cmp eax, XWIDGET_LOST_FOCUS	; close the menu if it lost focus --
	je .lost_focus			; -- i.e if the user clicked anything outside it

	cmp eax, XWIDGET_BUTTON
	jne .hang

	cmp ebx, [menu_shutdown_handle]
	je shutdown_dialog

	mov [.current_entry], 0

.check_entry_loop:
	mov ecx, [.current_entry]
	mov edx, [menu_entries]
	sub edx, 2
	cmp ecx, edx
	jg .hang

	mov edi, [.current_entry]
	shl edi, 2	; mul 4
	add edi, menu_entries_handles
	cmp ebx, [edi]
	je .clicked

	inc [.current_entry]
	jmp .check_entry_loop

.clicked:
	; start the application referenced by the item
	mov ecx, [.current_entry]
	call get_menu_entry

	mov dl, 0
	mov ecx, [config_size]
	call find_byte_in_string

	inc esi
	mov ebp, XOS_CREATE_TASK
	int 0x60

	jmp .destroy_menu

.lost_focus:
	cmp ebx, [menu_window_handle]
	jne .hang

.destroy_menu:
	mov eax, [menu_window_handle]
	call xwidget_kill_window

	mov ebp, XOS_FREE
	mov eax, [config_buffer]
	int 0x60
	jmp main.hang

align 4
.current_entry			dd 0

; get_menu_entry:
; Returns a pointer to beginning of menu entry
; In\	ECX = Entry number
; Out\	ESI = Pointer

get_menu_entry:
	mov [.number], ecx

	cmp ecx, 0
	je .first

	shl [.number], 1	; mul 2
	mov [.counter], 0

	mov esi, [config_buffer]
	mov [.ptr], esi

.loop:
	mov ecx, [.number]
	cmp [.counter], ecx
	je .done

	mov esi, [.ptr]
	mov dl, 0x00
	mov ecx, [config_size]
	call find_byte_in_string

	inc esi		; next char
	mov [.ptr], esi

	inc [.counter]
	jmp .loop

.done:
	mov esi, [.ptr]
	ret

.first:
	mov esi, [config_buffer]
	ret

align 4
.number				dd 0
.counter			dd 0
.ptr				dd 0

; draw_menu_entry:
; Draws a menu entry
; In\	ECX = Entry number
; Out\	Nothing

draw_menu_entry:
	mov [.entry], ecx

	call get_menu_entry
	mov [.text], esi

	; make a button for this entry
	mov eax, [.entry]
	mov ebx, 36
	mul ebx
	add ax, 4

	mov dx, ax
	mov cx, 4
	mov esi, [.text]
	mov eax, [menu_window_handle]
	mov bx, 120
	mov di, 32
	mov ebp, menu_color
	call xwidget_create_gbutton

	mov edi, [.entry]
	shl edi, 2	; mul 4
	add edi, menu_entries_handles
	mov [edi], eax

	ret

align 4
.entry				dd 0
.text				dd 0




