
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

align 4
memdisk_phys			dd 0
memdisk_base			dd 0

; memdisk_detect:
; Detects MEMDISK

memdisk_detect:
	; for debugging purposes, print the e820 memory map
	;call do_memory_map

	; disable paging ;)
	wbinvd
	mov eax, cr0
	or eax, 0x60000000
	and eax, not 0x80000000
	mov cr0, eax

	mov esi, e820_map

.loop:
	mov ecx, [e820_entries]
	cmp [.current_entry], ecx
	jge .no_memdisk

	cmp dword[esi+16], 2		; reserved
	je .check_entry

.next_entry:
	add esi, 32
	inc [.current_entry]
	jmp .loop

.check_entry:
	push esi

	mov esi, [esi]
	mov edi, mbr
	mov ecx, 512
	rep cmpsb
	je .found_memdisk

	pop esi
	jmp .next_entry

.found_memdisk:
	pop esi
	mov eax, [esi]
	mov [memdisk_phys], eax

	mov esi, .found_msg
	call kprint
	mov eax, [memdisk_phys]
	call hex_dword_to_string
	call kprint
	mov esi, newline
	call kprint

	wbinvd
	mov eax, cr0
	or eax, 0x80000000
	and eax, not 0x60000000
	mov cr0, eax

	mov al, BLKDEV_MEMDISK
	mov ah, BLKDEV_PARTITIONED
	mov edx, [memdisk_phys]
	call blkdev_register

	; map the drive in memory
	mov eax, KERNEL_HEAP
	mov ecx, [boot_device_size]
	shl ecx, 9
	add ecx, 8192
	shr ecx, 12
	call vmm_alloc_pages

	cmp eax, 0
	je .no_memory

	mov [memdisk_base], eax

	mov ebx, [memdisk_phys]
	and ebx, 0xFFFFF000
	mov ecx, [boot_device_size]
	shl ecx, 9
	add ecx, 8192
	shr ecx, 12
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE
	call vmm_map_memory

	mov eax, [memdisk_phys]
	and eax, 0xFFF
	add [memdisk_base], eax

	ret

.no_memdisk:
	;mov esi, .no_memdisk_msg
	;call kprint

	wbinvd
	mov eax, cr0
	or eax, 0x80000000
	and eax, not 0x60000000
	mov cr0, eax
	ret

.no_memory:
	mov esi, .no_memory_msg
	jmp early_boot_error

align 4
.current_entry			dd 0
.found_msg			db "Found memdisk memory-mapped drive at 0x",0
.no_memdisk_msg			db "memdisk drive not present.",10,0
.no_memory_msg			db "Insufficient memory to use memory-mapped memdisk drive.",0

; do_memory_map:
; Prints the memory map

do_memory_map:
	mov esi, .title
	call kprint

	mov esi, e820_map

.loop:
	mov ecx, [e820_entries]
	cmp [.current_entry], ecx
	jge .done

	push esi

	mov esi, .space
	call kprint

	pop esi
	push esi

	mov eax, [esi]
	mov edx, [esi+4]
	call hex_qword_to_string
	call kprint

	mov esi, .dash
	call kprint

	pop esi
	push esi

	mov eax, [esi+8]
	mov edx, [esi+12]
	call hex_qword_to_string
	call kprint

	mov esi, .dash
	call kprint

	pop esi
	push esi

	mov eax, [esi+16]
	call int_to_string
	call kprint

	mov esi, newline
	call kprint

	pop esi
	add esi, 32
	inc [.current_entry]
	jmp .loop

.done:
	ret

.title				db " STARTING ADDRESS - RANGE SIZE       - TYPE",10,0
.space				db " ",0
.dash				db " - ",0
.current_entry			dd 0

; memdisk_read:
; Reads from MEMDISK drive
; In\	EDX:EAX = LBA
; In\	ECX = Sector count
; In\	EDI = Buffer to read to
; Out\	EAX = 0 on success

memdisk_read:
	mov esi, eax
	shl esi, 9
	add esi, [memdisk_base]
	shl ecx, 9
	rep movsb

	xor eax, eax
	ret

.lba				dd 0
.count				dd 0
.dest				dd 0

.source				dd 0


