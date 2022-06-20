`timescale 1ns / 1ps   // NW 14.9.2015

module Multiplier(
  input clk, run, u,
  output stall,
  input [31:0] x, y,
  output [63:0] z);

reg [5:0] S;    // state
reg [63:0] P;   // product
wire [31:0] w0;
wire [32:0] w1;

assign stall = run & ~(S == 33);
assign w0 = P[0] ? y : 0;
assign w1 = (S == 32) & u ? {P[63], P[63:32]} - {w0[31], w0} :
       {P[63], P[63:32]} + {w0[31], w0};
assign z = P;

always @ (posedge(clk)) begin
  P <= (S == 0) ? {32'b0, x} : {w1[32:0], P[31:1]};
  S <= run ? S+1 : 0;
end

endmodule
