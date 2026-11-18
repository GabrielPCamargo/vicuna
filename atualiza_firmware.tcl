# atualiza_firmware.tcl
# Coloca um firmware novo no bitstream do Vicuna sem ressintetizar.
#
# Carregar (1x por sessao):
#   source /home/gabriel/Documents/research/vector/vicuna/atualiza_firmware.tcl
#
# Metodo recomendado (escreve direto nas BRAMs; precisa do impl_1 aberto):
#   open_run impl_1
#   fw_le_palavras 0 8            ;# confere o firmware atual do design
#   grava_firmware 2_1/2_1        ;# gera bitstreams/vicuna_2_1.bit (~1-2 min)
#
# Metodo antigo via updatemem/.mmi (nao precisa do impl_1 aberto):
#   atualiza_firmware 2_1/2_1
#
# Saidas em $FW_SAIDA_DIR:
#   vicuna_<nome>.bit    bitstream com o firmware nas BRAMs
#   <nome>_bram.elf      ELF so com as secoes da BRAM
#   <nome>_ddr.bin       dados inicializados da DDR, se houver (carregar a parte)

# ---------------------------------------------------------------------------
# Configuracao
# ---------------------------------------------------------------------------
set ::FW_RAIZ       /home/gabriel/Documents/research/vector/vicuna
set ::FW_DIR        $::FW_RAIZ/sw/build
set ::FW_BITSTREAM  $::FW_RAIZ/vivado/vicuna_demo/vicuna_demo.runs/impl_1/vicuna_ps_wrapper.bit
set ::FW_MMI        $::FW_RAIZ/firmware.mmi
set ::FW_SAIDA_DIR  $::FW_RAIZ/bitstreams
set ::FW_PROC       riscv
set ::FW_RAM_PADRAO u_ram/mem_reg   ;# trecho do nome das BRAMs da RAM do Vicuna

# Fim da BRAM no mapa do Vicuna (boot + ram = 0x00000000..0x0003FFFF)
set ::FW_BRAM_FIM   0x00040000

set ::FW_TOOL       /opt/riscv-vicuna/bin/riscv32-unknown-elf
set ::FW_READELF    ${::FW_TOOL}-readelf
set ::FW_OBJCOPY    ${::FW_TOOL}-objcopy

# ---------------------------------------------------------------------------
# Preparacao do ELF (comum aos dois metodos)
# ---------------------------------------------------------------------------

# Secoes alocadas (flag A) fora da BRAM: {nome tipo endereco tamanho}
proc fw_secoes_fora_bram {elf} {
    set fora {}
    foreach linha [split [exec -ignorestderr $::FW_READELF -SW $elf] \n] {
        set fim [string first "\]" $linha]
        if {$fim < 0 || ![regexp {^\s*\[\s*\d+\]} $linha]} { continue }
        set campos [regexp -all -inline {\S+} [string range $linha [expr {$fim + 1}] end]]
        if {[llength $campos] < 9} { continue }
        lassign $campos nome tipo addr off tam
        set flags [expr {[llength $campos] >= 10 ? [lindex $campos 6] : ""}]
        if {[string first A $flags] < 0} { continue }
        if {"0x$addr" >= $::FW_BRAM_FIM} {
            lappend fora [list $nome $tipo $addr $tam]
        }
    }
    return $fora
}

