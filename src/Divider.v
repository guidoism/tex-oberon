`timescale 1ns / 1ps  // NW 20.9.2015

module Divider(
  input clk, run, u,
  output stall,
  input [31:0] x, y,  // y > 0
  output [31:0] quot, rem);

reg [5:0] S;  // state
reg [63:0] RQ;
wire sign;
wire [31:0] x0, w0, w1;

assign stall = run & ~(S == 33);
assign sign = x[31] & u;
assign x0 = sign ? -x : x;
assign w0 = RQ[62: 31];
assign w1 = w0 - y;
assign quot = ~sign ? RQ[31:0] :
  (RQ[63:32] == 0) ? -RQ[31:0] : -RQ[31:0] - 1;
assign rem = ~sign ? RQ[63:32] :
  (RQ[63:32] == 0) ? 0 : y - RQ[63:32];

always @ (posedge(clk)) begin
  RQ <= (S == 0) ? {32'b0, x0} : {(w1[31] ? w0 : w1), RQ[30:0], ~w1[31]};
  S <= run ? S+1 : 0;
end
endmodule
