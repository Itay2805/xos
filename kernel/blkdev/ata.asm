
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Default IO ports used by ISA ATA
; For PCI IDE, the base ports must be gotten from PCI BARs 0 and 1
ATA_PRIMARY_BASE		= 0x1F0
ATA_SECONDARY_BASE		= 0x170
ATA_PRIMARY_STATUS		= 0x3F6
ATA_SECONDARY_STATUS		= 0x376

; ATA Commands
ATA_IDENTIFY			= 0xEC
ATA_FLUSH_LBA28			= 0xE7
ATA_FLUSH_LBA48			= 0xEA
ATA_READ_LBA28			= 0x20
ATA_WRITE_LBA28			= 0x30
ATA_READ_LBA48			= 0x24
ATA_WRITE_LBA48			= 0x34

align 2
ata_primary			dw ATA_PRIMARY_BASE
ata_secondary			dw ATA_SECONDARY_BASE
ata_primary_status		dw ATA_PRIMARY_STATUS
ata_secondary_status		dw ATA_SECONDARY_STATUS

pci_ide_bus			db 0
pci_ide_dev			db 0
pci_ide_function		db 0

; ata_detect:
; Detect ATA bus and ATA/ATAPI devices

ata_detect:
	; first detect PCI IDE controller
	mov ax, 0x0101
	call pci_get_device_class

	mov [pci_ide_bus], al
	mov [pci_ide_dev], ah
	mov [pci_ide_function], bl

	cmp [pci_ide_bus], 0xFF
	je .isa

	mov esi, .pci_msg
	call kprint
	mov al, [pci_ide_bus]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [pci_ide_dev]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [pci_ide_function]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

.detect_primary_port:
	; detect I/O ports from the PCI configuration
	mov al, [pci_ide_bus]
	mov ah, [pci_ide_dev]
	mov bl, [pci_ide_function]
	mov bh, PCI_BAR0
	call pci_read_dword

	cmp ax, 1
	jle .primary_standard
	and ax, 0xFFFC
	mov [ata_primary], ax

	mov al, [pci_ide_bus]
	mov ah, [pci_ide_dev]
	mov bl, [pci_ide_function]
	mov bh, PCI_BAR1
	call pci_read_dword

	and ax, 0xFFFC
	mov [ata_primary_status], ax

	jmp .detect_secondary_port

.primary_standard:
	mov [ata_primary], ATA_PRIMARY_BASE	; if BAR0 of PCI IDE is 0 or 1, then it uses standard isa ports
	mov [ata_primary_status], ATA_PRIMARY_STATUS

.detect_secondary_port:
	mov al, [pci_ide_bus]
	mov ah, [pci_ide_dev]
	mov bl, [pci_ide_function]
	mov bh, PCI_BAR2
	call pci_read_dword

	cmp ax, 1
	jle .secondary_standard
	and ax, 0xFFFC
	mov [ata_secondary], ax

	mov al, [pci_ide_bus]
	mov ah, [pci_ide_dev]
	mov bl, [pci_ide_function]
	mov bh, PCI_BAR3
	call pci_read_dword

	and ax, 0xFFFC
	mov [ata_secondary_status], ax

	jmp .detect_devices

.secondary_standard:
	mov [ata_secondary], ATA_SECONDARY_BASE
	mov [ata_secondary_status], ATA_SECONDARY_STATUS
	jmp .detect_devices

.isa:
	; to detect ISA ATA, use the "floating bus" technique
	mov dx, ATA_PRIMARY_BASE+7	; status
	in al, dx
	cmp al, 0xFF
	je .no_ata

	; use the default IO ports at 0x1F0 and 0x170
	mov [ata_primary], ATA_PRIMARY_BASE
	mov [ata_primary_status], ATA_PRIMARY_STATUS
	mov [ata_secondary], ATA_SECONDARY_BASE
	mov [ata_secondary_status], ATA_SECONDARY_STATUS

