// Wrapper Verilog puro para usar o demo_top_ps (SystemVerilog) como module reference no Vivado.
// O Vivado nao aceita arquivo SystemVerilog como top de uma module reference.
// Os atributos X_INTERFACE_* ficam aqui, porque e este modulo que o block design enxerga.

module demo_top_ps_wrap #(
    parameter                RAM_FPATH      = "",
    parameter integer        RAM_SIZE       = 262144,
    parameter                DIFF_CLK       = 1'b0,
    parameter integer        FREQ_MHZ       = 125,
    parameter integer        PLL_MUL        = 8,
    parameter integer        PLL_DIV        = 40,
    parameter integer        UART_BAUD_RATE = 115200,
    parameter integer        ICACHE_SZ      = 0,
    parameter integer        DCACHE_SZ      = 0,
    parameter         [31:0] DDR_V_BASE     = 32'h20000000,
    parameter         [31:0] DDR_SIZE       = 32'h20000000,
    parameter         [31:0] DDR_P_BASE     = 32'h00000000,
    parameter integer        AXI_ID_W       = 1,
    parameter integer        SPI_N_CS       = 2,
    parameter integer        N_GPIO         = 8
) (
    // Clock/reset de entrada (vem do PS)
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 sys_clk_pi CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_RESET sys_rst_ni" *)
    input  wire                  sys_clk_pi,
    input  wire                  sys_clk_ni,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 sys_rst_ni RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                  sys_rst_ni,

    input  wire                  uart_rx_i,
    output wire                  uart_tx_o,

    output wire                  spi_sclk_o,
    output wire                  spi_mosi_o,
    input  wire                  spi_miso_i,
    output wire [SPI_N_CS-1:0]   spi_cs_no,

    // GPIO como interface gpio_rtl: o make_wrapper do block design insere os IOBUFs
    // (porta gpio_tri_io no top). TRI_T=1 -> pino em alta impedancia (entrada).
    (* X_INTERFACE_INFO = "xilinx.com:interface:gpio:1.0 gpio TRI_I" *)
    input  wire [N_GPIO-1:0]     gpio_tri_i,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gpio:1.0 gpio TRI_O" *)
    output wire [N_GPIO-1:0]     gpio_tri_o,
    (* X_INTERFACE_INFO = "xilinx.com:interface:gpio:1.0 gpio TRI_T" *)
    output wire [N_GPIO-1:0]     gpio_tri_t,

    input  wire                  run_i,

    // Clock/reset gerados pelo PLL (25 MHz); FREQ_HZ precisa bater com o PLL
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_o CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axi, ASSOCIATED_RESET rst_no, FREQ_HZ 25000000" *)
    output wire                  clk_o,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_no RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    output wire                  rst_no,

    // AXI4 master
    output wire [AXI_ID_W-1:0]   m_axi_awid,
    output wire [31:0]           m_axi_awaddr,
    output wire [7:0]            m_axi_awlen,
    output wire [2:0]            m_axi_awsize,
    output wire [1:0]            m_axi_awburst,
    output wire                  m_axi_awlock,
    output wire [3:0]            m_axi_awcache,
    output wire [2:0]            m_axi_awprot,
    output wire [3:0]            m_axi_awqos,
    output wire                  m_axi_awvalid,
    input  wire                  m_axi_awready,

    output wire [31:0]           m_axi_wdata,
    output wire [3:0]            m_axi_wstrb,
    output wire                  m_axi_wlast,
    output wire                  m_axi_wvalid,
    input  wire                  m_axi_wready,

    input  wire [AXI_ID_W-1:0]   m_axi_bid,
    input  wire [1:0]            m_axi_bresp,
    input  wire                  m_axi_bvalid,
    output wire                  m_axi_bready,

    output wire [AXI_ID_W-1:0]   m_axi_arid,
    output wire [31:0]           m_axi_araddr,
    output wire [7:0]            m_axi_arlen,
    output wire [2:0]            m_axi_arsize,
    output wire [1:0]            m_axi_arburst,
    output wire                  m_axi_arlock,
    output wire [3:0]            m_axi_arcache,
    output wire [2:0]            m_axi_arprot,
    output wire [3:0]            m_axi_arqos,
    output wire                  m_axi_arvalid,
    input  wire                  m_axi_arready,

    input  wire [AXI_ID_W-1:0]   m_axi_rid,
    input  wire [31:0]           m_axi_rdata,
    input  wire [1:0]            m_axi_rresp,
    input  wire                  m_axi_rlast,
    input  wire                  m_axi_rvalid,
    output wire                  m_axi_rready
);

    wire [N_GPIO-1:0] gpio_oe;
    assign gpio_tri_t = ~gpio_oe;

    demo_top_ps #(
        .RAM_FPATH      ( RAM_FPATH      ),
        .RAM_SIZE       ( RAM_SIZE       ),
        .DIFF_CLK       ( DIFF_CLK       ),
        .FREQ_MHZ       ( FREQ_MHZ       ),
        .PLL_MUL        ( PLL_MUL        ),
        .PLL_DIV        ( PLL_DIV        ),
        .UART_BAUD_RATE ( UART_BAUD_RATE ),
        .ICACHE_SZ      ( ICACHE_SZ      ),
        .DCACHE_SZ      ( DCACHE_SZ      ),
        .DDR_V_BASE     ( DDR_V_BASE     ),
        .DDR_SIZE       ( DDR_SIZE       ),
        .DDR_P_BASE     ( DDR_P_BASE     ),
        .AXI_ID_W       ( AXI_ID_W       ),
        .SPI_N_CS       ( SPI_N_CS       ),
        .N_GPIO         ( N_GPIO         )
    ) u_top (
        .sys_clk_pi    ( sys_clk_pi    ),
        .sys_clk_ni    ( sys_clk_ni    ),
        .sys_rst_ni    ( sys_rst_ni    ),
        .uart_rx_i     ( uart_rx_i     ),
        .uart_tx_o     ( uart_tx_o     ),
        .spi_sclk_o    ( spi_sclk_o    ),
        .spi_mosi_o    ( spi_mosi_o    ),
        .spi_miso_i    ( spi_miso_i    ),
        .spi_cs_no     ( spi_cs_no     ),
        .gpio_in_i     ( gpio_tri_i    ),
        .gpio_out_o    ( gpio_tri_o    ),
        .gpio_oe_o     ( gpio_oe       ),
        .run_i         ( run_i         ),
        .clk_o         ( clk_o         ),
        .rst_no        ( rst_no        ),

        .m_axi_awid    ( m_axi_awid    ),
        .m_axi_awaddr  ( m_axi_awaddr  ),
        .m_axi_awlen   ( m_axi_awlen   ),
        .m_axi_awsize  ( m_axi_awsize  ),
        .m_axi_awburst ( m_axi_awburst ),
        .m_axi_awlock  ( m_axi_awlock  ),
        .m_axi_awcache ( m_axi_awcache ),
        .m_axi_awprot  ( m_axi_awprot  ),
        .m_axi_awqos   ( m_axi_awqos   ),
        .m_axi_awvalid ( m_axi_awvalid ),
        .m_axi_awready ( m_axi_awready ),

        .m_axi_wdata   ( m_axi_wdata   ),
        .m_axi_wstrb   ( m_axi_wstrb   ),
        .m_axi_wlast   ( m_axi_wlast   ),
        .m_axi_wvalid  ( m_axi_wvalid  ),
        .m_axi_wready  ( m_axi_wready  ),

        .m_axi_bid     ( m_axi_bid     ),
        .m_axi_bresp   ( m_axi_bresp   ),
        .m_axi_bvalid  ( m_axi_bvalid  ),
        .m_axi_bready  ( m_axi_bready  ),

        .m_axi_arid    ( m_axi_arid    ),
        .m_axi_araddr  ( m_axi_araddr  ),
        .m_axi_arlen   ( m_axi_arlen   ),
        .m_axi_arsize  ( m_axi_arsize  ),
        .m_axi_arburst ( m_axi_arburst ),
        .m_axi_arlock  ( m_axi_arlock  ),
        .m_axi_arcache ( m_axi_arcache ),
        .m_axi_arprot  ( m_axi_arprot  ),
        .m_axi_arqos   ( m_axi_arqos   ),
        .m_axi_arvalid ( m_axi_arvalid ),
        .m_axi_arready ( m_axi_arready ),

        .m_axi_rid     ( m_axi_rid     ),
        .m_axi_rdata   ( m_axi_rdata   ),
        .m_axi_rresp   ( m_axi_rresp   ),
        .m_axi_rlast   ( m_axi_rlast   ),
        .m_axi_rvalid  ( m_axi_rvalid  ),
        .m_axi_rready  ( m_axi_rready  )
    );

endmodule
