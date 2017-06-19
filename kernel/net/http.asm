
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; HyperText Transfer Protocol
HTTP_DESTINATION_PORT			= 80
HTTP_DEBUG_PORT				= 8080		; probably not needed..

HTTP_INITIAL_SEQ			= 0x00000000

align 2
http_source_port			dw 32768

http_get_string				db "GET "
http_head_string			db "HEAD "
http_version_string			db "HTTP/1.1"
http_user_agent_string			db "User-Agent: xOS kernel HTTP layer",0
http_host_string			db "Host: ",0
http_accept_language_string		db "Accept-Language: en-us",0
http_accept_encoding_string		db "Accept-Encoding: identity",0
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

; http_head:
; Performs an HTTP HEAD request
; In\	ESI = URI
; Out\	EAX = Buffer, -1 on error

http_head:
	inc [http_source_port]

	cmp [network_available], 1
	jne .error

	mov [.uri], esi

	mov edi, .domain
	mov ecx, 256
	xor al, al
	rep stosb

	mov edi, .path
	mov ecx, 256
	rep stosb

	; copy the domain host and path names
	mov esi, [.uri]
	mov edi, .domain
	call http_copy_domain

	mov esi, [.uri]
	mov edi, .path
	call http_copy_path

	; resolve the DNS
	mov esi, .domain
	call dns_request
	cmp eax, 0
	je .error

	mov [.ip], eax

	; create a socket connection
	mov al, SOCKET_PROTOCOL_TCP
	mov ebx, [.ip]
	mov edx, (HTTP_DESTINATION_PORT shl 16)
	mov dx, [http_source_port]
	call socket_open

	cmp eax, -1
	je .error
	mov [.socket], eax

	; construct the HTTP request
	mov ecx, 8192			; much, much more than enough
	call kmalloc
	mov [.request], eax

	mov ecx, TCP_WINDOW
	call malloc
	mov [.response], eax

	mov edi, [.request]
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

	mov esi, http_user_agent_string
	call strlen
	mov ecx, eax
	rep movsb

	mov al, 13
	stosb
	mov al, 10
	stosb

	mov esi, http_host_string
	call strlen
	mov ecx, eax
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

	mov esi, http_accept_encoding_string
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

	; two CRLF indicates end of request header
	mov al, 13
	stosb
	mov al, 10
	stosb
	mov al, 13
	stosb
	mov al, 10
	stosb

	sub edi, [.request]
	mov [.request_size], edi

	mov esi, [.request]
	call com1_send

	; send the request
	mov eax, [.socket]
	mov esi, [.request]
	mov ecx, [.request_size]
	mov dl, TCP_PSH or TCP_ACK
	call socket_write

	cmp eax, 0
	jne .error_close

	; receive the response
	mov [.response_size], 0

.receive_loop:
	mov eax, [.socket]
	mov edi, [.response]
	add edi, [.response_size]
	call socket_read

	add [.response_size], eax

	;cmp eax, 0
	;je .check_finish

	cmp dl, 0xFF
	je .finish

	test dl, TCP_PSH
	jnz .psh_ack

	test dl, TCP_FIN
	jnz .finish

	test dl, TCP_ACK
	jnz .check_data

	jmp .finish

.check_data:
	cmp eax, 0
	je .receive_loop

.psh_ack:
	; ACK the data we received
	mov eax, [.socket]
	mov esi, 0
	mov ecx, 0
	mov dl, TCP_ACK
	call socket_write

	cmp eax, 0
	jne .error_close

	jmp .receive_loop

.finish:
	mov eax, [.socket]
	call socket_close

	mov eax, [.request]
	call kfree

	mov eax, [.response]
	ret

.error_close:
	mov eax, [.socket]
	call socket_close

.error_free:
	mov eax, [.request]
	call kfree
	mov eax, [.response]
	call free

.error:
	mov eax, -1
	ret

align 4
.uri				dd 0
.ip				dd 0
.socket				dd 0
.request			dd 0
.request_size			dd 0
.response			dd 0
.response_size			dd 0

