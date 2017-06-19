
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Socket Functions, abstract TCP and UDP internal functionality..

;
;
; struct socket
; {
;	u8 flags;
;	u8 protocol;		// 0 = TCP, 1 = UDP
;	u16 window;		// 512 for UDP
;	u32 seq;		// TCP: sequence of next packet to be sent, unused for UDP
;	u32 ack;		// TCP: acknowledge of next packet to be sent, unused for UDP
;	u32 ip;			// remote IP address
;	u16 source;		// source port
;	u16 dest;		// destination port
;	u32 initial_seq;	// TCP: SEQ from initial SYN response, UDP: unused
;	u8 reserved[12];
; }
;
;

SOCKET_FLAGS			= 0x00
SOCKET_PROTOCOL			= 0x01
SOCKET_WINDOW			= 0x02
SOCKET_SEQ			= 0x04
SOCKET_ACK			= 0x08
SOCKET_IP			= 0x0C
SOCKET_SOURCE			= 0x10
SOCKET_DEST			= 0x12
SOCKET_INITIAL_SEQ		= 0x14
SOCKET_SIZE			= 0x20

MAX_SOCKETS			= 512

SOCKET_FLAGS_PRESENT		= 0x01

SOCKET_PROTOCOL_TCP		= 0
SOCKET_PROTOCOL_UDP		= 1

TCP_WINDOW			= 32768	; default window size for TCP

; UDP doesn't actually support windows, but we use these internally
UDP_WINDOW			= 512		; maximum window size for UDP

SOCKET_TIMEOUT			= 3072

align 4
sockets				dd 0

; socket_find_handle:
; Finds a free socket handle
; In\	Nothing
; Out\	EAX = Socket handle, -1 on error

socket_find_handle:
	mov [.socket], 0

.loop:
	mov esi, [.socket]
	cmp esi, MAX_SOCKETS
	jge .error

	shl esi, 5
	add esi, [sockets]
	test byte[esi+SOCKET_FLAGS], SOCKET_FLAGS_PRESENT
	jz .found

	inc [.socket]
	jmp .loop

.found:
	mov eax, [.socket]
	ret

.error:
	mov eax, -1
	ret

align 4
.socket				dd 0

; socket_open:
; Opens a TCP/UDP socket connection
; In\	AL = Protocol type (0 = TCP, 1 = UDP)
; In\	EBX = Remote IP address
; In\	EDX = High WORD: destination port, low WORD: source port
; Out\	EAX = Socket handle, -1 on error

socket_open:
	cmp al, SOCKET_PROTOCOL_TCP
	je .open_tcp

	;cmp al, SOCKET_PROTOCOL_UDP
	;je .open_udp

	; undefined protocol
	mov [kprint_type], KPRINT_TYPE_ERROR
	mov esi, .undefined_protocol
	call kprint

	mov [kprint_type], KPRINT_TYPE_NORMAL
	mov eax, -1
	ret

.open_tcp:
	mov [.ip], ebx

	mov [.source], dx
	shr edx, 16
	mov [.dest], dx

	; find a free socket
	call socket_find_handle
	cmp eax, -1
	je .error
	mov [.socket], eax

	; create the socket handle
	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]

	mov byte[esi+SOCKET_FLAGS], SOCKET_FLAGS_PRESENT
	mov byte[esi+SOCKET_PROTOCOL], SOCKET_PROTOCOL_TCP
	mov word[esi+SOCKET_WINDOW], TCP_WINDOW
	mov dword[esi+SOCKET_SEQ], 0
	mov dword[esi+SOCKET_ACK], 0
	mov dword[esi+SOCKET_INITIAL_SEQ], 0

	mov eax, [.ip]
	mov [esi+SOCKET_IP], eax

	mov ax, [.source]
	mov [esi+SOCKET_SOURCE], ax

	mov ax, [.dest]
	mov [esi+SOCKET_DEST], ax

	; initialize a connection with the server by sending a SYN request
	mov ecx, TCP_WINDOW
	call kmalloc
	mov [.buffer], eax

	mov eax, [.socket]
	mov esi, 0		; no data payload
	mov ecx, 0
	mov dl, TCP_SYN
	call socket_write

	cmp eax, 0
	jne .error_close

	; we have to have a SYN+ACK response
	mov eax, [.socket]
	mov edi, [.buffer]
	call socket_read

	cmp dl, 0xFF
	je .error

	test dl, TCP_SYN
	jz .error

	test dl, TCP_ACK
	jz .error

	; CX = window size
	;and ecx, 0xFFFF
	;mov esi, [.socket]
	;shl esi, 5
	;add esi, [sockets]
	;mov [esi+SOCKET_WINDOW], ecx

	; now we respond with ACK
	mov eax, [.socket]
	mov esi, 0
	mov ecx, 0
	mov dl, TCP_ACK
	call socket_write

	cmp eax, 0
	jne .error_close

	; finished..
	mov eax, [.buffer]
	call kfree

	mov eax, [.socket]
	ret

