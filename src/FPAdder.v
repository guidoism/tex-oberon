`timescale 1ns / 1ps  // NW 4.10.2016  pipelined
// u = 1: FLT; v = 1: FLOOR

module FPAdder(
  input clk, run, u, v,
  input [31:0] x, y,
  output stall,
  output [31:0] z);

reg [1:0] State;

wire xs, ys, xn, yn;  // signs, null
wire [7:0] xe, ye;
wire [24:0] xm, ym;

wire [8:0] dx, dy, e0, e1;
wire [7:0] sx, sy;  // shift counts
wire [1:0] sx0, sx1, sy0, sy1;
wire sxh, syh;
wire [24:0] x0, x1, x2, y0, y1, y2;
reg [24:0] x3, y3;

reg [26:0] Sum;
wire [26:0] s;

wire z24, z22, z20, z18, z16, z14, z12, z10, z8, z6, z4, z2;
wire [4:0] sc;  // shift count
wire [1:0] sc0, sc1;
wire [24:0] t1, t2;
reg [24:0] t3;

assign xs = x[31];  // sign x
assign xe = u ? 8'h96 : x[30:23];  // expo x
assign xm = {~u|x[23], x[22:0], 1'b0};  //mant x
assign xn = (x[30:0] == 0);
assign ys = y[31];  // sign y
assign ye = y[30:23];  // expo y
assign ym = {~u&~v, y[22:0], 1'b0};  //mant y
assign yn = (y[30:0] == 0);

assign dx = xe - ye;
assign dy = ye - xe;
assign e0 = (dx[8]) ? ye : xe;
assign sx = dy[8] ? 0 : dy;
assign sy = dx[8] ? 0 : dx;
assign sx0 = sx[1:0];
assign sx1 = sx[3:2];
assign sy0 = sy[1:0];
assign sy1 = sy[3:2];
assign sxh = sx[7] | sx[6] | sx[5];
assign syh = sy[7] | sy[6] | sy[5];

// denormalize, shift right
assign x0 = xs&~u ? -xm : xm;
assign x1 = (sx0 == 3) ? {{3{xs}}, x0[24:3]} :
  (sx0 == 2) ? {{2{xs}}, x0[24:2]} : (sx0 == 1) ? {xs, x0[24:1]} : x0;
assign x2 = (sx1 == 3) ? {{12{xs}}, x1[24:12]} :
  (sx1 == 2) ? {{8{xs}}, x1[24:8]} : (sx1 == 1) ? {{4{xs}}, x1[24:4]} : x1;
always @ (posedge(clk))
  x3 <= sxh ? {25{xs}} : (sx[4] ? {{16{xs}}, x2[24:16]} : x2);

assign y0 = ys&~u ? -ym : ym;
assign y1 = (sy0 == 3) ? {{3{ys}}, y0[24:3]} :
  (sy0 == 2) ? {{2{ys}}, y0[24:2]} : (sy0 == 1) ? {ys, y0[24:1]} : y0;
assign y2 = (sy1 == 3) ? {{12{ys}}, y1[24:12]} :
  (sy1 == 2) ? {{8{ys}}, y1[24:8]} : (sy1 == 1) ? {{4{ys}}, y1[24:4]} : y1;
always @ (posedge(clk))
	y3 <= syh ? {25{ys}} : (sy[4] ? {{16{ys}}, y2[24:16]} : y2);
	
// add
always @ (posedge(clk)) Sum <= {xs, xs, x3} + {ys, ys, y3};
assign s = (Sum[26] ? -Sum : Sum) + 1;

// post-normalize
assign z24 = ~s[25] & ~ s[24];
assign z22 = z24 & ~s[23] & ~s[22];
assign z20 = z22 & ~s[21] & ~s[20];
assign z18 = z20 & ~s[19] & ~s[18];
assign z16 = z18 & ~s[17] & ~s[16];
assign z14 = z16 & ~s[15] & ~s[14];
assign z12 = z14 & ~s[13] & ~s[12];
assign z10 = z12 & ~s[11] & ~s[10];
assign z8 = z10 & ~s[9] & ~s[8];
assign z6 = z8 & ~s[7] & ~s[6];
assign z4 = z6 & ~s[5] & ~s[4];
assign z2 = z4 & ~s[3] & ~s[2];

assign sc[4] = z10;  // sc = shift count of post normalization
assign sc[3] = z18 & (s[17] | s[16] | s[15] | s[14] | s[13] | s[12] | s[11] | s[10])
      | z2;
assign sc[2] = z22 & (s[21] | s[20] | s[19] | s[18])
      | z14 & (s[13] | s[12] | s[11] | s[10])
      | z6 & (s[5] | s[4] | s[3] | s[2]);
assign sc[1] = z24 & (s[23] | s[22])
      | z20 & (s[19] | s[18])
      | z16 & (s[15] | s[14])
      | z12 & (s[11] | s[10])
      | z8 & (s[7] | s[6])
      | z4 & (s[3] | s[2]);
assign sc[0] = ~s[25] & s[24]
      | z24 & ~s[23] & s[22]
      | z22 & ~s[21] & s[20]
      | z20 & ~s[19] & s[18]
      | z18 & ~s[17] & s[16]
      | z16 & ~s[15] & s[14]
      | z14 & ~s[13] & s[12]
      | z12 & ~s[11] & s[10]
      | z10 & ~s[9] & s[8]
      | z8 & ~s[7] & s[6]
      | z6 & ~s[5] & s[4]
      | z4 & ~s[3] & s[2];

assign e1 = e0 - sc + 1;
assign sc0 = sc[1:0];
assign sc1 = sc[3:2];

assign t1 = (sc0 == 3) ? {s[22:1], 3'b0} :
  (sc0 == 2) ? {s[23:1], 2'b0} : (sc0 == 1) ? {s[24:1], 1'b0} : s[25:1];
assign t2 = (sc1 == 3) ? {t1[12:0], 12'b0} :
  (sc1 == 2) ? {t1[16:0], 8'b0} : (sc1 == 1) ? {t1[20:0], 4'b0} : t1;
always @ (posedge(clk)) t3 <= sc[4] ? {t2[8:0], 16'b0} : t2;

assign stall = run & ~(State == 3);
always @ (posedge(clk)) State <= run ? State + 1 : 0;

assign z = v ? {{7{Sum[26]}}, Sum[25:1]} :  // FLOOR
    xn ? (u|yn ? 0 : y) :   // FLT or x = y = 0
    yn ? x :
    ((t3 == 0) | e1[8]) ? 0 : 
	 {Sum[26], e1[7:0], t3[23:1]};
endmodule