.detect_devices:
	mov esi, .ports_msg
	call kprint
	mov ax, [ata_primary]
	call hex_word_to_string
	call kprint
	mov esi, .ports_msg2
	call kprint
	mov ax, [ata_secondary]
	call hex_word_to_string
	call kprint
	mov esi, newline
	call kprint

	; reset the ATA channels
	call ata_reset

	; disable ATA IRQs
	mov dx, [ata_primary]
	add dx, 0x206
	mov al, 2
	out dx, al

	mov dx, [ata_secondary]
	add dx, 0x206
	mov al, 2
	out dx, al

	; detect the devices
	mov dl, 0			; primary channel/master dev
	call ata_identify
	mov dl, 1			; primary channel/slave dev
	call ata_identify
	mov dl, 2			; secondary channel/master dev
	call ata_identify
	mov dl, 3			; secondary channel/slave dev
	call ata_identify

	; setup the ATA IRQ stuff
	mov al, 14+IRQ_BASE
	mov ebp, ata_irq_primary
	call install_isr

	mov al, 15+IRQ_BASE
	mov ebp, ata_irq_secondary
	call install_isr

	mov al, 14
	call irq_unmask
	mov al, 15
	call irq_unmask

	; reset, also enables IRQs
	call ata_reset
	ret

.no_ata:
	mov esi, .no_ata_msg
	call kprint
	ret

.pci_msg			db "IDE controller at PCI slot ",0
.ports_msg			db "ATA channels at ports 0x",0
.ports_msg2			db ", 0x",0
.colon				db ":",0
.no_ata_msg			db "ATA not found.",10,0

; ata_reset:
; Resets the ATA channels

ata_reset:
	push edx
	push eax

	mov dx, [ata_primary_status]
	mov al, 4
	out dx, al

	mov dx, [ata_secondary_status]
	out dx, al

	call iowait
	call iowait

	mov dx, [ata_primary_status]
	mov al, 0
	out dx, al

	mov dx, [ata_secondary_status]
	out dx, al

	call iowait
	call iowait

	pop eax
	pop edx
	ret

; ata_identify:
; Identifies an ATA device
; In\	DL = Bit 0 -> set for slave device; bit 1 -> set for secondary controller
; Out\	EFLAGS.CF = 0 on success

ata_identify:
	push edx

	; reset the ATA channels
	call ata_reset

	; disable ATA IRQs
	mov dx, [ata_primary]
	add dx, 0x206
	mov al, 2
	out dx, al

	mov dx, [ata_secondary]
	add dx, 0x206
	mov al, 2
	out dx, al

	pop edx

	mov [.drive_backup], dl
	mov [.drive], dl
	test dl, 2	; secondary controller?
	jnz .secondary

.primary:
	mov dx, [ata_primary]
	mov [.io], dx

	mov esi, .primary_msg
	call kprint

	jmp .check_device

.secondary:
	mov dx, [ata_secondary]
	mov [.io], dx
	mov esi, .secondary_msg
	call kprint

.check_device:
	test [.drive], 1	; slave device?
	jnz .slave

.master:
	mov esi, .master_msg
	call kprint

	mov [.drive], 0xA0
	jmp .start

.slave:
	mov esi, .slave_msg
	call kprint

	mov [.drive], 0xB0	; with slave bit set

.start:
	mov dx, [.io]
	add dx, 6		; drive select
	mov al, [.drive]
	out dx, al
	call iowait

	mov dx, [.io]
	add dx, 2		; 0x1F2
	mov al, 0
	out dx, al
	inc dx			; 0x1F3
	out dx, al
	inc dx			; 0x1F4
	out dx, al
	inc dx			; 0x1F5
	out dx, al

	inc dx
	inc dx			; 0x1F7
	mov al, ATA_IDENTIFY
	out dx, al
	call iowait

	in al, dx
	cmp al, 0
	je .no_device
	cmp al, 0xFF
	je .no_device

.wait_for_bsy:
	in al, dx
	test al, 0x80
	jnz .wait_for_bsy

	test al, 1
	jnz .no_device
	test al, 0x20
	jnz .no_device

.check_ata:
	mov dx, [.io]
	add dx, 4
	in al, dx
	cmp al, 0
	jne .no_device

	inc dx
	in al, dx
	cmp al, 0
	jne .no_device

.wait_for_drq:
	mov dx, [.io]
	add dx, 7
	in al, dx
	test al, 8		; DRQ?
	jnz .read

	test al, 1		; ERR?
	jnz .no_device

	test al, 0x20		; DF?
	jnz .no_device

	jmp .wait_for_drq

