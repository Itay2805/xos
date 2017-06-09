
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

;
; struct window_handle {
; u16 flags;			// 0x00
; u16 event;			// 0x02
; u16 width;			// 0x04
; u16 height;			// 0x06
; u16 x;			// 0x08
; u16 y;			// 0x0A
; u32 framebuffer;		// 0x0C
; u32 reserved;			// 0x10
; u32 pid;			// 0x14
; u16 max_x;			// 0x18
; u16 max_y;			// 0x1A
; char title[65];		// 0x1C
; u8 padding[35];		// 0x5D
; };
;
;
; sizeof(window_handle) = 0x80;
;

; Structure of window handle
WINDOW_FLAGS			= 0x00
WINDOW_EVENT			= 0x02
WINDOW_WIDTH			= 0x04
WINDOW_HEIGHT			= 0x06
WINDOW_X			= 0x08
WINDOW_Y			= 0x0A
WINDOW_FRAMEBUFFER		= 0x0C
WINDOW_CONTROLS			= 0x10
WINDOW_PID			= 0x14
WINDOW_MAX_X			= 0x18
WINDOW_MAX_Y			= 0x1A
WINDOW_TITLE			= 0x1C
WINDOW_HANDLE_SIZE		= 0x80

; Window Flags
WM_PRESENT			= 0x0001
WM_NO_FRAME			= 0x0002
WM_TRANSPARENT			= 0x0004

; Window Transparent Color
WINDOW_TRANSPARENT_COLOR	= 0xFFFFFFFF	; -1

; Window Events
WM_LEFT_CLICK			= 0x0001
WM_RIGHT_CLICK			= 0x0002
WM_KEYPRESS			= 0x0004
WM_CLOSE			= 0x0008
WM_GOT_FOCUS			= 0x0010
WM_LOST_FOCUS			= 0x0020
WM_DRAG				= 0x0040

MAXIMUM_WINDOWS			= 512

align 4
open_windows			dd 0
active_window			dd -1
old_active_window		dd -1
window_handles			dd 0
wm_background			dd 0
wm_running			db 0
;wm_dirty			db 1	; when set to 1, the WM needs a redraw

; Default Window Theme
include				"kernel/gui/themes/default.asm"

default_wallpaper		db "wp1.bmp",0	; file to use as wallpaper

align 8
wm_wallpaper			dd 0		; pointer to raw pixel buffer
wm_wallpaper_size		dd 0		; size of raw pixel buffer
wm_wallpaper_width		dw 0
wm_wallpaper_height		dw 0

; wm_init:
; Initializes the window manager

wm_init:
	mov esi, .msg
	call kprint

	cli		; sensitive area of code!

	; allocate memory for window handles
	mov ecx, WINDOW_HANDLE_SIZE*MAXIMUM_WINDOWS
	call kmalloc
	mov [window_handles], eax

	; place mouse in middle of screen
	mov eax, [screen.width]
	mov ebx, [screen.height]
	shr eax, 1
	shr ebx, 1
	mov [mouse_x], eax
	mov [mouse_y], ebx
	call show_mouse

	mov [wm_running], 1
	sti
	call wm_redraw

	; open the wallpaper with read access
	mov esi, default_wallpaper
	mov edx, FILE_READ
	call vfs_open

	cmp eax, -1
	je .no_wallpaper
	mov [.file_handle], eax

	; get file size
	mov eax, [.file_handle]
	mov ebx, SEEK_END
	mov ecx, 0
	call vfs_seek
	cmp eax, 0
	jne .no_wallpaper

	mov eax, [.file_handle]
	call vfs_tell
	cmp eax, 0		; empty file?
	je .no_wallpaper

	mov [.wp_size], eax

	; back to the beginning of the file
	mov eax, [.file_handle]
	mov ebx, SEEK_SET
	mov ecx, 0
	call vfs_seek
	cmp eax, 0
	jne .no_wallpaper

	; allocate memory and read the file
	mov ecx, [.wp_size]
	call kmalloc
	mov [.tmp_memory], eax

	; for now, fixed size is 800x600
	mov ecx, 800*600*4
	call kmalloc
	mov [wm_wallpaper], eax

	; read the file
	mov eax, [.file_handle]
	mov ecx, [.wp_size]
	mov edi, [.tmp_memory]
	call vfs_read
	cmp eax, [.wp_size]
	jne .no_wallpaper

	mov eax, [.file_handle]
	call vfs_close

	mov edx, [.tmp_memory]
	mov ebx, [wm_wallpaper]
	call decode_bmp
	cmp ecx, -1
	je .no_wallpaper

	mov [wm_wallpaper_size], ecx
	mov [wm_wallpaper_width], si
	mov [wm_wallpaper_height], di

	mov eax, [.tmp_memory]
	call kfree

	mov esi, [screen.width]
	cmp [wm_wallpaper_width], si
	jne .resize

	mov esi, [screen.height]
	cmp [wm_wallpaper_height], si
	jne .resize

