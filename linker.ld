ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x40000000, LENGTH = 128M
}

SECTIONS
{
    .text : {
        *(.text.boot)
        *(.text*)
    } > RAM

    /* SlowAPI route table - must come BEFORE .rodata to not be captured */
    .rodata.routes : {
        . = ALIGN(8);
        __routes_start = .;
        KEEP(*(.rodata.routes))
        __routes_end = .;
    } > RAM

    .rodata : {
        *(.rodata*)
    } > RAM

    .data : {
        *(.data*)
    } > RAM

    .bss : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    . = ALIGN(16);
    . = . + 0x10000;
    _stack_top = .;
}
