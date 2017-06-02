
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

;
;
; struct xfs_directory
; {
;	u8 filename[32];
;	u32 lba;
;	u32 size_sectors;
;	u32 size_bytes;
;	u8 hour;
;	u8 minute;
;	u8 day;
;	u8 month;
;	u16 year;
;	u8 flags;
;	u8 reserved[13];
; }
;
; sizeof(xfs_directory) = 64;
;

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

; XFS Directory Flags
XFS_FLAGS_PRESENT	= 0x01
XFS_FLAGS_DIRECTORY	= 0x02
XFS_FLAGS_HIDDEN	= 0x04
XFS_FLAGS_READONLY	= 0x08
XFS_FLAGS_DELETED	= 0x10

XFS_SIGNATURE_MBR	= 0xF3		; in mbr partition table
XFS_ROOT_SIZE		= 64		; size of root directory in sectors
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

	test edx, FILE_CREATE		; creating and not just opening?
	jnz xfs_create			; yep -- create the file

	; ensure the file even exists
	call xfs_get_entry
	cmp eax, -1
	je .error
	mov [.file_entry], eax

	; ensure it is a file, and is present
	mov esi, [.file_entry]
	mov al, [esi+XFS_FLAGS]
	test al, XFS_FLAGS_PRESENT
	jz .error

	test al, XFS_FLAGS_DIRECTORY
	jnz .error

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

align 4
.filename		dd 0
.permission		dd 0
.file_entry		dd 0
.handle			dd 0
.msg			db "xfs: opened file '",0
.msg2			db "', file handle ",0

; xfs_create:
; Creates a blank file, delete it if it already exists
; In\	ESI = File name, ASCIIZ
; Out\	EAX = File handle

xfs_create:
	mov [.filename], esi

	movzx eax, byte[esi]		; drive letter
	sub al, 'A'
	shl eax, 3
	add eax, [virtual_drives]

	test byte[eax+VIRTUAL_DRIVE_FLAGS], VIRTUAL_DRIVE_PRESENT
	jz .error

	mov ebx, [eax+VIRTUAL_DRIVE_DRIVE]
	mov [.blkdev], ebx
	mov bl, [eax+VIRTUAL_DRIVE_PARTITION]
	mov [.partition], bl

	; read the boot sector
	mov edx, 0
	mov eax, 0
	mov ebx, [.blkdev]
	mov ecx, 1
	mov edi, [disk_buffer]
	call blkdev_read

	cmp al, 0
	jne .error

	; determine partition
	mov esi, [disk_buffer]
	add esi, 446
	movzx ecx, [.partition]
	shl ecx, 4
	add esi, ecx
	mov eax, [esi+8]
	mov [.lba_start], eax
	add eax, [esi+12]
	mov [.lba_end], eax

	; okay, does the file exist?
	mov esi, [.filename]
	call xfs_get_entry
	cmp eax, -1
	je .create_entry		; doesn't -- make the entry ourselves

	mov [.directory_entry], eax

	; exists, ensure file and not directory
	test byte[eax+XFS_FLAGS], XFS_FLAGS_DIRECTORY
	jnz .error

	mov dword[eax+XFS_SIZE_SECTORS], 1
	mov dword[eax+XFS_SIZE], 0
	mov byte[eax+XFS_FLAGS], XFS_FLAGS_PRESENT

	; TO-DO: put time/date support here
	jmp .write_directory

.create_entry:
	cmp ecx, 0		; disk error
	je .error

	mov [.directory_lba], ecx

	; read the directory we have
	mov edx, 0
	mov eax, [.directory_lba]
	mov ebx, [.blkdev]
	mov ecx, 8		; for now..
	mov edi, [disk_buffer]
	call blkdev_read

	cmp al, 0
	jne .error

	; search for an empty entry
	mov esi, [disk_buffer]
	mov ecx, 64

.find_entry_loop:
	test byte[esi+XFS_FLAGS], XFS_FLAGS_PRESENT
	jz .found_entry

	add esi, 64
	loop .find_entry_loop
	jmp .error

.found_entry:
	mov [.directory_entry], esi

	; allocate a sector
	mov eax, [.lba_start]
	mov edx, [.lba_end]
	mov ebx, [.blkdev]
	mov ecx, 1
	call xfs_allocate_sectors

	cmp eax, -1
	je .error

	mov [.file_lba], eax

	; actual file name...
	mov esi, [.filename]
	mov dl, '/'
	call count_byte_in_string

	mov ecx, eax
	mov esi, [.filename]
	call vfs_parse_filename
	cmp esi, -1
	je .error

	; okay, we have the actual file name in ESI
	call strlen
	mov ecx, eax
	mov edi, [.directory_entry]
	rep movsb
	xor al, al
	stosb

	; create the remaining of the directory entry
	mov edi, [.directory_entry]
	mov eax, [.file_lba]
	mov [edi+XFS_LBA], eax
	mov dword[edi+XFS_SIZE], 0		; byte
	mov dword[edi+XFS_SIZE_SECTORS], 1
	mov byte[edi+XFS_FLAGS], XFS_FLAGS_PRESENT

	; TO-DO: date and time support here!

