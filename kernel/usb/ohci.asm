
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

; OHCI MMIO Registers (all DWORDs)
OHCI_REVISION				= 0x00
OHCI_CONTROL				= 0x04
OHCI_COMMAND				= 0x08
OHCI_STATUS				= 0x0C
OHCI_INTERRUPT_ENABLE			= 0x10
OHCI_INTERRUPT_DISABLE			= 0x14
OHCI_COMM				= 0x18
OHCI_CONTROL_HEAD_ED			= 0x20
OHCI_CONTROL_CURRENT_ED			= 0x24
OHCI_BULK_HEAD_ED			= 0x28
OHCI_BULK_CURRENT_ED			= 0x2C
OHCI_FM_INTERVAL			= 0x34
OHCI_FM_REMAINING			= 0x38
OHCI_FM_NUMBER				= 0x3C
OHCI_LOW_SPEED_THRESHOLD		= 0x44
OHCI_ROOT_DESCRIPTOR_A			= 0x48
OHCI_ROOT_DESCRIPTOR_B			= 0x4C
OHCI_ROOT_STATUS			= 0x50
OHCI_ROOT_PORTS				= 0x54

; OHCI Control Register
OHCI_CONTROL_EXECUTE_CONTROL		= 0x00000010
OHCI_CONTROL_EXECUTE_BULK		= 0x00000020

; OHCI Command Register
OHCI_COMMAND_RESET			= 0x00000001
OHCI_COMMAND_CONTROL_FILLED		= 0x00000002
OHCI_COMMAND_OWNERSHIP_CHANGE		= 0x00000008

; OHCI Status Register
OHCI_STATUS_WRITE_DONE			= 0x00000002
OHCI_STATUS_UNRECOVERABLE_ERROR		= 0x00000010
OHCI_STATUS_FRAME_OVERFLOW		= 0x00000020
OHCI_STATUS_OWNERSHIP_CHANGE		= 0x40000000

; OHCI Root Hub Register
OHCI_ROOT_STATUS_LPSC			= 0x00010000

; OHCI Root Hub Port Registers
OHCI_PORT_CONNECT			= 0x00000001
OHCI_PORT_ENABLE			= 0x00000002
OHCI_PORT_CLEAR_SUSPEND			= 0x00000008
OHCI_PORT_RESET				= 0x00000010
OHCI_PORT_SET_POWER			= 0x00000100

; OHCI Packet Types
OHCI_PACKET_SETUP			= 0
OHCI_PACKET_OUT				= 1
OHCI_PACKET_IN				= 2
OHCI_PACKET_RESERVED			= 3

; OHCI Communications Area Structure
OHCI_COMM_INTERRUPT_TABLE		= 0x00		; 32 dwords
OHCI_COMM_FRAME_NUMBER			= 0x80		; word
OHCI_COMM_PADDING			= 0x82		; word
OHCI_COMM_DONE_HEAD			= 0x84		; dword
OHCI_COMM_SIZE				= 256		; bytes...

OHCI_DESCRIPTORS_SIZE			= 8		; 32 KB of descriptors is more than enough
OHCI_MAX_WAITS				= 8192		; max # of times to poll the controller before timeout

align 4
ohci_pci_list				dd 0
ohci_pci_count				dd 0
ohci_descriptors			dd 0
ohci_comm				dd 0

; ohci_init:
; Initializes USB OHCI controllers

ohci_init:
	; make a list of OHCI controllers
	mov ah, 0x0C
	mov al, 0x03
	mov bl, 0x10
	call pci_generate_list

	cmp ecx, 0
	je .done

	mov [ohci_pci_list], eax
	mov [ohci_pci_count], ecx

	mov esi, .starting
	call kprint
	mov eax, [ohci_pci_count]
	call int_to_string
	call kprint
	mov esi, .starting2
	call kprint

	; allocate space for endpoint descriptors and transfer descriptors
	mov eax, 0
	mov ecx, OHCI_DESCRIPTORS_SIZE
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE or PAGE_NO_CACHE
	call vmm_alloc
	mov [ohci_descriptors], eax

	; more space for communications area
	mov eax, 0
	mov ecx, 6
	mov dl, PAGE_PRESENT or PAGE_WRITEABLE or PAGE_NO_CACHE
	call vmm_alloc
	mov [ohci_comm], eax

