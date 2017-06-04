
rtl8139:
	.name		db "rtl8139.sys",0
			times 32 - ($-.name) db 0

	.lba		dd 1302
	.size_sects	dd 8
	.size_bytes	dd 8*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0


i8254x:
	.name		db "i8254x.sys",0
			times 32 - ($-.name) db 0

	.lba		dd 1311
	.size_sects	dd 8
	.size_bytes	dd 8*512
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x01		; file present
	.reserved:	times 13 db 0


