
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

;
; struct blkdev {
; u8 device_type;		// 00
; u8 device_content;		// 01
; u32 address;			// 02
; u16 padding;			// 06
; };
;
;
; sizeof(blkdev) = 8;
;

BLKDEV_DEVICE_TYPE		= 0x00
BLKDEV_DEVICE_CONTENT		= 0x01
BLKDEV_ADDRESS			= 0x02
BLKDEV_PADDING			= 0x06
BLKDEV_SIZE			= 0x08

; System can manage up to 64 block devices
MAXIMUM_BLKDEVS			= 64

; Device Type
BLKDEV_UNPRESENT		= 0
BLKDEV_ATA			= 1
BLKDEV_AHCI			= 2
BLKDEV_RAMDISK			= 3
BLKDEV_MEMDISK			= 4
BLKDEV_USBMSD			= 5

; Device Content
BLKDEV_FLAT			= 0
BLKDEV_PARTITIONED		= 1

; Default Disk I/O Buffer Size
DISK_BUFFER_SIZE		= 65536		; 64 kb

align 4
blkdev_structure		dd 0
blkdevs				dd 0	; number of block devices on the system
boot_device			dd 0
disk_buffer			dd 0

boot_partition_num		db 0

; blkdev_init:
; Detects and initializes block devices

blkdev_init:
	mov ecx, MAXIMUM_BLKDEVS*BLKDEV_SIZE
	call kmalloc
	mov [blkdev_structure], eax

	; detect devices ;)
	call memdisk_detect
	call ata_detect
	call ahci_detect
	;call usbmsd_detect

	; determine the boot device
	; allocate a temporary buffer 512 bytes to read the MBR of each device present
	; then search for the partition entry which we booted from
	; it's very unlikely two disks on the same system have identical partitions ;)

	; -- to make this faster: if MEMDISK is present then it is the boot drive
	cmp [memdisk_phys], 0
	jne .memdisk

	mov ecx, 512
	call kmalloc
	mov [.tmp_buffer], eax

.loop:
	mov ebx, [.current_device]
	cmp ebx, [blkdevs]
	jge .no_bootdev

	xor edx, edx	; lba sector 0, this function uses edx:eax to support 48-bit LBA
	xor eax, eax
	mov ecx, 1
	mov edi, [.tmp_buffer]
	call blkdev_read

	cmp al, 0
	je .check_device

.next:
	inc [.current_device]
	jmp .loop

.check_device:
	; scan the device's partition table for the boot partition
	mov esi, [.tmp_buffer]
	add esi, 0x1BE

	mov ecx, 4		; 4 partitions per mbr

.check_loop:
	push ecx
	mov edi, boot_partition
	mov ecx, 16
	rep cmpsb
	je .found_boot_device

	pop ecx
	loop .check_loop
	jmp .next

.found_boot_device:
	pop ecx
	sub ecx, 4
	test ecx, 0x80000000
	jz .save_boot_device

	not ecx
	inc ecx

.save_boot_device:
	; save the boot device
	mov eax, [.current_device]
	mov [boot_device], eax
	mov [boot_partition_num], cl

	mov esi, .bootdev_msg
	call kprint
	mov eax, [boot_device]
	call int_to_string
	call kprint
	mov esi, .bootdev_msg2
	call kprint
	movzx eax, [boot_partition_num]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	; allocate a disk buffer for use by filesystem drivers
	mov ecx, DISK_BUFFER_SIZE
	;call malloc		; when userspace drivers actually exist, then i'll put this memory as userspace
	call kmalloc
	mov [disk_buffer], eax

	; and fly!
	mov eax, [.tmp_buffer]
	call kfree
	ret

.no_bootdev:
	mov esi, .no_bootdev_msg
	jmp early_boot_error

.memdisk:
	mov [boot_device], 0

	mov esi, .bootdev_msg
	call kprint
	mov eax, [boot_device]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	; allocate a disk buffer for use by filesystem drivers
	mov ecx, DISK_BUFFER_SIZE
	;call malloc		; when userspace drivers actually exist, then i'll put this memory as userspace
	call kmalloc
	mov [disk_buffer], eax

	ret

