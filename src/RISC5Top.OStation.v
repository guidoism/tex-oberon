`timescale 1ns / 1ps  // NW 14.6.2018
`default_nettype none
// OberonStation ver 5.7.18/16.11.18 PDR

module RISC5Top(
  input wire OSCIN,  // 60MHz oscillator
  input wire [3:0] btn,  // [2:0] on AUX port, 3 reset
  input wire [7:0] nswi,  // open jumpers, [6:4] not connected
  input wire RxD, output wire TxD,  // 3.3V RS-232
  output wire [7:0] leds,
  output wire SRce0, SRce1, SRwe0, SRwe1, SRoe0, SRoe1, //SRAM
    output wire [3:0] SRbe, output wire [17:0] SRadr,
    inout wire [31:0] SRdat,
  input wire [1:0] MISO,  // SPI - SD card & network
    output wire [1:0] SCLK, MOSI, SS,
  output wire NEN,  // network enable
  output wire hsync, vsync, // video controller
    output wire [5:0] RGB,
  input wire PS2C, PS2D,    // keyboard
  inout wire msclk, msdat,  // mouse
  inout wire [7:0] gpio);

// IO addresses for input / output
// 0  -64  FFFFC0  milliseconds / --
// 1  -60  FFFFC4  switches / LEDs
// 2  -56  FFFFC8  RS-232 data / RS-232 data (start)
// 3  -52  FFFFCC  RS-232 status / RS-232 control
// 4  -48  FFFFD0  SPI data / SPI data (start)
// 5  -44  FFFFD4  SPI status / SPI control
// 6  -40  FFFFD8  PS2 mouse data, keyboard status / --
// 7  -36  FFFFDC  keyboard data / --
// 8  -32  FFFFE0  general-purpose I/O data
// 9  -28  FFFFE4  general-purpose I/O tri-state control

reg rst;
wire [23:0] adr;
wire [3:0] iowadr; // word address
wire [31:0] inbus, inbus0;  // data to RISC core
wire [31:0] outbus;  // data from RISC core
wire [31:0] romout, codebus;  // code to RISC core
wire clk, clkn, SRbe0, SRbe1;
wire rd, wr, ben, ioenb, vidreq;

wire [7:0] dataTx, dataRx, dataKbd;
wire rdyRx, doneRx, startTx, rdyTx, rdyKbd, doneKbd;
wire [27:0] dataMs;
reg bitrate;  // for RS232
wire limit;  // of cnt0

reg [7:0] Lreg;
reg [15:0] cnt0;
reg [31:0] cnt1; // milliseconds

wire [31:0] spiRx;
wire spiStart, spiRdy;
reg [3:0] spiCtrl;
wire [17:0] vidadr;
reg [7:0] gpout, gpoc;
wire [7:0] gpin;

RISC5 riscx(.clk(clk), .rst(rst), .irq(limit),
   .rd(rd), .wr(wr), .ben(ben), .stallX(vidreq),
   .adr(adr), .codebus(codebus), .inbus(inbus),
	.outbus(outbus));
PROM PM (.adr(adr[10:2]), .data(romout), .clk(clkn));
RS232R receiver(.clk(clk), .rst(rst), .RxD(RxD), .fsel(bitrate),
   .done(doneRx), .data(dataRx), .rdy(rdyRx));
RS232T transmitter(.clk(clk), .rst(rst), .start(startTx),
   .fsel(bitrate), .data(dataTx), .TxD(TxD), .rdy(rdyTx));
SPI spi(.clk(clk), .rst(rst), .start(spiStart), .dataTx(outbus),
   .fast(spiCtrl[2]), .dataRx(spiRx), .rdy(spiRdy),
 	.SCLK(SCLK[0]), .MOSI(MOSI[0]), .MISO(MISO[0] & MISO[1]));
VID #(.RGBW(6)) vid(.clk(clk), .req(vidreq), .inv(~nswi[7]),
   .vidadr(vidadr), .viddata(inbus0), .RGB(RGB),
	.hsync(hsync), .vsync(vsync));
PS2 kbd(.clk(clk), .rst(rst), .done(doneKbd), .rdy(rdyKbd), .shift(),
   .data(dataKbd), .PS2C(PS2C), .PS2D(PS2D));
MouseP Ms(.clk(clk), .rst(rst), .msclk(msclk),
   .msdat(msdat), .out(dataMs));