.finish:
	;mov [wm_dirty], 1
	call wm_redraw
	ret

.resize:
	mov edx, [wm_wallpaper]
	mov ax, [wm_wallpaper_width]
	mov bx, [wm_wallpaper_height]
	mov esi, [screen.width]
	mov edi, [screen.height]
	call stretch_buffer
	mov [wm_wallpaper], eax

	mov esi, [screen.width]
	mov edi, [screen.height]

	mov [wm_wallpaper_width], si
	mov [wm_wallpaper_height], di
	ret

.no_wallpaper:
	mov esi, .no_wp
	call kprint

	mov [wm_wallpaper], 0
	ret

.msg			db "Start windowing system...",10,0
.no_wp			db "Unable to use wallpaper; using solid color background.",10,0
.file_handle		dd 0
.wp_size		dd 0
.tmp_memory		dd 0

; wm_find_handle:
; Finds a free window handle
; In\	Nothing
; Out\	EAX = Window handle, -1 on error

wm_find_handle:
	cmp [open_windows], MAXIMUM_WINDOWS
	jge .no

	mov [.handle], 0

.loop:
	mov eax, [.handle]
	;mov ebx, WINDOW_HANDLE_SIZE
	;mul ebx
	shl eax, 7
	add eax, [window_handles]

	test word[eax], WM_PRESENT
	jz .found

	inc [.handle]
	cmp [.handle], MAXIMUM_WINDOWS
	jge .no
	jmp .loop

.found:
	mov edi, eax
	xor al, al
	mov ecx, WINDOW_HANDLE_SIZE
	rep stosb

	mov eax, [.handle]
	ret

.no:
	mov eax, -1
	ret

align 4
.handle			dd 0

; wm_get_window:
; Returns information of a window handle
; In\	EAX = Window handle
; Out\	EFLAGS.CF = 0 if present
; Out\	AX/BX = X/Y pos
; Out\	SI/DI = Width/Height
; Out\	DX = Flags
; Out\	ECX = Framebuffer
; Out\	EBP = Title text
align 32
wm_get_window:
	cmp eax, MAXIMUM_WINDOWS
	jge .no

	;mov ebx, WINDOW_HANDLE_SIZE
	;mul ebx
	shl eax, 7
	add eax, [window_handles]
	test word[eax], WM_PRESENT
	jz .no

	mov bx, [eax+WINDOW_Y]
	mov si, [eax+WINDOW_WIDTH]
	mov di, [eax+WINDOW_HEIGHT]
	mov dx, [eax+WINDOW_FLAGS]
	mov ecx, [eax+WINDOW_FRAMEBUFFER]
	mov ebp, eax
	add ebp, WINDOW_TITLE
	mov ax, [eax+WINDOW_X]

	clc
	ret

.no:
	stc
	ret

; wm_make_handle:
; Creates a window handle
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	DX = Flags
; In\	ECX = Window handle
; In\	EBP = Framebuffer address
; Out\	Nothing

