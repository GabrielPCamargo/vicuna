## Pino físico conectado ao cristal de 125 MHz do Ethernet PHY
#set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sys_clk_pi }];
#create_clock -period 8.000 -name sysclk [get_ports sys_clk_pi]
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sys_clk_pi]

## Botão de Reset
#set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { sys_rst_ni }];

## UART
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports uart_tx_o]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports uart_rx_i]

set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets vicuna_ps_i/vicuna/inst/u_top/vproc/core/controller_i/controller_fsm_i/ctrl_fsm*]

set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {vicuna_ps_i/vicuna/inst/u_top/vproc/core/ex_stage_i/mul.mult_i/ex_wb_pipe_o_reg[xif_en]}]
