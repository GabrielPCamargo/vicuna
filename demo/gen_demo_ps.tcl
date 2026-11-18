# Baseado no gen_demo.tcl da TU Wien (Copyright TU Wien, SHL-2.1).
# Cria o projeto com block design: Zynq-7000 PS + demo_top_ps (Vicuna) + SmartConnect -> S_AXI_HP0.
# Mesmos 8 argumentos do gen_demo.tcl, para nao mudar a sua linha de comando.
# DIFF-CLK e CLK-PER nao sao usados: o clock de entrada vem do FCLK_CLK0 do PS (125 MHz).
#
# Pre-requisito: copiar demo_top_ps.sv e demo_top_ps_wrap.v para $vproc_dir/demo/rtl/
# (a module reference exige um top em Verilog puro; o .v so instancia o demo_top_ps)

if {$argc != 8} {
    puts "usage: gen_demo_ps.tcl VPROC-DIR CORE-DIR CONFIG_FILE PART CONSTR-FILE RAM-FILE DIFF-CLK CLK-PER"
    exit 2
}

set vproc_dir   [lindex $argv 0]
set core_dir    [lindex $argv 1]
set config_file [lindex $argv 2]
set part        [lindex $argv 3]
set constr_file [lindex $argv 4]
set ram_file    [file normalize [lindex $argv 5]]   ;# caminho absoluto, usado no $readmemh

# Sem esse arquivo a BRAM do ram.sv e sintetizada vazia (so um aviso Synth 8-4445)
if {![file readable $ram_file]} {
    puts "AVISO: arquivo de memoria $ram_file nao encontrado ou sem permissao de leitura."
    puts "AVISO: compile o programa (gere o .vmem) antes da sintese, senao a RAM fica zerada."
}

# Ajustes do design
set fclk0_mhz   125      ;# precisa ser igual ao parametro FREQ_MHZ do demo_top_ps
set icache_sz   0        ;# comece sem cache para validar; depois teste 4096
set dcache_sz   0        ;# idem (ex.: 16384)
set ddr_v_base  0x10000000   ;# como o Vicuna enxerga a DDR
set ddr_p_base  0x10000000   ;# onde ela fica fisicamente
set ddr_size    0x10000000   ;# PYNQ-Z2: DDR de 512 MB (0x0000_0000-0x1FFF_FFFF); aqui os 256 MB de cima

# Board files da PYNQ-Z2: nao vem no Vivado; instalar pelo Vivado Store (ver abaixo)

################################################################################
# Projeto
################################################################################
set _xil_proj_name_ "vicuna_demo"   ;# mesmo nome do gen_demo.tcl (o seu script de lancamento espera este diretorio)
# Em modo batch o Vivado nem sempre carrega o board store; adiciona o caminho padrao
# do Vivado Store desta versao do Vivado, se existir.
set store_dir [file join $::env(HOME) .Xilinx Vivado [version -short] xhub board_store xilinx_board_store]
if {[file isdirectory $store_dir] && [lsearch -exact [get_param board.repoPaths] $store_dir] < 0} {
    set_param board.repoPaths [concat [get_param board.repoPaths] [list $store_dir]]
}
create_project -part $part ${_xil_proj_name_} ${_xil_proj_name_}
set proj_dir [get_property directory [current_project]]

set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/${_xil_proj_name_}.cache/ip" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "part" -value $part -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/${_xil_proj_name_}.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj

# Board part (necessario para o preset do PS com a DDR3, PS_CLK e MIOs corretos da PYNQ-Z2).
# Procura qualquer versao instalada do board file; sem ele o PS fica com a DDR padrao
# (MT41J128M8, 32 bits), que nao funciona na PYNQ-Z2, entao o script para com erro.
set board_matches [lsort [get_board_parts -quiet *pynq-z2*]]
if {[llength $board_matches] > 0} {
    set board_part [lindex $board_matches end]
    set_property board_part $board_part $obj
    set have_board 1
    puts "INFO: usando board part $board_part"
} else {
    puts "ERRO: board files da PYNQ-Z2 nao encontrados (Vivado [version -short])."
    puts "ERRO: board.repoPaths = [get_param board.repoPaths]"
    puts "ERRO: instale pelo Vivado (Tools > Vivado Store > Boards > pynq-z2) e rode o make de novo."
    exit 1
}