.write_directory:
	mov edx, 0
	mov eax, [.directory_lba]
	mov ebx, [.blkdev]
	mov ecx, 8		; for now
	mov esi, [disk_buffer]
	call blkdev_write

	cmp al, 0
	jne .error

	; blank the file
	mov ecx, 512
	call kmalloc
	mov [.zeroes], eax

	mov edi, [.zeroes]
	mov al, 0
	mov ecx, 512
	rep stosb

	mov edx, 0
	mov eax, [.file_lba]
	mov ebx, [.blkdev]
	mov ecx, 1
	mov esi, [.zeroes]
	call blkdev_write

	cmp al, 0
	jne .error

	; okay, open the file
	mov esi, [.filename]
	mov edx, FILE_WRITE or FILE_READ	; permissions
	call xfs_open

	; file handle in eax...
	mov [.handle], eax

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

	mov eax, [.handle]
	ret

.error:
	mov eax, -1
	ret

align 4
.filename		dd 0
.file_entry		dd 0
.lba_start		dd 0
.lba_end		dd 0
.blkdev			dd 0
.directory_lba		dd 0
.directory_entry	dd 0
.file_lba		dd 0
.zeroes			dd 0
.handle			dd 0
.partition		db 0
.msg			db "xfs: created file '",0
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
; Out\	ECX = Starting sector of directory, 0 for disk error

xfs_get_entry:
	mov [.path], esi
	mov [.directory_start], 0

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
	je .root_only		; yes, file is in root directory
	mov [.total_slashes], eax

	; okay, scan the file somewhere other than the root directory
	; first, we'll need to load the root directory and search for the first path
	mov edx, 0
	mov eax, [.lba_start]
	inc eax
	mov ecx, XFS_ROOT_SIZE
	mov ebx, [.blkdev]
	mov edi, [disk_buffer]
	call blkdev_read

	cmp al, 0
	jne .error_free

	; okay, scan the root directory for the first file name
	mov [.path_number], 1
	mov esi, [.path_copy]
	mov ecx, [.path_number]
	call vfs_parse_filename
	cmp esi, -1
	je .error_free

	mov edi, .buffer
	call vfs_copy_filename

	mov esi, .buffer
	call strlen
	cmp eax, 0
	je .error_free

	inc eax
	mov [.filename_size], eax

	mov esi, [disk_buffer]
	mov ecx, 0

.scan_root:
	push esi
	mov edi, .buffer
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

	jmp .scan_root

.root_found:
	pop esi		; root entry

	; ensure it is a directory and not a file
	mov al, [esi+XFS_FLAGS]
	test al, XFS_FLAGS_PRESENT
	jz .error_nodir

	test al, XFS_FLAGS_DIRECTORY
	jz .error_nodir

	; now loop through all the directories searching for the file
	inc [.path_number]

.directory_loop:
	; esi = directory entry
	mov ecx, [esi+XFS_SIZE]		; size of directory in entries
	mov [.directory_size], ecx

	mov edx, 0
	mov eax, [esi+XFS_LBA]
	mov [.directory_start], eax

	mov ecx, [esi+XFS_SIZE_SECTORS]
	mov ebx, [.blkdev]
	mov edi, [disk_buffer]
	call blkdev_read

	cmp al, 0
	jne .error_nodir

	mov esi, [.path_copy]
	mov ecx, [.path_number]
	call vfs_parse_filename
	cmp esi, -1
	je .error_free

	mov edi, .buffer
	call vfs_copy_filename

	mov esi, .buffer
	call strlen
	cmp eax, 0
	je .error_free

	inc eax
	mov [.filename_size], eax

	mov esi, [disk_buffer]
	mov ecx, 0

.scan_directory:
	push esi
	mov edi, .buffer
	push ecx
	mov ecx, [.filename_size]
	rep cmpsb
	pop ecx
	je .directory_found

	pop esi
	add esi, 64

	inc ecx
	cmp ecx, [.directory_size]
	jge .error_free

	jmp .scan_directory

.directory_found:
	inc [.path_number]
	mov ecx, [.total_slashes]
	cmp [.path_number], ecx
	jg .finished

	pop esi
	jmp .directory_loop

