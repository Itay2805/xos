
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; HyperText Transfer Protocol
HTTP_SOURCE_PORT			= 32768
HTTP_DESTINATION_PORT			= 80
HTTP_DEBUG_PORT				= 8080		; probably not needed..

HTTP_TIMEOUT				= 0x200000
HTTP_INITIAL_SEQ			= 0x00000000

http_get_string				db "GET "
http_head_string			db "HEAD "
http_version_string			db "HTTP/1.1"
http_user_agent_string			db "User-Agent: xOS kernel HTTP layer",0
http_host_string			db "Host: ",0
http_accept_language_string		db "Accept-Language: en-us",0
http_keep_alive_string			db "Connection: Keep-Alive",0

; http_copy_domain:
; Copies the domain name of a URI, stripping the "http://" if it is present
; In\	ESI = URI
; In\	EDI = Buffer
; Out\	Nothing

http_copy_domain:
	cmp dword[esi], "http"
	je .strip_http

	jmp .start

.strip_http:
	add esi, 7	; strlen("http://");

.start:
	lodsb
	cmp al, 0
	je .done
	cmp al, 13
	je .done
	cmp al, 10
	je .done
	cmp al, '/'
	je .done

	stosb
	jmp .start

.done:
	xor al, al
	stosb

	ret

; http_copy_path:
; Copies the path of a URI
; In\	ESI = URI
; In\	EDI = Buffer
; Out\	Nothing

http_copy_path:
	cmp dword[esi], "http"
	je .strip_http

	jmp .skip_domain

.strip_http:
	add esi, 7

.skip_domain:
	lodsb
	cmp al, '/'
	je .copy_path

	cmp al, 0
	je .root_path

	cmp al, 13
	je .root_path

	cmp al, 10
	je .root_path

	jmp .skip_domain

.copy_path:
	dec esi
	call strlen
	mov ecx, eax
	rep movsb

	xor al, al
	stosb

	ret

.root_path:
	mov al, '/'
	stosb

	xor al, al
	stosb

	ret

; http_close_connection:
; Closes an HTTP connection
; In\	EAX = IP address
; In\	EBX = ACK number
; In\	ECX = Sequence number
; In\	EDX = Payload size
; Out\	Nothing

http_close_connection:
	mov [.ip], eax
	mov [.ack], ebx
	mov [.seq], ecx
	mov [.size], edx

	mov ecx, 16384
	call kmalloc
	mov [.buffer], eax

.start:
	; receive packets until we have a FIN packet
	; if we have PSH, ignore and just send ACK
	; if we receive just ACK, send FIN ourselves
	mov edi, [.buffer]
	xor al, al
	mov ecx, 8192
	rep stosb

	mov [.packet_count], 0

.receive_packet_start:
	; receive a packet in the same buffer
	mov [.wait_loops], 0
	inc [.packet_count]
	cmp [.packet_count], HTTP_TIMEOUT
	jge .send_fin

.receive_packet_loop:
	inc [.wait_loops]
	cmp [.wait_loops], HTTP_TIMEOUT
	jg .send_fin

	mov edi, [.buffer]
	call net_receive

	cmp eax, 0
	jne .check_received_packet

	jmp .receive_packet_loop

.check_received_packet:
	mov [.response_size], eax

	mov esi, [.buffer]
	mov ax, [esi+12]
	xchg al, ah
	cmp ax, IP_PROTOCOL_TYPE	; IP packet?
	jne .receive_packet_start

	; read the IP packet
	mov esi, [.buffer]
	add esi, ETHERNET_HEADER_SIZE
	cmp byte[esi+9], TCP_PROTOCOL_TYPE	; TCP?
	jne .receive_packet_start

	add esi, IP_HEADER_SIZE			; to TCP packet

	mov eax, [esi+4]
	bswap eax
	mov [.seq], eax

	mov eax, [esi+8]
	bswap eax
	mov [.ack], eax

	; is it a FIN packet?
	mov al, [esi+13]
	test al, TCP_FIN
	jnz .server_fin

	; does it have a payload?
	test al, TCP_PSH
	jnz .handle_push

	; just an ACK?
	test al, TCP_ACK
	jnz .send_fin

	jmp .receive_packet_start

