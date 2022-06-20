`timescale 1ns / 1ps  // 1.2.2018
// register file, triple-port

module Registers(
  input clk,wr,
  input [3:0] rno0, rno1, rno2,
  input [31:0] din,
  output [31:0] dout0, dout1, dout2);
genvar i;
generate    //triple port register file, duplicated LUT array
	for (i = 0; i < 32; i = i+1)
	begin: rf32
	RAM16X1D # (.INIT(16'h0000))
	rfb(
	.DPO(dout1[i]), // data out
	.SPO(dout0[i]),
	.A0(rno0[0]),   // R/W address, controls D and SPO
	.A1(rno0[1]),
	.A2(rno0[2]),
	.A3(rno0[3]),
	.D(din[i]),  // data in
	.DPRA0(rno1[0]), // read-only adr, controls DPO
	.DPRA1(rno1[1]),
	.DPRA2(rno1[2]),
	.DPRA3(rno1[3]),
	.WCLK(clk),
	.WE(wr));

	RAM16X1D # (.INIT(16'h0000))
	rfc(
	.DPO(dout2[i]), // data out
	.SPO(),
	.A0(rno0[0]),   // R/W address, controls D and SPO
	.A1(rno0[1]),
	.A2(rno0[2]),
	.A3(rno0[3]),
	.D(din[i]),  // data in
	.DPRA0(rno2[0]), // read-only adr, controls DPO
	.DPRA1(rno2[1]),
	.DPRA2(rno2[2]),
	.DPRA3(rno2[3]),
	.WCLK(clk),
	.WE(wr));
	end
endgenerate
endmodule