.finished:
	mov eax, [.path_copy]
	call kfree

	pop eax
	mov ecx, [.directory_start]
	ret

.root_only:
	mov eax, [.lba_start]
	inc eax
	mov [.directory_start], eax

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
	cmp eax, 0
	je .error_free
	inc eax
	mov [.filename_size], eax

	mov esi, [disk_buffer]
	mov ecx, 0

.scan_root_only_loop:
	push esi
	mov edi, [.path_copy]
	add edi, 3
	push ecx
	mov ecx, [.filename_size]
	rep cmpsb
	pop ecx
	je .root_only_found

	pop esi
	add esi, 64

	inc ecx
	cmp ecx, XFS_ROOT_ENTRIES
	jge .error

	jmp .scan_root_only_loop

.root_only_found:
	mov eax, [.path_copy]
	call kfree

	pop eax		; eax = directory entry
	mov ecx, [.directory_start]
	ret

.error_free:
	mov eax, [.path_copy]
	call kfree

.error:
	mov eax, -1
	mov ecx, [.directory_start]
	ret

.error_nodir:
	mov eax, [.path_copy]
	call kfree

	mov eax, -1
	mov ecx, 0
	ret

align 4
.path			dd 0
.path_copy		dd 0
.blkdev			dd 0
.lba_start		dd 0
.filename_size		dd 0
.path_number		dd 0
.total_slashes		dd 0
.directory_size		dd 0
.directory_start	dd 0
.partition		db 0

.buffer:		times 33 db 0

; xfs_allocate_sectors:
; Allocates sectors
; In\	EAX = LBA start
; In\	EBX = Block device
; In\	ECX = Number of sectors
; In\	EDX = LBA end
; Out\	EAX = First free sector, -1 on error

xfs_allocate_sectors:
	mov [.lba], eax
	mov [.blkdev], ebx
	mov [.count], ecx
	mov [.lba_end], edx

	; allocate memory
	mov ecx, 512
	call malloc
	mov [.bootsect], eax

	; read the boot sector
	mov edx, 0
	mov eax, [.lba]
	mov ebx, [.blkdev]
	mov ecx, 1
	mov edi, [.bootsect]
	call blkdev_read

	cmp al, 0
	jne .error

	mov eax, [.lba_end]
	mov edi, [.bootsect]
	mov ebx, [edi+9]		; size of sector usage bitmap
	mov [.bitmap_size], ebx

	sub eax, ebx			; eax = lba sector of bitmap

	mov [.bitmap], eax

	mov ecx, [.count]
	call malloc
	mov [.zeroes], eax

	mov eax, [.bootsect]
	call free

	; memory manager initializes memory to zero, we don't need to do anything here

	; read the bitmap
	mov ecx, [.bitmap_size]
	shl ecx, 9
	call malloc
	mov [.memory], eax

	mov edx, 0
	mov eax, [.bitmap]
	mov ebx, [.blkdev]
	mov ecx, [.bitmap_size]
	mov edi, [.memory]
	call blkdev_read

	cmp al, 0
	jne .error_free

	; search for free sectors
	mov ecx, [.bitmap_size]
	shl ecx, 9		; mul 512
	mov esi, [.memory]

.find_loop:
	push esi
	push ecx
	mov edi, [.zeroes]
	mov ecx, [.count]
	rep cmpsb
	je .found

	pop ecx
	pop esi

	inc esi
	loop .find_loop
	jmp .error_free

.found:
	pop ecx		; don't need this
	pop esi
	mov [.tmp], esi

	sub esi, [.memory]
	add esi, [.lba]
	mov [.return], esi

	mov edi, [.tmp]
	mov al, 1
	mov ecx, [.count]
	rep stosb

	mov edx, 0
	mov eax, [.bitmap]
	mov ebx, [.blkdev]
	mov ecx, [.bitmap_size]
	mov esi, [.memory]
	call blkdev_write

	cmp al, 0
	jne .error_free

	mov esi, .msg
	call kprint
	mov eax, [.return]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	mov eax, [.zeroes]
	call free
	mov eax, [.memory]
	call free

	mov eax, [.return]
	ret

.error_free:
	mov eax, [.zeroes]
	call free
	mov eax, [.memory]
	call free

.error:
	mov eax, -1
	ret

align 4
.lba			dd 0
.lba_end		dd 0
.blkdev			dd 0
.count			dd 0
.memory			dd 0
.bitmap_size		dd 0
.bitmap			dd 0
.zeroes			dd 0
.bootsect		dd 0
.return			dd 0
.tmp			dd 0
.msg			db "xfs: found free sector LBA ",0