.server_fin:
	; server sent FIN - we have to send FIN + ACK
	mov edi, .tcp_header
	mov eax, [.ack]
	stosd
	mov eax, [.seq]
	cmp [.response_size], 0
	je .server_fin_zero

	add eax, [.response_size]
	jmp .server_fin_work
 
.server_fin_zero:
	inc eax

.server_fin_work:
	stosd
	mov eax, TCP_FIN or TCP_ACK
	stosd
	mov eax, 8192
	stosd

	mov eax, [my_ip]
	mov ebx, [.ip]
	mov ecx, 0
	mov edx, (HTTP_DESTINATION_PORT shl 16) or HTTP_SOURCE_PORT
	mov esi, .tcp_header
	mov edi, router_mac
	call tcp_send

	mov eax, [.buffer]
	call kfree

	ret

.handle_push:
	; server sent PSH - we have to send ACK
	mov edi, .tcp_header
	mov eax, [.ack]
	stosd
	mov eax, [.seq]
	add eax, [.response_size]
	stosd
	mov eax,TCP_ACK
	stosd
	mov eax, 8192
	stosd

	mov eax, [my_ip]
	mov ebx, [.ip]
	mov ecx, 0
	mov edx, (HTTP_DESTINATION_PORT shl 16) or HTTP_SOURCE_PORT
	mov esi, .tcp_header
	mov edi, router_mac
	call tcp_send

	jmp .receive_packet_start

.send_fin:
	mov edi, .tcp_header
	mov eax, [.ack]
	stosd
	mov eax, [.seq]
	inc eax			; payload size zero
	stosd
	mov eax, TCP_FIN or TCP_ACK
	stosd
	mov eax, 8192
	stosd

	mov eax, [my_ip]
	mov ebx, [.ip]
	mov ecx, 0
	mov edx, (HTTP_DESTINATION_PORT shl 16) or HTTP_SOURCE_PORT
	mov esi, .tcp_header
	mov edi, router_mac
	call tcp_send

	mov eax, [.buffer]
	call kfree

	ret

align 4
.ip				dd 0
.ack				dd 0
.seq				dd 0
.size				dd 0
.buffer				dd 0
.wait_loops			dd 0
.packet_count			dd 0
.response_size			dd 0

.tcp_header:
	.tcp_seq		dd 0
	.tcp_ack		dd 0
	.tcp_flags		dd 0
	.tcp_window		dd 0

; http_head:
; Performs an HTTP HEAD request
; In\	ESI = URI
; Out\	EAX = Buffer, -1 on error

http_head:
	cmp [network_available], 1
	jne .error

	mov [.uri], esi

	mov ecx, 16384
	call kmalloc
	mov [.packet], eax

	mov edi, .domain
	xor al, al
	mov ecx, 256
	rep stosb

	mov edi, .path
	mov ecx, 256
	rep stosb

	; copy the domain and the path
	mov esi, [.uri]
	mov edi, .domain
	call http_copy_domain

	mov esi, [.uri]
	mov edi, .path
	call http_copy_path

	; resolve the IP using DNS
	mov esi, .domain
	call dns_request
	cmp eax, 0
	je .error

	mov [.ip], eax

	; okay, create a connection with the server
	mov edi, .tcp_header
	mov eax, HTTP_INITIAL_SEQ		; sequence zero
	stosd
	mov eax, 0			; ack zero
	stosd
	mov eax, TCP_SYN		; SYN request
	stosd
	mov eax, 8192			; window size
	stosd

	mov eax, [my_ip]
	mov ebx, [.ip]
	mov ecx, 0
	mov edx, (HTTP_DESTINATION_PORT shl 16) or HTTP_SOURCE_PORT
	mov esi, .tcp_header
	mov edi, router_mac
	call tcp_send
	cmp eax, 0
	jne .error

	; receive the response, it should be SYN | ACK
	mov edi, [.packet]
	mov al, 0
	mov ecx, 8192
	rep stosb

	mov [.packet_count], 0

.receive_syn_start:
	; receive a packet in the same buffer
	mov [.wait_loops], 0
	inc [.packet_count]
	cmp [.packet_count], HTTP_TIMEOUT
	jge .error

