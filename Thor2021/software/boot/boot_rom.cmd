ENTRY (_start)

MEMORY {
	BIOS_BSS : ORIGIN = 0xFFFC0000, LENGTH = 32k
	BIOS_DATA : ORIGIN = 0xFFFC8000, LENGTH = 31k
	BIOS_CODE : ORIGIN = 0xFFFD0000, LENGTH = 64K
	BIOS_RODATA: ORIGIN = 0xFFFE0000, LENGTH = 128k
}

SECTIONS {
	.bss : {
		_bss_start = .;
		*(.bss);
		. = ALIGN(4);
		_bss_end = .;
	} >BIOS_BSS
	.data : {
		_data_start = .;
		_SDA_BASE_ = .;
		*(.data);
		. = ALIGN(4);
		_data_end = .;
	} >BIOS_DATA
	.text : {
		*(.text);
		. = ALIGN(4);
		_etext = .;
	} >BIOS_CODE
	.rodata : {
		_start_rodata = .;
		_SDA2_BASE_ = .;
		*(.rodata);
		. = ALIGN(4);
		_end_rodata = .;
	} >BIOS_RODATA
}
