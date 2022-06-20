`timescale 1ns / 1ps  // NW 4.5.09 / 15.8.10 / 15.11.10

// RS232 transmitter for 19200 bps, 8 bit data
// clock is 25 MHz; 25000 / 1302 = 19.2 KHz

module RS232T(
    input clk, rst,
    input start, // request to accept and send a byte
	 input fsel,  // frequency selection
    input [7:0] data,
    output rdy,
    output TxD);

wire endtick, endbit;
wire [11:0] limit;
reg run;
reg [11:0] tick;
reg [3:0] bitcnt;
reg [8:0] shreg;

assign limit = fsel ? 217 : 1302;
assign endtick = tick == limit;
assign endbit = bitcnt == 9;
assign rdy = ~run;
assign TxD = shreg[0];

always @ (posedge clk) begin
  run <= (~rst | endtick & endbit) ? 0 : start ? 1 : run;
  tick <= (run & ~endtick) ? tick + 1 : 0;
  bitcnt <= (endtick & ~endbit) ? bitcnt + 1 :
    (endtick & endbit) ? 0 : bitcnt;
  shreg <= (~rst) ? 1 : start ? {data, 1'b0} :
    endtick ? {1'b1, shreg[8:1]} : shreg;
end
endmodule