.receive_syn_loop:
	inc [.wait_loops]
	cmp [.wait_loops], HTTP_TIMEOUT
	jg .error

	mov edi, [.packet]
	call net_receive

	cmp eax, 0
	jne .check_received_syn

	jmp .receive_syn_loop

.check_received_syn:
	mov esi, [.packet]
	mov ax, [esi+12]
	xchg al, ah
	cmp ax, IP_PROTOCOL_TYPE	; IP packet?
	jne .receive_syn_start

	; read the IP packet
	mov esi, [.packet]
	add esi, ETHERNET_HEADER_SIZE
	cmp byte[esi+9], TCP_PROTOCOL_TYPE	; TCP?
	jne .receive_syn_start

	add esi, IP_HEADER_SIZE			; to TCP packet

	mov eax, [esi+8]			; ack should be one
	bswap eax
	cmp eax, HTTP_INITIAL_SEQ+1
	jne .receive_syn_start

	mov [.response_ack], eax

	mov eax, [esi+4]			; seq
	bswap eax
	mov [.response_seq], eax

	mov ax, [esi+14]
	xchg al, ah
	and eax, 0xFFFF
	mov [.window], eax			; window size

	mov al, [esi+13]			; flags

	; check for SYN + ACK
	test al, TCP_SYN
	jz .receive_syn_start

	test al, TCP_ACK
	jz .receive_syn_start

	; okay, send an ACK
	mov edi, .tcp_header
	mov eax, [.response_ack]		; sequence
	stosd
	mov eax, [.response_seq]		; ack
	inc eax
	stosd
	mov eax, TCP_ACK			; flags
	stosd
	mov eax, [.window]			; window size
	stosd

	mov eax, [my_ip]
	mov ebx, [.ip]
	mov ecx, 0
	mov edx, (HTTP_DESTINATION_PORT shl 16) or HTTP_SOURCE_PORT
	mov esi, .tcp_header
	mov edi, router_mac
	call tcp_send
	cmp eax, 0
	jne .error

	; now construct the HTTP request
	mov edi, [.packet]
	xor al, al
	mov ecx, 8192
	rep stosb

	; request line
	mov edi, [.packet]
	add edi, 4*4
	mov esi, http_head_string
	mov ecx, 5
	rep movsb

	mov esi, .path
	call strlen
	mov ecx, eax
	rep movsb
	mov al, ' '
	stosb

	mov esi, http_version_string
	mov ecx, 8
	rep movsb

	mov al, 13
	stosb
	mov al, 10
	stosb

	; user agent string
	mov esi, http_user_agent_string
	call strlen
	mov ecx, eax
	rep movsb

	mov al, 13
	stosb
	mov al, 10
	stosb

	; host
	mov esi, http_host_string
	mov ecx, 6
	rep movsb

	mov esi, .domain
	call strlen
	mov ecx, eax
	rep movsb

	mov al, 13
	stosb
	mov al, 10
	stosb

	mov esi, http_accept_language_string
	call strlen
	mov ecx, eax
	rep movsb

	mov al, 13
	stosb
	mov al, 10
	stosb

	mov esi, http_keep_alive_string
	call strlen
	mov ecx, eax
	rep movsb

	; empty lines indicate end of request
	mov al, 13
	stosb
	mov al, 10
	stosb
	mov al, 13
	stosb
	mov al, 10
	stosb

	sub edi, [.packet]
	add edi, 4*4
	mov [.size], edi

	; okay, construct the TCP header above the packet
	mov edi, [.packet]
	mov eax, [.response_ack]		; sequence
	stosd
	mov eax, [.response_seq]		; ack
	inc eax
	stosd
	mov eax, TCP_ACK or TCP_PSH		; flags
	stosd
	mov eax, [.window]			; window size
	stosd

	mov eax, [my_ip]
	mov ebx, [.ip]
	mov ecx, [.size]
	mov edx, (HTTP_DESTINATION_PORT shl 16) or HTTP_SOURCE_PORT
	mov esi, [.packet]
	mov edi, router_mac
	call tcp_send
	cmp eax, 0
	jne .error

	; we should have an ACK now
	mov edi, [.packet]
	mov al, 0
	mov ecx, 8192
	rep stosb

	mov [.packet_count], 0