.read:
	mov dx, [.io]
	mov ecx, 256
	mov edi, ata_identify_data
	rep insw

	mov esi, .quote
	call kprint
	mov esi, ata_identify_data.model
	call swap_string_order
	call trim_string
	call kprint
	mov esi, .quote
	call kprint
	mov esi, newline
	call kprint

	; register the device
	mov al, BLKDEV_ATA
	mov ah, BLKDEV_PARTITIONED
	movzx edx, [.drive_backup]
	call blkdev_register

	clc
	ret

.no_device:
	mov esi, .no_msg
	call kprint

	stc
	ret

.drive			db 0
.drive_backup		db 0
.io			dw 0
.buffer			dd 0
.primary_msg		db "ATA primary channel ",0
.secondary_msg		db "ATA secondary channel ",0
.master_msg		db "master device is ",0
.slave_msg		db "slave device is ",0
.quote			db "'",0
.no_msg			db "not present.",10,0

; ata_irq_primary:
; ATA Primary Channel IRQ Handler

ata_irq_primary:
	push eax
	mov [.happened], 1
	mov al, 0x20
	out 0xA0, al
	out 0x20, al
	pop eax
	iret

.happened		db 0

; ata_irq_secondary:
; ATA Secondary Channel IRQ Handler

ata_irq_secondary:
	push eax

	; first check if it's a spurious irq
	; because irq 15 is shared with ATA secondary channel and PIC2 spurious
	mov al, 0x0B
	out 0xA0, al
	call iowait
	in al, 0xA0

	test al, 0x80
	jz .spurious

	mov [.happened], 1	; tell the driver that an irq happened

	mov al, 0x20
	out 0xA0, al
	out 0x20, al
	pop eax
	iret

.spurious:
	mov al, 0x20
	out 0x20, al
	pop eax
	iret

.happened		db 0

; ata_read:
; Reads from an ATA device
; In\	EDX:EAX = LBA sector
; In\	ECX = Sector count
; In\	BL = Drive bitfield (bit 0 for slave device, bit 1 for secondary channel)
; In\	EDI = Buffer to read sectors
; Out\	AL = 0 on success, 1 on error
; Out\	AH = Drive status register

ata_read:
	; To save performance, only use LBA48 if it's nescessary
	; There's no reason to use almost twice the IO bandwidth when we can avoid it
	cmp edx, 0
	jne ata_read_lba48
	cmp eax, 0xFFFFFFF-256
	jge ata_read_lba48

	jmp ata_read_lba28

; ata_read_lba28:
; Reads from an ATA device using LBA28

ata_read_lba28:
	mov [.drive], bl
	mov [.count], ecx
	mov [.buffer], edi
	mov [.lba], eax
	mov [.current_count], 0

	cmp [.count], 0
	je .error

	test [.drive], 2		; secondary/primary channel?
	jnz .secondary

	mov dx, [ata_primary]
	mov [.io], dx
	jmp .check_device

.secondary:
	mov dx, [ata_secondary]
	mov [.io], dx

.check_device:
	test [.drive], 1		; primary/slave device?
	jnz .slave

	mov [.device], 0xE0
	jmp .start

.slave:
	mov [.device], 0xF0

.start:
	; first we need to send the highest 4 bits of the lba to the drive select port
	mov eax, [.lba]
	shr eax, 24		; keep only highest bits
	or al, [.device]
	mov dx, [.io]
	add dx, 6		; drive select port
	out dx, al
	call iowait

	; tell the controller we'll be using PIO
	mov dx, [.io]
	inc dx			; 0x1F1
	xor al, al
	out dx, al
	call iowait

	; sector count
	inc dx			; 0x1F2
	mov eax, [.count]
	out dx, al

	; LBA
	inc dx			; 0x1F3
	mov eax, [.lba]
	out dx, al
	inc dx			; 0x1F4
	shr eax, 8
	out dx, al
	inc dx			; 0x1F5
	shr eax, 8
	out dx, al
	inc dx
	inc dx			; 0x1F7

	mov al, ATA_READ_LBA28
	out dx, al
	call iowait

	in al, dx
	cmp al, 0
	je .error
	cmp al, 0xFF
	je .error

.wait_for_bsy:
	in al, dx
	test al, 0x80
	jnz .wait_for_bsy

