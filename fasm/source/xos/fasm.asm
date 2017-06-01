
; flat assembler interface for xOS

use32
org 0x8000000

application_header:
	.id			db "XOS1"	; tell the kernel we are a valid application
	.type			dd 0		; 32-bit application
	.entry			dd main		; entry point
	.reserved0		dq 0
	.reserved1		dq 0

	include			"libxwidget/src/libxwidget.asm"		; widget library ;)

	include			"fasm/source/xos/system.inc"
	include			"fasm/source/errors.inc"
	include			"fasm/source/symbdump.inc"
	include			"fasm/source/preproce.inc"
	include			"fasm/source/parser.inc"
	include			"fasm/source/exprpars.inc"
	include			"fasm/source/assemble.inc"
	include			"fasm/source/exprcalc.inc"
	include			"fasm/source/formats.inc"
	include			"fasm/source/x86_64.inc"
	include			"fasm/source/avx.inc"

	include			"fasm/source/tables.inc"
	include			"fasm/source/messages.inc"
	include			"fasm/source/variable.inc"
	include			"fasm/source/version.inc"

; main:
; Program entry point

main:
	call xwidget_init

	; create a window
	mov ax, 64
	mov bx, 64
	mov si, 256
	mov di, 208
	mov dx, 0
	mov ecx, title
	call xwidget_create_window

	mov [window_handle], eax

	; interface
	mov eax, [window_handle]
	call xwidget_lock

	mov eax, [window_handle]
	mov cx, 4
	mov dx, 4
	mov esi, input_text
	mov ebx, 0xFFFFFF
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 4
	mov dx, 4+20
	mov esi, output_text
	mov ebx, 0xFFFFFF
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 64
	mov dx, 4
	mov si, 190
	mov di, 18
	mov bl, 0
	mov ebp, input_textbox
	call xwidget_create_textbox

	mov eax, [window_handle]
	mov cx, 64
	mov dx, 4+20
	mov si, 190
	mov di, 18
	mov bl, 0
	mov ebp, output_textbox
	call xwidget_create_textbox

	mov eax, [window_handle]
	mov cx, 4
	mov dx, 4+20+20
	mov esi, log_text
	mov ebx, 0xFFFFFF
	call xwidget_create_label

	mov eax, [window_handle]
	mov cx, 4
	mov dx, 4+20+20+20
	mov si, 248
	mov di, 96
	mov bl, XWIDGET_TEXTBOX_MULTILINE
	mov ebp, log_textbox
	call xwidget_create_textbox

	mov eax, [window_handle]
	mov cx, 4
	mov dx, 168
	mov esi, assemble_text
	call xwidget_create_button
	mov [assemble_handle], eax

	mov eax, [window_handle]
	mov cx, 184
	mov dx, 176
	mov esi, version_text
	mov ebx, 0xAAAAAA
	call xwidget_create_label

	mov eax, [window_handle]
	call xwidget_unlock

	mov eax, [window_handle]
	call xwidget_redraw

	call init_memory

.idle:
	call xwidget_wait_event
	cmp eax, XWIDGET_CLOSE
	je .close

	cmp eax, XWIDGET_BUTTON
	jne .idle

	jmp .assemble

.close:
	mov al, 0
	call exit_program

.assemble:
	cmp byte[input_filename], 0
	je .idle

	mov [input_file], input_filename

	cmp byte[output_filename], 0
	je .output_zero

	mov [output_file], output_filename
	jmp .work

.output_zero:
	mov [output_file], 0

.work:
	call preprocessor
	call parser
	call assembler
	call formatter

	movzx eax, [current_pass]
	inc eax
	call display_number
	mov esi, _passes_suffix
	call display_string

	mov eax, [written_size]
	call display_number
	mov esi, _bytes_suffix
	call display_string

	jmp .idle

; xwidget_yield_handler:
; Called whenever the program is idle...

xwidget_yield_handler:
	ret

	;;
	;; DATA AREA
	;;

	title			db "Flat Assembler",0
	version_text		db "v", VERSION_STRING, 0
	input_text		db "Input:",0
	output_text		db "Output:",0
	log_text		db "Log messages:",0
	assemble_text		db "Assemble",0

	_passes_suffix		db " passes, ", 0
	_bytes_suffix		db " bytes.",10,0

	input_filename:		times 32 db 0
	output_filename:	times 32 db 0
	log_messages:		times 256 db 0

	align 4
	window_handle		dd 0
	assemble_handle		dd 0
	log_ptr			dd log_messages

	align 4
	input_textbox:
				.text	dd input_filename
				.limit	dd 24

	output_textbox:
				.text	dd output_filename
				.limit	dd 24

	log_textbox:
				.text	dd log_messages
				.limit	dd 255