# Localiza o ELF, separa BRAM/DDR e devolve um dict com os caminhos
proc fw_prepara {nome} {
    if {[file extension $nome] ne ".elf"} { append nome ".elf" }
    set nome [string trimleft $nome "/"]
    set elf  $::FW_DIR/$nome
    set base [file rootname [file tail $nome]]
    file mkdir $::FW_SAIDA_DIR

    if {![file exists $elf]} {
        set existentes [lmap f [glob -nocomplain -directory $::FW_DIR */*.elf *.elf] \
                            {string range $f [expr {[string length $::FW_DIR] + 1}] end}]
        error "Firmware nao encontrado: $elf\nDisponiveis em $::FW_DIR: $existentes"
    }

    set p [dict create elf $elf base $base \
               elf_bram $::FW_SAIDA_DIR/${base}_bram.elf \
               bin_ddr  $::FW_SAIDA_DIR/${base}_ddr.bin \
               saida    $::FW_SAIDA_DIR/vicuna_$base.bit \
               log      $::FW_SAIDA_DIR/vicuna_$base.log]

    set remover {}
    set com_dados {}
    foreach s [fw_secoes_fora_bram $elf] {
        lassign $s snome stipo saddr stam
        lappend remover -R $snome
        if {$stipo ne "NOBITS"} { lappend com_dados $snome }
        puts [format "  fora da BRAM: %-20s %-9s 0x%s (0x%s bytes)" $snome $stipo $saddr $stam]
    }
    exec -ignorestderr $::FW_OBJCOPY {*}$remover $elf [dict get $p elf_bram]

    if {[llength $com_dados] > 0} {
        set selecionar {}
        foreach s $com_dados { lappend selecionar -j $s }
        exec -ignorestderr $::FW_OBJCOPY -O binary {*}$selecionar $elf [dict get $p bin_ddr]
        puts "AVISO: secoes com dados na DDR: $com_dados"
        puts "       O bitstream NAO leva esses dados. Exportados para [dict get $p bin_ddr]"
    } elseif {[file exists [dict get $p bin_ddr]]} {
        file delete [dict get $p bin_ddr]
    }
    return $p
}

# ---------------------------------------------------------------------------
# Metodo recomendado: escrita direta nas propriedades INIT das BRAMs
# ---------------------------------------------------------------------------

# BRAMs da RAM do Vicuna: lista de {celula addr_begin addr_end bit}
proc fw_celulas {} {
    set cells [get_cells -quiet -hier -filter \
                   "PRIMITIVE_TYPE =~ BMEM.*.* && NAME =~ *${::FW_RAM_PADRAO}*"]
    if {[llength $cells] == 0} {
        error "Nenhuma BRAM encontrada com '$::FW_RAM_PADRAO'. O impl_1 esta aberto? (open_run impl_1)"
    }
    set lista {}
    foreach c $cells {
        set largura [get_property READ_WIDTH_A $c]
        set sb [get_property ram_slice_begin $c]
        set se [get_property ram_slice_end $c]
        if {$largura != 1 || $sb != $se} {
            error "$c tem largura $largura (bits $sb..$se); este script so trata BRAMs de 1 bit"
        }
        lappend lista [list $c [get_property ram_addr_begin $c] [get_property ram_addr_end $c] $sb]
    }
    return $lista
}

# Le n palavras a partir do endereco (em bytes) direto das INIT do design aberto
proc fw_le_palavras {{inicio 0} {n 8}} {
    set cells [fw_celulas]
    for {set k 0} {$k < $n} {incr k} {
        set end [expr {$inicio + 4 * $k}]
        set w   [expr {$end >> 2}]
        set val 0
        foreach c $cells {
            lassign $c cel ab ae bit
            if {$w < $ab || $w > $ae} { continue }
            set local [expr {$w - $ab}]
            set init  [get_property [format INIT_%02X [expr {$local / 256}]] $cel]
            set hex   [string range $init [expr {[string first h $init] + 1}] end]
            set hex   [string repeat 0 [expr {64 - [string length $hex]}]]$hex
            set pos   [expr {$local % 256}]
            scan [string index $hex [expr {63 - $pos / 4}]] %x nib
            set val [expr {$val | ((($nib >> ($pos % 4)) & 1) << $bit)}]
        }
        puts [format "  0x%08X: %08x" $end $val]
    }
}

# Le um arquivo "objcopy -O verilog" (bytes com enderecos @) para uma lista de palavras
proc fw_carrega_vh {vh nwords} {
    set W [lrepeat $nwords 0]
    set f [open $vh]
    set txt [read $f]
    close $f
    set addr 0
    foreach tok $txt {
        if {[string index $tok 0] eq "@"} {
            scan [string range $tok 1 end] %x addr
            continue
        }
        scan $tok %x b
        set w [expr {$addr >> 2}]
        if {$w >= $nwords} {
            error [format "Dado no endereco 0x%08X, fora da BRAM" $addr]
        }
        lset W $w [expr {[lindex $W $w] | ($b << (8 * ($addr & 3)))}]
        incr addr
    }
    return $W
}

# Escreve as palavras W nas INIT das BRAMs (largura 1: bit n da BRAM = endereco local n)
proc fw_aplica_init {W cells} {
    set nz [dict create]
    set i 0
    foreach v $W {
        if {$v != 0} { dict set nz [expr {$i / 256}] 1 }
        incr i
    }
    set zero "256'h[string repeat 0 64]"
    foreach c $cells {
        lassign $c cel ab ae bit
        set props {}
        set nblocos [expr {($ae - $ab + 1) / 256}]
        for {set g 0} {$g < $nblocos} {incr g} {
            set w0 [expr {$ab + $g * 256}]
            if {![dict exists $nz [expr {$w0 / 256}]]} {
                lappend props [format INIT_%02X $g] $zero
                continue
            }
            set hex ""
            for {set k 63} {$k >= 0} {incr k -1} {
                set nib 0
                for {set j 0} {$j < 4} {incr j} {
                    set v [lindex $W [expr {$w0 + 4 * $k + $j}]]
                    set nib [expr {$nib | ((($v >> $bit) & 1) << $j)}]
                }
                append hex [format %X $nib]
            }
            lappend props [format INIT_%02X $g] "256'h$hex"
        }
        set_property -dict $props $cel
    }
}

proc grava_firmware {nome} {
    set cells [fw_celulas]   ;# falha cedo se o impl_1 nao estiver aberto
    set p [fw_prepara $nome]
    set nwords [expr {$::FW_BRAM_FIM / 4}]

    set vh $::FW_SAIDA_DIR/[dict get $p base]_bram.vh
    exec -ignorestderr $::FW_OBJCOPY -O verilog [dict get $p elf_bram] $vh
    set W [fw_carrega_vh $vh $nwords]

    puts "Gravando [dict get $p elf] em [llength $cells] BRAMs..."
    fw_aplica_init $W $cells

    puts "Primeiras palavras gravadas (compare com o objdump):"
    fw_le_palavras 0 4

    write_bitstream -force [dict get $p saida]
    puts "OK: [dict get $p saida]"
    return [dict get $p saida]
}

# ---------------------------------------------------------------------------
# Metodo antigo: updatemem + .mmi
# ---------------------------------------------------------------------------
proc atualiza_firmware {nome} {
    set p [fw_prepara $nome]
    foreach {tipo arq} [list "bitstream" $::FW_BITSTREAM ".mmi" $::FW_MMI] {
        if {![file exists $arq]} { error "Arquivo de $tipo nao encontrado: $arq" }
    }
    set cmd [list updatemem -meminfo $::FW_MMI -data [dict get $p elf_bram] \
                 -proc $::FW_PROC -bit $::FW_BITSTREAM -out [dict get $p saida] -force -debug]
    set status [catch {exec {*}$cmd 2>@1} texto opcoes]
    set f [open [dict get $p log] w]
    puts $f $texto
    close $f
    if {$status != 0 && [lindex [dict get $opcoes -errorcode] 0] eq "CHILDSTATUS"} {
        puts $texto
        error "updatemem falhou. Log em [dict get $p log]"
    }
    puts "OK: [dict get $p saida]"
    return [dict get $p saida]
}

puts "Carregado. Com o impl_1 aberto: fw_le_palavras 0 8 | grava_firmware <nome_do_elf>"