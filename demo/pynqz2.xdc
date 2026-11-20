## Pino físico conectado ao cristal de 125 MHz do Ethernet PHY
#set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sys_clk_pi }];
#create_clock -period 8.000 -name sysclk [get_ports sys_clk_pi]
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sys_clk_pi]

## Botão de Reset
#set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { sys_rst_ni }];

## UART
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports uart_tx_o]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports uart_rx_i]

## SPI no PMOD B (pinagem padrao Pmod SPI: 1=CS, 2=MOSI, 3=MISO, 4=SCK; CS1 no pino 7)
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {spi_cs_no[0]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports spi_mosi_o]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports spi_miso_i]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports spi_sclk_o]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports {spi_cs_no[1]}]

## GPIO (N_GPIO = 8): [3:0] = LD0..LD3, [7:4] = BTN0..BTN3
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {gpio_tri_io[0]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {gpio_tri_io[1]}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {gpio_tri_io[2]}]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {gpio_tri_io[3]}]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {gpio_tri_io[4]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {gpio_tri_io[5]}]
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33} [get_ports {gpio_tri_io[6]}]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33} [get_ports {gpio_tri_io[7]}]

set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets vicuna_ps_i/vicuna/inst/u_top/vproc/core/controller_i/controller_fsm_i/ctrl_fsm*]

set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets {vicuna_ps_i/vicuna/inst/u_top/vproc/core/ex_stage_i/mul.mult_i/ex_wb_pipe_o_reg[xif_en]}]