.error_close:
	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]
	xor al, al
	mov ecx, SOCKET_SIZE
	rep stosb

	mov eax, [.buffer]
	call kfree

.error:
	mov eax, -1
	ret

align 4
.ip				dd 0
.socket				dd 0
.buffer				dd 0
.source				dw 0
.dest				dw 0

.undefined_protocol		db "net-socket: cannot open socket with undefined protocol.",10,0

; socket_close:
; Closes a socket
; In\	EAX = Socket handle
; Out\	Nothing

socket_close:
	cmp eax, MAX_SOCKETS
	jge .return

	mov [.socket], eax

	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]

	mov al, [esi+SOCKET_FLAGS]
	test al, SOCKET_FLAGS_PRESENT
	jz .return

	mov al, [esi+SOCKET_PROTOCOL]
	cmp al, SOCKET_PROTOCOL_TCP
	je .tcp

	;cmp al, SOCKET_PROTOCOL_UDP
	;je .udp

	mov [kprint_type], KPRINT_TYPE_ERROR
	mov esi, .undefined_protocol
	call kprint
	mov [kprint_type], KPRINT_TYPE_NORMAL
	ret

.tcp:
	mov ecx, TCP_WINDOW
	call kmalloc
	mov [.buffer], eax

	; send a FIN packet
	mov eax, [.socket]
	mov esi, 0
	mov ecx, 0
	mov dl, TCP_FIN or TCP_ACK
	call socket_write

	;cmp eax, 0
	;jne .tcp_finish

	; wait for server's response --
	; -- it should response with FIN+ACK
	mov [.wait_count], 0

.tcp_wait_fin_ack:
	inc [.wait_count]
	cmp [.wait_count], 2
	jg .tcp_finish

	mov eax, [.socket]
	mov edi, [.buffer]
	call socket_read

	cmp dl, 0xFF
	je .tcp_wait_fin_ack

	test dl, TCP_FIN
	jz .tcp_wait_fin_ack

	test dl, TCP_ACK
	jz .tcp_wait_fin_ack

	; okay, send ACK
	mov eax, [.socket]
	mov esi, 0
	mov ecx, 0
	mov dl, TCP_ACK
	call socket_write

	jmp .tcp_finish

.tcp_fin:
	test dl, TCP_ACK
	jz .tcp_fin_ack

	; send an ACK packet
	mov eax, [.socket]
	mov esi, 0
	mov ecx, 0
	mov dl, TCP_ACK
	call socket_write
	jmp .tcp_finish

.tcp_fin_ack:
	; send a FIN+ACK packet
	mov eax, [.socket]
	mov esi, 0
	mov ecx, 0
	mov dl, TCP_ACK or TCP_FIN
	call socket_write
	jmp .tcp_finish

.tcp_finish:
	; clear the socket handle
	mov edi, [.socket]
	shl edi, 5
	add edi, [sockets]
	mov ecx, SOCKET_SIZE
	xor al, al
	rep stosb

	ret

.return:
	ret

align 4
.socket				dd 0
.buffer				dd 0
.wait_count			dd 0

.undefined_protocol		db "net-socket: cannot close socket with undefined protocol.",10,0

; socket_write:
; Writes to a socket
; In\	EAX = Socket handle
; In\	ESI = Data payload
; In\	ECX = Data payload size
; In\	DL = Flags for TCP, unused for UDP
; Out\	EAX = 0 on success

socket_write:
	cmp eax, MAX_SOCKETS
	jge .error

	mov [.socket], eax
	mov [.payload], esi
	mov [.size], ecx
	mov [.flags], dl

	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]

	mov al, [esi+SOCKET_FLAGS]
	test al, SOCKET_FLAGS_PRESENT
	jz .error

	mov al, [esi+SOCKET_PROTOCOL]
	cmp al, SOCKET_PROTOCOL_TCP
	je .write_tcp

	;cmp al, SOCKET_PROTOCOL_UDP
	;je .write_udp

	mov [kprint_type], KPRINT_TYPE_ERROR
	mov esi, .undefined_protocol
	call kprint

	mov [kprint_type], KPRINT_TYPE_NORMAL
	mov eax, -1
	ret

