
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

;
; struct file {
;	u32 flags;		// 00
;	u32 position;		// 04
;	u8 path[120];		// 08
; }
;
;
; sizeof(file) = 0x80;
;

FILE_FLAGS		= 0x00
FILE_POSITION		= 0x04
FILE_NAME		= 0x08
FILE_HANDLE_SIZE	= 0x80

;
; struct virtual_drive {
;	u32 drive;		// for blkdev
;	u8 partition;		// partition #
;	u8 flags;		// flags
;	u8 fs_type;		// same as partition MBR ID
;	u8 reserved;
; }
;
;
; sizeof(virtual_drive) = 8;
;

VIRTUAL_DRIVE_DRIVE	= 0x00
VIRTUAL_DRIVE_PARTITION	= 0x04
VIRTUAL_DRIVE_FLAGS	= 0x05
VIRTUAL_DRIVE_TYPE	= 0x06
VIRTUAL_DRIVE_SIZE	= 0x08

; Max no. of files the kernel can handle
MAXIMUM_FILE_HANDLES	= 512
MAXIMUM_VIRTUAL_DRIVES	= 26

; File Flags
FILE_PRESENT		= 0x00000001
FILE_WRITE		= 0x00000002
FILE_READ		= 0x00000004
FILE_CREATE		= 0x00000080

; Virtual Drive Flags
VIRTUAL_DRIVE_PRESENT	= 0x01

; Constants For Seeking in File
SEEK_SET		= 0x00
SEEK_CUR		= 0x01
SEEK_END		= 0x02

align 4
file_handles		dd 0
virtual_drives		dd 0
open_files		dd 0

virtual_drives_count	db 2	; to make the first HDD be "C" and not "A"
boot_virtual_drive	db 0

path:			times 120 db 0

; vfs_init:
; Initializes the virtual file system

vfs_init:
	; allocate memory for file handles
	mov ecx, FILE_HANDLE_SIZE*MAXIMUM_FILE_HANDLES
	call kmalloc
	mov [file_handles], eax
	mov [open_files], 0

	; virtual drives
	mov ecx, VIRTUAL_DRIVE_SIZE*MAXIMUM_VIRTUAL_DRIVES
	call kmalloc
	mov [virtual_drives], eax

	; allocate drive letter for all virtual drives
	mov [.current_blkdev], 0

.loop:
	mov eax, [.current_blkdev]
	mov cl, [.partition]
	call vfs_register_device

	inc [.partition]
	cmp [.partition], 3
	jg .next_device
	jmp .loop

.next_device:
	inc [.current_blkdev]
	mov [.partition], 0
	mov eax, [.current_blkdev]
	cmp eax, [blkdevs]
	jg .done
	jmp .loop

.done:
	mov esi, .boot_msg
	call kprint
	mov al, [boot_virtual_drive]
	call com1_send_byte
	mov esi, .boot_msg2
	call kprint

	mov edi, path
	mov al, [boot_virtual_drive]
	stosb
	mov al, ":"
	stosb
	mov al, "/"
	stosb

	ret

align 4
.current_blkdev		dd 0
.partition		db 0
.boot_msg		db "vfs: virtual boot device is '",0
.boot_msg2		db ":'",10,0

; vfs_register_device:
; Registers a device
; In\	EAX = Block device
; In\	CL = Partition number
; Out\	AL = Drive letter, -1 on error

