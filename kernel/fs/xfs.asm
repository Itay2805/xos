
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; XFS Directory Entry Structure
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

XFS_SIGNATURE_MBR	= 0xF3		; in mbr partition table
XFS_ROOT_SIZE		= 64
XFS_ROOT_ENTRIES	= 512

; xfs_detect:
; Detects the xFS filesystem

xfs_detect:
	mov esi, .starting_msg
	call kprint

	; simply ensure the boot partition was even XFS
	cmp [boot_partition.type], XFS_SIGNATURE_MBR
	jne .not_xfs

	ret

.not_xfs:
	mov esi, .not_xfs_msg
	jmp early_boot_error

.tmp			dd 0
.starting_msg		db "Detecting XFS partition on boot device...",10,0
.not_xfs_msg		db "Unable to access file system on boot device.",0
;.test_filename		db "kernel32.sys",0

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
	call vfs_find_handle
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

	mov esi, .msg
	call kprint
	mov esi, [.filename]
	call kprint
	mov esi, .msg2
	call kprint
	mov eax, [.handle]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	inc [open_files]

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

align 4
.handle			dd 0
.base			dd 0
.dest			dd 0

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
; Out\	EAX = # of bytes successfully read

xfs_read:
	mov [.handle], eax
	mov [.count], ecx
	mov [.buffer], edi

	; get filename entry
	mov esi, [.handle]
	shl esi, 7
	add esi, [file_handles]
	add esi, FILE_NAME
	call xfs_get_entry

	cmp eax, -1
	je .bad

	mov edx, [eax+XFS_SIZE]		; size in bytes
	mov [.size], edx

	mov eax, [eax+XFS_LBA]		; LBA sector
	mov ebx, 512
	mul ebx			; use MUL and not SHL because we need the 64-bit result
	mov dword[.file_start], eax
	mov dword[.file_start+4], edx

	; ensure this read doesn't go out of the file
	mov eax, [.handle]
	shl eax, 7
	add eax, [file_handles]
	mov eax, [eax+FILE_POSITION]
	add eax, [.count]
	cmp eax, [.size]
	jg .bad

	; add the position to the file start in bytes
	mov eax, [.handle]
	shl eax, 7
	add eax, [file_handles]
	mov eax, [eax+FILE_POSITION]
	add dword[.file_start], eax
	adc dword[.file_start+4], 0

	; determine the block device
	mov esi, [.handle]
	shl esi, 7
	add esi, [file_handles]
	mov al, [esi+FILE_NAME]		; drive letter
	and eax, 0xFF
	sub eax, 'A'
	shl eax, 3			; mul 8
	add eax, [virtual_drives]

	mov eax, [eax+VIRTUAL_DRIVE_DRIVE]
	mov [.blkdev], eax

	; perform the read with a function that makes it easier ;)
	mov edx, dword[.file_start+4]
	mov eax, dword[.file_start]
	mov ebx, [.blkdev]
	mov ecx, [.size]
	mov edi, [.buffer]
	call blkdev_read_bytes		; this function reads bytes, not sectors ;)
	cmp eax, 0
	jne .bad

	; increment the position of the file
	mov esi, [.handle]
	shl esi, 7
	add esi, [file_handles]
	mov eax, [.count]
	add [esi+FILE_POSITION], eax

	mov eax, [.count]
	ret

.bad:
	mov eax, 0
	ret

align 4
.handle			dd 0
.count			dd 0
.buffer			dd 0
.size			dd 0
.blkdev			dd 0

align 8
.file_start		dq 0	; bytes

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;; End of public routines, start of driver internal routines

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; xfs_get_entry:
; Returns a pointer to an XFS directory entry for a file
; In\	ESI = Full path
; Out\	EAX = Pointer to directory entry, -1 on error

xfs_get_entry:
	mov [.path], esi

	; determine the device which contains the xfs partition
	mov al, [esi]		; drive letter
	and eax, 0xFF
	sub eax, 'A'
	shl eax, 3		; mul 3
	add eax, [virtual_drives]
	mov edx, [eax+VIRTUAL_DRIVE_DRIVE]
	mov [.blkdev], edx
	mov dl, [eax+VIRTUAL_DRIVE_PARTITION]
	mov [.partition], dl

	; read the MBR
	mov edx, 0
	mov eax, 0
	mov ebx, [.blkdev]
	mov ecx, 1
	mov edi, [disk_buffer]
	call blkdev_read
	cmp al, 0
	jne .error

	; okay, read the LBA start from the partition entry
	mov esi, [disk_buffer]
	add esi, 446
	movzx ecx, [.partition]
	shl ecx, 4		; mul 16
	add esi, ecx
	mov eax, [esi+8]	; lba
	mov [.lba_start], eax

	; make a copy of the path
	mov ecx, 120
	call kmalloc
	mov [.path_copy], eax

	mov esi, [.path]
	call strlen
	mov edi, [.path_copy]
	mov ecx, eax
	rep movsb

	; how many slashes are there in the path?
	mov esi, [.path_copy]
	mov dl, '/'
	call count_byte_in_string
	cmp eax, 1		; only one?
	je .root		; yes, file is in root directory

	; TO-DO: load file from a non-root directory here!
	mov eax, -1
	ret

.root:
	; load the root directory
	mov edx, 0
	mov eax, [.lba_start]
	inc eax			; root is at lba 1
	mov ecx, XFS_ROOT_SIZE
	mov ebx, [.blkdev]
	mov edi, [disk_buffer]
	call blkdev_read

	cmp al, 0
	jne .error_free

	; scan for the filename
	mov esi, [.path_copy]
	add esi, 3
	call strlen
	cmp eax, 32
	jge .error_free
	inc eax
	mov [.filename_size], eax

	mov esi, [disk_buffer]
	mov ecx, 0

.scan_root_loop:
	push esi
	mov edi, [.path_copy]
	add edi, 3
	push ecx
	mov ecx, [.filename_size]
	rep cmpsb
	pop ecx
	je .root_found

	pop esi
	add esi, 64

	inc ecx
	cmp ecx, XFS_ROOT_ENTRIES
	jge .error

	jmp .scan_root_loop

.root_found:
	mov eax, [.path_copy]
	call kfree

	pop eax		; eax = directory entry
	ret

.error_free:
	mov eax, [.path_copy]
	call kfree

.error:
	mov eax, -1
	ret

align 4
.path			dd 0
.path_copy		dd 0
.blkdev			dd 0
.lba_start		dd 0
.filename_size		dd 0
.partition		db 0