.write_tcp:
	; allocate memory for the buffer which will be passed to the TCP layer
	mov ecx, [.size]
	add ecx, TCP_HEADER_SIZE
	call kmalloc
	mov [.buffer], eax

	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]

	mov eax, [esi+SOCKET_IP]
	mov [.ip], eax
	mov eax, [esi+SOCKET_SEQ]
	mov [.seq], eax
	mov eax, [esi+SOCKET_ACK]
	mov [.ack], eax
	movzx eax, word[esi+SOCKET_WINDOW]
	mov [.window], eax
	mov ax, [esi+SOCKET_SOURCE]
	mov [.source], ax
	mov ax, [esi+SOCKET_DEST]
	mov [.dest], ax

	; the buffer has a 16-byte header
	; DWORD: seq
	; DWORD: ack
	; DWORD: flags
	; DWORD: window size
	mov edi, [.buffer]
	mov eax, [.seq]
	stosd
	mov eax, [.ack]
	stosd
	movzx eax, [.flags]
	stosd
	mov eax, [.window]
	stosd

	mov esi, [.payload]
	mov ecx, [.size]
	rep movsb

	; okay, transmit the packet
	mov eax, [my_ip]			; source IP is us
	mov ebx, [.ip]				; destination IP is the host
	mov ecx, [.size]
	movzx edx, [.dest]
	shl edx, 16
	mov dx, [.source]
	mov esi, [.buffer]
	mov edi, router_mac
	call tcp_send

	push eax
	mov eax, [.buffer]
	call kfree

	pop eax
	ret

.error:
	mov eax, -1
	ret

align 4
.socket				dd 0
.payload			dd 0
.size				dd 0
.buffer				dd 0
.ip				dd 0
.seq				dd 0
.ack				dd 0
.window				dd 0
.dest				dw 0
.source				dw 0
.flags				db 0

.undefined_protocol		db "net-socket: cannot write to socket with undefined protocol.",10,0

; socket_read:
; Reads from socket
; In\	EAX = Socket handle
; In\	EDI = Buffer to read to
; Out\	EAX = Payload size read
; Out\	CX = TCP: window size, UDP: zero
; Out\	DL = TCP: flags, UDP: zero

socket_read:
	cmp eax, MAX_SOCKETS
	jge .error

	mov [.socket], eax
	mov [.buffer], edi

	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]

	mov al, [esi+SOCKET_FLAGS]
	test al, SOCKET_FLAGS_PRESENT
	jz .error

	mov al, [esi+SOCKET_PROTOCOL]
	cmp al, SOCKET_PROTOCOL_TCP
	je .read_tcp

	;cmp al, SOCKET_PROTOCOL_UDP
	;je .read_udp

	mov [kprint_type], KPRINT_TYPE_ERROR
	mov esi, .undefined_protocol
	call kprint

	mov [kprint_type], KPRINT_TYPE_NORMAL
	mov eax, -1
	ret

.read_tcp:
	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]

	mov eax, [esi+SOCKET_IP]
	mov [.ip], eax

	movzx ecx, word[esi+SOCKET_WINDOW]
	call kmalloc
	mov [.packet], eax

	mov [.packet_count], 0

.receive_tcp_start:
	mov [.wait_loops], 0
	inc [.packet_count]
	cmp [.packet_count], SOCKET_TIMEOUT / 2
	jg .error_free

.receive_tcp_loop:
	;sti
	;hlt

	inc [.wait_loops]
	cmp [.wait_loops], SOCKET_TIMEOUT
	jge .receive_tcp_start

	mov edi, [.packet]
	call net_receive

	cmp eax, -1
	je .receive_tcp_loop

	cmp eax, 0
	jne .check_tcp_received

	jmp .receive_tcp_loop

.check_tcp_received:
	; destination has to be our MAC
	mov esi, [.packet]
	mov edi, my_mac
	mov ecx, 6
	rep cmpsb
	jne .receive_tcp_start

	; packet type has to be IP
	mov esi, [.packet]
	mov ax, [esi+12]
	xchg al, ah
	cmp ax, IP_PROTOCOL_TYPE
	jne .receive_tcp_start

	add esi, ETHERNET_HEADER_SIZE
	mov eax, [esi+12]		; source IP
	cmp eax, [.ip]
	jne .receive_tcp_start

	mov eax, [esi+16]		; destination IP
	cmp eax, [my_ip]		; has to be ours
	jne .receive_tcp_start

	mov al, [esi+9]
	cmp al, TCP_PROTOCOL_TYPE
	jne .receive_tcp_start

	; this packet is for us, but it may or may not be in the correct order
	; for simplicity, only accept packets sent in order
	; most servers will resend them if we don't respond anyway
	mov ax, [esi+2]
	xchg al, ah
	movzx eax, ax
	mov [.ip_size], eax

	add esi, IP_HEADER_SIZE		; to TCP header
	mov [.tcp], esi

	mov esi, [.tcp]
	mov al, [esi+13]
	test al, TCP_SYN		; did we receive a SYN packet?
	jz .tcp_work

	; yep -- save the initial sequence
	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]
	mov edi, [.tcp]
	mov eax, [edi+4]		; SEQ
	bswap eax			; big endian
	;inc eax
	mov [esi+SOCKET_INITIAL_SEQ], eax

