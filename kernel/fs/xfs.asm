
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; struct file {
; u32 flags;		// 00
; u32 position;		// 04
; u8 path[120];		// 08
; }
;
;
; sizeof(file) = 0x20;
;

FILE_FLAGS		= 0x00
FILE_POSITION		= 0x04
FILE_NAME		= 0x08
FILE_HANDLE_SIZE	= 0x80

; Max no. of files the kernel can handle
MAXIMUM_FILE_HANDLES	= 512		; increase this in the future

; File Flags
FILE_PRESENT		= 0x00000001
FILE_WRITE		= 0x00000002
FILE_READ		= 0x00000004

; XFS File Entry Structure
XFS_FILENAME		= 0x00
XFS_LBA			= 0x20
XFS_SIZE_SECTORS	= 0x24
XFS_SIZE		= 0x28
XFS_HOUR		= 0x2C
XFS_MINUTE		= 0x2D
XFS_DAY			= 0x2E
XFS_MONTH		= 0x2F
XFS_YEAR		= 0x30
XFS_FLAGS		= 0x32

; Constants For Seeking in File
SEEK_SET		= 0x00
SEEK_CUR		= 0x01
SEEK_END		= 0x02

XFS_SIGNATURE_MBR	= 0xF3		; in mbr partition table
XFS_ROOT_SIZE		= 64
XFS_ROOT_ENTRIES	= 512

file_handles		dd 0
open_files		dd 0
xfs_new_filename:	times 12 db 0

; xfs_detect:
; Detects the xFS filesystem

xfs_detect:
	mov esi, .starting_msg
	call kprint

	; first ensure the boot partition was even XFS
	cmp [boot_partition.type], XFS_SIGNATURE_MBR
	jne .not_xfs

	; allocate memory for file handles
	mov ecx, MAXIMUM_FILE_HANDLES*FILE_HANDLE_SIZE
	call kmalloc
	mov [file_handles], eax
	mov [open_files], 0

	; we're done :3
	ret

.not_xfs:
	mov esi, .not_xfs_msg
	jmp early_boot_error

.tmp			dd 0
.starting_msg		db "Detecting XFS partition on boot device...",10,0
.not_xfs_msg		db "Unable to access file system on boot device.",0
.test_filename		db "kernel32.sys",0

; xfs_open:
; Opens a file
; In\	ESI = File name, ASCIIZ
; In\	EDX = Permissions bitfield
; Out\	EAX = File handle, -1 on error

xfs_open:
	mov [.filename], esi
	mov [.permission], edx

	; ensure the file even exists
	call xfs_get_entry
	cmp eax, -1
	je .error
	mov [.file_entry], eax

	; find a free file handle
	call xfs_find_handle
	cmp eax, -1
	je .error
	mov [.handle], eax

	; store information in the handle
	mov eax, [.handle]
	shl eax, 7		; mul 128
	add eax, [file_handles]

	mov edx, [.permission]
	or edx, FILE_PRESENT
	mov dword [eax], edx
	mov dword [eax+FILE_POSITION], 0	; always start at position zero

	mov edi, eax
	add edi, FILE_NAME

	push edi

	mov esi, [.filename]
	call strlen

	pop edi
	mov ecx, eax
	rep movsb

	xor al, al
	stosb

	;mov esi, .msg
	;call kprint
	;mov esi, [.filename]
	;call kprint
	;mov esi, .msg2
	;call kprint
	;mov eax, [.handle]
	;call int_to_string
	;call kprint
	;mov esi, newline
	;call kprint

	; return the handle to the user
	mov eax, [.handle]
	ret

.error:
	mov eax, -1
	ret

.filename		dd 0
.permission		dd 0
.file_entry		dd 0
.handle			dd 0
.msg			db "xfs: opened file '",0
.msg2			db "', file handle ",0

; xfs_close:
; Closes a file
; In\	EAX = File handle
; Out\	Nothing