vfs_register_device:
	mov [.blkdev], eax
	mov [.partition], cl

	mov al, [virtual_drives_count]
	mov [.virtual_drive], al

	; read the master boot record
	mov ecx, 512
	call kmalloc
	mov [.buffer], eax

	mov edx, 0
	mov eax, 0
	mov ebx, [.blkdev]
	mov ecx, 1
	mov edi, [.buffer]
	call blkdev_read

	cmp al, 0		; error?
	jne .cancel

	; determine the partition
	movzx esi, [.partition]
	shl esi, 4		; mul 16
	add esi, 446
	add esi, [.buffer]

	cmp dword[esi+8], 0	; no LBA?
	je .cancel

	cmp dword[esi+12], 0	; 0-size partition?
	je .cancel

	; okay, save the partition's information
	movzx edi, [.virtual_drive]
	shl edi, 3			; mul 8
	add edi, [virtual_drives]

	mov eax, [.blkdev]
	mov [edi+VIRTUAL_DRIVE_DRIVE], eax

	mov al, [esi+4]			; FS type
	mov [edi+VIRTUAL_DRIVE_TYPE], al

	mov byte[edi+VIRTUAL_DRIVE_FLAGS], VIRTUAL_DRIVE_PRESENT

	mov al, [.partition]
	mov [edi+VIRTUAL_DRIVE_PARTITION], al

	inc [virtual_drives_count]

	mov esi, .msg
	call kprint
	mov al, [.virtual_drive]
	add al, 'A'
	call com1_send_byte
	mov esi, .msg2
	call kprint
	mov eax, [.blkdev]
	call int_to_string
	call kprint
	mov esi, .msg3
	call kprint
	movzx eax, [.partition]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	; save the boot device if this is the one
	mov eax, [.blkdev]
	cmp eax, [boot_device]
	jne .finish

	mov al, [.partition]
	cmp al, [boot_partition_num]
	jne .finish

	mov al, [.virtual_drive]
	add al, 'A'
	mov [boot_virtual_drive], al

.finish:
	mov al, [.virtual_drive]
	add al, 'A'
	ret

.cancel:
	mov al, -1
	ret

align 4
.blkdev			dd 0
.buffer			dd 0
.partition		db 0
.virtual_drive		db 0
.msg			db "vfs: registered virtual drive '",0
.msg2			db ":' block device ",0
.msg3			db " partition #",0

; vfs_find_handle:
; Returns a free file handle
; In\	Nothing
; Out\	EAX = Free file handle, -1 on error

vfs_find_handle:
	mov [.handle], 0

.loop:
	mov eax, [.handle]
	shl eax, 7
	add eax, [file_handles]
	test dword[eax], FILE_PRESENT
	jz .found

.next:
	inc [.handle]
	cmp [.handle], MAXIMUM_FILE_HANDLES
	jge .no
	jmp .loop

.found:
	mov eax, [.handle]
	ret

.no:
	mov eax, -1
	ret

align 4
.handle				dd 0

; vfs_open:
; Opens a file
; In\	ESI = File name, ASCIIZ
; In\	EDX = Permissions bitfield
; Out\	EAX = File handle, -1 on error

vfs_open:
	mov [.filename], esi
	mov [.permissions], edx

	cmp byte[esi+1], ":"		; custom drive letter?
	jne .default_path

	mov al, [esi]
	cmp al, 'A'
	jl .bad

	cmp al, 'Z'
	jg .bad

	mov ecx, 120
	call kmalloc
	mov [.memory], eax

	mov esi, [.filename]
	call strlen
	mov ecx, eax
	mov edi, [.memory]
	rep movsb
	mov al, 0
	stosb

	jmp .call_driver

.default_path:
	mov ecx, 120
	call kmalloc
	mov [.memory], eax

	mov esi, path
	mov edi, [.memory]
	mov ecx, 120
	rep movsb

	mov esi, [.memory]
	call strlen
	mov edi, eax
	add edi, [.memory]

	push edi

	mov esi, [.filename]
	call strlen

	pop edi
	mov ecx, eax
	rep movsb

	mov al, 0
	stosb

.call_driver:
	; call FS-specific driver here
	; for now, only XFS is supported
	; TO-DO: add support for external non-kernel FS drivers
	; TO-DO: implement a "real" file system like FAT32
	mov esi, [.memory]
	mov al, [esi]		; drive letter
	and eax, 0xFF
	sub eax, 'A'
	shl eax, 3		; mul 8
	add eax, [virtual_drives]

	test byte[eax+VIRTUAL_DRIVE_FLAGS], VIRTUAL_DRIVE_PRESENT	; is the drive present?
	jz .bad

	mov al, [eax+VIRTUAL_DRIVE_TYPE]
	cmp al, XFS_SIGNATURE_MBR
	je .xfs

	; unknown filesystem
	jmp .bad