wm_make_handle:
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.flags], dx
	mov [.framebuffer], ebp

	mov eax, ecx		; eax = window handle
	;mov ebx, WINDOW_HANDLE_SIZE
	;mul ebx
	shl eax, 7
	add eax, [window_handles]

	mov edx, [.framebuffer]
	mov [eax+WINDOW_FRAMEBUFFER], edx

	movzx edx, [current_task]	; pid of the running process
	mov [eax+WINDOW_PID], edx

	mov dx, [.flags]
	or dx, WM_PRESENT
	mov [eax], dx

	mov dx, [.x]
	mov [eax+WINDOW_X], dx

	mov dx, [.y]
	mov [eax+WINDOW_Y], dx

	mov dx, [.width]
	mov [eax+WINDOW_WIDTH], dx

	mov dx, [.height]
	mov [eax+WINDOW_HEIGHT], dx

	test [.flags], WM_TRANSPARENT	; transparent windows can't be moved
	jnz .finish

	test [.flags], WM_NO_FRAME	; same for frameless windows
	jnz .finish

	mov edx, [screen.width]
	sub dx, [.width]
	sub dx, [window_border_x_min]
	mov [eax+WINDOW_MAX_X], dx

	mov edx, [screen.height]
	sub dx, [.height]
	sub dx, [window_border_y_min]
	mov [eax+WINDOW_MAX_Y], dx

.finish:
	ret

align 2
.x			dw 0
.y			dw 0
.width			dw 0
.height			dw 0
.flags			dw 0
align 4
.framebuffer		dd 0

; wm_create_window:
; Creates a window
; In\	AX/BX = X/Y pos
; In\	SI/DI = Width/Height
; In\	DX = Flags
; In\	ECX = Title text
; Out\	EAX = Window handle, -1 on error
align 32
wm_create_window:
	cli		; sensitive area of code

	cmp [open_windows], MAXIMUM_WINDOWS
	jge .no

	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.flags], dx
	mov [.title], ecx

	; find a free window handle
	call wm_find_handle
	cmp eax, -1
	je .no
	mov [.handle], eax

	; allocate a window canvas
	movzx eax, [.width]
	movzx ebx, [.height]
	mul ebx
	shl eax, 2		; mul 4
	mov ecx, eax
	call malloc

	cmp eax, 0
	je .no

	mov [.framebuffer], eax

	; clear the framebuffer
	movzx eax, [.width]
	movzx ebx, [.height]
	mul ebx
	mov ecx, eax
	mov edi, [.framebuffer]

	; if the window is transparent, clear it with the transparent color
	test [.flags], WM_TRANSPARENT
	jnz .transparent

.normal:
	mov eax, [window_background]
	jmp .clear

.transparent:
	mov eax, WINDOW_TRANSPARENT_COLOR

.clear:
	rep stosd

	; create the window handle
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	mov dx, [.flags]
	or dx, WM_PRESENT
	mov ecx, [.handle]
	mov ebp, [.framebuffer]
	call wm_make_handle

	cmp [.title], 0
	je .done

	mov eax, [.handle]
	;mov ebx, WINDOW_HANDLE_SIZE
	;mul ebx
	shl eax, 7
	add eax, [window_handles]
	add eax, WINDOW_TITLE
	mov edi, eax
	mov esi, [.title]
	mov ecx, 64
	rep movsb

.done:
	mov eax, [.handle]
	mov [active_window], eax	; by default, when a new window is created, the focus goes to it
	inc [open_windows]

	;mov [wm_dirty], 1
	call wm_redraw

	mov eax, [.handle]	; return the window handle to the application
	ret

.no:
	mov eax, -1
	ret

align 2
.x			dw 0
.y			dw 0
.width			dw 0
.height			dw 0
.flags			dw 0
align 4
.handle			dd 0
.framebuffer		dd 0
.title			dd 0

; wm_detect_window:
; Detects which window the mouse is on
; In\	Nothing
; Out\	EAX = Window handle, -1 on error
align 32
wm_detect_window:
	cmp [open_windows], 0
	je .no

	mov [.handle], MAXIMUM_WINDOWS-1

.loop:
	cmp [.handle], -1
	je .no

	mov eax, [.handle]
	call wm_get_window
	jc .next

	mov [.x], ax
	mov [.y], bx
	add si, ax
	add di, bx

	test dx, WM_NO_FRAME
	jnz .start

	test dx, WM_TRANSPARENT
	jnz .start

.border:
	add si, [window_border_x_min]
	add di, [window_border_y_min]

.start:
	mov [.max_x], si
	mov [.max_y], di

	mov eax, [mouse_x]
	mov ebx, [mouse_y]

	cmp ax, [.x]
	jl .next
	cmp ax, [.max_x]
	jg .next

	cmp bx, [.y]
	jl .next
	cmp bx, [.max_y]
	jg .next

	; return the window handle
	mov eax, [.handle]
	ret

