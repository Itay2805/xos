
;; xOS32
;; Copyright (C) 2016-2017 by Omar Mohammad.

use32

;
; struct task {
; u16 state;		// 00
; u16 parent;		// 02
; u32 eip;		// 04
; u32 esp;		// 08
; u32 eflags;		// 0C
; u32 pmem_base;	// 10
; u32 mem_size;		// 14
; u32 reserved1;	// 18
; u32 reserved2;	// 1C
; u8 filename[32];	// 20
; };
;
;
; sizeof(task) = 64;
;

TASK_STATE		= 0x00
TASK_PARENT		= 0x02
TASK_EIP		= 0x04
TASK_ESP		= 0x08
TASK_EFLAGS		= 0x0C
TASK_PMEM_BASE		= 0x10
TASK_MEM_SIZE		= 0x14
TASK_RESERVED1		= 0x18
TASK_RESERVED2		= 0x1C
TASK_FILENAME		= 0x20
TASK_SIZE		= 0x40

; Task State Flags
TASK_PRESENT		= 0x0001
TASK_SLEEPING		= 0x0002

; Stack Frame for IRET
IRET_EIP		= 0x0000
IRET_CS			= 0x0004
IRET_EFLAGS		= 0x0008
IRET_ESP		= 0x000C
IRET_SS			= 0x0010

; Default Stack Size of a Task
TASK_STACK		= 65536		; 64 KB

; Load Address of a Task
TASK_LOAD_ADDR		= 0x8000000	; 128 MB

MAXIMUM_TASKS		= 256		; probably expand this in the future?

; Program Header
PROGRAM_SIGNATURE	= 0x00
PROGRAM_TYPE		= 0x04
PROGRAM_ENTRY		= 0x08

; Program Type Values
PROGRAM_FILE		= 0x00
DRIVER_FILE		= 0x01

align 2
running_tasks		dw 0
current_task		dw 0
align 8
task_structure		dd 0
idle_time		dd 0
nonidle_time		dd 0

; tasking_init:
; Initializes the multitasking subsystem

tasking_init:
	mov esi, .msg
	call kprint

	mov ecx, MAXIMUM_TASKS*TASK_SIZE
	call kmalloc
	mov [task_structure], eax

	; mark the first task (PID 0) as present
	; this prevents user applications from taking PID 0
	; PID 0 really is the Idle task, which just Halts the CPU in an infinite loop
	mov word[eax], TASK_PRESENT
	mov edi, eax
	add edi, TASK_FILENAME
	mov esi, .idle_task_name
	call strlen
	mov ecx, eax
	rep movsb
	xor al, al
	stosb

	mov [running_tasks], 1
	mov [current_task], 0

	ret

.msg			db "Initialize multitasking...",10,0
.idle_task_name		db "System Idle Task",0

; get_free_task:
; Finds a free task
; In\	Nothing
; Out\	EAX = PID of free task, -1 on error

get_free_task:
	mov [.pid], 1

	cmp [running_tasks], MAXIMUM_TASKS
	jge .no

.loop:
	cmp [.pid], MAXIMUM_TASKS
	jge .no

	mov eax, [.pid]
	shl eax, 6	; mul 64
	add eax, [task_structure]
	test word[eax], TASK_PRESENT
	jz .done

	inc [.pid]
	jmp .loop

.done:
	mov edi, eax
	mov eax, 0
	mov ecx, TASK_SIZE
	rep stosb

	mov eax, [.pid]
	ret

.no:
	mov eax, -1
	ret

.pid			dd 0

; create_task_memory:
; Creates a task from memory
; In\	EDX = Entry point
; Out\	EAX = PID

