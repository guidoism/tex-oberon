`timescale 1ns / 1ps  // PS/2 mouse PDR 14.10.2013/01.10.2015/23.11.2018
// with Microsoft 3rd (scroll) button init magic and filter
module MouseP(
  input wire clk, rst,
  inout wire msclk, msdat,
  output wire [27:0] out);

  reg [30:0] rx;
  reg [14:0] count;
  reg [9:0] filter, tx, x, y;
  reg [2:0] btns, sent;
  reg req;
  wire shift, endbit, endcount, done, run;
  wire [9:0] dx, dy;
  wire [8:0] cmd;  //including odd tx parity bit

// 322222222221111111111 (scroll mouse z and rx parity p ignored)
// 0987654321098765432109876543210   X, Y = overflow
// -------------------------------   s, t = x, y sign bits
// yyyyyyyy01pxxxxxxxx01pYXts1MRL0   normal report
// p--ack---0Ap--cmd---01111111111   cmd + ack bit (A) & byte

  assign run = (sent == 7);
  assign cmd = (sent == 0) ? 9'h0F4 :   //enable reporting, rate 200,100,80
   (sent == 2) ? 9'h0C8 : (sent == 4) ? 9'h064 : (sent == 6) ? 9'h150 : 9'h1F3;
  assign endcount = (count[14:12] == 3'b111);  // more than 11*100uS @25MHz
  assign shift = ~req & (filter == 10'b1);  //low for 360nS @25MHz
  assign endbit = run ? ~rx[0] : ~rx[10];
  assign done = endbit & endcount & ~req;
  assign dx = {{2{rx[5]}}, rx[7] ? 8'b0 : rx[19:12]};  //sign+overfl
  assign dy = {{2{rx[6]}}, rx[8] ? 8'b0 : rx[30:23]};  //sign+overfl
//  assign out = {run,  // full debug
//    run ? {rx[25:0], endbit} : {rx[30:10], endbit, sent, tx[0], ~req}};
//  assign out = {run,  // debug then normal
//    run ? {btns, 2'b0, y, 2'b0, x} : {rx[30:10], sent, endbit, tx[0], ~req}};
  assign out = {run, btns, 2'b0, y, 2'b0, x}; // normal
  assign msclk = req ? 1'b0 : 1'bz;  //bidir clk/request
  assign msdat = ~tx[0] ? 1'b0 : 1'bz;  //bidir data

  always @ (posedge clk) begin
    filter <= {msclk, filter[9:1]};
    count <= (~rst | shift | endcount) ? 15'b0 : count+15'b1;
    req <= rst & ~run & (req ^ endcount);
    sent <= ~rst ? 3'b0 : sent + {2'b0, (done & ~run)};
    tx <= (~rst | run) ? 10'h3FF : req ? {cmd, 1'b0} : shift ? {1'b1, tx[9:1]} : tx;
    rx <= (~rst | done) ? 31'h7FFFFFFF : (shift & ~endbit) ? {msdat, rx[30:1]} : rx;
    x <= ~run ? 10'b0 : done ? x + dx : x;
    y <= ~run ? 10'b0 : done ? y + dy : y;
    btns <= ~run ? 3'b0 : done ? {rx[1], rx[3], rx[2]} : btns;
  end

endmodule