.loop:
	mov ecx, [.controller]
	cmp ecx, [ohci_pci_count]
	jge .done

	call ohci_init_controller
	inc [.controller]
	jmp .loop

.done:
	ret

align 4
.controller			dd 0
.starting			db "usb-ohci: found ",0
.starting2			db " OHCI controllers, initialize in order.",10,0

; ohci_init_controller:
; Initializes a single OHCI host controller
; In\	ECX = Controller number
; Out\	Nothing

ohci_init_controller:
	mov [.controller], ecx

	shl ecx, 2		; mul 4
	add ecx, [ohci_pci_list]

	mov al, [ecx+PCI_DEVICE_BUS]
	mov [.bus], al
	mov al, [ecx+PCI_DEVICE_SLOT]
	mov [.slot], al
	mov al, [ecx+PCI_DEVICE_FUNCTION]
	mov [.function], al

	; debug messages are fun ;)
	mov esi, .starting
	call kprint
	mov al, [.bus]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [.slot]
	call hex_byte_to_string
	call kprint
	mov esi, .colon
	call kprint
	mov al, [.function]
	call hex_byte_to_string
	call kprint
	mov esi, newline
	call kprint

	; enable DMA, MMIO and disable interrupt line
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov bh, PCI_STATUS_COMMAND
	call pci_read_dword

	or eax, 0x406

	mov edx, eax
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov bh, PCI_STATUS_COMMAND
	call pci_write_dword

	; map the controller's MMIO space in memory
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov dl, 0	; BAR0
	call pci_map_memory

	cmp eax, 0
	je .memory_error

	mov [.mmio], eax

	; allocate memory for device addresses
	mov ecx, USB_MAX_ADDRESSES
	call kmalloc
	mov [.memory], eax

	; register the controller
	mov al, [.bus]
	mov ah, [.slot]
	mov bl, [.function]
	mov cl, USB_OHCI
	mov edx, [.mmio]
	mov esi, [.memory]
	call usb_register

	; controller number is in EAX
	call usb_reset_controller
	ret

.memory_error:
	mov esi, .memory_error_msg
	call kprint
	ret

align 4
.controller			dd 0
.memory				dd 0
.mmio				dd 0	; base of MMIO registers
.bus				db 0
.slot				db 0
.function			db 0

.starting			db "usb-ohci: initialize OHCI controller on PCI slot ",0
.colon				db ":",0
.memory_error_msg		db "usb-ohci: unable to map MMIO into virtual address space, aborting...",10,0

; ohci_reset_controller:
; Resets an OHCI controller
; In\	EAX = Pointer to controller information
; Out\	Nothing

ohci_reset_controller:
	mov [.controller], eax

	; read MMIO base
	mov edx, [eax+USB_CONTROLLER_BASE]
	mov [.mmio], edx

	; handoff
	mov edi, [.mmio]
	mov dword[edi+OHCI_COMMAND], OHCI_COMMAND_OWNERSHIP_CHANGE

	mov eax, 10
	call pit_sleep

	; save the frame interval to restore it after the reset
	mov edi, [.mmio]
	mov eax, [edi+OHCI_FM_INTERVAL]
	mov [.frame_interval], eax

	; reset the host controller
	mov edi, [.mmio]
	mov dword[edi+OHCI_COMMAND], OHCI_COMMAND_RESET

.reset_loop:
	mov edi, [.mmio]
	test dword[edi+OHCI_COMMAND], OHCI_COMMAND_RESET
	jnz .reset_loop

	; disable all interrupts
	mov edi, [.mmio]
	mov dword[edi+OHCI_INTERRUPT_DISABLE], 0xC000007F	; disable everything
	mov dword[edi+OHCI_STATUS], 0x0000007F		; clear status

	; reload the frame interval
	mov eax, [.frame_interval]
	cmp ax, 0			; if zero --
	je .set_default_interval	; -- set the default interval

	mov edi, [.mmio]
	mov [edi+OHCI_FM_INTERVAL], eax
	jmp .set_operation

.set_default_interval:
	mov eax, 0x2EDF			; default value according to spec...
	mov edi, [.mmio]
	mov [edi+OHCI_FM_INTERVAL], eax

