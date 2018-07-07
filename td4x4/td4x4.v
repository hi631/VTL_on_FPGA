`timescale 1ns / 1ps
module td4x4(
  input wire          clk_50M,
	output wire [2:0]  VGA_R,
	output wire [2:0]  VGA_G,
	output wire [1:0]  VGA_B,
	output             VGA_HS, VGA_VS,
   input              srx,        // RS232C
   output             stx,
	input wire         ps2_data, ps2_clk, // PS2 Keyboard
   output wire [7:0]  LED,
   input  wire [2:0]  BTN,
   // SDRAM
   inout  wire [15:0] SDRAM_DATA, // SDRAM Data bus 16 Bits
   output wire [12:0] SDRAM_ADDR, // SDRAM Address bus 13 Bits
   output wire        SDRAM_DQML, // SDRAM Low-byte Data Mask
   output wire        SDRAM_DQMH, // SDRAM High-byte Data Mask
   output wire        SDRAM_nWE,  // SDRAM Write Enable
   output wire        SDRAM_nCAS, // SDRAM Column Address Strobe
   output wire        SDRAM_nRAS, // SDRAM Row Address Strobe
   output wire        SDRAM_nCS,  // SDRAM Chip Select
   output wire [1:0]  SDRAM_BA,   // SDRAM Bank Address
   output wire        SDRAM_CLK,  // SDRAM Clock
   output wire        SDRAM_CKE  // SDRAM Clock Enable
   );

	wire [7:0] tdled,vgaled;
	assign LED[7:0] = tdled | vgaled;
	// TD4
	wire [7:0]  ioad;	wire [15:0] iowdt; wire [15:0] iordt; wire ior,iow; // td4 I/O
	//reg  [7:0]  ioad;	reg  [15:0] iowdt; reg  [15:0] iordt;reg ior,iow; // For Debug
	td4 td4( .CLOCK(clk50),.RESET(reset), .IN({5'd0,BTN[2:0]}), .OUT(tdled),
				.srx(srx), .stx(stx), .ps2d( ps2_data), .ps2c( ps2_clk),
				.ioad(ioad), .iowdt(iowdt), .iordt(iordt), .ior(ior), .iow(iow));

	vga_disp vga_disp(
	//.clk_50M(clk_50M),
	.reset(reset), .clk150(clk150), .clk50(clk50), .clk25(clk25),
	.VGA_R(VGA_R),	.VGA_G(VGA_G),	.VGA_B(VGA_B),
	.VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
	.ioad(ioad), .iowdt(iowdt), .iordt(), .ior(), .iow(iow),
	.LED(vgaled),	.BTN(BTN),
	//
	.SDRAM_DATA(SDRAM_DATA), // SDRAM Data bus 16 Bits
	.SDRAM_ADDR(SDRAM_ADDR), // SDRAM Address bus 13 Bits
	.SDRAM_DQML(SDRAM_DQML), // SDRAM Low-byte Data Mask
	.SDRAM_DQMH(SDRAM_DQMH), // SDRAM High-byte Data Mask
	.SDRAM_nWE(SDRAM_nWE),   // SDRAM Write Enable
	.SDRAM_nCAS(SDRAM_nCAS), // SDRAM Column Address Strobe
	.SDRAM_nRAS(SDRAM_nRAS), // SDRAM Row Address Strobe
	.SDRAM_nCS(SDRAM_nCS),   // SDRAM Chip Select
	.SDRAM_BA(SDRAM_BA),     // SDRAM Bank Address
	.SDRAM_CLK(SDRAM_CLK),   // SDRAM Clock
	.SDRAM_CKE(SDRAM_CKE)    // SDRAM Clock Enable
	);

  // 'clk150'と'reset'を作成
  (* keep = 1 *)wire clk150, clk50, pll_locked, reset;
  assign reset = ~pll_locked;
  cgen cgen (.areset(BTN[0]), .inclk0(clk_50M), .c0(clk150), .c1(clk50), .locked(pll_locked));
	// 'clk25'を作成
	(* keep = 1 *)reg clk25;
	reg [2:0] clk25c;
	always @(posedge clk150) begin
		if(clk25c==2) begin clk25 <= ~clk25; clk25c <= 0; end
		else          clk25c <= clk25c + 1;
	end

	reg [27:0] div1msc;
	(* syn_Preserv = 1 *)reg       clk1ms;
	always @(posedge clk25) begin // 1sを作成
		if(div1msc==25000000) begin div1msc <= 0; clk1ms <=1; end
		else               begin div1msc <= div1msc + 8'd1; clk1ms <= 0; end
		//
	end

endmodule
