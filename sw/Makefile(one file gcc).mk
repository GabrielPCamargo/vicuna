# Copyright TU Wien
# Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# Generic Makefile for RV32IMV applications
# Specify program name with PROG, object files with OBJ

SW_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ==============================================================================
# CONFIGURAÇÃO DA NEWLIB E TOOLCHAIN CUSTOMIZADA
# ==============================================================================
LLVM_INSTALL_DIR ?= /home/gabriel/Documents/research/vector/llvm/install
RISCV_SYSROOT    := $(LLVM_INSTALL_DIR)/riscv32-unknown-elf
# ==============================================================================

COMPILER ?= llvm
ifeq ($(COMPILER),gcc)
    RISCV_CC            := riscv32-unknown-elf-gcc
    RISCV_LD            := riscv32-unknown-elf-gcc
    RISCV_DUMP          := riscv32-unknown-elf-objdump
    RISCV_OBCP          := riscv32-unknown-elf-objcopy
    ARCH                := rv32im_zve32x
    LD_SCRIPT           := $(SW_DIR)/link.ld
else ifeq ($(COMPILER),llvm)
    # Compilador C/Assembly continua sendo o Clang
    RISCV_CC            := $(LLVM_INSTALL_DIR)/bin/clang --target=riscv32-unknown-elf --sysroot=$(RISCV_SYSROOT)
    # Mas o Linker passa a ser o GCC padrão do sistema
    RISCV_LD            := riscv32-unknown-elf-gcc
    RISCV_DUMP          := $(LLVM_INSTALL_DIR)/bin/llvm-objdump
    RISCV_OBCP          := $(LLVM_INSTALL_DIR)/bin/llvm-objcopy
    ARCH                := rv32imzve32x
    # Removidos os argumentos exclusivos do lld (-fuse-ld=lld, etc)
    CC_SPECIFIC_OPTIONS := -Wno-unused-command-line-argument
    LD_SCRIPT           := $(SW_DIR)/lld_link.ld
endif

# Removidas as flags de relaxamento (-mrelax, -mno-relax) para deixar o linker GNU decidir
RISCV_FLAGS := -march=$(ARCH) -mabi=ilp32 -static -mcmodel=medany \
               -fvisibility=hidden -nostartfiles -Wall -nodefaultlibs \
               $(CC_SPECIFIC_OPTIONS)

CFLAGS := $(CFLAGS) -I$(SW_DIR)/lib/

PROG ?= test
OBJ  ?= test.o

# Arquivos base da aplicação
RISCV_OBJ := $(SW_DIR)/crt0.o $(OBJ) $(SW_DIR)/lib/uart.o $(SW_DIR)/syscalls.o

# Caminhos absolutos para as bibliotecas limpas que compilamos
LIBC_A := /home/gabriel/Documents/research/vector/llvm/install/riscv32-unknown-elf/lib/libc.a
LIBM_A := /home/gabriel/Documents/research/vector/llvm/install/riscv32-unknown-elf/lib/libm.a

all: $(PROG).vmem

dump: $(PROG).elf
	$(RISCV_DUMP) -D $<

# A regra de linkagem agora usa o RISCV_LD (que é o GCC)
$(PROG).elf: $(RISCV_OBJ) $(LD_SCRIPT)
	$(RISCV_LD) $(RISCV_FLAGS) -T $(LD_SCRIPT) $(RISCV_OBJ) $(LIBC_A) $(LIBM_A) -o $@

%.o: %.c
	$(RISCV_CC) $(RISCV_FLAGS) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(RISCV_CC) $(RISCV_FLAGS) $(ASFLAGS) -c -o $@ $<

%.vmem: %.bin
	srec_cat $^ -binary -offset 0x0000 -byte-swap 4 -o $@ -vmem
%.bin: %.elf
	$(RISCV_OBCP) -O binary $^ $@

clean:
	rm -f *.o *.elf *.bin *.vmem

include $(SW_DIR)/toolchain.mk