.set_operation:
	; set the controller's operational mode
	mov edi, [.mmio]
	mov eax, [edi+OHCI_CONTROL]
	and eax, not (3 shl 6)
	or eax, 2 shl 6
	mov [edi+OHCI_CONTROL], eax

	mov eax, 10
	call pit_sleep

	; turn on power for the root hub
	mov edi, [.mmio]
	mov eax, [edi+OHCI_ROOT_STATUS]
	or eax, OHCI_ROOT_STATUS_LPSC
	mov [edi+OHCI_ROOT_STATUS], eax

	mov eax, 20
	call pit_sleep

	; count the downstream ports of the root hub
	mov edi, [.mmio]
	mov eax, [edi+OHCI_ROOT_DESCRIPTOR_A]
	and al, 0x0F
	cmp al, 0		; can't be zero ports!
	je .done

	mov [.port_count], al
	mov [.current_port], 0

.ports_loop:
	; go through the registers of each port, reset and enable everything
	mov al, [.current_port]
	cmp al, [.port_count]
	jge .done

	movzx edi, [.current_port]
	shl edi, 2			; mul 4 (dword)
	add edi, OHCI_ROOT_PORTS
	add edi, [.mmio]

	mov dword[edi], OHCI_PORT_SET_POWER

	mov eax, 10
	call pit_sleep

	mov dword[edi], OHCI_PORT_RESET

.wait_for_port:
	test dword[edi], OHCI_PORT_RESET
	jnz .wait_for_port

	mov dword[edi], OHCI_PORT_ENABLE	; enable the port

	; give it a little time...
	mov eax, 5
	call pit_sleep

.next_port:
	inc [.current_port]
	jmp .ports_loop

.done:
	; Already did this above ^^
	;mov edi, [.mmio]
	;mov eax, [edi+OHCI_CONTROL]
	;and eax, not (3 shl 6)
	;or eax, 2 shl 6
	;mov [edi+OHCI_CONTROL], eax

	ret

align 4
.controller			dd 0
.mmio				dd 0
.frame_interval			dd 0
.port_count			db 0
.current_port			db 0

; ohci_setup:
; Sends a setup packet
; In\	EAX = Pointer to controller information
; In\	BL = Device address
; In\	BH = Endpoint
; In\	ESI = Setup packet data
; In\	EDI = Data stage, if present
; In\	ECX = Size of data stage, zero if not present, bit 31 is direction
;	Bit 31 = 0: host to device
;	Bit 31 = 1: device to host
; Out\	EAX = 0 on success

ohci_setup:
	mov [.waits], 0

	mov [.controller], eax
	mov [.packet], esi
	mov [.data], edi
	mov [.data_size], ecx

	and bl, 0x7F
	mov [.address], bl
	and bh, 0x0F
	mov [.endpoint], bh

	mov eax, [.controller]
	mov edx, [eax+USB_CONTROLLER_BASE]
	mov [.mmio], edx

	; physical addresses for DMA
	mov eax, [.packet]
	call virtual_to_physical
	mov [.packet], eax

	cmp [.data_size], 0	; no data stage?
	je .skip_data

	mov eax, [.data]
	call virtual_to_physical
	mov [.data], eax

.skip_data:
	; construct the descriptors
	mov eax, [ohci_descriptors]
	mov [.descriptors], eax
	call virtual_to_physical
	mov [.descriptors_phys], eax

	; construct the endpoint descriptor
	mov edi, [.descriptors]
	movzx eax, [.address]		; device address
	movzx ebx, [.endpoint]		; endpoint
	shl ebx, 7
	or eax, ebx
	mov ebx, 32
	shl ebx, 16
	or eax, ebx
	or eax, 1 shl 13		; low speed device
	stosd

	; TD tail pointer
	mov eax, 0xF0000000
	stosd

	; TD head pointer
	mov eax, [.descriptors_phys]
	add eax, 16
	stosd

	; next endpoint descriptor pointer
	mov eax, 0
	stosd

	; construct the first TD
	mov edi, [.descriptors]
	add edi, 16
	mov eax, OHCI_PACKET_SETUP
	shl eax, 19
	or eax, 1 shl 25	; data toggle is in TD not ED
	or eax, 14 shl 28	; indicate to the OHCI that this TD is new and just being supplied
	stosd

	; pointer to setup packet
	mov eax, [.packet]
	stosd

	; pointer to second TD
	mov eax, [.descriptors_phys]
	add eax, 32
	stosd

	; pointer to last byte of setup packet
	mov eax, [.packet]
	add eax, 7	; size - 1
	stosd

	; if there is a data stage, we need two TDs for data and status
	; if not, we only need one TD for status
	cmp [.data_size], 0
	je .no_data

	; data direction?
	test [.data_size], 0x80000000
	jnz .data_in