.next:
	dec [.handle]
	jmp .loop

.no:
	mov eax, -1
	ret

align 4
.handle			dd 0
.x			dw 0
.y			dw 0
.max_x			dw 0
.max_y			dw 0

; wm_is_mouse_on_window:
; Checks if the mouse is on the surface of a window
; In\	EAX = Window handle
; Out\	EAX = 1 if mouse is on surface of window
align 32
wm_is_mouse_on_window:
	call wm_get_window
	jc .no

	mov [.x], ax
	mov [.y], bx
	add si, ax
	add di, bx

	test dx, WM_NO_FRAME
	jnz .start

	test dx, WM_TRANSPARENT
	jnz .start

.border:
	add si, [window_border_x_min]
	add di, [window_border_y_min]

.start:
	mov [.max_x], si
	mov [.max_y], di

	mov eax, [mouse_x]
	mov ebx, [mouse_y]

	cmp ax, [.x]
	jl .no
	cmp ax, [.max_x]
	jg .no

	cmp bx, [.y]
	jl .no
	cmp bx, [.max_y]
	jg .no

	mov eax, 1
	ret

.no:
	xor eax, eax	; mov eax, 0
	ret

align 2
.x			dw 0
.y			dw 0
.max_x			dw 0
.max_y			dw 0

; wm_redraw:
; Redraws all windows
align 32
wm_redraw:
	cli

	;cmp [wm_dirty], 1
	;jne .done

	; lock the screen to improve performance!
	call use_back_buffer
	call lock_screen

	cmp [wm_wallpaper], 0
	je .clear_screen

	mov ax, 0
	mov bx, 0
	mov si, [wm_wallpaper_width]
	mov di, [wm_wallpaper_height]
	mov edx, [wm_wallpaper]
	call blit_buffer_no_transparent

	jmp .start_windows

.clear_screen:
	mov ebx, [wm_color]
	call clear_screen

.start_windows:
	; now move on to the windows
	xor eax, eax
	mov [.handle], eax
	cmp [open_windows], eax
	je .done

	;mov ebx, 0
	mov ecx, [window_inactive_title]
	call set_text_color

.loop:
	cmp [.handle], MAXIMUM_WINDOWS
	jge .do_active_window

	mov eax, [active_window]
	cmp [.handle], eax
	je .next

	mov eax, [.handle]
	call wm_get_window
	jc .next
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.framebuffer], ecx
	mov [.title], ebp

	test dx, WM_NO_FRAME
	jnz .no_frame

	test dx, WM_TRANSPARENT
	jnz .transparent

	; draw the window border
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]

	cmp [window_full_border_height], 0
	je .unfocused_unfull_border

	mov di, [.height]
	jmp .unfocused_draw

.unfocused_unfull_border:
	mov di, 0

.unfocused_draw:
	add si, [window_border_x_min]
	add di, [window_border_y_min]
	mov edx, [window_border]
	mov cl, [window_opacity]
	call alpha_fill_rect

	; the close button
	mov ax, [.x]
	mov bx, [.y]
	add ax, [window_close_x]
	add bx, [window_close_y]
	mov si, [window_close_width]
	mov di, [window_close_height]
	mov edx, [window_close_color]
	call fill_rect

	; the window title
	mov esi, [.title]
	call strlen

	mov cx, [.x]
	mov dx, cx
	add dx, [.width]
	add dx, [window_border_x_min]
	add cx, dx
	shr cx, 1

	shl ax, 2			; mul 4
	sub cx, ax

	mov dx, [.y]
	;add cx, [window_title_x]
	add dx, [window_title_y]
	call print_string_transparent

	; the window frame buffer
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	add ax, [window_canvas_x]
	add bx, [window_canvas_y]
	mov edx, [.framebuffer]
	mov ecx, WINDOW_TRANSPARENT_COLOR
	call blit_buffer

.next:
	inc [.handle]
	jmp .loop