.tcp_work:
	mov esi, [.tcp]
	mov al, [esi+13]
	test al, TCP_SYN
	jnz .tcp_copy_payload

	; ensure it is in the correct order
	; the SEQ of the packet has to be the ACK we last sent
	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]
	mov eax, [esi+SOCKET_ACK]
	mov [.last_ack], eax
	mov edi, [.tcp]
	mov eax, [edi+4]
	bswap eax
	sub eax, [esi+SOCKET_INITIAL_SEQ]
	mov ebx, [.last_ack]
	sub ebx, [esi+SOCKET_INITIAL_SEQ]

	;pusha
	;call hex_dword_to_string
	;call com1_send
	;mov esi, newline
	;call com1_send

	;popa
	;pusha
	;mov eax, ebx
	;call hex_dword_to_string
	;call com1_send
	;mov esi, newline
	;call com1_send

	;popa

	mov [.my_seq], ebx
	mov [.receive_seq], eax

	sub eax, ebx
	test eax, 0x80000000
	jnz .tcp_seq_negative

	jmp .tcp_check_seq

.tcp_seq_negative:
	not eax
	inc eax

.tcp_check_seq:
	cmp eax, 1
	jg .tcp_drop_packet

	jmp .tcp_copy_payload

.tcp_drop_packet:
	; tell the log that we're dropping a packet
	mov [kprint_type], KPRINT_TYPE_WARNING
	mov esi, .tcp_drop_msg
	call kprint
	mov eax, [.my_seq]
	call int_to_string
	call kprint
	mov esi, .tcp_drop_msg2
	call kprint
	mov eax, [.receive_seq]
	call int_to_string
	call kprint
	mov esi, .tcp_drop_msg3
	call kprint

	mov [kprint_type], KPRINT_TYPE_NORMAL
	jmp .receive_tcp_start

.tcp_copy_payload:
	mov esi, [.tcp]
	mov bl, [esi+12]
	shr bl, 4
	and bl, 0x0F
	and ebx, 0xFF
	shl ebx, 2			; ebx = TCP header size
	mov [.tcp_header], ebx

	mov eax, [.ip_size]
	sub eax, IP_HEADER_SIZE
	sub eax, ebx
	mov [.payload_size], eax

	; copy the payload into the buffer pointed by the application
	mov edi, [.buffer]
	mov esi, [.tcp]
	add esi, [.tcp_header]
	mov ecx, [.payload_size]
	rep movsb

	; update the socket handle with the new ack and seq
	mov esi, [.tcp]
	mov eax, [esi+4]
	bswap eax
	mov [.seq], eax

	mov eax, [esi+8]
	bswap eax
	mov [.ack], eax

	mov esi, [.socket]
	shl esi, 5
	add esi, [sockets]

	mov eax, [.ack]
	mov [esi+SOCKET_SEQ], eax

	mov eax, [.seq]
	mov ebx, [.payload_size]
	cmp ebx, 0
	je .tcp_payload_zero

	add eax, ebx
	jmp .tcp_set_ack

.tcp_payload_zero:
	inc eax

.tcp_set_ack:
	mov [esi+SOCKET_ACK], eax

.tcp_finish:
	; okay, we're finished
	mov eax, [.payload_size]
	mov esi, [.tcp]
	mov cx, [esi+14]		; window size
	xchg cl, ch
	mov dl, [esi+13]		; TCP flags

	pusha
	mov eax, [.packet]
	call kfree
	popa

	ret

.error_free:
	mov eax, [.packet]
	call kfree

.error:
	mov eax, 0
	mov cx, 0xFFFF
	mov dl, 0xFF
	ret

align 4
.socket				dd 0
.buffer				dd 0
.wait_loops			dd 0
.packet_count			dd 0
.packet				dd 0
.ip				dd 0
.ip_size			dd 0
.payload_size			dd 0
.tcp				dd 0
.tcp_header			dd 0
.ack				dd 0
.seq				dd 0
.last_ack			dd 0
.my_seq				dd 0
.receive_seq			dd 0

.window				dw 0
.flags				db 0

.undefined_protocol		db "net-socket: cannot read from socket with undefined protocol.",10,0
.tcp_drop_msg			db "net-tcp: expected SEQ ",0
.tcp_drop_msg2			db " but got SEQ ",0
.tcp_drop_msg3			db ", dropping packet...",10,0