.data_out:
	mov [.data_token], OHCI_PACKET_OUT
	mov [.status_token], OHCI_PACKET_IN	; status is always opposite of data!
	jmp .continue

.data_in:
	mov [.data_token], OHCI_PACKET_IN
	mov [.status_token], OHCI_PACKET_OUT

.continue:
	; construct second TD for data
	mov edi, [.descriptors]
	add edi, 32
	mov eax, [.data_token]
	shl eax, 19
	or eax, (1 shl 25) or (1 shl 24)	; DATA1
	or eax, 14 shl 28
	stosd

	; pointer to data packet
	mov eax, [.data]
	stosd

	; pointer to third TD
	mov eax, [.descriptors_phys]
	add eax, 48
	stosd

	; pointer to last byte of data packet
	mov eax, [.data]
	mov ebx, [.data_size]
	and ebx, 0x7FFFFFFF
	add eax, ebx
	dec eax		; size minus one
	stosd

	; construct third TD for status
	mov edi, [.descriptors]
	add edi, 48
	mov eax, [.status_token]
	shl eax, 19
	or eax, 1 shl 25
	or eax, 14 shl 28
	stosd

	; data buffer -- null pointer
	mov eax, 0
	stosd

	; next TD -- bad pointer
	mov eax, 0xF0000000
	stosd

	; last byte of data buffer -- null pointer
	mov eax, 0
	stosd

	jmp .send_packet

.no_data:
	; construct second TD (status)
	mov edi, [.descriptors]
	add edi, 32
	mov eax, OHCI_PACKET_IN
	shl eax, 19
	or eax, 1 shl 25
	or eax, 14 shl 28
	stosd

	; data buffer -- null pointer
	mov eax, 0
	stosd

	; next TD -- bad pointer
	mov eax, 0xF0000000
	stosd

	; last byte of data buffer -- null pointer
	mov eax, 0
	stosd

.send_packet:
	; disable control list execution
	mov edi, [.mmio]
	mov eax, [edi+OHCI_CONTROL]
	and eax, not OHCI_CONTROL_EXECUTE_CONTROL
	mov [edi+OHCI_CONTROL], eax

	; clear the communications area
	mov edi, [ohci_comm]
	xor eax, eax
	mov ecx, 256/4
	rep stosd

	; send the address of the communications area
	mov eax, [ohci_comm]
	call virtual_to_physical
	mov edi, [.mmio]
	mov [edi+OHCI_COMM], eax

	; send the address of the ED
	mov edi, [.mmio]
	mov eax, [.descriptors_phys]
	mov [edi+OHCI_CONTROL_HEAD_ED], eax

	xor eax, eax
	mov [edi+OHCI_CONTROL_CURRENT_ED], eax

	; control list filled
	mov edi, [.mmio]
	mov eax, [edi+OHCI_COMMAND]
	or eax, OHCI_COMMAND_CONTROL_FILLED
	mov [edi+OHCI_COMMAND], eax

	; enable execution
	mov edi, [.mmio]
	mov eax, [edi+OHCI_CONTROL]
	or eax, OHCI_CONTROL_EXECUTE_CONTROL
	and eax, not (3 shl 6)
	or eax, 2 shl 6
	mov [edi+OHCI_CONTROL], eax

.wait:
	inc [.waits]
	cmp [.waits], OHCI_MAX_WAITS
	jg .error

	; wait for the controller to finish, while checking for errors
	mov edi, [.mmio]
	mov eax, [edi+OHCI_STATUS]

	test eax, OHCI_STATUS_UNRECOVERABLE_ERROR
	jnz .error

	test eax, OHCI_STATUS_FRAME_OVERFLOW
	jnz .error

	mov esi, [.descriptors]
	mov eax, [esi+8]

	; TD head pointer
	and eax, 0xFFFFFFF0
	cmp eax, [esi+4]	; head = tail?
	je .done

	; commented this because halted doesn't always mean finished...
	;mov eax, [esi+8]
	;test eax, 1		; test for halted
	;jnz .done

	mov edi, [.mmio]
	mov eax, [edi+OHCI_COMMAND]
	test eax, OHCI_COMMAND_CONTROL_FILLED
	jz .done

	jmp .wait

