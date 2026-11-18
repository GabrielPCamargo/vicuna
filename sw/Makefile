# Copyright TU Wien
# Licensed under the Solderpad Hardware License v2.1, see LICENSE.txt for details
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1


# Generic Makefile for RV32IMV applications (C, C++ e assembly)
#
# Cada aplicacao fica numa pasta propria dentro de sw/ (ex.: 2_2/), so com os
# fontes e o seu linker script (<APP>/ldscript.ld). O Makefile e compartilhado.
#
# Uso:
#   make APP=2_2                 compila uma aplicacao
#   make APP=2_2 COMPILER=llvm
#   make APP=2_2 dump
#   make APP=2_2 clean
#   make apps                    compila todas as aplicacoes de APPS
#   make clean-all               apaga build/ inteiro
#
# Saidas em build/<APP>/: objetos, <APP>.elf, <APP>.bin, <APP>.vmem
#
# Estrutura esperada de cada aplicacao (todas as subpastas sao opcionais):
#   <APP>/*.c|cpp|S
#   <APP>/ports/cpu/*.c|cpp|S
#   <APP>/common/*.c|cpp|S
#   <APP>/include/
#   <APP>/ldscript.ld linker script da aplicacao (obrigatorio com gcc)
#   <APP>/app.mk      overrides opcionais (PORT_DIR, CFLAGS, LD_SCRIPT, ...)

SW_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# ---------------------------------------------------------------------------
# Aplicacoes
# ---------------------------------------------------------------------------
APPS ?= 2_1
APP  ?= 2_1

APP_DIR   := $(SW_DIR)/$(APP)
BUILD_DIR := $(SW_DIR)/build/$(APP)
PROG      := $(BUILD_DIR)/$(APP)

ifeq ($(wildcard $(APP_DIR)/.),)
    $(error Pasta da aplicacao nao encontrada: $(APP_DIR))
endif

# Overrides especificos da aplicacao (opcional)
-include $(APP_DIR)/app.mk

PORT_DIR   ?= $(APP_DIR)/ports/cpu
INC_DIR    ?= $(APP_DIR)/include
COMMON_DIR ?= $(APP_DIR)/common