xfs_close:
	cmp eax, MAXIMUM_FILE_HANDLES
	jge .quit

	;mov [.handle], eax

	;mov esi, .msg
	;call kprint
	;mov eax, [.handle]
	;call int_to_string
	;call kprint
	;mov esi, newline
	;call kprint

	; just clear the entire file handle ;)
	;mov eax, [.handle]
	shl eax, 7		; mul 128
	add eax, [file_handles]
	mov edi, eax
	mov ecx, FILE_HANDLE_SIZE
	xor al, al
	rep stosb

	dec [open_files]

.quit:
	ret

.handle			dd 0
.msg			db "xfs: close file handle ",0

; xfs_seek:
; Moves position in file stream
; In\	EAX = File handle
; In\	EBX = Where to move from
; In\	ECX = Where to move to, relative to where to move from
; Out\	EAX = 0 on success

xfs_seek:
	cmp eax, MAXIMUM_FILE_HANDLES
	jge .error

	mov [.base], ebx
	mov [.dest], ecx

	shl eax, 7	; mul 128
	add eax, [file_handles]
	mov [.handle], eax

	test dword[eax], FILE_PRESENT
	jz .error

	cmp [.base], SEEK_SET	; beginning of file
	je .set

	cmp [.base], SEEK_CUR	; from current pos
	je .current

	cmp [.base], SEEK_END	; end of file
	je .end

	jmp .error

.set:
	mov esi, [.handle]
	add esi, FILE_NAME
	call xfs_get_entry
	cmp eax, -1
	je .error

	mov ebx, [.dest]
	cmp [eax+XFS_SIZE], ebx
	jl .error

	mov edi, [.handle]
	mov ebx, [.dest]
	mov [edi+FILE_POSITION], ebx

	xor eax, eax
	ret

.current:
	mov esi, [.handle]
	add esi, FILE_NAME
	call xfs_get_entry
	cmp eax, -1
	je .error

	mov edi, [.handle]
	mov ebx, [.dest]
	add ebx, [edi+FILE_POSITION]	; current pos

	cmp [eax+XFS_SIZE], ebx
	jl .error

	mov edi, [.handle]
	mov ebx, [.dest]
	add [edi+FILE_POSITION], ebx

	xor eax, eax
	ret

.end:
	mov esi, [.handle]
	add esi, FILE_NAME
	call xfs_get_entry
	cmp eax, -1
	je .error

	mov ebx, [eax+XFS_SIZE]
	sub ebx, [.dest]
	jc .error		; negative number

	mov edi, [.handle]
	mov [edi+FILE_POSITION], ebx

	xor eax, eax
	ret

.done:
	xor eax, eax
	ret

.error:
	mov eax, -1
	ret

.handle			dd 0
.base			dd 0
.dest			dd 0
.filename:		times 13 db 0

; xfs_tell:
; Returns current position in file stream
; In\	EAX = File handle
; Out\	EAX = Current position, -1 on error

xfs_tell:
	cmp eax, MAXIMUM_FILE_HANDLES
	jge .error

	shl eax, 7
	add eax, [file_handles]
	test dword[eax], FILE_PRESENT
	jz .error

	mov eax, [eax+FILE_POSITION]
	ret

.error:
	mov eax, -1
	ret

; xfs_read:
; Reads from a file stream
; In\	EAX = File handle
; In\	ECX = # bytes to read
; In\	EDI = Buffer to read to
; Out\	EAX = # of successful bytes read

