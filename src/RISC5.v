`timescale 1ns / 1ps  // 31.8.2018
//with interrupt and floating-point

module RISC5(
input clk, rst, irq, stallX,
input [31:0] inbus, codebus,
output [23:0] adr,
output rd, wr, ben,
output [31:0] outbus);

localparam StartAdr = 22'h3FF800;

reg [21:0] PC;
reg [31:0] IR;  // instruction register
reg N, Z, C, OV;  // condition flags 
reg [31:0] H;  // aux register
reg stallL1;

wire [21:0] pcmux, pcmux0, nxpc;
wire cond, S;
wire sa, sb, sc;

wire p, q, u, v;  // instruction fields
wire [3:0] op, ira, ira0, irb, irc;
wire [2:0] cc;
wire [15:0] imm;
wire [19:0] off;
wire [21:0] disp;

wire regwr;
wire stall, stallL0, stallM, stallD, stallFA, stallFM, stallFD;
wire nn, zz, cx, vv;

reg irq1, intEnb, intPnd, intMd;
reg [25:0] SPC; // saved PC on interrupt
wire intAck;

wire [31:0] A, B, C0, C1, aluRes, regmux, inbus1;
wire [31:0] lshout, rshout;
wire [31:0] quotient, remainder;
wire [63:0] product;
wire [31:0] fsum, fprod, fquot;

wire ADD, SUB, MUL, DIV;
wire FAD, FSB, FML, FDV;
wire LDR, STR, BR, RTI;

Registers regs (.clk(clk), .wr(regwr), .rno0(ira0), .rno1(irb),
   .rno2(irc), .din(regmux), .dout0(A), .dout1(B), .dout2(C0));

Multiplier mulUnit (.clk(clk), .run(MUL), .stall(stallM),
   .u(~u), .x(B), .y(C1), .z(product));

Divider divUnit (.clk(clk), .run(DIV), .stall(stallD),
   .u(~u), .x(B), .y(C1), .quot(quotient), .rem(remainder));

LeftShifter LSUnit (.x(B), .y(lshout), .sc(C1[4:0]));

RightShifter RSUnit(.x(B), .y(rshout), .sc(C1[4:0]), .md(IR[16]));

FPAdder fpaddx (.clk(clk), .run(FAD|FSB), .u(u), .v(v), .stall(stallFA),
   .x(B), .y({FSB^C0[31], C0[30:0]}), .z(fsum));

FPMultiplier fpmulx (.clk(clk), .run(FML), .stall(stallFM),
   .x(B), .y(C0), .z(fprod));

FPDivider fpdivx (.clk(clk), .run(FDV), .stall(stallFD),
   .x(B), .y(C0), .z(fquot));

assign p = IR[31];
assign q = IR[30];
assign u = IR[29];
assign v = IR[28];
assign cc  = IR[26:24];
assign ira = IR[27:24];
assign irb = IR[23:20];
assign op  = IR[19:16];
assign irc = IR[3:0];
assign imm = IR[15:0];   // reg instr.
assign off = IR[19:0];   // mem instr.
assign disp = IR[21:0];  // branch instr.

assign ADD = ~p & (op == 8);
assign SUB = ~p & (op == 9);
assign MUL = ~p & (op == 10);
assign DIV = ~p & (op == 11);

assign FAD = ~p & (op == 12);
assign FSB = ~p & (op == 13);
assign FML = ~p & (op == 14);
assign FDV = ~p & (op == 15);

assign LDR = p & ~q & ~u;
assign STR = p & ~q & u;
assign BR = p & q;
assign RTI = BR & ~u & ~v & IR[4];

// Arithmetic-logical unit (ALU)
assign ira0 = BR ? 15 : ira;
assign C1 = q ? {{16{v}}, imm} : C0;
assign adr = stallL0 ? B[23:0] + {{4{off[19]}}, off} : {pcmux, 2'b00};
assign rd = LDR & ~stallX & ~stallL1;
assign wr = STR & ~stallX & ~stallL1;
assign ben = p & ~q & v & ~stallX & ~stallL1;  // byte enable

assign aluRes =
  ~op[3] ?
    (~op[2] ?
      (~op[1] ?
        (~op[0] ? 
          (q ?  // MOV
            (~u ? {{16{v}}, imm} : {imm, 16'b0}) :
            (~u ? C0 : (~v ? H : {N, Z, C, OV, 20'b0, 8'h53}))) :
          lshout) :  //  LSL
        rshout) : //  ASR, ROR
      (~op[1] ?
        (~op[0] ? B & C1 : B & ~C1) :  // AND, ANN
        (~op[0] ? B | C1 : B ^ C1))) : // IOR. XOR
    (~op[2] ?
       (~op[1] ?
          (~op[0] ? B + C1 + (u&C) : B - C1 - (u&C)) :   // ADD, SUB
           (~op[0] ? product[31:0] : quotient)) :  // MUL, DIV
       (~op[1] ?    // flt.pt.
          fsum :
          (~op[0] ? fprod : fquot)));

assign regwr = ~p & ~stall | (LDR & ~stallX & ~stallL1) | (BR & cond & v & ~stallX);
assign inbus1 = ~ben ? inbus :
  {24'b0, (adr[1] ? (adr[0] ? inbus[31:24] : inbus[23:16]) :
          (adr[0] ? inbus[15:8] : inbus[7:0]))};
assign regmux = LDR ? inbus1 : (BR & v) ? {8'b0, nxpc, 2'b0} : aluRes;
assign outbus = ~ben ? A :
  adr[1] ? (adr[0] ? {A[7:0], 24'b0} : {8'b0, A[7:0], 16'b0}) :
           (adr[0] ? {16'b0, A[7:0], 8'b0} : {24'b0, A[7:0]});

// Control unit CU
assign S = N ^ OV;
assign nxpc = PC + 1;
assign cond = IR[27] ^
  ((cc == 0) & N | // MI, PL
   (cc == 1) & Z | // EQ, NE
   (cc == 2) & C | // CS, CC
   (cc == 3) & OV | // VS, VC
   (cc == 4) & (C|Z) | // LS, HI
   (cc == 5) & S | // LT, GE
   (cc == 6) & (S|Z) | // LE, GT
   (cc == 7)); // T, F

assign intAck = intPnd & intEnb & ~intMd & ~stall;
assign pcmux = ~rst | stall | intAck | RTI ? 
   (~rst | stall ? (~rst ? StartAdr : PC) :
   (intAck ? 1 : SPC)) : pcmux0;
assign pcmux0 = (BR & cond) ? (u? nxpc + disp : C0[23:2]) : nxpc;
  
assign sa = aluRes[31];
assign sb = B[31];
assign sc = C1[31];

assign nn = RTI ? SPC[25] : regwr ? regmux[31] : N;
assign zz = RTI ? SPC[24] : regwr ? (regmux == 0) : Z;
assign cx = RTI ? SPC[23] :
    ADD ? (~sb&sc&~sa) | (sb&sc&sa) | (sb&~sa) :
	 SUB ? (~sb&sc&~sa) | (sb&sc&sa) | (~sb&sa) : C;
assign vv = RTI ? SPC[22] :
    ADD ? (sa&~sb&~sc) | (~sa&sb&sc): 
	 SUB ? (sa&~sb&sc) | (~sa&sb&~sc) : OV;
	 
assign stallL0 = (LDR|STR) & ~stallL1;
assign stall = stallL0 | stallM | stallD | stallX | stallFA | stallFM | stallFD;

always @ (posedge clk) begin
  PC <= pcmux;
  IR <= stall ? IR : codebus;
  stallL1 <= stallX ? stallL1 : stallL0;
  N <= nn; Z <= zz; C <= cx; OV <= vv;
  H <= MUL ? product[63:32] : DIV ? remainder : H;

  irq1 <= irq;  // edge detector
  intPnd <= rst & ~intAck & ((~irq1 & irq) | intPnd);
  intMd <= rst & ~RTI & (intAck | intMd);
  intEnb <= ~rst ? 0 : (BR & ~u & ~v & IR[5]) ? IR[0] : intEnb;
  SPC <= (intAck) ? {nn, zz, cx, vv, pcmux0} : SPC;
  end 
endmodule 