.tmp_buffer			dd 0
.current_device			dd 0
.bootdev_msg			db "Boot device is logical device ",0
.bootdev_msg2			db ", partition #",0
.no_bootdev_msg			db "Unable to determine the boot device.",10,0

; blkdev_register:
; Registers a device
; In\	AL = Device type
; In\	AH = Device content (partitioned/flat?)
; In\	EDX = Address
; Out\	EDX = Device number

blkdev_register:
	mov [.type], al

	mov edi, [blkdevs]
	shl edi, 3		; mul 8
	add edi, [blkdev_structure]
	mov [edi+BLKDEV_DEVICE_TYPE], al
	mov [edi+BLKDEV_DEVICE_CONTENT], ah
	mov [edi+BLKDEV_ADDRESS], edx
	mov word[edi+6], 0

	mov esi, .msg
	call kprint

	mov al, [.type]
	cmp al, BLKDEV_ATA
	je .ata
	cmp al, BLKDEV_AHCI
	je .ahci
	cmp al, BLKDEV_RAMDISK
	je .ramdisk
	cmp al, BLKDEV_MEMDISK
	je .memdisk

.undefined:
	mov esi, .undefined_msg
	call kprint
	jmp .done

.ata:
	mov esi, .ata_msg
	call kprint
	jmp .done

.ahci:
	mov esi, .ahci_msg
	call kprint
	jmp .done

.ramdisk:
	mov esi, .ramdisk_msg
	call kprint
	jmp .done

.memdisk:
	mov esi, .memdisk_msg
	call kprint

.done:
	mov esi, .msg2
	call kprint
	mov eax, [blkdevs]
	call int_to_string
	call kprint
	mov esi, newline
	call kprint

	mov edx, [blkdevs]
	inc [blkdevs]
	ret

.type			db 0
.msg			db "Registered ",0
.ata_msg		db "ATA device",0
.ahci_msg		db "AHCI device",0
.ramdisk_msg		db "ramdisk device",0
.memdisk_msg		db "memdisk device",0
.undefined_msg		db "undefined device",0
.msg2			db ", device number ",0

; blkdev_get_buffer:
; Returns a pointer to the disk buffer -- for use by userspace drivers in the future
; In\	Nothing
; Out\	EAX = Pointer to disk buffer

blkdev_get_buffer:
	mov eax, [disk_buffer]
	ret

; blkdev_read:
; Reads from a block device
; In\	EDX:EAX	= LBA sector
; In\	ECX = Sector count
; In\	EBX = Drive number
; In\	EDI = Buffer to read sectors
; Out\	AL = 0 on success, 1 on error
; Out\	AH = Device status (for ATA and AHCI, at least)
align 32
blkdev_read:
	mov [.count], ecx
	mov [.buffer], edi
	mov dword[.lba], eax
	mov dword[.lba+4], edx

	cmp ebx, [blkdevs]	; can't read from a non existant drive
	jge .fail

	shl ebx, 3
	add ebx, [blkdev_structure]

	; give control to device-specific code
	cmp byte[ebx], BLKDEV_MEMDISK
	je .memdisk

	cmp byte[ebx], BLKDEV_ATA
	je .ata

	cmp byte[ebx], BLKDEV_AHCI
	je .ahci

	;cmp byte[ebx], BLKDEV_RAMDISK
	;je .ramdisk

	jmp .fail

.ata:
	mov bl, [ebx+BLKDEV_ADDRESS]
	mov [.ata_drive], bl

.ata_loop:
	cmp [.count], 255
	jg .ata_big

	cmp [.count], 0
	je .done

	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov bl, [.ata_drive]
	mov ecx, [.count]
	mov edi, [.buffer]
	call ata_read
	cmp al, 1
	je .fail

	jmp .done

