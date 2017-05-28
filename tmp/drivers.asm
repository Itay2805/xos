
rtl8139:
	.name		db "rtl8139.sys",0
			times 32 - ($-.name) db 0

	.lba		dd 1301
	.size_sects	dd 50
	.size_bytes	dd 50*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0


