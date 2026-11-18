// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Modificado para síntese em FPGAs Xilinx
module cv32e40x_clock_gate
#(
  parameter LIB = 0
  )
(
    input  logic clk_i,
    input  logic en_i,
    input  logic scan_cg_en_i,
    output logic clk_o
  );

  logic enable_combined;
  assign enable_combined = en_i | scan_cg_en_i;

  // Substitui a lógica de simulação pela primitiva de gating de clock da Xilinx
  BUFGCE clock_gate_inst (
    .I(clk_i),
    .CE(enable_combined),
    .O(clk_o)
  );

endmodule // cv32e40x_clock_gate