.wait_for_drq:
	in al, dx
	test al, 8		; drq?
	jnz .read_sector
	test al, 1		; err?
	jnz .error
	test al, 0x20		; df?
	jnz .error
	jmp .wait_for_drq

.read_sector:
	; read a single sector
	mov edi, [.buffer]
	mov dx, [.io]
	mov ecx, 256
	rep insw
	mov [.buffer], edi

	; give the drive time to refresh its buffers and status
	call iowait
	call iowait

	inc [.current_count]
	mov ecx, [.count]
	cmp [.current_count], ecx
	jge .done

	mov dx, [.io]
	add dx, 7
	jmp .wait_for_drq

.error:
	mov esi, .err_msg
	call kprint
	movzx eax, [.drive]
	call int_to_string
	call kprint
	mov esi, .err_msg2
	call kprint
	mov al, ATA_READ_LBA28
	call hex_byte_to_string
	call kprint
	mov esi, .err_msg3
	call kprint
	mov eax, [.lba]
	call hex_dword_to_string
	call kprint
	mov esi, .err_msg4
	call kprint
	mov eax, [.count]
	call hex_byte_to_string
	call kprint
	mov esi, .err_msg5
	call kprint
	mov dx, [.io]
	add dx, 7
	in al, dx
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	mov dx, [.io]
	add dx, 7		; status
	in al, dx
	mov ah, al
	mov al, 1

	push eax
	call ata_reset
	pop eax
	ret

.done:
	mov dx, [.io]
	add dx, 7
	in al, dx
	mov ah, al
	mov al, 0
	ret

align 2
.io			dw 0
.drive			db 0
.device			db 0

align 4
.count			dd 0
.current_count		dd 0
.buffer			dd 0
.lba			dd 0
.err_msg		db "Error in ATA device ",0
.err_msg2		db ", command 0x",0
.err_msg3		db ", LBA 0x",0
.err_msg4		db ", count 0x",0
.err_msg5		db ", status 0x",0

; ata_read_lba48:
; Reads from an ATA device using LBA48

ata_read_lba48:
	mov [.drive], bl
	mov [.count], ecx
	mov [.buffer], edi
	mov dword[.lba], eax
	mov dword[.lba+4], edx
	mov [.current_count], 0

	cmp [.count], 0
	je .error

	test [.drive], 2		; secondary/primary channel?
	jnz .secondary

	mov dx, [ata_primary]
	mov [.io], dx
	jmp .check_device

.secondary:
	mov dx, [ata_secondary]
	mov [.io], dx

.check_device:
	test [.drive], 1		; primary/slave device?
	jnz .slave

	mov [.device], 0x40
	jmp .start

.slave:
	mov [.device], 0x50

.start:
	; select the device
	mov al, [.device]
	mov dx, [.io]
	add dx, 6
	out dx, al
	call iowait

	; tell the controller we'll be using PIO
	mov dx, [.io]
	inc dx			; 0x1F1
	xor al, al
	out dx, al
	call iowait

	; sector count high
	inc dx			; 0x1F2
	xor al, al
	out dx, al

	; LBA high bytes
	inc dx			; 0x1F3
	mov al, byte[.lba+3]
	out dx, al

	inc dx			; 0x1F4
	mov al, byte[.lba+4]
	out dx, al

	inc dx			; 0x1F5
	mov al, byte[.lba+5]
	out dx, al
	call iowait

	; sector count low
	mov dx, [.io]
	add dx, 2		; 0x1F2
	mov eax, [.count]
	out dx, al

	inc dx			; 0x1F3
	mov al, byte[.lba]
	out dx, al

	inc dx			; 0x1F4
	mov al, byte[.lba+1]
	out dx, al

	inc dx			; 0x1F5
	mov al, byte[.lba+2]
	out dx, al
	call iowait

	inc dx
	inc dx

	mov al, ATA_READ_LBA48		; send command
	out dx, al
	call iowait

	in al, dx
	cmp al, 0
	je .error
	cmp al, 0xFF
	je .error

.wait_for_bsy:
	in al, dx
	test al, 0x80
	jnz .wait_for_bsy

.wait_for_drq:
	in al, dx
	test al, 8		; drq?
	jnz .read_sector
	test al, 1		; err?
	jnz .error
	test al, 0x20		; df?
	jnz .error
	jmp .wait_for_drq