.do_active_window:
	cmp [active_window], -1
	je .done

	mov ecx, [window_title]
	call set_text_color

	mov eax, [active_window]
	call wm_get_window
	jc .done
	mov [.x], ax
	mov [.y], bx
	mov [.width], si
	mov [.height], di
	mov [.framebuffer], ecx
	mov [.title], ebp

	test dx, WM_NO_FRAME
	jnz .focused_no_frame

	test dx, WM_TRANSPARENT
	jnz .focused_transparent

	; draw the window border
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]

	cmp [window_full_border_height], 0
	je .focused_unfull_border

	mov di, [.height]
	jmp .focused_draw

.focused_unfull_border:
	mov di, 0

.focused_draw:
	add si, [window_border_x_min]
	add di, [window_border_y_min]
	mov edx, [window_active_border]
	mov cl, [window_opacity]
	call alpha_fill_rect

	cmp [window_active_outline], -1
	je .skip_outline

	; and the outline
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, 2
	add si, [window_border_x_min]
	mov edx, [window_active_outline]
	call fill_rect

.skip_outline:
	; the close button
	mov ax, [.x]
	mov bx, [.y]
	add ax, [window_close_x]
	add bx, [window_close_y]
	mov si, [window_close_width]
	mov di, [window_close_height]
	mov edx, [window_close_color]
	call fill_rect

	; the window title
	mov esi, [.title]
	call strlen

	mov cx, [.x]
	mov dx, cx
	add dx, [.width]
	add dx, [window_border_x_min]
	add cx, dx
	shr cx, 1

	shl ax, 2			; mul 4
	sub cx, ax

	mov dx, [.y]
	;add cx, [window_title_x]
	add dx, [window_title_y]
	call print_string_transparent

	; the window frame buffer
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	add ax, [window_canvas_x]
	add bx, [window_canvas_y]
	mov edx, [.framebuffer]
	mov ecx, WINDOW_TRANSPARENT_COLOR
	call blit_buffer

.done:
	;mov [wm_dirty], 0
	call redraw_mouse.redraw	; this takes care of all the dirty work before actually drawing the cursor ;)
	ret

.focused_transparent:
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	mov edx, [window_border]
	mov cl, 1
	call alpha_fill_rect

	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	mov ecx, WINDOW_TRANSPARENT_COLOR
	mov edx, [.framebuffer]
	call blit_buffer
	jmp .done

.focused_no_frame:
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	mov edx, [.framebuffer]
	call blit_buffer_no_transparent
	jmp .done

.transparent:
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	mov edx, [window_border]
	mov cl, 1
	call alpha_fill_rect

	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	mov ecx, WINDOW_TRANSPARENT_COLOR
	mov edx, [.framebuffer]
	call blit_buffer

	jmp .next

.no_frame:
	mov ax, [.x]
	mov bx, [.y]
	mov si, [.width]
	mov di, [.height]
	mov edx, [.framebuffer]
	call blit_buffer_no_transparent

	jmp .next

align 4
.handle			dd 0
align 2
.x			dw 0
.y			dw 0
.width			dw 0
.height			dw 0
align 4
.framebuffer		dd 0
.title			dd 0

; wm_mouse_event:
; WM Mouse Event Handler
align 32
wm_mouse_event:
	;cli		; sensitive area!

	cmp [wm_running], 0
	je .no_wm

	;test [mouse_data], MOUSE_LEFT_BTN	; left click event
	;jz .done

	; now we know the user has his finger on the left button
	; is he clicking or dragging?
	test [mouse_old_data], MOUSE_LEFT_BTN
	jnz .drag

.click:
	; now we know the user just clicked on something
	; if he clicked on the active window, send the window a click event
	; if not, then give the window focus and send it a click event too
	; if the user did not click on a window, ignore the event
	mov eax, [active_window]
	cmp eax, MAXIMUM_WINDOWS
	jge .set_focus

	call wm_is_mouse_on_window
	cmp eax, 0
	je .set_focus

	; send the window a click event ONLY if the mouse is not on the title bar
	; otherwise we page fault in usermode! ;)
	mov eax, [active_window]
	shl eax, 7
	add eax, [window_handles]

	; check if the window has a title bar at all
	test word[eax+WINDOW_FLAGS], WM_NO_FRAME
	jnz .frameless

	test word[eax+WINDOW_FLAGS], WM_TRANSPARENT
	jnz .frameless

	mov ecx, [mouse_y]
	mov dx, [eax+WINDOW_Y]
	;add dx, [window_border_y_min]
	add dx, [window_canvas_y]

	cmp cx, dx
	jl .check_exit

	mov dx, [eax+WINDOW_Y]
	add dx, [eax+WINDOW_HEIGHT]
	add dx, [window_border_y_min]
	cmp cx, dx
	jg .done

	; x pos too
	mov ecx, [mouse_x]
	mov dx, [eax+WINDOW_X]
	add dx, [window_canvas_x]

	cmp cx, dx
	jl .done

	mov dx, [eax+WINDOW_X]
	add dx, [eax+WINDOW_WIDTH]
	add dx, [window_border_x_min]
	cmp cx, dx
	jg .done

	or word[eax+WINDOW_EVENT], WM_LEFT_CLICK
	;mov [wm_dirty], 1

	jmp .done