.domain:			times 256 db 0
.path:				times 256 db 0

; http_get:
; Performs an HTTP GET request
; In\	ESI = URI
; Out\	EAX = Buffer, -1 on error
; Out\	ECX = Buffer size, including HTTP headers

http_get:
	inc [http_source_port]

	cmp [network_available], 1
	jne .error

	mov [.uri], esi

	mov edi, .domain
	mov ecx, 256
	xor al, al
	rep stosb

	mov edi, .path
	mov ecx, 256
	rep stosb

	; copy the domain host and path names
	mov esi, [.uri]
	mov edi, .domain
	call http_copy_domain

	mov esi, [.uri]
	mov edi, .path
	call http_copy_path

	; resolve the DNS
	mov esi, .domain
	call dns_request
	cmp eax, 0
	je .error

	mov [.ip], eax

	; create a socket connection
	mov al, SOCKET_PROTOCOL_TCP
	mov ebx, [.ip]
	mov edx, (HTTP_DESTINATION_PORT shl 16)
	mov dx, [http_source_port]
	call socket_open

	cmp eax, -1
	je .error
	mov [.socket], eax

	; construct the HTTP request
	mov ecx, 8192			; much, much more than enough
	call kmalloc
	mov [.request], eax

	mov ecx, TCP_WINDOW
	call malloc
	mov [.response], eax

	mov edi, [.request]
	mov esi, http_get_string
	mov ecx, 4
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

	mov esi, http_user_agent_string
	call strlen
	mov ecx, eax
	rep movsb

	mov al, 13
	stosb
	mov al, 10
	stosb

	mov esi, http_host_string
	call strlen
	mov ecx, eax
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

	mov esi, http_accept_encoding_string
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

	; two CRLF indicates end of request header
	mov al, 13
	stosb
	mov al, 10
	stosb
	mov al, 13
	stosb
	mov al, 10
	stosb

	sub edi, [.request]
	mov [.request_size], edi

	; send the request
	mov eax, [.socket]
	mov esi, [.request]
	mov ecx, [.request_size]
	mov dl, TCP_PSH or TCP_ACK
	call socket_write

	;cmp eax, 0
	;jne .error_close

	; receive the response
	mov [.response_size], 0
	mov [.response_size2], 0

.receive_loop:
	cmp [.response_size2], TCP_WINDOW-8192
	jl .receive_work

	; resize the working memory
	mov eax, [.response]
	mov ecx, [.response_size]
	add ecx, TCP_WINDOW
	call realloc
	mov [.response], eax

	mov [.response_size2], 0

.receive_work:
	mov eax, [.socket]
	mov edi, [.response]
	add edi, [.response_size]
	call socket_read

	add [.response_size], eax
	add [.response_size2], eax

	; check what's happening...
	cmp dl, 0xFF
	je .finish

	test dl, TCP_PSH
	jnz .psh_ack

	test dl, TCP_FIN
	jnz .finish

	test dl, TCP_ACK
	jnz .check_payload

	jmp .finish

.check_payload:
	cmp eax, 0
	je .receive_loop

.psh_ack:
	; ACK the data we received
	mov eax, [.socket]
	mov esi, 0
	mov ecx, 0
	mov dl, TCP_ACK
	call socket_write

	;cmp eax, 0
	;jne .error_close

	jmp .receive_loop


.finish:
	mov eax, [.socket]
	call socket_close

	mov eax, [.request]
	call kfree

	mov eax, [.response]
	mov ecx, [.response_size]
	ret

.error_close:
	mov eax, [.socket]
	call socket_close

.error_free:
	mov eax, [.request]
	call kfree
	mov eax, [.response]
	call free

.error:
	mov eax, -1
	mov ecx, 0
	ret

align 4
.uri				dd 0
.ip				dd 0
.socket				dd 0
.request			dd 0
.request_size			dd 0
.response			dd 0
.response_size			dd 0
.response_size2			dd 0

.domain:			times 256 db 0
.path:				times 256 db 0




