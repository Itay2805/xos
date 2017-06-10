OUTPUT_FORMAT("binary")
OUTPUT_ARCH("i386")
ENTRY(__linker_entry)
SECTIONS
{
	. = 0x8000000;
	.text : {
		*(.text)
		. = ALIGN(4096);
	}
	.data : {
		*(.data)
		*(.rodata)
		. = ALIGN(4096);
	}
	__bss_start = .;
	.bss : {
		bss = .; _bss = .; __bss = .;
		*(.bss);
	}
	end = .; _end = .; __end = .;
}