.read_sector:
	; read a single sector
	mov edi, [.buffer]
	mov dx, [.io]
	mov ecx, 256
	rep insw
	mov [.buffer], edi

	; give the drive time to refresh its buffers and status
	call iowait
	call iowait

	inc [.current_count]
	mov ecx, [.count]
	cmp [.current_count], ecx
	jge .done

	mov dx, [.io]
	add dx, 7
	jmp .wait_for_drq

.error:
	mov esi, .err_msg
	call kprint
	movzx eax, [.drive]
	call int_to_string
	call kprint
	mov esi, .err_msg2
	call kprint
	mov al, ATA_READ_LBA48
	call hex_byte_to_string
	call kprint
	mov esi, .err_msg3
	call kprint
	mov eax, dword[.lba]
	mov edx, dword[.lba+4]
	call hex_qword_to_string
	call kprint
	mov esi, .err_msg4
	call kprint
	mov eax, [.count]
	call hex_byte_to_string
	call kprint
	mov esi, .err_msg5
	call kprint
	mov dx, [.io]
	add dx, 7
	in al, dx
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	mov dx, [.io]
	add dx, 7		; status
	in al, dx
	mov ah, al
	mov al, 1

	push eax
	call ata_reset
	pop eax
	ret

.done:
	mov dx, [.io]
	add dx, 7
	in al, dx
	mov ah, al
	mov al, 0
	ret

align 2
.io			dw 0
.drive			db 0
.device			db 0

align 4
.count			dd 0
.current_count		dd 0
.buffer			dd 0

align 8
.lba			dq 0
.err_msg		db "Error in ATA device ",0
.err_msg2		db ", command 0x",0
.err_msg3		db ", LBA 0x",0
.err_msg4		db ", count 0x",0
.err_msg5		db ", status 0x",0

; ata_write:
; Writes to an ATA device
; In\	EDX:EAX = LBA sector
; In\	ECX = Sector count
; In\	BL = Drive bitfield (bit 0 for slave device, bit 1 for secondary channel)
; In\	ESI = Buffer to read sectors
; Out\	AL = 0 on success, 1 on error
; Out\	AH = Drive status register

ata_write:
	;cmp edx, 0
	;jne ata_write_lba48
	;cmp eax, 0xFFFFFFF-256
	;jge ata_write_lba48

	jmp ata_write_lba28

; ata_write_lba28:
; Writes to an ATA device using LBA28

ata_write_lba28:
	mov [.drive], bl
	mov [.count], ecx
	mov [.buffer], esi
	mov [.lba], eax
	mov [.current_count], 0

	cmp [.count], 0
	je .error

	test [.drive], 2		; secondary/primary channel?
	jnz .secondary

	mov dx, [ata_primary]
	mov [.io], dx
	jmp .check_device

.secondary:
	mov dx, [ata_secondary]
	mov [.io], dx

.check_device:
	test [.drive], 1		; primary/slave device?
	jnz .slave

	mov [.device], 0xE0
	jmp .start

.slave:
	mov [.device], 0xF0

.start:
	; first we need to send the highest 4 bits of the lba to the drive select port
	mov eax, [.lba]
	shr eax, 24		; keep only highest bits
	or al, [.device]
	mov dx, [.io]
	add dx, 6		; drive select port
	out dx, al
	call iowait

	; tell the controller we'll be using PIO
	mov dx, [.io]
	inc dx			; 0x1F1
	xor al, al
	out dx, al
	call iowait

	; sector count
	inc dx			; 0x1F2
	mov eax, [.count]
	out dx, al

	; LBA
	inc dx			; 0x1F3
	mov eax, [.lba]
	out dx, al
	inc dx			; 0x1F4
	shr eax, 8
	out dx, al
	inc dx			; 0x1F5
	shr eax, 8
	out dx, al
	inc dx
	inc dx			; 0x1F7

	mov al, ATA_WRITE_LBA28
	out dx, al
	call iowait

	in al, dx
	cmp al, 0
	je .error
	cmp al, 0xFF
	je .error

.wait_for_bsy:
	in al, dx
	test al, 0x80
	jnz .wait_for_bsy

.wait_for_drq:
	in al, dx
	test al, 8		; drq?
	jnz .write_sector
	test al, 1		; err?
	jnz .error
	test al, 0x20		; df?
	jnz .error
	jmp .wait_for_drq