xfs_read:
	cmp eax, MAXIMUM_FILE_HANDLES
	jge .error

	shl eax, 7
	add eax, [file_handles]
	mov [.handle], eax

	mov [.count], ecx
	mov [.buffer], edi

	cmp [.count], 0
	je .error
	test [.count], 0x80000000	; negative
	jnz .error

	mov eax, [.handle]
	test dword[eax], FILE_PRESENT or FILE_READ	; ensure the file is present and we have read access
	jz .error

	mov esi, [.handle]
	add esi, FILE_NAME
	call xfs_get_entry
	cmp eax, -1
	je .error

	mov ebx, [eax+XFS_LBA]
	mov [.lba], ebx		; start of file data

	mov ebx, [eax+XFS_SIZE]
	mov [.size], ebx	; file size

	; check if we are reading beyond the file size
	mov eax, [.handle]
	mov ebx, [eax+FILE_POSITION]
	add ebx, [.count]
	cmp ebx, [.size]
	jg .error

	; okay, calculate the start of the LBA and read
	mov eax, [.handle]
	mov eax, [eax+FILE_POSITION]
	mov ebx, 512
	xor edx, edx
	div ebx			; use div 512 and not shr 9 because we need the remainder too
	add [.lba], eax
	mov [.start], edx	; number of bytes into the first lba

	; read into a temporary buffer first
	mov ecx, [.count]
	call kmalloc
	mov [.tmp_buffer], eax

	mov edx, 0
	mov eax, [.lba]
	mov ecx, [.count]
	add ecx, 511
	shr ecx, 9
	mov ebx, [boot_device]
	mov edi, [.tmp_buffer]
	call blkdev_read	; nice function -- independent of device types

	cmp al, 0
	jne .error

	; now copy only the needed data
	mov esi, [.tmp_buffer]
	add esi, [.start]
	mov edi, [.buffer]
	mov ecx, [.count]
	rep movsb

	; avoid memory leaks ;)
	mov eax, [.tmp_buffer]
	call kfree

	; update the file position
	mov edi, [.handle]
	mov ebx, [.count]
	add [edi+FILE_POSITION], ebx

	mov eax, [.count]
	ret

.error:
	mov eax, 0
	ret

.handle			dd 0
.count			dd 0
.buffer			dd 0
.lba			dd 0
.size			dd 0
.start			dd 0
.tmp_buffer		dd 0

; xfs_find_handle:
; Searches for a free file handle
; In\	Nothing
; Out\	EAX = File handle, -1 on error

xfs_find_handle:
	cmp [open_files], MAXIMUM_FILE_HANDLES
	jge .bad

	mov [.current_handle], 0

.loop:
	cmp [.current_handle], MAXIMUM_FILE_HANDLES-1
	jge .bad

	mov eax, [.current_handle]
	shl eax, 7		; mul 128
	add eax, [file_handles]
	test dword[eax], FILE_PRESENT
	jz .done

	inc [.current_handle]
	jmp .loop

.done:
	mov eax, [.current_handle]
	ret

.bad:
	mov eax, -1
	ret

.current_handle			dd 0

; xfs_read_root:
; Reads the root directory into the disk buffer
; In\	Nothing
; OUt\	AL = 0 on success

xfs_read_root:
	xor edx, edx
	mov eax, [boot_partition.lba]
	inc eax
	mov ecx, XFS_ROOT_SIZE
	mov ebx, [boot_device]
	mov edi, [disk_buffer]
	call blkdev_read

	ret

; xfs_get_entry:
; Returns a file entry
; In\	ESI = Filename
; Out\	EAX = Pointer to file entry, -1 on error

xfs_get_entry:
	mov [.filename], esi

	mov esi, [.filename]
	call strlen
	inc eax
	mov [.filename_size], eax

	call xfs_read_root
	cmp al, 0
	jne .error

	; now scan the root directory for the file name
	mov [.current_entry], 0
	mov esi, [disk_buffer]

.loop:
	push esi

	mov edi, [.filename]
	mov ecx, [.filename_size]
	rep cmpsb
	je .found

	pop esi
	add esi, 64

	inc [.current_entry]
	cmp [.current_entry], XFS_ROOT_ENTRIES
	jge .error
	jmp .loop

.found:
	pop eax
	ret

.error:
	mov esi, .fail_msg
	call kprint
	mov esi, [.filename]
	call kprint
	mov esi, .fail_msg2
	call kprint

	mov eax, -1
	ret

.current_entry			dd 0
.filename			dd 0
.filename_size			dd 0
.fail_msg			db "xfs: file '",0
.fail_msg2			db "' not found.",10,0



