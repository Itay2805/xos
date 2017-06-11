OUTPUT_FORMAT("binary")
OUTPUT_ARCH("i386")
ENTRY(__linker_entry)
SECTIONS
{
	. = 0x8000000;
	.header : {
		*(.header)
		. = ALIGN(4);
	}

	.text : {
		*(.text)
		. = ALIGN(4);
	}
	.data : {
		*(.data)
		*(.rodata)
		. = ALIGN(4);
	}
	__bss_start = .;
	.bss : {
		bss = .; _bss = .; __bss = .;
		*(.bss);
	}
	end = .; _end = .; __end = .;
}