.write_sector:
	; write a single sector
	mov esi, [.buffer]
	mov dx, [.io]
	mov ecx, 256

.write_sector_loop:
	outsw
	jmp .write_sector_delay

.write_sector_delay:
	loop .write_sector_loop

	mov [.buffer], esi

	; give the drive time to refresh its buffers and status
	call iowait
	call iowait

	inc [.current_count]
	mov ecx, [.count]
	cmp [.current_count], ecx
	jge .done

	mov dx, [.io]
	add dx, 7
	jmp .wait_for_drq

.error:
	mov esi, .err_msg
	call kprint
	movzx eax, [.drive]
	call int_to_string
	call kprint
	mov esi, .err_msg2
	call kprint
	mov al, ATA_WRITE_LBA28
	call hex_byte_to_string
	call kprint
	mov esi, .err_msg3
	call kprint
	mov eax, [.lba]
	call hex_dword_to_string
	call kprint
	mov esi, .err_msg4
	call kprint
	mov eax, [.count]
	call hex_byte_to_string
	call kprint
	mov esi, .err_msg5
	call kprint
	mov dx, [.io]
	add dx, 7
	in al, dx
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	mov dx, [.io]
	add dx, 7		; status
	in al, dx
	mov ah, al
	mov al, 1

	push eax
	call ata_reset
	pop eax
	ret

.flush_error:
	mov esi, .err_msg
	call kprint
	movzx eax, [.drive]
	call int_to_string
	call kprint
	mov esi, .err_msg2
	call kprint
	mov al, ATA_FLUSH_LBA28
	call hex_byte_to_string
	call kprint
	mov esi, .err_msg3
	call kprint
	mov eax, [.lba]
	call hex_dword_to_string
	call kprint
	mov esi, .err_msg4
	call kprint
	mov eax, [.count]
	call hex_byte_to_string
	call kprint
	mov esi, .err_msg5
	call kprint
	mov dx, [.io]
	add dx, 7
	in al, dx
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	mov dx, [.io]
	add dx, 7		; status
	in al, dx
	mov ah, al
	mov al, 1

	push eax
	call ata_reset
	pop eax
	ret

.done:
	; flush the device caches
	call iowait
	call iowait

	mov dx, [.io]
	add dx, 7
	mov al, ATA_FLUSH_LBA28
	out dx, al
	call iowait

.flush_wait:
	in al, dx
	test al, 0x80		; bsy
	jnz .flush_wait
	test al, 0x01		; err
	jnz .flush_error
	test al, 0x20		; df
	jnz .flush_error

.really_quit:
	in al, dx
	mov ah, al
	mov al, 0
	ret

align 2
.io			dw 0
.drive			db 0
.device			db 0

align 4
.count			dd 0
.current_count		dd 0
.buffer			dd 0
.lba			dd 0
.err_msg		db "Error in ATA device ",0
.err_msg2		db ", command 0x",0
.err_msg3		db ", LBA 0x",0
.err_msg4		db ", count 0x",0
.err_msg5		db ", status 0x",0

; ata_identify_data:
; Data returned from the ATA/ATAPI IDENTIFY command
align 16
ata_identify_data:
	.device_type		dw 0		; 0

	.cylinders		dw 0		; 1
	.reserved_word2		dw 0		; 2
	.heads			dw 0		; 3
				dd 0		; 4
	.sectors_per_track	dw 0		; 6
	.vendor_unique:		times 3 dw 0	; 7
	.serial_number:		times 20 db 0	; 10
				dd 0		; 11
	.obsolete1		dw 0		; 13
	.firmware_revision:	times 8 db 0	; 14
	.model:			times 40 db 0	; 18
	.maximum_block_transfer	db 0
				db 0
				dw 0

				db 0
	.dma_support		db 0
	.lba_support		db 0
	.iordy_disable		db 0
	.iordy_support		db 0
				db 0
	.standyby_timer_support	db 0
				db 0
				dw 0

				dd 0
	.translation_fields	dw 0
				dw 0
	.current_cylinders	dw 0
	.current_heads		dw 0
	.current_spt		dw 0
	.current_sectors	dd 0
				db 0
				db 0
				db 0
	.user_addressable_secs	dd 0
				dw 0
	times 512 - ($-ata_identify_data) db 0


