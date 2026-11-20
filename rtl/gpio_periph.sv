module gpio_periph #(
  parameter int unsigned N_GPIO = 8   // até 32
) (
  input  logic              clk_i,
  input  logic              rst_ni,
  // barramento (mesmo protocolo do mem_* do vproc_top)
  input  logic              req_i,
  input  logic              we_i,
  input  logic [3:0]        be_i,
  input  logic [4:0]        addr_i,    // offset em bytes dentro do periférico
  input  logic [31:0]       wdata_i,
  output logic              rvalid_o,
  output logic [31:0]       rdata_o,
  // lado dos pads
  input  logic [N_GPIO-1:0] gpio_in_i,
  output logic [N_GPIO-1:0] gpio_out_o,
  output logic [N_GPIO-1:0] gpio_oe_o
);

  logic [31:0]       be_mask;
  logic [N_GPIO-1:0] bmask, wmask;
  logic [N_GPIO-1:0] dir_q, out_q;
  logic [N_GPIO-1:0] in_meta_q, in_sync_q;
  logic [31:0]       rdata_d, rdata_q;
  logic              rvalid_q;

  assign be_mask = {{8{be_i[3]}}, {8{be_i[2]}}, {8{be_i[1]}}, {8{be_i[0]}}};
  assign bmask   = be_mask[N_GPIO-1:0];
  assign wmask   = wdata_i[N_GPIO-1:0] & bmask;

  // Sincronizador de 2 flops: as entradas vêm de fora e são assíncronas
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      in_meta_q <= '0;
      in_sync_q <= '0;
    end else begin
      in_meta_q <= gpio_in_i;
      in_sync_q <= in_meta_q;
    end
  end

  // Leitura
  always_comb begin
    rdata_d = '0;
    case (addr_i[4:2])
      3'd0: rdata_d[N_GPIO-1:0] = dir_q;
      3'd1: rdata_d[N_GPIO-1:0] = out_q;
      3'd2: rdata_d[N_GPIO-1:0] = in_sync_q;
      default: ;
    endcase
  end

  // Escrita e resposta
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dir_q    <= '0;      // após o reset, todos os pinos são entrada
      out_q    <= '0;
      rvalid_q <= 1'b0;
      rdata_q  <= '0;
    end else begin
      rvalid_q <= req_i;
      if (req_i && !we_i) rdata_q <= rdata_d;
      if (req_i &&  we_i) begin
        case (addr_i[4:2])
          3'd0: dir_q <= (dir_q & ~bmask) | wmask;
          3'd1: out_q <= (out_q & ~bmask) | wmask;
          3'd3: out_q <= out_q |  wmask;
          3'd4: out_q <= out_q & ~wmask;
          default: ;
        endcase
      end
    end
  end

  assign rvalid_o   = rvalid_q;
  assign rdata_o    = rdata_q;
  assign gpio_out_o = out_q;
  assign gpio_oe_o  = dir_q;

endmodule