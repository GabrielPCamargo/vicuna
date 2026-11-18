/* Copyright TU Wien                                                               */
/* Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details */
/* SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1                                */


OUTPUT_ARCH(riscv)
ENTRY(_start)

SEARCH_DIR(.)
__DYNAMIC = 0;

MEMORY
{
    boot : ORIGIN = 0x00000000, LENGTH = 0x00002000 /*   8 kB */
    ram  : ORIGIN = 0x00002000, LENGTH = 0x0003E000 /* 248 kB */
    /* DDR do PS vista pelo Vicuna (DDR_V_BASE / DDR_SIZE do gen_demo_ps.tcl).
     * Os ultimos 4 kB ficam fora do linker: reservados para a caixa de correio
     * (0x1FFFFFF8) e outros usos com endereco fixo. */
    ddr  : ORIGIN = 0x2010F000, LENGTH = 0x1FE00000 /* 256 MB - 4 kB */
}

/* Mesmos tamanhos do linker script do MicroBlaze V (OBPMark), para o benchmark
 * rodar com a mesma organizacao de memoria nas duas plataformas. */
_STACK_SIZE = DEFINED(_STACK_SIZE) ? _STACK_SIZE : 0x300000;    /*  2 MB         */
_HEAP_SIZE  = DEFINED(_HEAP_SIZE)  ? _HEAP_SIZE  : 0x1DCD6500;   /* 30.000.000 B  */

SECTIONS
{
    .vectors 0 : {
        *(.vectors)
    } >boot

    .text : {
        . = ALIGN(4);
        _stext = .;
        *(.text)
        *(.text.*)
        _etext  =  .;
        __CTOR_LIST__ = .;
        LONG((__CTOR_END__ - __CTOR_LIST__) / 4 - 2)
        *(.ctors)
        LONG(0)
        __CTOR_END__ = .;
        __DTOR_LIST__ = .;
        LONG((__DTOR_END__ - __DTOR_LIST__) / 4 - 2)
        *(.dtors)
        LONG(0)
        __DTOR_END__ = .;
        *(.lit)
        *(.shdata)
        . = ALIGN(4);
        _endtext = .;
    } >ram

    .rodata : {
        . = ALIGN(4);
        *(.rodata);
        *(.rodata.*)
    } >ram

    .shbss : {
        . = ALIGN(4);
        *(.shbss)
    } >ram

    .data : {
        . = ALIGN(4);
        sdata = .;
        _sdata = .;
        *(.data);
        *(.data.*)
        edata = .;
        _edata = .;
    } >ram

    .bss (NOLOAD) : {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        _bss_end = .;
    } >ram

    .user_align (NOLOAD) : {
        . = ALIGN(0x1000);
        _user_start = .;
    } >ram
    
    /* Fim dos dados na BRAM */
    . = ALIGN(8);
    _end = .;
    PROVIDE(_end = .);

    /* ---------------------------------------------------------------------
     * DDR. O programa e carregado apenas na BRAM (via .vmem): nada copia
     * valores iniciais para a DDR, e o crt0 nao zera as secoes abaixo.
     * --------------------------------------------------------------------- */

    /* ---------------------------------------------------------------------
     * DDR com conteudo inicial (ex.: imagem de entrada do OBPMark).
     * Esta secao NAO vai para o .vmem: o Makefile a remove do .bin da BRAM
     * (-R .my_image) e a extrai em um arquivo separado (-j .my_image), que e
     * carregado na DDR pelo XSCT/ARM antes de ligar o Vicuna.
     * Uso no C:  __attribute__((section(".my_image"))) const uint16_t img[] = {...};
     * --------------------------------------------------------------------- */
    .my_image : {
        . = ALIGN(64);
        _my_image_start = .;
        KEEP(*(.my_image))
        . = ALIGN(64);
        _my_image_end = .;
    } >ddr

    /* Heap e pilha na DDR, iguais ao script do MicroBlaze V:
     * mesmos tamanhos, mesma ordem (heap, depois pilha) e mesmos simbolos.
     * O _sbrk precisa usar _heap_start/_heap_end; o crt0 usa _stack para o sp. */
    .heap (NOLOAD) : {
        . = ALIGN(8);
        _heap = .;
        _heap_start = .;
        . += _HEAP_SIZE;
        _heap_end = .;
    } >ddr

    .stack (NOLOAD) : {
        _stack_end = .;          /* endereco mais baixo da pilha (como no MicroBlaze) */
        . += _STACK_SIZE;
        . = ALIGN(8);
        _stack = .;              /* topo da pilha: valor inicial do sp */
        __stack = _stack;
    } >ddr

    /* Buffers extras sem valor inicial: __attribute__((section(".ddr"))) */
    .ddr (NOLOAD) : {
        . = ALIGN(64);
        _ddr_start = .;
        *(.ddr)
        *(.ddr.*)
        . = ALIGN(64);
        _ddr_end = .;
    } >ddr

    .stab 0 (NOLOAD) : {
        [ .stab ]
    }

    .stabstr 0 (NOLOAD) : {
        [ .stabstr ]
    }
}