create_task_memory:
	mov [.entry], edx

	call get_free_task
	cmp eax, -1
	je .no
	mov [.pid], eax

	; allocate a stack ;)
	mov ecx, TASK_STACK
	call malloc
	add eax, TASK_STACK
	mov [.stack], eax

	; create the task structure
	mov edi, [.pid]
	shl edi, 6		; mul 64
	add edi, [task_structure]
	mov word[edi], TASK_PRESENT

	mov ax, [current_task]
	mov [edi+TASK_PARENT], ax

	mov eax, [.entry]
	mov [edi+TASK_EIP], eax
	mov dword[edi+TASK_EFLAGS], 0x202

	mov eax, [.stack]
	mov [edi+TASK_ESP], eax

	; ready ;)
	inc [running_tasks]
	mov eax, [.pid]
	ret

.no:
	mov eax, -1
	ret

.entry			dd 0
.pid			dd 0
.stack			dd 0

; yield:
; Gives control to the next task
align 32
yield:
	cli		; sensitive area of code! ;)

	cmp [running_tasks], 1
	jle .idle

	cmp [current_task], 0		; if we're not running the idle task --
	jne .save_state			; -- then we need to save the task's EIP, stack and EFLAGS

.next:
	inc [current_task]

.loop:
	movzx eax, [current_task]
	cmp eax, MAXIMUM_TASKS
	jge .idle

	shl eax, 6
	add eax, [task_structure]
	test word[eax], TASK_PRESENT
	jz .next

	; Map the task in memory
	push eax
	mov ebp, eax		; EBP = task information
	mov eax, TASK_LOAD_ADDR
	mov ebx, [ebp+TASK_PMEM_BASE]
	mov ecx, [ebp+TASK_MEM_SIZE]
	mov dl, PAGE_PRESENT OR PAGE_WRITEABLE OR PAGE_USER
	call vmm_map_memory

	pop eax			; EAX = task information

	; Execute this task in ring 3
	mov dx, 0x23
	mov ds, dx
	mov es, dx
	mov fs, dx
	mov gs, dx

	push 0x23		; SS
	mov edx, [eax+TASK_ESP]
	push edx		; ESP
	mov edx, [eax+TASK_EFLAGS]
	push edx		; EFLAGS
	push 0x1B		; CS
	mov edx, [eax+TASK_EIP]
	push edx		; EIP

	iret

.save_state:
	;add esp, 4

	movzx eax, [current_task]
	shl eax, 6
	add eax, [task_structure]

	mov edx, [esp+4]		; eip
	mov [eax+TASK_EIP], edx

	mov edx, [esp+4+IRET_ESP]	; esp
	mov [eax+TASK_ESP], edx

	mov edx, [esp+4+IRET_EFLAGS]	; eflags
	mov [eax+TASK_EFLAGS], edx

	;sub esp, 4	; restore stack

	; unmap the current task for the virtual address space
	mov ecx, [eax+TASK_MEM_SIZE]		; memory size in pages
	mov eax, TASK_LOAD_ADDR
	call vmm_unmap_memory

	jmp .next

.idle:
	mov [current_task], 0
	add esp, 4		; clean up the stack
	jmp idle_process	; if no processes are running, keep the CPU usage low

; create_task:
; Creates a task from a file
; In\	ESI = Filename
; Out\	EAX = PID, or error code (-1 = no memory/free tasks, -2 = file read error, -3 = corrupt program)