.xfs:
	mov esi, [.memory]
	mov edx, [.permissions]
	call xfs_open

	push eax
	mov eax, [.memory]
	call kfree
	pop eax			; file handle
	ret

.bad:
	mov eax, -1
	ret

align 4
.filename		dd 0
.permissions		dd 0
.memory			dd 0

; vfs_seek:
; Moves position in file stream
; In\	EAX = File handle
; In\	EBX = Where to move from
; In\	ECX = Where to move to, relative to where to move from
; Out\	EAX = 0 on success

vfs_seek:
	mov [.handle], eax
	mov [.base], ebx
	mov [.destination], ecx

	cmp eax, MAXIMUM_FILE_HANDLES
	jge .bad

	shl eax, 7
	add eax, [file_handles]
	test dword[eax], FILE_PRESENT
	jz .bad

	; determine which driver to call
	mov al, [eax+FILE_NAME]		; drive letter
	and eax, 0xFF
	sub eax, 'A'
	shl eax, 3		; mul 8
	add eax, [virtual_drives]

	test byte[eax+VIRTUAL_DRIVE_FLAGS], VIRTUAL_DRIVE_PRESENT
	jz .bad

	mov al, [eax+VIRTUAL_DRIVE_TYPE]	; FS type

	cmp al, XFS_SIGNATURE_MBR
	je .xfs

	; unknown fs...
	jmp .bad

.xfs:
	mov eax, [.handle]
	mov ebx, [.base]
	mov ecx, [.destination]
	call xfs_seek
	ret

.bad:
	mov eax, -1
	ret

align 4
.handle			dd 0
.base			dd 0
.destination		dd 0

; vfs_tell:
; Returns current position in file stream
; In\	EAX = File handle
; Out\	EAX = Current position, -1 on error

vfs_tell:
	mov [.handle], eax

	cmp eax, MAXIMUM_FILE_HANDLES
	jge .bad

	shl eax,7
	add eax, [file_handles]
	test dword[eax], FILE_PRESENT
	jz .bad

	; determine which driver to call
	mov al, [eax+FILE_NAME]		; drive letter
	and eax, 0xFF
	sub eax, 'A'
	shl eax, 3		; mul 8
	add eax, [virtual_drives]

	test byte[eax+VIRTUAL_DRIVE_FLAGS], VIRTUAL_DRIVE_PRESENT
	jz .bad

	mov al, [eax+VIRTUAL_DRIVE_TYPE]	; FS type

	cmp al, XFS_SIGNATURE_MBR
	je .xfs

	; unknown fs...
	jmp .bad

.xfs:
	mov eax, [.handle]
	call xfs_tell
	ret

.bad:
	mov eax, -1
	ret

align 4
.handle			dd 0

; vfs_read:
; Reads from a file stream
; In\	EAX = File handle
; In\	ECX = # bytes to read
; In\	EDI = Buffer to read to
; Out\	EAX = # of bytes successfully read

vfs_read:
	mov [.handle], eax
	mov [.count], ecx
	mov [.buffer], edi

	cmp eax, MAXIMUM_FILE_HANDLES
	jge .bad

	shl eax,7
	add eax, [file_handles]
	test dword[eax], FILE_PRESENT
	jz .bad

	test dword[eax], FILE_READ	; check for read permission
	jz .bad

	; determine which driver to call
	mov al, [eax+FILE_NAME]		; drive letter
	and eax, 0xFF
	sub eax, 'A'
	shl eax, 3		; mul 8
	add eax, [virtual_drives]

	test byte[eax+VIRTUAL_DRIVE_FLAGS], VIRTUAL_DRIVE_PRESENT
	jz .bad

	mov al, [eax+VIRTUAL_DRIVE_TYPE]	; FS type

	cmp al, XFS_SIGNATURE_MBR
	je .xfs

	; unknown fs...
	jmp .bad