.ata_big:
	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov bl, [.ata_drive]
	mov ecx, 255
	mov edi, [.buffer]
	call ata_read
	cmp al, 1
	je .fail

	sub [.count], 255
	add [.buffer], 255*512
	add dword[.lba], 255
	jmp .ata_loop

.ahci:
	mov bl, [ebx+BLKDEV_ADDRESS]
	mov [.ahci_port], bl

.ahci_loop:
	cmp [.count], 255
	jg .ahci_big

	cmp [.count], 0
	je .done

	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov bl, [.ahci_port]
	mov ecx, [.count]
	mov edi, [.buffer]
	call ahci_read
	cmp al, 1
	je .fail

	jmp .done

.ahci_big:
	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov bl, [.ahci_port]
	mov ecx, 255
	mov edi, [.buffer]
	call ahci_read
	cmp al, 1
	je .fail

	sub [.count], 255
	add [.buffer], 255*512
	add dword[.lba], 255
	jmp .ahci_loop

.memdisk:
	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov ecx, [.count]
	mov edi, [.buffer]
	call memdisk_read
	ret

.done:
	mov al, 0
	ret

.fail:
	mov al, 1
	mov ah, -1
	ret

.ata_drive		db 0
.ahci_port		db 0
align 4
.buffer			dd 0
.count			dd 0
align 8
.lba			dq 0

; blkdev_write:
; Writes to a block device
; In\	EDX:EAX	= LBA sector
; In\	ECX = Sector count
; In\	EBX = Drive number
; In\	ESI = Buffer to write sectors
; Out\	AL = 0 on success, 1 on error
; Out\	AH = Device status (for ATA and AHCI, at least)
align 32
blkdev_write:
	mov [.count], ecx
	mov [.buffer], esi
	mov dword[.lba], eax
	mov dword[.lba+4], edx

	cmp ebx, [blkdevs]	; can't write to a non existant drive
	jge .fail

	shl ebx, 3
	add ebx, [blkdev_structure]

	; give control to device-specific code
	cmp byte[ebx], BLKDEV_MEMDISK
	je .memdisk

	cmp byte[ebx], BLKDEV_ATA
	je .ata

	cmp byte[ebx], BLKDEV_AHCI
	je .ahci

	;cmp byte[ebx], BLKDEV_RAMDISK
	;je .ramdisk

	jmp .fail

.ata:
	mov bl, [ebx+BLKDEV_ADDRESS]
	mov [.ata_drive], bl

.ata_loop:
	cmp [.count], 255
	jg .ata_big

	cmp [.count], 0
	je .done

	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov bl, [.ata_drive]
	mov ecx, [.count]
	mov esi, [.buffer]
	call ata_write
	cmp al, 1
	je .fail

	jmp .done

.ata_big:
	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov bl, [.ata_drive]
	mov ecx, 255
	mov esi, [.buffer]
	call ata_write
	cmp al, 1
	je .fail

	sub [.count], 255
	add [.buffer], 255*512
	add dword[.lba], 255
	jmp .ata_loop


.ahci:
	mov bl, [ebx+BLKDEV_ADDRESS]
	mov [.ahci_port], bl

.ahci_loop:
	cmp [.count], 255
	jg .ahci_big

	cmp [.count], 0
	je .done

	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov bl, [.ahci_port]
	mov ecx, [.count]
	mov esi, [.buffer]
	call ahci_write
	cmp al, 1
	je .fail

	jmp .done

.ahci_big:
	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov bl, [.ahci_port]
	mov ecx, 255
	mov esi, [.buffer]
	call ahci_write
	cmp al, 1
	je .fail

	sub [.count], 255
	add [.buffer], 255*512
	add dword[.lba], 255
	jmp .ahci_loop

.memdisk:
	mov edx, dword[.lba+4]
	mov eax, dword[.lba]
	mov ecx, [.count]
	mov esi, [.buffer]
	call memdisk_read
	ret

.done:
	mov al, 0
	ret

.fail:
	mov al, 1
	mov ah, -1
	ret

.ata_drive		db 0
.ahci_port		db 0
align 4
.buffer			dd 0
.count			dd 0
align 8
.lba			dq 0