create_task:
	mov [.filename], esi

	call get_free_task
	cmp eax, -1
	je .no_memory

	mov [.pid], eax

	; allocate a stack
	mov ecx, TASK_STACK
	call malloc
	add eax, TASK_STACK
	mov [.stack], eax

	; open the file
	mov esi, [.filename]
	mov edx, FILE_READ
	call xfs_open
	cmp eax, -1
	je .file_error

	mov [.handle], eax

	; get file size
	mov eax, [.handle]
	mov ebx, SEEK_END
	mov ecx, 0
	call xfs_seek
	cmp eax, 0
	jne .file_error

	mov eax, [.handle]
	call xfs_tell
	cmp eax, -1
	je .file_error

	mov [.file_size], eax

	mov eax, [.handle]
	mov ebx, SEEK_SET
	mov ecx, 0
	call xfs_seek
	cmp eax, 0
	jne .file_error

	; convert the file size to pages
	mov ecx, [.file_size]
	add ecx, 4095
	shr ecx, 12
	mov [.pages], ecx
	call pmm_alloc

	cmp eax, 0
	je .no_memory
	mov [.memory], eax

	mov eax, TASK_LOAD_ADDR
	mov ebx, [.memory]
	mov ecx, [.pages]
	mov dl, PAGE_PRESENT OR PAGE_WRITEABLE OR PAGE_USER
	call vmm_map_memory

	mov eax, [.handle]
	mov edi, TASK_LOAD_ADDR
	mov ecx, [.file_size]
	call xfs_read

	cmp eax, [.file_size]
	jne .file_error

	mov eax, [.handle]
	call xfs_close

	; verify the program is valid
	mov esi, TASK_LOAD_ADDR
	cmp dword[esi], "XOS1"
	jne .corrupt

	cmp dword[esi+PROGRAM_TYPE], PROGRAM_FILE
	jne .corrupt

	mov eax, [esi+PROGRAM_ENTRY]
	mov [.entry], eax

	; create the task structure
	mov edi, [.pid]
	shl edi, 6		; mul 64
	add edi, [task_structure]
	mov word[edi], TASK_PRESENT

	mov ax, [current_task]
	mov [edi+TASK_PARENT], ax

	mov eax, [.entry]
	mov [edi+TASK_EIP], eax
	mov dword[edi+TASK_EFLAGS], 0x202

	mov eax, [.stack]
	mov [edi+TASK_ESP], eax

	mov eax, [.memory]
	mov [edi+TASK_PMEM_BASE], eax

	mov eax, [.pages]
	mov [edi+TASK_MEM_SIZE], eax

	add edi, TASK_FILENAME
	push edi

	mov esi, [.filename]
	call strlen
	mov ecx, eax

	pop edi
	rep movsb
	xor al, al
	stosb

	; ready ;)
	cmp [current_task], 0	; idle
	je .finish

	mov eax, TASK_LOAD_ADDR
	mov ecx, [.pages]
	call vmm_unmap_memory

	movzx ebp, [current_task]
	shl ebp, 6
	add ebp, [task_structure]
	mov eax, TASK_LOAD_ADDR
	mov ebx, [ebp+TASK_PMEM_BASE]
	mov ecx, [ebp+TASK_MEM_SIZE]
	mov dl, PAGE_PRESENT OR PAGE_WRITEABLE OR PAGE_USER
	call vmm_map_memory

.finish:
	inc [running_tasks]
	mov eax, [.pid]

	ret

.no_memory:
	mov esi, .no_memory_msg
	call kprint

	mov eax, -1
	ret

.file_error:
	mov esi, .file_error_msg
	call kprint

	mov eax, -2
	ret

.corrupt:
	mov esi, .corrupt_msg
	call kprint

	mov eax, -3
	ret

.entry				dd 0
.filename			dd 0
.pid				dd 0
.stack				dd 0
.handle				dd 0
.file_size			dd 0
.pages				dd 0
.memory				dd 0
.no_memory_msg			db "load error: Insufficient memory to start program.",10,0
.file_error_msg			db "load error: Unable to read program file.",10,0
.corrupt_msg			db "load error: Program file is corrupt.",10,0

; terminate:
; Terminates the current task

terminate:
	movzx eax, [current_task]	; simply kill the current task ;)
	call kill_task

	add esp, 4
	jmp idle_process

; kill_task:
; Kills a task
; In\	EAX = PID
; Out\	Nothing

kill_task:
	cmp eax, MAXIMUM_TASKS
	jge .finish

	mov [.task], eax

	; verify the task even exists
	shl eax, 6
	add eax, [task_structure]
	test word[eax+TASK_STATE], TASK_PRESENT
	jz .finish

	; clean up after the task by killing any windows created by it
	mov [.window_handle], 0