.xfs:
	mov eax, [.handle]
	mov ecx, [.count]
	mov edi, [.buffer]
	call xfs_read
	ret

.bad:
	mov eax, 0
	ret

align 4
.handle			dd 0
.count			dd 0
.buffer			dd 0

; vfs_write:
; Reads from a file stream
; In\	EAX = File handle
; In\	ECX = # bytes to write
; In\	ESI = Buffer to write
; Out\	EAX = # of bytes successfully written

vfs_write:
	mov [.handle], eax
	mov [.count], ecx
	mov [.buffer], esi

	cmp eax, MAXIMUM_FILE_HANDLES
	jge .bad

	shl eax,7
	add eax, [file_handles]
	test dword[eax], FILE_PRESENT
	jz .bad

	test dword[eax], FILE_WRITE	; check for write permission
	jz .bad

	; determine which driver to call
	mov al, [eax+FILE_NAME]		; drive letter
	and eax, 0xFF
	sub eax, 'A'
	shl eax, 3		; mul 8
	add eax, [virtual_drives]

	test byte[eax+VIRTUAL_DRIVE_FLAGS], VIRTUAL_DRIVE_PRESENT
	jz .bad

	mov al, [eax+VIRTUAL_DRIVE_TYPE]	; FS type

	cmp al, XFS_SIGNATURE_MBR
	je .xfs

	; unknown fs...
	jmp .bad

.xfs:
	mov eax, [.handle]
	mov ecx, [.count]
	mov esi, [.buffer]
	call xfs_write
	ret

.bad:
	mov eax, 0
	ret

align 4
.handle			dd 0
.count			dd 0
.buffer			dd 0

; vfs_close:
; Closes a file
; In\	EAX = File handle
; Out\	Nothing

vfs_close:
	cmp eax, MAXIMUM_FILE_HANDLES
	jge .done

	shl eax, 7
	add eax, [file_handles]
	test dword[eax], FILE_PRESENT
	jz .done

	mov edi, eax
	mov al, 0
	mov ecx, FILE_HANDLE_SIZE
	rep stosb

	dec [open_files]

.done:
	mov eax, 0
	ret

; vfs_parse_filename:
; Parses a file name separated by '/'
; In\	ESI = File name
; In\	ECX = Number of slash
; Out\	ESI = Pointer to specific file name, -1 on error

vfs_parse_filename:
	cmp ecx, 0
	je .finish

	mov [.count], ecx
	mov [.current_slash], 0
	mov [.filename], esi
	call strlen
	add esi, eax
	mov [.end_filename], esi

	mov esi, [.filename]

.loop:
	lodsb
	cmp al, '/'
	je .found_slash

	cmp esi, [.end_filename]
	jge .error

	jmp .loop

.found_slash:
	inc [.current_slash]
	mov ecx, [.count]
	cmp ecx, [.current_slash]
	je .finish

	jmp .loop

.finish:
	ret

.error:
	mov esi, -1
	ret

align 4
.count				dd 0
.current_slash			dd 0
.filename			dd 0
.end_filename			dd 0

; vfs_copy_filename:
; Copies a string terminated by '/' or NULL
; In\	ESI = File name
; In\	EDI = Destination buffer
; Out\	EAX = Number of bytes copied

vfs_copy_filename:
	mov [.filename], esi
	mov [.destination], edi

	mov [.count], 0

	mov esi, [.filename]
	mov edi, [.destination]

.loop:
	lodsb
	cmp al, 0
	je .done
	cmp al, '/'
	je .done

	stosb
	inc [.count]
	jmp .loop

.done:
	xor al, al
	stosb

	mov eax, [.count]
	ret

align 4
.filename			dd 0
.destination			dd 0
.count				dd 0