.frameless:
	; ensure the window has been clicked
	mov edx, [mouse_x]
	cmp dx, [eax+WINDOW_X]
	jl .done

	mov dx, [eax+WINDOW_X]
	add dx, [eax+WINDOW_WIDTH]
	and edx, 0xFFFF
	cmp edx, [mouse_x]
	jl .done

	mov edx, [mouse_y]
	cmp dx, [eax+WINDOW_Y]
	jl .done

	mov dx, [eax+WINDOW_Y]
	add dx, [eax+WINDOW_HEIGHT]
	and edx, 0xFFFF
	cmp edx, [mouse_y]
	jl .done

	; send a click event
	or word[eax+WINDOW_EVENT], WM_LEFT_CLICK
	jmp .done

.check_exit:
	mov ecx, [mouse_x]
	mov edx, [mouse_y]
	sub ecx, [eax+WINDOW_X]
	sub edx, [eax+WINDOW_Y]

	cmp cx, [window_close_x]
	jl .done

	cmp dx, [window_close_y]
	jl .done

	mov bx, [window_close_x]
	add bx, [window_close_width]

	cmp cx, bx
	jg .done

	mov bx, [window_close_y]
	add bx, [window_close_height]

	cmp dx, bx
	jg .done

	; here the user has clicked on the close button
	; send the window a close event
	mov eax, [active_window]
	shl eax, 7
	add eax, [window_handles]
	or word[eax+WINDOW_EVENT], WM_CLOSE
	jmp .done

.set_focus:
	mov eax, [active_window]
	mov [old_active_window], eax

	call wm_detect_window
	mov [active_window], eax

	cmp eax, -1
	je .no_focus

	shl eax, 7
	add eax, [window_handles]
	or word[eax+WINDOW_EVENT], WM_GOT_FOCUS

	cmp [old_active_window], -1
	je .click

	mov eax, [old_active_window]
	shl eax, 7
	add eax, [window_handles]
	or word[eax+WINDOW_EVENT], WM_LOST_FOCUS

	;jmp .done
	jmp .click

.no_focus:
	cmp [old_active_window], -1
	je .done

	mov eax, [old_active_window]
	shl eax, 7
	add eax, [window_handles]
	or word[eax+WINDOW_EVENT], WM_LOST_FOCUS
	jmp .done

.drag:
	;mov [wm_dirty], 1

	; if the user dragged something --
	; -- we'll need to know if a window has been dragged --
	; -- because we'll need to move the window to follow the mouse ;)
	cmp [active_window], MAXIMUM_WINDOWS
	jge .done

	mov esi, [active_window]
	shl esi, 7	; mul 128
	add esi, [window_handles]

	; frameless windows and transparent windows cannot be dragged like this
	test word[esi+WINDOW_FLAGS], WM_NO_FRAME
	jnz .done

	test word[esi+WINDOW_FLAGS], WM_TRANSPARENT
	jnz .done

	; make sure the mouse is actually on the window title bar
	mov ecx, [mouse_old_y]
	mov dx, [esi+WINDOW_Y]
	cmp cx, dx
	jl .done

	add dx, [window_canvas_y]
	cmp cx, dx
	;jg .done
	jg .drag_canvas

	mov ecx, [mouse_old_x]
	mov dx, [esi+WINDOW_X]
	cmp cx, dx
	jl .done

	add dx, [window_border_x_min]
	add dx, [esi+WINDOW_WIDTH]
	cmp cx, dx
	jg .done

	mov ecx, [mouse_old_x]
	mov edx, [mouse_old_y]
	mov eax, [mouse_x]
	mov ebx, [mouse_y]

