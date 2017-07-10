
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Domain Name System..

;
;
; struct dns_cache
; {
;	u8 domain[508];
;	u32 ip;
; }
;
; sizeof(dns_cache) = 512;
;
;

DNS_CACHE_DOMAIN			= 0
DNS_CACHE_IP				= 508
DNS_CACHE_SIZE				= 512
DNS_MAX_CACHE				= 512

DNS_HEADER_SIZE				= 12
DNS_DESTINATION_PORT			= 53

align 2
dns_id					dw "XS"

align 4
dns_cache				dd 0	; keep a cache of all used IP addresses to speed up networking
dns_end_cache				dd 0
dns_cache_entries			dd 0

; dns_request:
; Gets the IP address of a domain name
; In\	ESI = Domain name
; Out\	EAX = IP address, 0 on error

dns_request:
	mov [.domain], esi

	call strlen
	cmp eax, 255			; byte limit
	jge .error

	; check if the domain name exists in the cache
	; to speed up networking
	mov [.domain_size], eax

	mov esi, [dns_cache]

.search_cache_loop:
	push esi
	mov edi, [.domain]
	mov ecx, [.domain_size]
	inc ecx
	rep cmpsb
	je .found_cache
	pop esi

	add esi, DNS_CACHE_SIZE
	cmp esi, [dns_end_cache]
	jge .send_request

	jmp .search_cache_loop

.found_cache:
	pop esi
	mov eax, [esi+DNS_CACHE_IP]	; get the IP address from the cache
	ret

.send_request:
	; the domain is not in the cache --
	; -- construct a DNS packet
	mov ecx, 8192			; much more than enough
	call kmalloc
	mov [.packet], eax

	; make the DNS header
	mov edi, [.packet]
	mov ax, [dns_id]
	stosw				; transaction ID

	mov ax, 0x100			; standard query, recursion
	xchg al, ah
	stosw				; flags and opcode

	mov ax, 1			; one question
	xchg al, ah
	stosw

	mov ax, 0			; no replies
	stosw

	mov ax, 0			; no authority
	stosw

	mov ax, 0			; no resource records
	stosw

	mov esi, [.domain]
	mov [.tmp_domain], esi

.do_domain:
	mov [.label_size], 0
	mov esi, [.tmp_domain]

	push edi
	inc edi				; skip label size

.loop:
	lodsb
	cmp al, 0
	je .domain_done

	cmp al, '.'
	je .label_done

	stosb
	inc [.label_size]
	jmp .loop

.label_done:
	mov [.tmp_domain], esi
	mov [.tmp], edi
	pop edi
	mov al, [.label_size]
	stosb

	mov edi, [.tmp]
	jmp .do_domain

.domain_done:
	mov [.tmp], edi
	pop edi

	mov al, [.label_size]
	stosb

	mov edi, [.tmp]

	mov al, 0		; null terminate
	stosb

	mov ax, 1		; class and type
	xchg al, ah
	stosw
	stosw

.send:
	sub edi, [.packet]
	mov [.packet_size], edi

	; okay, open a socket
	call net_increment_port

	mov al, SOCKET_PROTOCOL_UDP
	mov ebx, [dns_ip]
	mov edx, (DNS_DESTINATION_PORT shl 16)
	mov dx, [local_port]
	call socket_open

	cmp eax, -1
	je .error

	mov [.socket], eax

	; send the DNS message
	mov eax, [.socket]
	mov esi, [.packet]
	mov ecx, [.packet_size]
	mov dl, 0		; TCP flags, unused for UDP
	call socket_write

	cmp eax, 0
	jne .error_close

	; receive the response
	mov edi, [.packet]
	xor al, al
	mov ecx, 8192
	rep stosb

	mov ecx, 0		; as a counter

.try_receive:
	push ecx

	mov eax, [.socket]
	mov edi, [.packet]
	call socket_read

	pop ecx
	cmp eax, 0
	jne .receive_done

	inc ecx
	cmp ecx, 3
	jg .error_close

	jmp .try_receive

.receive_done:
	mov eax, [.socket]
	call socket_close

	mov esi, [.packet]

	mov ax, [esi+6]			; answer count
	xchg al, ah
	cmp ax, 0			; at least one answer
	je .error

	mov ax, [esi+4]			; question count
	xchg al, ah
	cmp ax, 1
	jne .error

	add esi, DNS_HEADER_SIZE	; to questions

.skip_loop:
	; skip over the questions
	movzx eax, byte[esi]
	cmp eax, 0
	je .questions_finished

	add esi, eax
	inc esi
	jmp .skip_loop

.questions_finished:
	add esi, 5

	mov ax, [esi+2]		; answer type
	xchg al, ah
	cmp ax, 1
	jne .error

	mov ax, [esi+4]		; class
	xchg al, ah
	cmp ax, 1
	jne .error

	mov ax, [esi+10]	; data length
	xchg al, ah
	cmp ax, 4		; IP address length
	jne .error

	mov eax, [esi+12]	; actual IP address -- the value we wanted from the beginning
	mov [.ip], eax

	cmp eax, 0xFFFFFFFF
	je .error

	cmp eax, 0x00000000
	je .error

	; add the IP to the cache, so we don't actually do a DNS request if we need it again
	mov edi, [dns_cache_entries]
	shl edi, 9
	add edi, [dns_cache]
	push edi
	mov esi, [.domain]
	mov ecx, [.domain_size]
	rep movsb
	xor al, al
	stosb
	pop edi
	mov eax, [.ip]
	mov [edi+DNS_CACHE_IP], eax

	xor edi, edi
	mov eax, [.ip]
	ret

.error_close:
	mov eax, [.socket]
	call socket_close

.error:
	mov eax, 0x00000000
	ret

align 4
.domain					dd 0
.tmp_domain				dd 0
.packet					dd 0
.tmp					dd 0
.packet_size				dd 0
.domain_size				dd 0
.ip					dd 0
.socket					dd 0
.label_size				db 0