.error:
	; clear the "control execute" bit
	mov edi, [.mmio]
	mov eax, [edi+OHCI_CONTROL]
	and eax, not OHCI_CONTROL_EXECUTE_CONTROL
	mov [edi+OHCI_CONTROL], eax

	; clear the status register
	mov dword[edi+OHCI_STATUS], 0x0000007F

	;mov esi, .error_msg
	;call kprint
	;movzx eax, [.address]
	;call int_to_string
	;call kprint
	;mov esi, .error_msg2
	;call kprint
	;movzx eax, [.endpoint]
	;call int_to_string
	;call kprint
	;mov esi, newline
	;call kprint

	mov eax, -1
	ret

.done:
	; clear the "control execute" bit
	mov edi, [.mmio]
	mov eax, [edi+OHCI_CONTROL]
	and eax, not OHCI_CONTROL_EXECUTE_CONTROL
	mov [edi+OHCI_CONTROL], eax

	; clear the status register
	mov dword[edi+OHCI_STATUS], 0x0000007F

	mov eax, 0
	ret

align 4
.controller			dd 0
.packet				dd 0
.data				dd 0
.data_size			dd 0
.data_token			dd 0
.status_token			dd 0
.mmio				dd 0
.address			db 0
.endpoint			db 0

align 4
.waits				dd 0

align 4
.descriptors			dd 0
.descriptors_phys		dd 0

.error_msg			db "usb-ohci: SETUP transfer error on device ",0
.error_msg2			db " endpoint ",0

; ohci_interrupt:
; Sends/receives an interrupt packet
; In\	EAX = Pointer to controller information
; In\	BL = Device address
; In\	BH = Endpoint
; In\	ESI = Interrupt packet
; In\	ECX = Bits 0-30: Size of interrupt packet, bit 31: direction
;	Bit 31 = 0: host to device
;	Bit 31 = 1: device to host
; Out\	EAX = 0 on success

ohci_interrupt:
	mov [.waits], 0
	mov [.controller], eax
	mov [.packet], esi
	mov [.size], ecx

	and bl, 0x7F
	mov [.address], bl
	and bh, 0x0F
	mov [.endpoint], bh

	; if there is no data to be transferred, ignore the request
	;mov ecx, [.size]
	;and ecx, 0x7FFFFFFF
	;cmp ecx, 0
	;je .finish2

	mov eax, [.controller]
	mov edx, [eax+USB_CONTROLLER_BASE]
	mov [.mmio], edx	; MMIO base

	; physical addresses for the DMA to be happy...
	mov eax, [.packet]
	call virtual_to_physical
	mov [.packet], eax

	mov eax, [ohci_descriptors]
	mov [.descriptors], eax
	call virtual_to_physical
	mov [.descriptors_phys], eax

	; construct the endpoint descriptor
	mov edi, [.descriptors]
	movzx eax, [.address]		; device address
	movzx ebx, [.endpoint]		; endpoint
	shl ebx, 7
	or eax, ebx
	mov ebx, 8
	shl ebx, 16
	or eax, ebx
	or eax, 1 shl 13		; low speed device
	stosd

	; TD tail pointer
	mov eax, 0xF0000000
	stosd

	; TD head pointer
	mov eax, [.descriptors_phys]
	add eax, 16
	stosd

	; next endpoint descriptor pointer
	mov eax, 0
	stosd

	; construct the first TD
	mov edi, [.descriptors]
	add edi, 16

	; determine the data direction
	test [.size], 0x80000000
	jnz .in_packet

.out_packet:
	mov eax, OHCI_PACKET_OUT
	jmp .continue

.in_packet:
	mov eax, OHCI_PACKET_IN