.loop:
	cmp [.window_handle], MAXIMUM_WINDOWS
	jge .kill_task

	mov edi, [.window_handle]
	shl edi, 7
	add edi, [window_handles]
	test dword[edi+WINDOW_FLAGS], WM_PRESENT
	jz .next_window

	mov eax, [.task]
	cmp [edi+WINDOW_PID], eax
	je .kill_window

.next_window:
	inc [.window_handle]
	jmp .loop

.kill_window:
	mov eax, [.window_handle]
	call wm_kill
	jmp .next_window

.kill_task:
	mov edi, [.task]
	shl edi, 6
	add edi, [task_structure]

	push edi		; edi = task information

	mov eax, [edi+TASK_PMEM_BASE]
	mov ecx, [edi+TASK_MEM_SIZE]
	call pmm_free		; free the task's memory

	pop edi
	xor al, al
	mov ecx, TASK_SIZE
	rep stosb

	dec [running_tasks]
	mov [current_task], 0

.finish:
	ret

align 4
.task				dd 0
.window_handle			dd 0

; kill_all:
; Kills all running tasks

kill_all:
	mov [.current_task], 1		; don't kill the idle task

.loop:
	cmp [.current_task], MAXIMUM_TASKS
	jge .done

	mov eax, [.current_task]
	call kill_task

	inc [.current_task]
	jmp .loop

.done:
	ret

align 4
.current_task			dd 0

;
; struct user_task_info
; {
;	u16 state;
;	u16 parent_pid;
;	u32 program_memory;
;	u8 filename[32];
; }
;

; enum_tasks:
; Enumerates tasks
; In\	AX = PID of task
; In\	EDI = Pointer to structure to save task's info (in the table above)
; Out\	EAX = 0 on success, EDI filled with information
; Out\	EBX = PID of next available task that can be enumerated, 0 on end of tasks
; Out\	ECX = Number of running tasks, including idle

enum_tasks:
	cmp ax, MAXIMUM_TASKS
	jge .error

	mov [.buffer], edi
	mov [.pid], ax

	and eax, 0xFFFF
	shl eax, 6		; mul 64
	add eax, [task_structure]

	; copy the state of the task
	mov edi, [.buffer]
	mov dx, [eax+TASK_STATE]
	test dx, TASK_PRESENT
	jz .error

	mov word[edi], dx
	
	mov dx, [eax+TASK_PARENT]
	mov word[edi+2], dx

	mov edx, [eax+TASK_MEM_SIZE]	; pages
	shl edx, 12			; bytes
	mov dword[edi+4], edx

	; copy the filename
	mov esi, eax
	add esi, TASK_FILENAME
	call strlen
	mov ecx, eax
	mov edi, [.buffer]
	add edi, 8
	rep movsb
	xor al, al
	stosb

.find_next_task:
	movzx eax, [.pid]
	cmp eax, MAXIMUM_TASKS-1
	jge .end_of_tasks

	inc eax
	mov [.pid], ax

.find_next_task_loop:
	movzx eax, [.pid]
	cmp eax, MAXIMUM_TASKS
	jge .end_of_tasks

	shl eax, 6		; mul 64
	add eax, [task_structure]
	test word[eax+TASK_STATE], TASK_PRESENT
	jnz .found_next_task

	inc [.pid]
	jmp .find_next_task_loop

.found_next_task:
	mov eax, 0			; success
	movzx ebx, [.pid]		; next PID
	movzx ecx, [running_tasks]	; task count
	ret

.end_of_tasks:
	mov eax, 0
	mov ebx, 0
	movzx ecx, [running_tasks]
	ret

.error:
	mov eax, 1
	mov ebx, 0
	movzx ecx, [running_tasks]
	ret

align 4
.buffer				dd 0
.pid				dw 0



