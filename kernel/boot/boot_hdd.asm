
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.
;; boot/boot_hdd.asm -- Harddisk boot sector

use16
org 0

jmp short relocate
nop

align 8
filesystem_block:
	.fs_magic			db 0xF3
	.usage_block_size		dd 7500
	.volume_label			db "XOS",0

relocate:
	cli
	cld
	push ds
	push si

	xor ax, ax
	mov ds, ax
	mov ax, 0x4000
	mov es, ax

	mov si, 0x7C00
	xor di, di
	mov cx, 512
	rep movsb

	jmp 0x4000:main

main:
	pop si
	pop ds
	mov di, partition
	mov cx, 16
	rep movsb

	mov ax, 0x4000
	mov ds, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov sp, 0
	sti

	mov [bootdisk], dl

	mov si, _starting
	call print

load_root_directory:
	mov eax, 1
	add eax, dword[partition.lba]
	mov ebx, 64
	mov cx, 0x4000
	mov dx, disk_buffer
	call read_sectors
	jc disk_error

find_file:
	mov si, disk_buffer		; each directory entry is 32 bytes in size
					; and the first entry is always reserved, so skip it
	mov di, _kernel_filename
	mov cx, 0

.loop:
	pusha
	mov cx, _kernel_filename_size
	rep cmpsb
	je .found_file
	popa

	inc cx
	cmp cx, 512
	je file_not_found

	add si, 64
	jmp .loop

.found_file:
	popa

	;test byte[si+0x32], 0x01	; valid entry?
	;jz file_not_found

	;test byte[si+0x32], 0x02	; directory?
	;jnz file_not_found

	mov eax, dword[si+0x20]
	mov [.lba], eax
	mov ebx, dword[si+0x24]
	mov [.size], ebx

	mov word[.segment], 0x100
	mov word[.offset], 0

.work:
	cmp ebx, 127
	jg .big

	mov eax, [.lba]
	mov ebx, [.size]
	mov cx, [.segment]
	mov dx, [.offset]
	call read_sectors
	jc disk_error

	popa

.execute:
	mov si, partition
	mov dl, [bootdisk]
	jmp 0:0x1000

.big:
	mov eax, [.lba]
	mov ebx, 127
	mov cx, [.segment]
	mov dx, [.offset]
	call read_sectors
	jc disk_error

	add dword[.lba], 127
	sub dword[.size], 127
	mov ebx, [.size]

	add word[.segment], 0xFE0
	mov word[.offset], 0
	jmp .work

.lba				= 0
.size				= 4
.segment			= 8
.offset				= 12

file_not_found:
	mov si, _crlf
	call print

	mov si, _file_not_found
	call print

	jmp $


disk_error:
	mov si, _crlf
	call print

	mov si, _disk_error
	call print

	jmp $

read_sectors:
	mov [.lba], eax
	add eax, ebx
	mov [.end_lba], eax
	mov [.offset], dx
	mov [.segment], cx

	mov ah, 0
	mov dl, [bootdisk]
	int 0x13
	jc .fail

	mov eax, [.lba]
	mov [dap.lba], eax
	mov word[dap.sectors], 1
	mov ax, [.offset]
	mov word[dap.offset], ax
	mov ax, [.segment]
	mov word[dap.segment], ax

.read_sectors_loop:
	mov ah, 0x42
	mov si, dap
	mov dl, [bootdisk]
	int 0x13
	jc .fail

	mov ah, 0xE
	mov al, '.'
	int 0x10

	add dword[dap.lba], 1
	mov eax, [dap.lba]
	cmp eax, [.end_lba]
	jg .done

	add word[dap.offset], 512

	jmp .read_sectors_loop

.done:
	clc
	ret

.fail:
	stc
	ret

.lba				dd 0
.end_lba			dd 0
.segment			dw 0
.offset				dw 0

print:
	mov ah, 0xE

.loop:
	lodsb
	cmp al, 0
	je .done
	int 0x10
	jmp .loop

.done:
	ret

bootdisk			db 0

partition:
	.boot			db 0
	.chs			db 0
				db 0
				db 0
	.type			db 0
	.end_chs		db 0
				db 0
				db 0
	.lba			dd 0
	.size			dd 0

align 4

dap:
	.size			db 0x10
	.reserved		db 0
	.sectors		dw 1
	.offset			dw 0x7C00
	.segment		dw 0
	.lba			dd 0
				dd 0

_crlf				db 13,10,0
_starting			db ".",0
_disk_error			db "DE",0
_file_not_found			db "NF",0
_kernel_filename		db "kernel32.sys"
_kernel_filename_size		= $ - _kernel_filename

times 510 - ($-$$) db 0
dw 0xAA55

disk_buffer:

