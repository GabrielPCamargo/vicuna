# waive_loops.tcl - roda como tcl.pre do write_bitstream (configurado pelo gen_demo_ps.tcl).
# Encontra o loop combinacional conhecido do Vicuna + CV32E40X (vproc/vicuna issue #111)
# e aplica ALLOW_COMBINATORIAL_LOOPS em uma net do loop, seja qual for o nome dela.
# Se aparecer um loop com celulas fora do Vicuna, para com erro em vez de esconder.

report_drc -name lutlp -checks LUTLP-1
foreach v [get_drc_violations -quiet -name lutlp] {
    set cells [get_cells -of_objects $v]

    # Seguranca: so libera loops inteiramente dentro do Vicuna
    foreach p [get_property PARENT $cells] {
        if {![string match "*/u_top/vproc/*" $p]} {
            error "Loop inclui celulas fora do Vicuna ($p) - verifique o design!"
        }
    }

    # Net de saida de um LUT do loop
    set pin [get_pins -of_objects [lindex $cells 0] -filter {DIRECTION == OUT}]
    set net [get_nets -of_objects $pin]
    set_property ALLOW_COMBINATORIAL_LOOPS TRUE $net
    puts "INFO: Waived Vicuna combinatorial loop on net $net"
}
