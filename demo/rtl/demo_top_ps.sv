// demo_top com acesso a DDR do PS (Zynq) via AXI4 master.
//   0x0000_0000 .. RAM_SIZE-1        : ram32 (codigo, INIT_FILE)
//   0xFF00_0000 .. 0xFF00_FFFF        : hwregs (UART)       [inalterado]
//   DDR_V_BASE  .. +DDR_SIZE-1        : DDR do PS via AXI   [novo]
// hwreg_iface e uart_iface continuam em demo_top.sv (nao duplicar).
// Compile com o define MAIN_CORE_CV32E40X.

module demo_top_ps #(
        parameter              RAM_FPATH      = "",
        parameter int unsigned RAM_SIZE       = 262144,
        parameter bit          DIFF_CLK       = 1'b0,
        parameter int unsigned FREQ_MHZ       = 125,
        parameter int unsigned PLL_MUL        = 8,
        parameter int unsigned PLL_DIV        = 40,
        parameter int unsigned UART_BAUD_RATE = 115200,
        parameter int unsigned ICACHE_SZ      = 0,
        parameter int unsigned DCACHE_SZ      = 0,
        // Janela da DDR: como o Vicuna enxerga (V) e onde fica fisicamente (P)
        parameter logic [31:0] DDR_V_BASE     = 32'h1000_0000,
        parameter logic [31:0] DDR_SIZE       = 32'h1000_0000,   // potencia de 2
        parameter logic [31:0] DDR_P_BASE     = 32'h1000_0000,
        parameter int unsigned AXI_ID_W       = 1
    )
    (
        input  logic sys_clk_pi,
        input  logic sys_clk_ni,
        input  logic sys_rst_ni,

        input  logic uart_rx_i,
        output logic uart_tx_o,

        // Controle pelo PS (EMIO GPIO): so libera o Vicuna depois que a DDR esta pronta
        input  logic run_i,

        // Clock/reset gerados aqui (PLL) -> usar no SmartConnect e em S_AXI_HP0_ACLK
        // FREQ_HZ abaixo precisa bater com CLK_FREQ (FREQ_MHZ*PLL_MUL/PLL_DIV); ajuste se mudar o PLL
        (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_o CLK" *)
        (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axi, ASSOCIATED_RESET rst_no, FREQ_HZ 25000000" *)
        output logic clk_o,
        (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_no RST" *)
        (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
        output logic rst_no,

        // AXI4 master -> S_AXI_HP0 do PS
        output logic [AXI_ID_W-1:0]     m_axi_awid,
        output logic [31:0]             m_axi_awaddr,
        output logic [7:0]              m_axi_awlen,
        output logic [2:0]              m_axi_awsize,
        output logic [1:0]              m_axi_awburst,
        output logic                    m_axi_awlock,
        output logic [3:0]              m_axi_awcache,
        output logic [2:0]              m_axi_awprot,
        output logic [3:0]              m_axi_awqos,
        output logic                    m_axi_awvalid,
        input  logic                    m_axi_awready,

        output logic [31:0]             m_axi_wdata,
        output logic [3:0]              m_axi_wstrb,
        output logic                    m_axi_wlast,
        output logic                    m_axi_wvalid,
        input  logic                    m_axi_wready,

        input  logic [AXI_ID_W-1:0]     m_axi_bid,
        input  logic [1:0]              m_axi_bresp,
        input  logic                    m_axi_bvalid,
        output logic                    m_axi_bready,

        output logic [AXI_ID_W-1:0]     m_axi_arid,
        output logic [31:0]             m_axi_araddr,
        output logic [7:0]              m_axi_arlen,
        output logic [2:0]              m_axi_arsize,
        output logic [1:0]              m_axi_arburst,
        output logic                    m_axi_arlock,
        output logic [3:0]              m_axi_arcache,
        output logic [2:0]              m_axi_arprot,
        output logic [3:0]              m_axi_arqos,
        output logic                    m_axi_arvalid,
        input  logic                    m_axi_arready,

        input  logic [AXI_ID_W-1:0]     m_axi_rid,
        input  logic [31:0]             m_axi_rdata,
        input  logic [1:0]              m_axi_rresp,
        input  logic                    m_axi_rlast,
        input  logic                    m_axi_rvalid,
        output logic                    m_axi_rready
    );

    localparam logic [31:0] MEM_START = 32'h00000000;
    localparam logic [31:0] MEM_MASK  = RAM_SIZE-1;
    localparam logic [31:0] DDR_MASK  = DDR_SIZE-1;
    localparam int unsigned CLK_FREQ  = (FREQ_MHZ * 1_000_000 * PLL_MUL) / PLL_DIV;

    // ---------------------------------------------------------------
    // Clock (igual ao demo_top original)
    logic sys_clk;
    generate
        if (DIFF_CLK) begin
            IBUFDS sysclkbuf (
                .I  ( sys_clk_pi ),
                .IB ( sys_clk_ni ),
                .O  ( sys_clk    )
            );
        end else begin
            assign sys_clk = sys_clk_pi;
        end
    endgenerate

    logic clk_raw, pll_lock;
    logic pll_fb_out, pll_fb_in;
    localparam real CLKIN_PERIOD_NS = 1000.0 / FREQ_MHZ;

    BUFG clk_fb_buf (
        .I ( pll_fb_out ),
        .O ( pll_fb_in  )
    );

    PLLE2_BASE #(
        .CLKIN1_PERIOD  ( CLKIN_PERIOD_NS  ),
        .CLKFBOUT_MULT  ( PLL_MUL     ),
        .CLKOUT0_DIVIDE ( PLL_DIV     )
    ) pll_inst (
        .CLKIN1         ( sys_clk     ),
        .CLKOUT0        ( clk_raw     ),
        .CLKOUT1        (             ),
        .CLKOUT2        (             ),
        .CLKOUT3        (             ),
        .CLKOUT4        (             ),
        .CLKOUT5        (             ),
        .LOCKED         ( pll_lock    ),
        .PWRDWN         ( 1'b0        ),
        .RST            ( ~sys_rst_ni ),
        .CLKFBOUT       ( pll_fb_out  ),
        .CLKFBIN        ( pll_fb_in   )
    );

    logic clk;
    BUFG clkbuf (
        .I ( clk_raw ),
        .O ( clk     )
    );

    logic rst_n;
    assign rst_n  = sys_rst_ni & pll_lock & run_i;
    assign clk_o  = clk;
    assign rst_no = rst_n;

    // ---------------------------------------------------------------
    // Vicuna
    logic        mem_req;
    logic [31:0] mem_addr;
    logic        mem_we;
    logic  [3:0] mem_be;
    logic [31:0] mem_wdata;
    logic        mem_rvalid;
    logic        mem_err;
    logic [31:0] mem_rdata;

    vproc_top #(
        .MEM_W        ( 32                          ),
        .VMEM_W       ( 32                          ),
        .VREG_TYPE    ( vproc_pkg::VREG_XLNX_RAM32M ),
        .MUL_TYPE     ( vproc_pkg::MUL_XLNX_DSP48E1 ),
        .ICACHE_SZ    ( ICACHE_SZ                   ),
        .DCACHE_SZ    ( DCACHE_SZ                   )
    ) vproc (
        .clk_i        ( clk                         ),
        .rst_ni       ( rst_n                       ),
        .mem_req_o    ( mem_req                     ),
        .mem_addr_o   ( mem_addr                    ),
        .mem_we_o     ( mem_we                      ),
        .mem_be_o     ( mem_be                      ),
        .mem_wdata_o  ( mem_wdata                   ),
        .mem_rvalid_i ( mem_rvalid                  ),
        .mem_err_i    ( mem_err                     ),
        .mem_rdata_i  ( mem_rdata                   ),
        .pend_vreg_wr_map_o (                       )
    );

    // ---------------------------------------------------------------
    // FIFO de requests (Vicuna nao faz backpressure; max 32 pendentes)
    typedef struct packed {
        logic        we;
        logic [31:0] addr;
        logic  [3:0] be;
        logic [31:0] wdata;
    } req_t;

    req_t       fifo [32];
    logic [4:0] wptr, rptr;
    logic [5:0] cnt;
    logic       push, pop;
    req_t       head;

    function automatic logic in_ddr(input logic [31:0] a);
        return ((a & ~DDR_MASK) == DDR_V_BASE);
    endfunction

    typedef enum logic [2:0] {IDLE, LOC_WAIT, RD, RD_WAIT, WR, WR_WAIT} state_e;
    state_e state;

    // Caminho rapido: nada pendente e destino local (RAM/UART) -> comportamento original
    logic fast_req;
    assign fast_req = mem_req & (cnt == 0) & (state == IDLE) & ~in_ddr(mem_addr);
    assign push     = mem_req & ~fast_req;
    assign head     = fifo[rptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wptr <= '0;
            rptr <= '0;
            cnt  <= '0;
        end else begin
            if (push) begin
                fifo[wptr] <= '{we: mem_we, addr: mem_addr, be: mem_be, wdata: mem_wdata};
                wptr       <= wptr + 5'd1;
            end
            if (pop) rptr <= rptr + 5'd1;
            cnt <= cnt + {5'b0, push} - {5'b0, pop};
        end
    end

    // ---------------------------------------------------------------
    // Barramento local (ram32 + hwregs), alimentado pelo caminho rapido ou pela FIFO
    logic head_ddr;
    assign head_ddr = in_ddr(head.addr);

    logic        fifo_loc_req, loc_req, loc_we, loc_rvalid, loc_err;
    logic  [3:0] loc_be;
    logic [31:0] loc_addr, loc_wdata;

    assign fifo_loc_req = (state == IDLE) & (cnt != 0) & ~head_ddr;
    assign loc_req      = fast_req | fifo_loc_req;
    assign loc_we       = fast_req ? mem_we    : head.we;
    assign loc_be       = fast_req ? mem_be    : head.be;
    assign loc_addr     = fast_req ? mem_addr  : head.addr;
    assign loc_wdata    = fast_req ? mem_wdata : head.wdata;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) loc_rvalid <= 1'b0;
        else        loc_rvalid <= loc_req;
    end

    logic        sram_rvalid;
    logic [31:0] sram_rdata;
    logic        hwreg_rvalid;
    logic [31:0] hwreg_rdata;

    assign loc_err = loc_rvalid & (~(sram_rvalid | hwreg_rvalid));

    ram32 #(
        .SIZE      ( RAM_SIZE / 4                                      ),
        .INIT_FILE ( RAM_FPATH                                         )
    ) u_ram (
        .clk_i     ( clk                                               ),
        .rst_ni    ( rst_n                                             ),
        .req_i     ( loc_req & ((loc_addr & ~MEM_MASK) == MEM_START)   ),
        .we_i      ( loc_req & loc_we                                  ),
        .be_i      ( loc_be                                            ),
        .addr_i    ( loc_addr                                          ),
        .wdata_i   ( loc_wdata                                         ),
        .rvalid_o  ( sram_rvalid                                       ),
        .rdata_o   ( sram_rdata                                        )
    );

    hwreg_iface #(
        .CLK_FREQ       ( CLK_FREQ                                  ),
        .UART_BAUD_RATE ( UART_BAUD_RATE                            )
    ) hwregs (
        .clk_i          ( clk                                       ),
        .rst_ni         ( rst_n                                     ),
        .req_i          ( loc_req & (loc_addr[31:16] == 16'hFF00)   ),
        .we_i           ( loc_we                                    ),
        .addr_i         ( loc_addr[15:0]                            ),
        .wdata_i        ( loc_wdata                                 ),
        .rvalid_o       ( hwreg_rvalid                              ),
        .rdata_o        ( hwreg_rdata                               ),
        .rx_i           ( uart_rx_i                                 ),
        .tx_o           ( uart_tx_o                                 )
    );

    // ---------------------------------------------------------------
    // FSM: atende a FIFO um request por vez (ordem preservada)
    logic aw_done, w_done;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state   <= IDLE;
            aw_done <= 1'b0;
            w_done  <= 1'b0;
        end else begin
            unique case (state)
                IDLE: begin
                    aw_done <= 1'b0;
                    w_done  <= 1'b0;
                    if (cnt != 0) begin
                        if (~head_ddr)    state <= LOC_WAIT;
                        else if (head.we) state <= WR;
                        else              state <= RD;
                    end
                end
                LOC_WAIT: if (loc_rvalid)    state <= IDLE;
                RD:       if (m_axi_arready) state <= RD_WAIT;
                RD_WAIT:  if (m_axi_rvalid)  state <= IDLE;
                WR: begin
                    if (m_axi_awvalid & m_axi_awready) aw_done <= 1'b1;
                    if (m_axi_wvalid  & m_axi_wready ) w_done  <= 1'b1;
                    if ((aw_done | (m_axi_awvalid & m_axi_awready)) &
                        (w_done  | (m_axi_wvalid  & m_axi_wready ))) state <= WR_WAIT;
                end
                WR_WAIT:  if (m_axi_bvalid)  state <= IDLE;
                default:  state <= IDLE;
            endcase
        end
    end

    logic [31:0] phys_addr;
    assign phys_addr = {head.addr[31:2], 2'b00} - DDR_V_BASE + DDR_P_BASE;

    // AR
    assign m_axi_arvalid = (state == RD);
    assign m_axi_arid    = '0;
    assign m_axi_araddr  = phys_addr;
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = 3'd2;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'd0;
    assign m_axi_rready  = (state == RD_WAIT);

    // AW
    assign m_axi_awvalid = (state == WR) & ~aw_done;
    assign m_axi_awid    = '0;
    assign m_axi_awaddr  = phys_addr;
    assign m_axi_awlen   = 8'd0;
    assign m_axi_awsize  = 3'd2;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awlock  = 1'b0;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'd0;

    // W / B
    assign m_axi_wvalid  = (state == WR) & ~w_done;
    assign m_axi_wdata   = head.wdata;
    assign m_axi_wstrb   = head.be;
    assign m_axi_wlast   = 1'b1;
    assign m_axi_bready  = (state == WR_WAIT);

    // ---------------------------------------------------------------
    // Resposta -> Vicuna
    assign mem_rvalid = loc_rvalid |
                        ((state == RD_WAIT) & m_axi_rvalid) |
                        ((state == WR_WAIT) & m_axi_bvalid);
    assign mem_rdata  = (state == RD_WAIT) ? m_axi_rdata :
                        (hwreg_rvalid ? hwreg_rdata : sram_rdata);
    assign mem_err    = (state == RD_WAIT) ? m_axi_rresp[1] :
                        (state == WR_WAIT) ? m_axi_bresp[1] : loc_err;
    assign pop        = ((state == LOC_WAIT) & loc_rvalid) |
                        ((state == RD_WAIT)  & m_axi_rvalid) |
                        ((state == WR_WAIT)  & m_axi_bvalid);

endmodule
