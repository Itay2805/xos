
netio:
	.name		db "netio",0
			times 32 - ($-.name) db 0

	.lba		dd 1301
	.size_sects	dd 1
	.size_bytes	dd 2
	.time		db 10+12
			db 48
	.date		db 2, 2
	.year		dw 2017
	.flags		db 0x03		; file present
	.reserved:	times 13 db 0
