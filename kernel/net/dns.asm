
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; Domain Name System..
DNS_HEADER_SIZE				= 12
DNS_SOURCE_PORT				= 32768
DNS_DESTINATION_PORT			= 53

align 2
dns_id					dw "XS"

; dns_request:
; Gets the IP address of a domain name
; In\	ESI = Domain name
; Out\	EAX = IP address, 0 on error

dns_request:
	mov [.domain], esi

	call strlen
	cmp eax, 255			; byte limit
	jge .error

	; construct a DNS packet
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

	; okay, send the packet by UDP
	mov eax, dword[my_ip]		; my IP
	mov ebx, dword[dns_ip]		; destination IP - DNS server
	mov ecx, [.packet_size]
	mov edx, (DNS_DESTINATION_PORT shl 16) or DNS_SOURCE_PORT
	mov esi, [.packet]
	mov edi, router_mac
	call udp_send

	cmp eax, 0
	jne .error

	; clear the packet data
	mov edi, [.packet]
	mov al, 0
	mov ecx, 8192
	rep stosb

.receive_start:
	; receive a packet in the same buffer
	mov [.wait_loops], 0
	inc [.packet_count]
	cmp [.packet_count], NET_TIMEOUT
	jge .error

.receive_loop:
	inc [.wait_loops]
	cmp [.wait_loops], NET_TIMEOUT
	jg .error

	mov edi, [.packet]
	call net_receive

	cmp eax, 0
	jne .check_received

	jmp .receive_loop

.check_received:
	mov esi, [.packet]
	mov ax, [esi+12]
	xchg al, ah
	cmp ax, IP_PROTOCOL_TYPE	; IP packet?
	jne .receive_start

	; read the IP packet
	mov esi, [.packet]
	add esi, ETHERNET_HEADER_SIZE
	cmp byte[esi+9], UDP_PROTOCOL_TYPE	; UDP?
	jne .receive_start

	add esi, IP_HEADER_SIZE			; to TCP/UDP header
	mov ax, [esi]		; the reply source must be our destination
	xchg al, ah
	cmp ax, DNS_DESTINATION_PORT
	jne .receive_start

	mov ax, [esi+2]		; and reply destination must be our source...
	xchg al, ah
	cmp ax, DNS_SOURCE_PORT
	jne .receive_start

	add esi, UDP_HEADER_SIZE	; to the DNS packet..

	mov [.dns_body], esi

	mov ax, [esi+2]
	xchg al, ah
	test ax, 0x8000			; message is a response?
	jz .receive_start

	and ax, 0x000F
	cmp ax, 0			; query success?
	jne .receive_start

	mov ax, [esi+6]			; answer count
	xchg al, ah
	cmp ax, 0			; at least one answer
	je .receive_start

	mov ax, [esi+4]			; question count
	xchg al, ah
	cmp ax, 1
	jne .receive_start

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
	jne .receive_start

	mov ax, [esi+4]		; class
	xchg al, ah
	cmp ax, 1
	jne .receive_start

	mov ax, [esi+10]	; data length
	xchg al, ah
	cmp ax, 4		; IP address length
	jne .receive_start

	mov eax, [esi+12]	; actual IP address -- the value we wanted from the beginning
	push eax

	mov eax, [.packet]
	call kfree

	pop eax
	ret

.error:
	mov eax, 0
	ret

align 4
.domain					dd 0
.tmp_domain				dd 0
.packet					dd 0
.tmp					dd 0
.packet_size				dd 0
.wait_loops				dd 0
.packet_count				dd 0
.dns_body				dd 0
.label_size				db 0



