`timescale 1ns / 1ps

// Motorola Serial Peripheral Interface (SPI) PDR 23.3.12 / 16.10.13
// transmitter / receiver of words (fast, clk/3) or bytes (slow, clk/64)
// e.g 8.33MHz or ~400KHz respectively at 25MHz (slow needed for SD-card init)
// note: bytes are always MSbit first; but if fast, words are LSByte first

module SPI(
  input clk, rst,
  input start, fast,
  input [31:0] dataTx,
  output [31:0] dataRx,
  output reg rdy,
  input MISO, output MOSI, output SCLK);

wire endbit, endtick;
reg [31:0] shreg;
reg [5:0] tick;
reg [4:0] bitcnt;

assign endtick = fast ? (tick == 2) : (tick == 63);  //25MHz clk
assign endbit = fast ? (bitcnt == 31) : (bitcnt == 7);
assign dataRx = fast ? shreg : {24'b0, shreg[7:0]};
assign MOSI = (~rst | rdy) ? 1 : shreg[7];
assign SCLK = (~rst | rdy) ? 0 : fast ? endtick : tick[5];

always @ (posedge clk) begin
  tick <= (~rst | rdy | endtick) ? 0 : tick + 1;
  rdy <= (~rst | endtick & endbit) ? 1 : start ? 0 : rdy;
  bitcnt <= (~rst | start) ? 0 : (endtick & ~endbit) ? bitcnt + 1 : bitcnt;
  shreg <= ~rst ? -1 : start ? dataTx : endtick ?
    {shreg[30:24], MISO, shreg[22:16], shreg[31], shreg[14:8],
       shreg[23], shreg[6:0], (fast ? shreg[15] : MISO)} : shreg;
end

endmodule