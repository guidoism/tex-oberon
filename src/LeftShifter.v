`timescale 1ns / 1ps  // NW 9.11.2016

module LeftShifter(
input [31:0] x,
input [4:0] sc,
output [31:0] y);

// shifter for LSL
wire [1:0] sc0, sc1;
wire [31:0] t1, t2;

assign sc0 = sc[1:0];
assign sc1 = sc[3:2];

assign t1 = (sc0 == 3) ? {x[28:0], 3'b0} :
    (sc0 == 2) ? {x[29:0], 2'b0} :
    (sc0 == 1) ? {x[30:0], 1'b0} : x;
assign t2 = (sc1 == 3) ? {t1[19:0], 12'b0} :
    (sc1 == 2) ? {t1[23:0], 8'b0} :
    (sc1 == 1) ? {t1[27:0], 4'b0} : t1;
assign y = sc[4] ? {t2[15:0], 16'b0} : t2;
endmodule