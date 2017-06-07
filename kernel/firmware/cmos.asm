
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; CMOS Registers Index
CMOS_REGISTER_SECOND		= 0x00
CMOS_REGISTER_MINUTE		= 0x02
CMOS_REGISTER_HOUR		= 0x04
CMOS_REGISTER_DAY		= 0x07
CMOS_REGISTER_MONTH		= 0x08
CMOS_REGISTER_YEAR		= 0x09
CMOS_REGISTER_STATUS_A		= 0x0A
CMOS_REGISTER_STATUS_B		= 0x0B
CMOS_REGISTER_DEFAULT_CENTURY	= 0x32

cmos_century			db CMOS_REGISTER_DEFAULT_CENTURY	; should read this from acpi fadt..

; cmos_init:
; Initializes the CMOS

cmos_init:
	; read century register from ACPI FADT
	mov al, [acpi_fadt.century]
	cmp al, 0
	je .default_century

	mov [cmos_century], al
	jmp .done

.default_century:
	mov [cmos_century], CMOS_REGISTER_DEFAULT_CENTURY

.done:
	ret

; bcd_byte_to_dec:
; Converts a BCD byte to a decimal integer
; In\	AL = BCD
; Out\	AL = Decimal

bcd_byte_to_dec:
	mov [.bcd], al

	mov [.dec], al
	and [.dec], 0xF

	shr al, 4
	movzx eax, al
	mov ebx, 10
	mul ebx
	add [.dec], al

	mov al, [.dec]
	ret

.bcd				db 0
.dec				db 0

; cmos_read:
; Reads a CMOS register
; In\	CL = Index
; Out\	AL = Value

cmos_read:
	mov al, cl
	out 0x70, al
	call iowait
	in al, 0x71
	ret

; cmos_write:
; Writes to a CMOS register
; In\	AL = Value
; In\	CL = Index
; Out\	Nothing

cmos_write:
	push eax
	mov al, cl
	out 0x70, al
	call iowait
	pop eax
	out 0x71, al
	call iowait

	ret

; cmos_read_time:
; Returns the current time from the CMOS chip
; In\	Nothing
; Out\	AH:AL:BL = Hours:Minutes:Seconds

cmos_read_time:
	mov cl, CMOS_REGISTER_SECOND
	call cmos_read
	call bcd_byte_to_dec
	mov [.second], al

	mov cl, CMOS_REGISTER_MINUTE
	call cmos_read
	call bcd_byte_to_dec
	mov [.minute], al

	mov cl, CMOS_REGISTER_HOUR
	call cmos_read
	mov [.hour_bcd], al

	; check for 24 hour or 12 hour time
	mov cl, CMOS_REGISTER_STATUS_B
	call cmos_read
	test al, 2
	jnz .24_hour

.12_hour:
	; for 12 hour, determine AM or PM
	test [.hour_bcd], 0x80
	jnz .pm

.am:
	cmp [.hour_bcd], 0x12
	je .12_am

	mov al, [.hour_bcd]
	call bcd_byte_to_dec
	mov [.hour], al
	jmp .done

.12_am:
	mov [.hour], 0
	jmp .done

.pm:
	mov al, [.hour_bcd]
	and al, not 0x80	; mask off the highest bit
	call bcd_byte_to_dec
	add al, 12		; to PM
	mov [.hour], al
	jmp .done

.24_hour:
	mov al, [.hour_bcd]
	call bcd_byte_to_dec
	mov [.hour], al

.done:
	mov ah, [.hour]
	mov al, [.minute]
	mov bl, [.second]
	ret

.hour			db 0
.minute			db 0
.second			db 0
.hour_bcd		db 0

; cmos_read_date:
; Reads the date from the CMOS chip
; In\	Nothing
; Out\	CL/CH/DX = Day/Month/Year

cmos_read_date:
	mov cl, CMOS_REGISTER_DAY
	call cmos_read
	call bcd_byte_to_dec
	mov [.day], al

	mov cl, CMOS_REGISTER_MONTH
	call cmos_read
	call bcd_byte_to_dec
	mov [.month], al

	mov cl, CMOS_REGISTER_YEAR
	call cmos_read
	call bcd_byte_to_dec
	and ax, 0xFF
	mov [.year], ax

	mov cl, [cmos_century]
	call cmos_read
	call bcd_byte_to_dec
	and eax, 0xFF
	mov ebx, 100		; century
	mul ebx
	add [.year], ax

	mov cl, [.day]
	mov ch, [.month]
	mov dx, [.year]

	ret

.day			db 0
.month			db 0
.year			dw 0

; cmos_get_time:
; Returns current time
; In\	Nothing
; Out\	AH:AL:BL = Hours:Minutes:Seconds
; Out\	CL/CH/DX = Day/Month/Year

cmos_get_time:
	mov cl, CMOS_REGISTER_STATUS_A
	call cmos_read
	test al, 0x80			; update in progress?
	jnz .return

	call cmos_read_time
	mov [.hour], ah
	mov [.minute], al
	mov [.second], bl

	call cmos_read_date
	mov [.day], cl
	mov [.month], ch
	mov [.year], dx

.return:
	mov ah, [.hour]
	mov al, [.minute]
	mov bl, [.second]

	mov cl, [.day]
	mov ch, [.month]
	mov dx, [.year]

	ret

.hour			db 0
.minute			db 0
.second			db 0

.day			db 0
.month			db 0
.year			dw 0