################################################################################
# Fontes (iguais ao gen_demo.tcl; demo_top.sv continua porque tem hwreg_iface/uart_iface)
################################################################################
set obj [get_filesets sources_1]
set src_list {}
lappend src_list "$vproc_dir/demo/rtl/demo_top.sv"
lappend src_list "$vproc_dir/demo/rtl/demo_top_ps.sv"
lappend src_list "$vproc_dir/demo/rtl/demo_top_ps_wrap.v"
lappend src_list "$vproc_dir/demo/rtl/ram.sv"
lappend src_list "$vproc_dir/demo/rtl/uart_rx.sv"
lappend src_list "$vproc_dir/demo/rtl/uart_tx.sv"
lappend src_list "$vproc_dir/rtl/vproc_pkg.sv"
lappend src_list "$config_file"
foreach file {
    vproc_top.sv vproc_xif.sv vproc_core.sv vproc_decoder.sv vproc_lsu.sv vproc_alu.sv
    vproc_mul.sv vproc_mul_block.sv vproc_sld.sv vproc_elem.sv vproc_pending_wr.sv vproc_vregfile.sv
    vproc_vregpack.sv vproc_vregunpack.sv vproc_queue.sv vproc_result.sv vproc_pipeline.sv
    vproc_pipeline_wrapper.sv vproc_unit_wrapper.sv vproc_unit_mux.sv vproc_vreg_wr_mux.sv
    vproc_dispatcher.sv vproc_cache.sv
} {
    lappend src_list "$vproc_dir/rtl/$file"
}
set main_core ""
if {[string first "cv32e40x" $core_dir] != -1} {
    set main_core "MAIN_CORE_CV32E40X"
    lappend src_list "$core_dir/rtl/include/cv32e40x_pkg.sv"
    foreach file {
        if_xif.sv if_c_obi.sv cv32e40x_core.sv
        cv32e40x_if_stage.sv cv32e40x_id_stage.sv cv32e40x_ex_stage.sv
        cv32e40x_load_store_unit.sv cv32e40x_wb_stage.sv cv32e40x_register_file.sv
        cv32e40x_register_file_wrapper.sv cv32e40x_cs_registers.sv cv32e40x_csr.sv
        cv32e40x_a_decoder.sv           cv32e40x_decoder.sv              cv32e40x_pc_target.sv
        cv32e40x_alignment_buffer.sv    cv32e40x_div.sv                  cv32e40x_pma.sv
        cv32e40x_alu_b_cpop.sv          cv32e40x_popcnt.sv               cv32e40x_m_decoder.sv
        cv32e40x_alu.sv                 cv32e40x_ff_one.sv               cv32e40x_prefetcher.sv
        cv32e40x_b_decoder.sv           cv32e40x_i_decoder.sv            cv32e40x_prefetch_unit.sv
        cv32e40x_compressed_decoder.sv  cv32e40x_controller_bypass.sv    cv32e40x_mpu.sv
        cv32e40x_controller_fsm.sv      cv32e40x_instr_obi_interface.sv  cv32e40x_sleep_unit.sv
        cv32e40x_controller.sv          cv32e40x_int_controller.sv       cv32e40x_mult.sv
        cv32e40x_data_obi_interface.sv  cv32e40x_write_buffer.sv
        cv32e40x_lsu_response_filter.sv
    } {
        lappend src_list "$core_dir/rtl/$file"
    }
    lappend src_list "$core_dir/../demo/rtl/cv32e40x_clock_gate_xilinx.sv"
} else {
    error "Core nao suportado em '$core_dir' (apenas cv32e40x)"
}
add_files -fileset $obj -norecurse -scan_for_includes $src_list

# Simulacao: continua usando o demo_top original (sem AXI)
set obj [get_filesets sim_1]
add_files -fileset $obj -norecurse -scan_for_includes [list "$vproc_dir/demo/rtl/demo_tb.sv"]
set_property top demo_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# O define precisa existir ANTES de criar o block design (a module reference le os fontes)
set_property verilog_define "$main_core" -objects [get_filesets sources_1]
set_property verilog_define "$main_core" -objects [get_filesets sim_1]

# Constraints (ver notas: remover clock/reset de entrada e manter so a UART)
add_files -fileset [get_filesets constrs_1] -norecurse $constr_file

# Waiver automatica do loop combinacional conhecido do Vicuna + CV32E40X
# (vproc/vicuna issue #111). O waive_loops.tcl roda antes do write_bitstream,
# encontra a net do loop pelo DRC e aplica ALLOW_COMBINATORIAL_LOOPS, entao
# nao depende do nome da net (que muda entre builds). Fica na mesma pasta deste script.
set waive_script [file join [file dirname [file normalize [info script]]] waive_loops.tcl]
if {[file exists $waive_script]} {
    add_files -fileset utils_1 -norecurse $waive_script
    set_property STEPS.WRITE_BITSTREAM.TCL.PRE $waive_script [get_runs impl_1]
} else {
    puts "AVISO: $waive_script nao encontrado; o write_bitstream pode falhar com DRC LUTLP-1."
}

