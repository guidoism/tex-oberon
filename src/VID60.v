`timescale 1ns / 1ps
// 1024x768 display controller NW/PR 24.1.2014
// 60Hz vertical refresh version PR 7.8.15/5.7.18/25.11.18

module VID #(
  parameter RGBW = 3,  // no of RGB pins
  parameter Org = 18'b1101_1111_1111_0000_00)  //DFF00H, rows 0-255 invisible
 (input wire clk, inv,
  input wire [31:0] viddata,
  output wire req,  // SRAM read request
  output wire [17:0] vidadr,
  output wire hsync, vsync, output wire [RGBW-1:0] RGB); // to display

reg [10:0] hcnt;
reg [9:0] vcnt;
reg [31:0] pixbuf, vidbuf;
reg blank, hs, vs, req1, req2;
wire pclk, hend, vend, vblank, req0, xfer;

assign hend = (hcnt == 1344-1), vend = (vcnt == 806-1);
assign hsync = ~hs, vsync = ~vs;  // -ve, -ve
assign vblank = vcnt[8] & vcnt[9];  // vcnt >= 768
assign req0 = (hcnt[4:0] == 0) & ~hcnt[10] & ~vblank;
assign req = req2;
assign xfer = (hcnt[4:0] == 31);  // as late as possible after req
assign vidadr = Org + {3'b0, ~vcnt, hcnt[9:5]};
assign RGB = {RGBW{(pixbuf[0] ^ inv) & ~blank}};

always @(posedge pclk) begin
  hcnt <= hend ? 0 : hcnt+1;
  vcnt <= hend ? (vend ? 0 : (vcnt+1)) : vcnt;
  blank <= xfer ? vblank | hcnt[10] : blank;  // vblank or hcnt >= 1024
  hs <= (hcnt == 1032+31) | hs & (hcnt != 1176+31);
  vs <= (vcnt == 771) | vs & (vcnt != 777);
  pixbuf <= xfer ? vidbuf : {1'b0, pixbuf[31:1]};
end

always @(posedge req0, posedge clk)
  if (req0) req1 <= 1'b1; else req1 <= 1'b0;

always @(posedge clk) begin
  req2 <= req1 & ~req2;
  vidbuf <= req2 ? viddata : vidbuf;
end

// pixel clock generation
wire clkin;
BUFG clkbuf(.I(clk), .O(clkin));
(* LOC = "DCM_X1Y0" *) DCM #(.CLK_FEEDBACK("NONE"), .CLKFX_MULTIPLY(13), .CLKFX_DIVIDE(5)) 
  dcm(.CLKIN(clkin), .CLK0(), .CLK90(), .CLK180(), .CLK270(), 
    .CLKDV(), .CLKFX(pclk), .CLKFX180(), .CLKFB(),
    .RST(1'b0), .DSSEN(1'b0), .PSCLK(1'b0), .PSEN(1'b0), .PSINCDEC(1'b0), 
    .CLK2X(), .CLK2X180(), .LOCKED(), .PSDONE(), .STATUS());

endmodule