; blkdev_read_bytes:
; Reads from a block devices in the form of bytes not sectors
; In\	EDX:EAX = Starting byte
; In\	ECX = Byte count
; In\	EBX = Block device number
; In\	EDI = Buffer to read bytes
; Out\	EAX = 0 on success

blkdev_read_bytes:
	mov dword[.bytes], eax
	mov dword[.bytes+4], edx
	mov [.count], ecx
	mov [.device], ebx
	mov [.buffer], edi

	; allocate memory
	mov ecx, [.count]
	add ecx, 4096		; to be safe...
	call malloc		; user memory is fine, we'll free it soon anyway
	mov [.tmp_buffer], eax

	; read sectors to this temporary memory
	mov edx, dword[.bytes+4]
	mov eax, dword[.bytes]
	mov ebx, 512	; to sectors... using DIV not SHR because dividing 64-bit by 32-bit
	div ebx
	mov edx, 0

	mov ebx, [.device]
	mov edi, [.tmp_buffer]
	mov ecx, [.count]
	shr ecx, 9	; div 512
	inc ecx
	call blkdev_read

	cmp al, 0
	jne .error

	; copy the requested bytes into the buffer requested
	pushfd
	cli

	mov esi, dword[.bytes]
	and esi, 0x1FF		; mod 512
	add esi, [.tmp_buffer]
	mov edi, [.buffer]
	mov ecx, [.count]
	call memcpy		; fast SSE memcpy

	popfd

	; finished!
	mov eax, [.tmp_buffer]
	call free

	mov eax, 0
	ret

.error:
	mov eax, [.tmp_buffer]
	call free

	mov eax, -1
	ret

align 8
.bytes			dq 0
.count			dd 0
.device			dd 0
.buffer			dd 0
.tmp_buffer		dd 0

; blkdev_write_bytes:
; Writes to a block device in units of bytes not sectors
; In\	EDX:EAX = Starting byte
; In\	ECX = Byte count
; In\	EBX = Block device number
; In\	ESI = Buffer to write
; Out\	EAX = 0 on success

blkdev_write_bytes:
	mov dword[.bytes], eax
	mov dword[.bytes+4], edx
	mov [.count], ecx
	mov [.device], ebx
	mov [.buffer], esi

	; allocate memory
	mov ecx, [.count]
	add ecx, 4096		; to be safe...
	call malloc		; user memory is fine, we'll free it soon anyway
	mov [.tmp_buffer], eax

	; read sectors to this temporary memory
	mov edx, dword[.bytes+4]
	mov eax, dword[.bytes]
	mov ebx, 512	; to sectors... using DIV not SHR because dividing 64-bit by 32-bit
	div ebx
	mov edx, 0

	mov ebx, [.device]
	mov edi, [.tmp_buffer]
	mov ecx, [.count]
	shr ecx, 9	; div 512
	inc ecx
	call blkdev_read

	cmp al, 0
	jne .error

	; copy the bytes to be written
	pushfd
	cli

	mov esi, [.buffer]
	mov edi, dword[.bytes]
	and edi, 0x1FF
	add edi, [.tmp_buffer]
	mov ecx, [.count]
	call memcpy		; fast SSE memcpy

	popfd

	; write
	mov edx, dword[.bytes+4]
	mov eax, dword[.bytes]
	mov ebx, 512	; to sectors... using DIV not SHR because dividing 64-bit by 32-bit
	div ebx
	mov edx, 0

	mov ebx, [.device]
	mov esi, [.tmp_buffer]
	mov ecx, [.count]
	shr ecx, 9	; div 512
	inc ecx
	call blkdev_write

	cmp al, 0
	jne .error

	; finished!
	mov eax, [.tmp_buffer]
	call free

	mov eax, 0
	ret

.error:
	mov eax, [.tmp_buffer]
	call free

	mov eax, -1
	ret

align 8
.bytes			dq 0
.count			dd 0
.device			dd 0
.buffer			dd 0
.tmp_buffer		dd 0





