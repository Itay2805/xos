
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

MAX_DRIVER_FUNCTION		= 0x000E
DRIVER_LOAD_ADDRESS		= 0x80000000	; 2 GB

; Standard Driver Requests
; Requests 2 to 15 are reserved for future expansion
; Device-specific requests range from 16 to 0xFFFFFFFF
STD_DRIVER_INIT			= 0x0000
STD_DRIVER_RESET		= 0x0001

; Standard Driver Return Status
; Device-specific status range from 16 to 0xFFFFFFFE
STD_DRIVER_SUCCESS		= 0x0000
STD_DRIVER_FAIL			= 0x0001
STD_DRIVER_INVALID_REQUEST	= -1

align 4
net_mem				dd 0
net_mem_size			dd 0
net_entry			dd 0
net_driver:			times 120 db 0

; Driver API Calls

driver_api_table:
	dd kprint			; 0x0000
	dd pci_read_dword		; 0x0001
	dd pci_write_dword		; 0x0002
	dd pci_get_device_class		; 0x0003
	dd pci_get_device_class_progif	; 0x0004
	dd pci_get_device_vendor	; 0x0005
	dd pci_map_memory		; 0x0006
	dd pci_generate_list		; 0x0007

	dd kmalloc			; 0x0008
	dd kfree			; 0x0009
	dd vmm_alloc			; 0x000A
	dd vmm_free			; 0x000B
	dd pmm_alloc			; 0x000C
	dd pmm_free			; 0x000D
	dd virtual_to_physical		; 0x000E

; driver_api:
; INT 0x61 handler

driver_api:
	cmp ebp, MAX_DRIVER_FUNCTION
	jg .done

	sti

	shl ebp, 2		; mul 4
	add ebp, driver_api_table
	mov ebp, [ebp]
	call ebp

.done:
	iret

; load_driver:
; Loads a driver
; In\	ESI = File name
; Out\	EAX = 0 on success
; Out\	EBX = Driver base memory
; Out\	ECX = Driver memory size in pages
; Out\	EDX = Driver entry point

load_driver:
	mov [.filename], esi

	; open the file
	mov esi, [.filename]
	mov edx, FILE_READ
	call vfs_open

	cmp eax, -1
	je .error
	mov [.handle], eax

	; get file size
	mov eax, [.handle]
	mov ebx, SEEK_END
	mov ecx, 0
	call vfs_seek

	cmp eax, 0
	jne .error

	mov eax, [.handle]
	call vfs_tell
	cmp eax, 0
	je .error

	cmp eax, -1
	je .error

	mov [.file_size], eax

	; round it to pages
	add eax, 4095
	shr eax, 12
	mov [.size_pages], eax

	; allocate memory
	mov ecx, [.size_pages]
	call pmm_alloc
	mov [.memory], eax

	mov eax, DRIVER_LOAD_ADDRESS
	mov ebx, [.memory]
	mov ecx, [.size_pages]
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE
	call vmm_map_memory

	; read the file
	mov eax, [.handle]
	mov ebx, SEEK_SET
	mov ecx, 0
	call vfs_seek

	mov eax, [.handle]
	mov ecx, [.file_size]
	mov edi, DRIVER_LOAD_ADDRESS
	call vfs_read

	cmp eax, [.file_size]
	jne .error_free

	; close the file
	mov eax, [.handle]
	call vfs_close

	; ensure it is valid
	mov esi, DRIVER_LOAD_ADDRESS
	cmp dword[esi], "XOS1"
	jne .error_free_mem

	cmp dword[esi+PROGRAM_TYPE], DRIVER_FILE
	jne .error_free_mem

	mov ebp, [esi+PROGRAM_ENTRY]
	mov [.entry], ebp

	mov eax, STD_DRIVER_INIT	; initialize driver command, which is standard for all drivers
	call ebp			; call the driver

	; eax contains status from driver
	mov ebx, [.memory]
	mov ecx, [.size_pages]
	mov edx, [.entry]
	ret

.error_free:
	mov eax, [.handle]
	call vfs_close

.error_free_mem:
	mov eax, [.memory]
	mov ecx, [.size_pages]
	call pmm_free

.error:
	mov eax, -1
	mov ebx, -1
	mov ecx, -1
	ret

align 4
.filename			dd 0
.file_size			dd 0
.size_pages			dd 0
.memory				dd 0
.handle				dd 0
.entry				dd 0


