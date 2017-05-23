
; en-US keyboard layout scancodes

align 16
usb_ascii_codes:
	db 0, 0, 0, 0
	db "abcdefghijklmnopqrstuvwxyz1234567890"
	db 13		; enter
	db 27		; escape
	db 8		; backspace
	db "	"	; tab
	db " "		; space
	db "-=[]\", 0
	db ";'`,./"
	db 0		; Caps lock
	times 12 db 0	; F1 -> F12
	db 0		; prtscr
	db 0		; scroll lock
	db 0		; pause
	db 0		; insert
	db 0		; home
	db 0		; pgup
	db 0		; delete
	db 0		; end
	db 0		; pgdn
	db 0		; right
	dd 0		; left
	db 0		; down
	db 0		; up
	db 0		; numlock

	; NumPad
	db "/*-+", 13
	db "1234567890.",0
	times 256 - ($-usb_ascii_codes) db 0

align 16
usb_ascii_codes_shift:
	db 0, 0, 0, 0
	db "ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()"
	db 13		; enter
	db 27		; escape
	db 8		; backspace
	db "	"	; tab
	db " "		; space
	db "_+{}|", 0
	db ":"
	db '"'
	db "~<>?"
	db 0		; Caps lock
	times 12 db 0	; F1 -> F12
	db 0		; prtscr
	db 0		; scroll lock
	db 0		; pause
	db 0		; insert
	db 0		; home
	db 0		; pgup
	db 0		; delete
	db 0		; end
	db 0		; pgdn
	db 0		; right
	dd 0		; left
	db 0		; down
	db 0		; up
	db 0		; numlock

	; NumPad
	db "/*-+", 13
	db "1234567890.",0
	times 256 - ($-usb_ascii_codes_shift) db 0

align 16
ps2_ascii_codes:
	db 0,27
	db "1234567890-=",8
	db "	"
	db "qwertyuiop[]",13,0
	db "asdfghjkl;'`",0
	db "\zxcvbnm,./",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,"789"
	db "-456+"
	db "1230."
	times 128 - ($-ps2_ascii_codes) db 0

align 16
ps2_ascii_codes_caps_lock:
	db 0,27
	db "1234567890-=",8
	db "	"
	db "QWERTYUIOP[]",13,0
	db "ASDFGHJKL;'`",0
	db "\ZXCVBNM,./",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,"789"
	db "-456+"
	db "1230."
	times 128 - ($-ps2_ascii_codes_caps_lock) db 0

align 16
ps2_ascii_codes_shift:
	db 0,27
	db "!@#$%^&*()_+",8
	db "	"
	db "QWERTYUIOP{}",13,0
	db "ASDFGHJKL:", '"', "~",0
	db "|ZXCVBNM<>?",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,"789"
	db "-456+"
	db "1230."
	times 128 - ($-ps2_ascii_codes_shift) db 0

align 16
ps2_ascii_codes_shift_caps_lock:
	db 0,27
	db "!@#$%^&*()_+",8
	db "	"
	db "qwertyuiop{}",13,0
	db "asdfghjkl:", '"', "~",0
	db "|zxcvbnm<>?",0
	db "*",0
	db " "
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,"789"
	db "-456+"
	db "1230."
	times 128 - ($-ps2_ascii_codes_shift_caps_lock) db 0



