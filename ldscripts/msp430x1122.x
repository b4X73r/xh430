/* Default linker script, for normal executables */
OUTPUT_FORMAT("elf32-msp430","elf32-msp430","elf32-msp430")
OUTPUT_ARCH(msp:110)
MEMORY
{
  text   (rx)   	: ORIGIN = 0xf000,  LENGTH = 0x1000
  data   (rwx)  	: ORIGIN = 0x0200, 	LENGTH = 256
/*  vectors (rw)  	: ORIGIN = 0xffe0,      LENGTH = 0x20 */
  bootloader(rx)	: ORIGIN = 0x0c00,	LENGTH = 1K
  infomem(rx)		: ORIGIN = 0x1000,	LENGTH = 256
  infomemnobits(rx)	: ORIGIN = 0x1000,      LENGTH = 256
}
SECTIONS
{
  .text :
  {
    . = ALIGN(2);
   *(.text)
    . = ALIGN(2);
    *(.text.*)
    _etext = . ;
  }  > text
  .data   : AT (ADDR (.text) + SIZEOF (.text))
  {
     PROVIDE (__data_start = .) ;
    . = ALIGN(2);
    *(.data)
    . = ALIGN(2);
    *(.gnu.linkonce.d*)
    . = ALIGN(2);
     _edata = . ;
  }  > data
  /* Bootloader.  */
  .bootloader   :
  {
     PROVIDE (__boot_start = .) ;
    *(.bootloader)
    . = ALIGN(2);
    *(.bootloader.*)
  }  > bootloader
   /* Information memory.  */
  .infomem   :
  {
    *(.infomem)
    . = ALIGN(2);
    *(.infomem.*)
  }  > infomem
  /* Information memory (not loaded into MPU).  */
  .infomemnobits   :
  {
    *(.infomemnobits)
    . = ALIGN(2);
    *(.infomemnobits.*)
  }  > infomemnobits
  .bss  SIZEOF(.data) + ADDR(.data) :
  {
     PROVIDE (__bss_start = .) ;
    *(.bss)
    *(COMMON)
     PROVIDE (__bss_end = .) ;
     _end = . ;
  }  > data
  .noinit  SIZEOF(.bss) + ADDR(.bss) :
  {
     PROVIDE (__noinit_start = .) ;
    *(.noinit)
    *(COMMON)
     PROVIDE (__noinit_end = .) ;
     _end = . ;
  }  > data
/*
  .vectors  :
  {
     PROVIDE (__vectors_start = .) ;
    *(.vectors*)
     _vectors_end = . ;
  }  > vectors
  /* Stabs debugging sections.  */
  PROVIDE (__stack = 0x300) ;
  PROVIDE (__data_start_rom = _etext) ;
  PROVIDE (__data_end_rom   = _etext + SIZEOF (.data)) ;
  PROVIDE (__noinit_start_rom = _etext + SIZEOF (.data)) ;
  PROVIDE (__noinit_end_rom = _etext + SIZEOF (.data) + SIZEOF (.noinit)) ;
}
INCLUDE ldscripts/msp430f1122_symbols.ld
