// ============================================================================
// spi_periph - SPI master simples, mapeado em memoria
//
// Mesmo protocolo de barramento do gpio_periph: o req e sempre aceito e a
// resposta (rvalid + rdata) sai no ciclo seguinte.
//
// Mapa de registradores (offset dentro da pagina do periferico):
//   0x00 CTRL    [0] EN    [1] CPOL    [2] CPHA      (so muda com BUSY = 0)
//   0x04 CLKDIV  [15:0]    f_sclk = f_clk / (2 * (CLKDIV + 1)) (so com BUSY = 0)
//   0x08 CS      [N_CS-1:0] nivel direto dos pinos cs_n (reset = todos em 1)
//   0x0C DATA    escrita: inicia transferencia de 1 byte (ignorada se BUSY)
//                leitura: ultimo byte recebido
//   0x10 STATUS  [0] BUSY
//
// Uso tipico pelo software: CS = ~(1 << n); escreve DATA; espera BUSY = 0;
// le DATA; CS = todos em 1.
// ============================================================================

module spi_periph #(
    parameter int unsigned N_CS = 2   // ate 8 (os bits de CS usam o byte 0)
) (
    input  logic            clk_i,
    input  logic            rst_ni,

    // Barramento
    input  logic            req_i,
    input  logic            we_i,
    input  logic [3:0]      be_i,
    input  logic [4:0]      addr_i,
    input  logic [31:0]     wdata_i,
    output logic            rvalid_o,
    output logic [31:0]     rdata_o,

    // Pinos SPI
    output logic            sclk_o,
    output logic            mosi_o,
    input  logic            miso_i,
    output logic [N_CS-1:0] cs_no
);

    localparam logic [2:0] REG_CTRL   = 3'd0;
    localparam logic [2:0] REG_CLKDIV = 3'd1;
    localparam logic [2:0] REG_CS     = 3'd2;
    localparam logic [2:0] REG_DATA   = 3'd3;
    localparam logic [2:0] REG_STATUS = 3'd4;

    logic [2:0] reg_idx;
    assign reg_idx = addr_i[4:2];

    // ------------------------------------------------------------------
    // Estado
    // ------------------------------------------------------------------
    logic            en_q, cpol_q, cpha_q;
    logic [15:0]     clkdiv_q;
    logic [N_CS-1:0] cs_q;

    logic            busy_q;
    logic [15:0]     div_cnt_q;   // ciclos ate a proxima borda de SCLK
    logic [3:0]      edge_cnt_q;  // 16 bordas por byte (0..15)
    logic            sclk_q;      // nivel real do pino SCLK
    logic [7:0]      tx_q;        // registrador de deslocamento de saida
    logic [7:0]      rx_q;        // registrador de deslocamento de entrada

    // ------------------------------------------------------------------
    // Controle das bordas
    // ------------------------------------------------------------------
    logic wr, start, tick, leading, sample_edge, do_sample, do_shift;

    assign wr    = req_i & we_i;
    assign start = wr & (reg_idx == REG_DATA) & be_i[0] & en_q & ~busy_q;

    // tick: momento de gerar uma borda de SCLK
    assign tick = busy_q & (div_cnt_q == '0);

    // Bordas pares (0, 2, ...) sao as "leading" (saem do nivel de repouso)
    assign leading = ~edge_cnt_q[0];

    // CPHA = 0: amostra na leading, desloca na trailing
    // CPHA = 1: desloca na leading, amostra na trailing
    assign sample_edge = leading ^ cpha_q;
    assign do_sample   = tick &  sample_edge;
    // Com CPHA = 1 o MSB ja esta em MOSI desde o inicio, entao a primeira
    // leading (borda 0) nao desloca.
    assign do_shift    = tick & ~sample_edge & ~(cpha_q & (edge_cnt_q == '0));

    // ------------------------------------------------------------------
    // Registradores de configuracao
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            en_q     <= 1'b0;
            cpol_q   <= 1'b0;
            cpha_q   <= 1'b0;
            clkdiv_q <= 16'd49;       // 1 MHz com clock de 100 MHz
            cs_q     <= '1;           // todos os chip selects inativos
        end else if (wr) begin
            case (reg_idx)
                REG_CTRL: if (be_i[0] && !busy_q)
                    {cpha_q, cpol_q, en_q} <= wdata_i[2:0];
                REG_CLKDIV: if (!busy_q) begin
                    if (be_i[0]) clkdiv_q[7:0]  <= wdata_i[7:0];
                    if (be_i[1]) clkdiv_q[15:8] <= wdata_i[15:8];
                end
                REG_CS: if (be_i[0])
                    cs_q <= wdata_i[N_CS-1:0];
                default: ;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Nucleo SPI
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            busy_q     <= 1'b0;
            div_cnt_q  <= '0;
            edge_cnt_q <= '0;
            sclk_q     <= 1'b0;
            tx_q       <= '0;
            rx_q       <= '0;
        end else if (start) begin
            busy_q     <= 1'b1;
            tx_q       <= wdata_i[7:0];
            edge_cnt_q <= '0;
            div_cnt_q  <= clkdiv_q;
        end else if (tick) begin
            sclk_q     <= ~sclk_q;
            div_cnt_q  <= clkdiv_q;
            edge_cnt_q <= edge_cnt_q + 4'd1;
            if (do_sample) rx_q <= {rx_q[6:0], miso_i};
            if (do_shift)  tx_q <= {tx_q[6:0], 1'b0};
            if (edge_cnt_q == 4'd15) busy_q <= 1'b0;
        end else if (busy_q) begin
            div_cnt_q  <= div_cnt_q - 16'd1;
        end else begin
            sclk_q     <= cpol_q;     // em repouso, SCLK segue o CPOL
        end
    end

    // Todas as saidas vem direto de flops: sem glitches nos pads
    assign sclk_o = sclk_q;
    assign mosi_o = tx_q[7];
    assign cs_no  = cs_q;

    // ------------------------------------------------------------------
    // Leitura (resposta no ciclo seguinte, igual ao gpio_periph)
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rvalid_o <= 1'b0;
            rdata_o  <= '0;
        end else begin
            rvalid_o <= req_i;
            if (req_i && !we_i) begin
                case (reg_idx)
                    REG_CTRL:   rdata_o <= {29'b0, cpha_q, cpol_q, en_q};
                    REG_CLKDIV: rdata_o <= {16'b0, clkdiv_q};
                    REG_CS:     rdata_o <= {{(32-N_CS){1'b0}}, cs_q};
                    REG_DATA:   rdata_o <= {24'b0, rx_q};
                    REG_STATUS: rdata_o <= {31'b0, busy_q};
                    default:    rdata_o <= '0;
                endcase
            end
        end
    end

endmodule