.continue:
	shl eax, 19
	or eax, 1 shl 18		; buffer rounding
	or eax, 1 shl 25		; data toggle is in TD not ED
	or eax, 14 shl 28		; new TD to be executed
	stosd

	; pointer to packet
	mov eax, [.packet]
	stosd

	; next TD -- invalid pointer
	mov eax, 0xF0000000
	stosd

	; last byte of packet
	mov eax, [.packet]
	mov ebx, [.size]
	and ebx, 0x7FFFFFFF
	add eax, ebx
	dec eax
	stosd

.send_packet:
	; disable control list execution
	mov edi, [.mmio]
	mov eax, [edi+OHCI_CONTROL]
	and eax, not OHCI_CONTROL_EXECUTE_CONTROL
	mov [edi+OHCI_CONTROL], eax

	; clear the communications area
	mov edi, [ohci_comm]
	xor eax, eax
	mov ecx, 256/4
	rep stosd

	; send the address of the communications area
	mov eax, [ohci_comm]
	call virtual_to_physical
	mov edi, [.mmio]
	mov [edi+OHCI_COMM], eax

	; send the address of the ED
	mov edi, [.mmio]
	mov eax, [.descriptors_phys]
	mov [edi+OHCI_CONTROL_HEAD_ED], eax

	xor eax, eax
	mov [edi+OHCI_CONTROL_CURRENT_ED], eax

	; control list filled
	mov edi, [.mmio]
	mov eax, [edi+OHCI_COMMAND]
	or eax, OHCI_COMMAND_CONTROL_FILLED
	mov [edi+OHCI_COMMAND], eax

	; enable execution
	mov edi, [.mmio]
	mov eax, [edi+OHCI_CONTROL]
	or eax, OHCI_CONTROL_EXECUTE_CONTROL
	and eax, not (3 shl 6)
	or eax, 2 shl 6
	mov [edi+OHCI_CONTROL], eax

.wait:
	inc [.waits]
	cmp [.waits], OHCI_MAX_WAITS
	jg .error

	; wait for the controller to finish, while checking for errors
	mov edi, [.mmio]
	mov eax, [edi+OHCI_STATUS]

	test eax, OHCI_STATUS_UNRECOVERABLE_ERROR
	jnz .error

	test eax, OHCI_STATUS_FRAME_OVERFLOW
	jnz .error

	mov esi, [.descriptors]
	mov eax, [esi+8]

	; TD head pointer
	and eax, 0xFFFFFFF0
	cmp eax, [esi+4]	; head = tail?
	je .done

	; commented this because halted doesn't always mean finished...
	mov eax, [esi+8]
	test eax, 1		; test for halted
	jnz .done

	mov edi, [.mmio]
	mov eax, [edi+OHCI_COMMAND]
	test eax, OHCI_COMMAND_CONTROL_FILLED
	jz .done

	mov esi, [.descriptors]
	mov eax, [esi+16]		; first TD
	shr eax, 28
	cmp eax, 0
	je .done

	cmp eax, 14
	jge .wait

	jmp .error

	;jmp .wait

.error:
	; clear the "control execute" bit
	mov edi, [.mmio]
	mov eax, [edi+OHCI_CONTROL]
	and eax, not OHCI_CONTROL_EXECUTE_CONTROL
	mov [edi+OHCI_CONTROL], eax

	; clear the status register
	mov dword[edi+OHCI_STATUS], 0x0000007F

	;mov esi, .error_msg
	;call kprint
	;movzx eax, [.address]
	;call int_to_string
	;call kprint
	;mov esi, .error_msg2
	;call kprint
	;movzx eax, [.endpoint]
	;call int_to_string
	;call kprint
	;mov esi, newline
	;call kprint

	mov eax, -1
	ret

.done:
	; clear the "control execute" bit
	mov edi, [.mmio]
	mov eax, [edi+OHCI_CONTROL]
	and eax, not OHCI_CONTROL_EXECUTE_CONTROL
	mov [edi+OHCI_CONTROL], eax

	; clear the status register
	mov dword[edi+OHCI_STATUS], 0x0000007F

	mov eax, 0
	ret

align 4
.controller			dd 0
.packet				dd 0
.size				dd 0
.mmio				dd 0
.address			db 0
.endpoint			db 0

align 4
.waits				dd 0

align 4
.descriptors			dd 0
.descriptors_phys		dd 0

.error_msg			db "usb-ohci: interrupt transfer error on device ",0
.error_msg2			db " endpoint ",0