assign codebus = (adr[23:14] == 10'h3FF) ? romout : inbus0;
assign iowadr = adr[5:2];
assign ioenb = (adr[23:6] == 18'h3FFFF);
assign inbus = ~ioenb ? inbus0 :
   ((iowadr == 0) ? cnt1 :
    (iowadr == 1) ? {20'b0, btn, ~nswi} :  //btn/swi internal pulldown/up
    (iowadr == 2) ? {24'b0, dataRx} :
    (iowadr == 3) ? {30'b0, rdyTx, rdyRx} :
    (iowadr == 4) ? spiRx :
    (iowadr == 5) ? {31'b0, spiRdy} :
    (iowadr == 6) ? {3'b0, rdyKbd, dataMs} :
    (iowadr == 7) ? {24'b0, dataKbd} :
    (iowadr == 8) ? {24'b0, gpin} :
	 (iowadr == 9) ? {24'b0, gpoc} : 0);

assign SRce0 = ~(~ben | ~adr[1]);
assign SRce1 = ~(~ben | adr[1]);
assign SRbe0 = ~(~ben | ~adr[0]);
assign SRbe1 = ~(~ben | adr[0]);
assign SRoe0 = wr, SRoe1 = wr;
assign SRbe = {SRbe1, SRbe0, SRbe1, SRbe0};
assign SRadr = vidreq ? vidadr : adr[19:2];

// double-data-rate outputs for SRAM write-enable
ODDR2 srwe0ddr(.D0(1'b1), .D1(~wr), .Q(SRwe0),
  .C0(clk), .C1(clkn), .R(1'b0), .S(1'b0), .CE(1'b1));
ODDR2 srwe1ddr(.D0(1'b1), .D1(~wr), .Q(SRwe1),
  .C0(clk), .C1(clkn), .R(1'b0), .S(1'b0), .CE(1'b1));

genvar i;
generate // tri-state buffer for SRAM
  for (i = 0; i < 32; i = i+1)
  begin: bufblock
    IOBUF SRbuf (.I(outbus[i]), .O(inbus0[i]), .IO(SRdat[i]), .T(~wr));
  end
endgenerate

generate // tri-state buffer for gpio port
  for (i = 0; i < 8; i = i+1)
  begin: gpioblock
    IOBUF gpiobuf (.I(gpout[i]), .O(gpin[i]), .IO(gpio[i]), .T(~gpoc[i]));
  end
endgenerate

assign dataTx = outbus[7:0];
assign startTx = wr & ioenb & (iowadr == 2);
assign doneRx = rd & ioenb & (iowadr == 2);
assign limit = (cnt0 == 24999);
assign leds = Lreg;
assign spiStart = wr & ioenb & (iowadr == 4);
assign SS = ~spiCtrl[1:0];  //active low slave select
assign MOSI[1] = MOSI[0], SCLK[1] = SCLK[0], NEN = spiCtrl[3];
assign doneKbd = rd & ioenb & (iowadr == 7);

always @(posedge clk)
begin
  rst <= ((cnt1[4:0] == 0) & limit) ? ~btn[3] : rst;
  Lreg <= ~rst ? 0 : (wr & ioenb & (iowadr == 1)) ? outbus[7:0] : Lreg;
  cnt0 <= limit ? 0 : cnt0 + 1;
  cnt1 <= cnt1 + limit;
  spiCtrl <= ~rst ? 0 : (wr & ioenb & (iowadr == 5)) ? outbus[3:0] : spiCtrl;
  bitrate <= ~rst ? 0 : (wr & ioenb & (iowadr == 3)) ? outbus[0] : bitrate;
  gpout <= (wr & ioenb & (iowadr == 8)) ? outbus[7:0] : gpout;
  gpoc <= ~rst ? 0 : (wr & ioenb & (iowadr == 9)) ? outbus[7:0] : gpoc;
end

// CPU clock generation and buffering
wire clk0, clkfx180;//, clkfx;

DCM_SP #(.CLKFX_MULTIPLY(5), .CLKFX_DIVIDE(12)) 
  dcm0(.CLKIN(OSCIN), .CLKFX(clk), .CLKFX180(clkfx180),
    .CLK0(clk0), .CLK90(), .CLK180(), .CLK270(), .CLKFB(clk0),
    .RST(1'b0), .DSSEN(1'b0), .PSCLK(1'b0), .PSEN(1'b0), .PSINCDEC(1'b0), 
    .CLKDV(), .CLK2X(), .CLK2X180(), .LOCKED(), .PSDONE(), .STATUS());
//BUFG clkbuf(.I(clkfx), .O(clk));
BUFG clknbuf(.I(clkfx180), .O(clkn));

endmodule
