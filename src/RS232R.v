`timescale 1ns / 1ps  // NW 4.5.09 / 15.11.10

// RS232 receiver for 19200 or 115200 bps, 8 bit data
// clock is 25 MHz


module RS232R(
    input clk, rst,
	 input RxD,
    input fsel,
    input done,   // "byte has been read"
    output rdy,
    output [7:0] data);

wire endtick, midtick, endbit;
wire [11:0] limit;
reg run, stat;
reg Q0, Q1;  // synchronizer and edge detector
reg [11:0] tick;
reg [3:0] bitcnt;
reg [7:0] shreg;

assign limit = fsel ? 217 : 1302;
assign endtick = tick == limit;
assign midtick = tick == {1'b0, limit[11:1]};  // limit/2
assign endbit = bitcnt == 8;
assign data = shreg;
assign rdy = stat;

always @ (posedge clk) begin
  Q0 <= RxD; Q1 <= Q0;
  run <= (Q1 & ~Q0) | ~(~rst | endtick & endbit) & run;
  tick <= (run & ~endtick) ? tick+1 : 0;
  bitcnt <= (endtick & ~endbit) ? bitcnt + 1 :
    (endtick & endbit) ? 0 : bitcnt;
  shreg <= midtick ? {Q1, shreg[7:1]} : shreg;
  stat <= (endtick & endbit) | ~(~rst | done) & stat;
end
endmodule