# Fontes da aplicacao, relativos a APP_DIR
src_in = $(foreach e,c cpp S,$(wildcard $(1)/*.$(e)))
APP_SRCS := $(patsubst $(APP_DIR)/%,%,                                      \
              $(call src_in,$(APP_DIR)) $(call src_in,$(PORT_DIR))          \
              $(call src_in,$(COMMON_DIR)))
APP_OBJ  := $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(basename $(APP_SRCS))))

# Runtime comum (crt0 + lib), relativos a SW_DIR
RT_SRCS := crt0.S lib/uart.c lib/syscalls.c lib/runtime.c
RT_OBJ  := $(addprefix $(BUILD_DIR)/rt/,$(addsuffix .o,$(basename $(RT_SRCS))))

# crt0 precisa ser o primeiro objeto
RISCV_OBJ := $(firstword $(RT_OBJ)) $(APP_OBJ) $(wordlist 2,99,$(RT_OBJ))

# ---------------------------------------------------------------------------
# Compilador
# ---------------------------------------------------------------------------
COMPILER ?= gcc
ifeq ($(COMPILER),gcc)
    RISCV_CC            := riscv32-unknown-elf-gcc
    RISCV_CXX           := riscv32-unknown-elf-g++
    RISCV_DUMP          := riscv32-unknown-elf-objdump
    RISCV_OBCP          := riscv32-unknown-elf-objcopy
    ARCH                := rv32im_zve32x
    LD_SCRIPT           ?= $(APP_DIR)/ldscript.ld
else ifeq ($(COMPILER),llvm)
    # Pick the first clang executable in $PATH with version >= 14, or the
    # default clang if there is no clang >= 14; the individual steps are:
    #  - find all files containing 'clang*' in all directories in $PATH
    #  - use sed to select all those that match 'clang-[0-9]+'
    #  - use awk to select all those that end with a number >= 14
    #  - append 'clang' to that list in case there is no clang >= 14
    #  - select the first executable from that list
    RISCV_CC            := $(shell find `echo $$PATH | sed 's/:/ /g'`         \
                             -maxdepth 1 -name 'clang*' |                     \
                             sed -n '/clang-[0-9][0-9]*$$/p' |                \
                             awk -F"-" '$$NF>=14' | (cat && echo clang) |     \
                             head -n 1) --target=riscv32
    # clang detecta C++ pela extensao .cpp, entao o mesmo binario serve
    RISCV_CXX           := $(RISCV_CC)
    RISCV_DUMP          := llvm-objdump
    RISCV_OBCP          := llvm-objcopy
    ARCH                := rv32imzve32x
    CC_SPECIFIC_OPTIONS := -fuse-ld=lld -Wno-unused-command-line-argument
    LD_SCRIPT           ?= $(SW_DIR)/lld_link.ld
else
    $(error COMPILER deve ser 'gcc' ou 'llvm')
endif

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
RISCV_FLAGS := -march=$(ARCH) -mabi=ilp32 -static -mcmodel=medany             \
               -fvisibility=hidden --specs=nano.specs --specs=nosys.specs     \
               -nostartfiles -Wall $(CC_SPECIFIC_OPTIONS)

INCLUDES := -I$(SW_DIR)/lib/ -I$(APP_DIR) -I$(PORT_DIR) -I$(INC_DIR) -I$(COMMON_DIR)

# -MMD -MP: gera .d para recompilar quando um header muda
CFLAGS   := $(CFLAGS) $(INCLUDES) -MMD -MP
ASFLAGS  := $(ASFLAGS) $(INCLUDES) -MMD -MP

# Bare-metal: sem excecoes, RTTI e guardas de inicializacao thread-safe
CXXFLAGS := $(CXXFLAGS) -fno-exceptions -fno-rtti -fno-threadsafe-statics

LDFLAGS := $(LDFLAGS) -u _printf_float

# ---------------------------------------------------------------------------
# Regras
# ---------------------------------------------------------------------------
all: $(PROG).vmem

apps:
	@for a in $(APPS); do $(MAKE) --no-print-directory APP=$$a || exit 1; done

dump: $(PROG).elf
	$(RISCV_DUMP) -D $<

# O link usa o driver C++ para que libstdc++ seja encontrada
$(PROG).elf: $(RISCV_OBJ) $(LD_SCRIPT)
	$(RISCV_CXX) $(RISCV_FLAGS) -T $(LD_SCRIPT) $(LDFLAGS) $(RISCV_OBJ) -lm -o $@

# Fontes da aplicacao
$(BUILD_DIR)/%.o: $(APP_DIR)/%.c
	@mkdir -p $(@D)
	$(RISCV_CC) $(RISCV_FLAGS) $(CFLAGS) -c -o $@ $<

$(BUILD_DIR)/%.o: $(APP_DIR)/%.cpp
	@mkdir -p $(@D)
	$(RISCV_CXX) $(RISCV_FLAGS) $(CFLAGS) $(CXXFLAGS) -c -o $@ $<

$(BUILD_DIR)/%.o: $(APP_DIR)/%.S
	@mkdir -p $(@D)
	$(RISCV_CC) $(RISCV_FLAGS) $(ASFLAGS) -c -o $@ $<

# Runtime comum (compilado por aplicacao, pois usa os includes dela)
$(BUILD_DIR)/rt/%.o: $(SW_DIR)/%.c
	@mkdir -p $(@D)
	$(RISCV_CC) $(RISCV_FLAGS) $(CFLAGS) -c -o $@ $<

$(BUILD_DIR)/rt/%.o: $(SW_DIR)/%.S
	@mkdir -p $(@D)
	$(RISCV_CC) $(RISCV_FLAGS) $(ASFLAGS) -c -o $@ $<


# currently unusable due to problems with byte order
# (see https://github.com/riscv/riscv-tools/issues/168#issuecomment-554973539)
#%.vmem: %.elf
#	$(OBJCOPY) -O verilog --verilog-data-width 4 $^ $@

# workaround (requires srecord):
# note: start address must be reset manually because it is lost in bin file
%.vmem: %.bin
	srec_cat $^ -binary -offset 0x0000 -byte-swap 4 -o $@ -vmem
%.bin: %.elf
	$(RISCV_OBCP) -O binary -R .my_image $^ $@

clean:
	rm -rf $(BUILD_DIR)

clean-all:
	rm -rf $(SW_DIR)/build

.PHONY: all apps dump clean clean-all
.PRECIOUS: %.bin %.elf

-include $(RISCV_OBJ:.o=.d)

include $(SW_DIR)/toolchain.mk