update_compile_order -fileset sources_1

################################################################################
# Block design
################################################################################
set bd_name "vicuna_ps"
create_bd_design $bd_name

# --- Processing System (Zynq-7000) ---
set ps7 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0            {0} \
    CONFIG.PCW_USE_S_AXI_HP0            {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $fclk0_mhz \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE    {1} \
    CONFIG.PCW_GPIO_EMIO_GPIO_IO        {1} \
] $ps7

# Preset da PYNQ-Z2 (DDR3, MIOs, UART0/SD/Ethernet do PS) vem do board part.
# O preset e aplicado primeiro; as nossas configuracoes (HP0, EMIO, FCLK0) vem depois.
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config [list make_external "FIXED_IO, DDR" apply_board_preset "$have_board" Master "Disable" Slave "Disable"] $ps7

set_property -dict [list \
    CONFIG.PCW_USE_M_AXI_GP0            {0} \
    CONFIG.PCW_USE_S_AXI_HP0            {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $fclk0_mhz \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE    {1} \
    CONFIG.PCW_GPIO_EMIO_GPIO_IO        {1} \
] $ps7

# --- Vicuna (module reference) ---
set vic [create_bd_cell -type module -reference demo_top_ps_wrap vicuna]
# RAM_FPATH sem aspas extras: o block design ja poe o valor entre aspas ao gerar o HDL.
# Com "\"...\"" o caminho chegava ao $readmemh com aspas dentro (aviso Synth 8-4445).
set_property -dict [list \
    CONFIG.RAM_FPATH     $ram_file \
    CONFIG.FREQ_MHZ      $fclk0_mhz \
    CONFIG.ICACHE_SZ     $icache_sz \
    CONFIG.DCACHE_SZ     $dcache_sz \
    CONFIG.DDR_V_BASE    "32'h[string range $ddr_v_base 2 end]" \
    CONFIG.DDR_P_BASE    "32'h[string range $ddr_p_base 2 end]" \
    CONFIG.DDR_SIZE      "32'h[string range $ddr_size   2 end]" \
] $vic

# --- SmartConnect e reset do dominio do clock do Vicuna (clk_o, do PLL) ---
set smc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1} CONFIG.NUM_CLKS {1}] $smc

set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_vicuna]

set gnd [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 gnd]
set_property -dict [list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {1}] $gnd

# --- Conexoes ---
# Clock/reset de entrada do Vicuna vem do PS (o PLL do demo_top_ps gera o clock de 25 MHz)
connect_bd_net [get_bd_pins ps7/FCLK_CLK0]     [get_bd_pins vicuna/sys_clk_pi]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins vicuna/sys_rst_ni]
connect_bd_net [get_bd_pins gnd/dout]          [get_bd_pins vicuna/sys_clk_ni]
# Start/stop: EMIO GPIO 0 -> run_i
connect_bd_net [get_bd_pins ps7/GPIO_O]        [get_bd_pins vicuna/run_i]

# Reset do interconnect: independente do run_i
connect_bd_net [get_bd_pins vicuna/clk_o]      [get_bd_pins rst_vicuna/slowest_sync_clk]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins rst_vicuna/ext_reset_in]

# AXI: Vicuna -> SmartConnect -> S_AXI_HP0 (tudo no clock clk_o)
connect_bd_intf_net [get_bd_intf_pins vicuna/m_axi] [get_bd_intf_pins smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc/M00_AXI]  [get_bd_intf_pins ps7/S_AXI_HP0]
connect_bd_net [get_bd_pins vicuna/clk_o] [get_bd_pins smc/aclk] [get_bd_pins ps7/S_AXI_HP0_ACLK]
connect_bd_net [get_bd_pins rst_vicuna/peripheral_aresetn] [get_bd_pins smc/aresetn]

# UART para fora (mesmos nomes de porta do demo_top original, para reaproveitar o XDC)
create_bd_port -dir I uart_rx_i
create_bd_port -dir O uart_tx_o
connect_bd_net [get_bd_ports uart_rx_i]     [get_bd_pins vicuna/uart_rx_i]
connect_bd_net [get_bd_pins vicuna/uart_tx_o] [get_bd_ports uart_tx_o]

# Mapa de enderecos (DDR vista pela HP0)
assign_bd_address

regenerate_bd_layout
validate_bd_design
save_bd_design

################################################################################
# Wrapper e top
################################################################################
set wrapper [make_wrapper -files [get_files ${bd_name}.bd] -top]
add_files -norecurse $wrapper
set_property top ${bd_name}_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "Projeto criado. Para gerar o bitstream:"
puts "  launch_runs impl_1 -to_step write_bitstream -jobs 8"