.do_x:
	sub ax, cx
	js .x_negative

	add [esi+WINDOW_X], ax
	mov ax, [esi+WINDOW_MAX_X]
	cmp [esi+WINDOW_X], ax
	jg .x_max

	jmp .do_y

.x_max:
	mov ax, [esi+WINDOW_MAX_X]
	mov [esi+WINDOW_X], ax
	jmp .do_y

.x_negative:
	not ax
	inc ax
	sub [esi+WINDOW_X], ax
	js .x_zero
	jmp .do_y

.x_zero:
	mov word[esi+WINDOW_X], 0

.do_y:
	sub bx, dx
	js .y_negative

	add [esi+WINDOW_Y], bx
	mov bx, [esi+WINDOW_MAX_Y]
	cmp [esi+WINDOW_Y], bx
	jg .y_max
	jmp .done

.y_max:
	mov bx, [esi+WINDOW_MAX_Y]
	mov [esi+WINDOW_Y], bx
	jmp .done

.y_negative:
	not bx
	inc bx
	sub [esi+WINDOW_Y], bx
	js .y_zero

	jmp .done

.y_zero:
	mov word[esi+WINDOW_Y], 0
	jmp .done

.drag_canvas:
	mov eax, [active_window]
	cmp eax, -1
	je .done

	shl eax, 7
	add eax, [window_handles]
	test word[eax+WINDOW_FLAGS], WM_PRESENT
	jz .done

	or word[eax+WINDOW_EVENT], WM_DRAG

.done:
	call wm_redraw
	ret

.no_wm:
	call redraw_mouse
	ret

align 8
.handle			dd 0

; wm_kbd_event:
; WM Keyboard Event Handler
align 32
wm_kbd_event:
	cmp [wm_running], 0
	je .quit

	; simply send a keypress event to the focused window
	cmp [open_windows], 0
	je .quit

	cmp [active_window], -1
	je .quit

	mov eax, [active_window]
	shl eax, 7		; mul 128
	add eax, [window_handles]

	or word[eax+WINDOW_EVENT], WM_KEYPRESS

.quit:
	ret

; wm_read_event:
; Reads the WM event
; In\	EAX = Window handle
; Out\	AX = Bitfield of WM event data; I'll document this somewhere
align 32
wm_read_event:
	cmp eax, MAXIMUM_WINDOWS
	jge .no

	shl eax, 7
	add eax, [window_handles]
	test word[eax], WM_PRESENT	; is the window present?
	jz .no

	mov edi, eax
	mov ax, [edi+WINDOW_EVENT]	; return the event data
	mov word[edi+WINDOW_EVENT], 0
	ret

.no:
	xor ax, ax
	ret

; wm_kill:
; Kills a window
; In\	EAX = Window handle
; Out\	Nothing

wm_kill:
	cli

	cmp [active_window], eax
	je .clear_active

	jmp .work

.clear_active:
	mov [active_window], -1

.work:
	shl eax, 7
	add eax, [window_handles]
	test word[eax], WM_PRESENT
	jz .no

	push eax
	mov eax, [eax+WINDOW_FRAMEBUFFER]
	call free		; free the framebuffer memory

	pop edi
	mov eax, 0
	mov ecx, WINDOW_HANDLE_SIZE
	rep stosb

	dec [open_windows]

.no:
	call wm_redraw
	ret

; wm_kill_all:
; Kills all windows

wm_kill_all:
	mov [.handle], 0

.loop:
	cmp [.handle], MAXIMUM_WINDOWS
	jge .done

	mov eax, [.handle]
	call wm_kill

	inc [.handle]
	jmp .loop

.done:
	ret

align 4
.handle				dd 0

; wm_close_active_window:
; Sends the focused window a close event - used by keyboard event Alt+F4

wm_close_active_window:
	cmp [active_window], -1
	je .quit

	mov eax, [active_window]
	shl eax, 7
	add eax, [window_handles]
	test word[eax], WM_PRESENT
	jz .quit

	or word[eax+WINDOW_EVENT], WM_CLOSE	; send a close event..

.quit:
	ret