.receive_ack_start:
	; receive a packet in the same buffer
	mov [.wait_loops], 0
	inc [.packet_count]
	cmp [.packet_count], HTTP_TIMEOUT
	jge .error

.receive_ack_loop:
	inc [.wait_loops]
	cmp [.wait_loops], HTTP_TIMEOUT
	jg .error

	mov edi, [.packet]
	call net_receive

	cmp eax, 0
	jne .check_received_ack

	jmp .receive_ack_loop

.check_received_ack:
	mov esi, [.packet]
	mov ax, [esi+12]
	xchg al, ah
	cmp ax, IP_PROTOCOL_TYPE	; IP packet?
	jne .receive_ack_start

	; read the IP packet
	mov esi, [.packet]
	add esi, ETHERNET_HEADER_SIZE
	cmp byte[esi+9], TCP_PROTOCOL_TYPE	; TCP?
	jne .receive_ack_start

	add esi, IP_HEADER_SIZE			; to TCP packet

	mov eax, [esi+8]			; ack should be one
	bswap eax
	mov ebx, HTTP_INITIAL_SEQ+1
	add ebx, [.size]
	cmp eax, ebx
	jne .receive_ack_start

	mov [.response_ack], eax

	mov eax, [esi+4]			; seq
	bswap eax
	mov [.response_seq], eax

	mov al, [esi+13]			; flags

	; check for ACK
	test al, TCP_ACK
	jz .receive_ack_start

	; okay, receive the actual response
	mov edi, [.packet]
	mov al, 0
	mov ecx, 8192
	rep stosb

	mov [.packet_count], 0

.receive_response_start:
	; receive a packet in the same buffer
	mov [.wait_loops], 0
	inc [.packet_count]
	cmp [.packet_count], HTTP_TIMEOUT
	jge .error

.receive_response_loop:
	inc [.wait_loops]
	cmp [.wait_loops], HTTP_TIMEOUT
	jg .error

	mov edi, [.packet]
	call net_receive

	cmp eax, 0
	jne .check_received_response

	jmp .receive_response_loop

.check_received_response:
	mov [.response_size], eax

	mov esi, [.packet]
	mov ax, [esi+12]
	xchg al, ah
	cmp ax, IP_PROTOCOL_TYPE	; IP packet?
	jne .receive_response_start

	; read the IP packet
	mov esi, [.packet]
	add esi, ETHERNET_HEADER_SIZE
	cmp byte[esi+9], TCP_PROTOCOL_TYPE	; TCP?
	jne .receive_response_start

	add esi, IP_HEADER_SIZE			; to TCP packet

	mov eax, [esi+8]			; ack should be one
	bswap eax
	mov ebx, HTTP_INITIAL_SEQ+1
	add ebx, [.size]
	cmp eax, ebx
	jne .receive_response_start

	mov [.response_ack], eax

	mov eax, [esi+4]			; seq
	bswap eax
	mov [.response_seq], eax

	mov al, [esi+13]			; flags

	; check for ACK + PSH
	test al, TCP_ACK
	jz .receive_response_start
	test al, TCP_PSH
	jz .receive_response_start

	; okay, copy the packet
	pusha
	mov ecx, [.response_size]
	call malloc
	mov [.return], eax
	popa

	mov al, [esi+12]
	shr al, 4
	movzx eax, al
	shl eax, 2		; mul 4
	add esi, eax
	mov ecx, [.response_size]
	sub ecx, eax
	mov edi, [.return]
	rep movsb
	xor al, al
	stosb

	mov eax, [.ip]
	mov ebx, [.response_ack]
	mov ecx, [.response_seq]
	mov edx, [.response_size]
	call http_close_connection

	mov eax, [.packet]
	call kfree

	mov eax, [.return]
	ret

.error:
	mov eax, [.packet]
	call kfree

	mov eax, -1
	ret

align 4
.uri					dd 0
.ip					dd 0
.packet					dd 0
.wait_loops				dd 0
.packet_count				dd 0
.response_ack				dd 0
.response_seq				dd 0
.window					dd 0
.size					dd 0
.response_size				dd 0
.return					dd 0

.tcp_header:
	.tcp_seq			dd 0
	.tcp_ack			dd 0
	.tcp_flags			dd 0
	.tcp_window			dd 0

.domain:				times 256 db 0
.path:					times 256 db 0




