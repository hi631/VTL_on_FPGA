
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

module vga_disp(
	//input wire         clk_50M,
	input              reset, clk150, clk50,clk25,
	output wire [2:0]  VGA_R,
	output wire [2:0]  VGA_G,
	output wire [1:0]  VGA_B,
	output             VGA_HS, VGA_VS,
	// cpu io
	input  wire [7:0]  ioad,
	input  wire [15:0] iowdt,
	output reg  [15:0] iordt,
	input  wire        ior, iow,
	//
   output wire [7:0]  LED,
   input  wire [2:0]  BTN,
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
   output wire        SDRAM_CKE   // SDRAM Clock Enable
   );

	assign LED[7:1] = 7'd0;
	reg ledx;
	assign LED[0] = ledx;
	
	reg [15:0] div1msc;
	(* syn_Preserv = 1 *)reg       clk1ms;
	always @(posedge clk25) begin // 1msを作成
		if(div1msc==25000) begin div1msc <= 0; clk1ms <=1; end
		else               begin div1msc <= div1msc + 8'd1; clk1ms <= 0; end
	end

  vga vga(
	.dotclk(clk25), .VGA_RGB(), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), 
	.VGA_AS(activep), .chhdot(chdot), .chvdot(cvdot), .chvchr(cvchr));
  assign VGA_R = vdat[7:5];
  assign VGA_G = vdat[4:2];
  assign VGA_B = vdat[1:0];
  
  (* keep = 1 *)wire actives, activep,activef,activefs; // ピクセルデータ有効
  (* keep = 1 *)wire [23:0] sdram_addr = s_md ? r_addr : w_addr;
  (* keep = 1 *)wire [15:0] sdram_din = s_din;
  (* keep = 1 *)wire [15:0] sdram_out;
  (* keep = 1 *)wire sdram_we = w_we && ~s_md;
  (* keep = 1 *)wire sdram_oe = r_oe | w_oe;
  (* keep = 1 *)wire [1:0]  sdram_ds = w_ds;

	assign activef  = activefd[1];
	assign actives  = activefd[5];
	assign activefs = activep || actives;
  	reg [5:0] activefd;
	always @(posedge clk25)	begin
		activefd[5:0] <= {activefd[4:0], activep};
	end

	// cpu I/O
	reg [23:0] sd_waddr;
	reg [15:0] sd_wdata;
	reg [10:0] tb_waddr;
	reg [7:0]  tb_wdata;
	reg        sd_wreq=0, tb_dreq=0, tb_wreq=0;
	always @(posedge clk50) begin
		if(iow && ioad[7:4]==4'h01) begin // IOaddr = $10-$1F
			// VRAM/TRAMアクセス
			case(ioad[3:0])
				4'h0: begin tb_wdata[7:0]  <= iowdt[7:0]; sd_wdata <= iowdt; end
				4'h1: begin tb_waddr[10:0] <= iowdt[10:0]; tb_dreq <= 1; end // TM Write
				4'h2: sd_waddr[23:16] <= iowdt[7:0];
				4'h3: begin sd_waddr[15:0] <= iowdt; sd_wreq <= 1; end // SD Write
				4'h4: begin tb_wdata <= iowdt[7:0]; tb_wreq <= 1; end // TextBuf Write
			endcase
		end
		if(w_we)   sd_wreq <= 0; 
		if(tmemwr) begin tb_dreq <= 0; tb_wreq <= 0; end
	end

	reg [3:0]  sqcnt;
	reg [15:0] s_din,sdo; 
	reg [23:0] r_addr,w_addr;
	reg [1:0]  w_ds;
	(* syn_Preserv = 1 *)reg s_md,r_we,w_we,r_oe,w_oe,vsd,hsd,btn1,btn2;
	reg [1:0]  sinit=0,tinit=0;
	reg [15:0] wdat;
	reg [7:0]  wdofs,wdofd=0,btnx;
	reg [8:0]  wdcnt,wlcnt;
	reg [7:0]  vdat,vdatl;
	reg [10:0] tb_xp=0;
	reg [10:0] tb_yp=0;
	wire [10:0] tb_wadp = tb_yp*80+tb_xp;
	
	always @(posedge clk25)	begin
		if(activefs==0) s_md <= 0; else  s_md <= ~s_md;

		if(sinit==2'd2 && BTN[1]==1) begin sinit <= 0; wdofs <= 0; end
		case(sinit)
			2'd0: begin w_addr <= -2; w_we <= 0; wdat <= 0; wdcnt <= 0; wlcnt <= 0; sinit <= 1; end
			2'd1: begin
				// VRAM(SDRAM)初期化
				if(s_md==1) begin
					if(w_addr!=24'h04b000) begin 
						w_addr <= w_addr + 1;
						if(wlcnt<3 || wlcnt>=476) wdat <= {wdcnt[7:0],wdcnt[7:0]}; 
						else
						case(wdcnt)
							9'd0  : wdat <= 16'h0000;
							9'd319: wdat <= 16'h0000;
							default: wdat <= 16'h0000;
						endcase
						wdcnt <= wdcnt + 1;
						if(wdcnt==319) begin wdcnt <= 0; wlcnt <= wlcnt + 1; end
						s_din <= 16'h0101;//wdat;
						w_ds <= 2'b11;
						w_we <= 1;
					end else begin w_we <= 0; sinit <= 2; end
				end
			end
			2'd2: begin
				if(w_we==1) w_we <= 0;
				if(sd_wreq && (s_md==1 || activefs==0)) begin
					w_addr <= {1'b0,sd_waddr[23:1]};
					s_din <= sd_wdata;
					if(sd_waddr[0]) w_ds <= 2'b10; else w_ds <= 2'b01; // 1Byteアクセス
					w_we <= 1;
				end else sinit <= 2;
			end
		endcase 
	end

	always @(posedge clk25)	begin	
		case(tinit)	
			2'd0: begin
				if(tb_dreq) begin
					tramin[7:0] <= tb_wdata; tmemwa[10:0] <= tb_waddr;
					tmemwr <= 1; 
				end else if(tb_wreq==1) begin
					if(tb_wdata>=8'h20) begin
						tramin[7:0] <= tb_wdata; tmemwa[10:0] <= tb_wadp; 
					end	
					tmemwr<= 1;
					if(tb_wdata==8'h08) begin tb_xp <= tb_xp - 1; end
					else if(tb_xp!=79 && tb_wdata!=8'h0a) begin tb_xp <= tb_xp + 1; end
					else begin 
						if(tb_yp!=24)  tb_yp <= tb_yp + 1;
						else begin tb_yp <= 0; cvcscr <= 1; cvcofs <= 1; end
						if(cvcscr==1) begin 
							if(cvcofs!=24) cvcofs <= cvcofs + 1;
							else           cvcofs <= 0;
						end
						tb_xp <= 0;	tinit <= 1;
					end 
				end 
				if(tmemwr) tmemwr <= 0;
			end
			2'd1: begin
				if(tb_xp==80) begin tb_xp <= 0; tmemwr<= 0; tinit <= 0; end
				else begin
					tramin[7:0] <= 0;	tmemwa[10:0] <= tb_wadp;  
					tmemwr<= 1;	tb_xp <= tb_xp + 1;
				end
			end
		endcase 

	end
		
	reg clk25d, clk50d; 

	always @(posedge clk150) clk25d <= clk25;
	reg [15:0] sd_data;
	always @(posedge clk25)	begin           // SD制御
		if(VGA_VS==0) begin r_addr <= -1; r_oe <=1 ; r_we <= 0; end
		if(activef) 
			if(s_md==0) begin r_oe <= 1; end
			else        begin r_oe <= 0; r_addr <= r_addr + 24'd1; end
		else if(actives && s_md==0) r_oe <= 1; 
		else r_oe <= 0; 
	end
	always @(posedge clk25d) begin          // 読出し
		sd_data <= sdram_out;
	end
	always @(posedge clk25) begin           // 表示
		if(actives) begin
			vdatl <= sd_data[15:8]; 
			if(vga_cg==8'h00) begin
				if(s_md==0) begin
					vdat <= sd_data[7:0]; 
				end else begin	
					vdat <= vdatl; vdatl <= 0; end
			end else begin
				vdat <= vga_cg;
			end
		end else begin vdat <= 8'h00; end
	end

	always @(posedge clk50) begin
		if(clk25==0) cgchr <= tramout;
	end
	//wire [7:0]  cgchr = tramout;
	reg  [7:0]  cgchr;
	wire [10:0] cgadr = {cgchr[7:0],cvdot[3:1]};
	wire [7:0] cgdata;
	reg [7:0] vga_cg;
	cg cg(.adr(cgadr), .clk(clk50), .data(cgdata));

	(* keep = 1 *)wire [4:0] cvdot,cvchr;
	(* keep = 1 *)wire [9:0] chdot;
	wire [6:0] chchr = chdot/8;
	always @(posedge clk25) begin 
		if(cgdata[7-chdot[2:0]]==1 && cvdot[4]==0 && cvchr<5'd25) 
			vga_cg <= 8'hff; 
		else begin 
			if(cvdot[4:1]==4'h8 && chchr[6:0]==tb_xp[6:0] && cvstartp==tb_yp) vga_cg <= 8'hff;
			else vga_cg <= 8'h00;
		end
	end

	// TextBufferRAM(80x25)
	reg  [4:0]  cvcofs=0;
	reg         cvcscr=0;
	wire [10:0] cvstarta = cvchr + cvcofs;
	wire [10:0] cvstartp = cvstarta<25 ? cvstarta : cvstarta - 25; 
	wire [10:0] tmemra = cvstartp*80+chdot/8;
	reg  [10:0] tmemwa=0;
	reg         tmemwr;
	reg  [7:0]  tramin;
   reg  [7:0]  tramout;
   wire        tramwe  = clk25 ? 0      : tmemwr;
   wire [10:0] tramadr = clk25 ? tmemra : tmemwa;
   reg  [7:0]  trammem [0:2047]; 
   always @(posedge clk50) begin
      if(tramwe) trammem[tramadr] <= tramin;
      else       tramout <= trammem[tramadr];
   end

	// Display SDRAM
   assign SDRAM_CLK = ~clk150; 
   assign SDRAM_CKE = 1'b1;
   sdram sdram (
     // system interface
     .clk_64( clk150), .clk_8( clk25), .init( reset),
     // cpu/chipset interface
    .addr( sdram_addr), .din( sdram_din), .dout( sdram_out),
	.ds( sdram_ds), .we( sdram_we), .oe( sdram_oe),
    // interface to the MT48LC16M16 chip
     .sd_addr( SDRAM_ADDR), .sd_data( SDRAM_DATA), .sd_dqm( {SDRAM_DQMH, SDRAM_DQML} ),
     .sd_ba( SDRAM_BA), .sd_cs( SDRAM_nCS), .sd_we( SDRAM_nWE),
     .sd_ras( SDRAM_nRAS), .sd_cas( SDRAM_nCAS)
  );

endmodule

module vga(dotclk, VGA_RGB, VGA_HS, VGA_VS, VGA_AS, chhdot, chvdot, chvchr);
	input dotclk;
	output [7:0] VGA_RGB;
	output VGA_HS, VGA_VS, VGA_AS;
	output [9:0] chhdot;
	output [4:0] chvdot,chvchr;

	(* syn_Preserv = 1 *)reg [9:0] chdot;
	(* syn_Preserv = 1 *)reg [4:0] cvdot,cvchr;
	reg [9:0] hcount;
	(* syn_Preserv = 1 *)reg [9:0] vcount,acount;
	assign chhdot = chdot;
	assign chvdot = cvdot;
	assign chvchr = cvchr;
	

	reg [7:0] VGA_RGB_out;
	reg VGA_HS_out;
	reg VGA_VS_out;

	assign VGA_RGB = VGA_RGB_out;
	assign VGA_HS = VGA_HS_out;
	assign VGA_VS = VGA_VS_out;
	assign VGA_AS = actives;

	parameter H_ACTIVE_PIXEL_LIMIT = 640;
	parameter H_FPORCH_PIXEL_LIMIT = 656+8; // 640+16
	parameter H_SYNC_PIXEL_LIMIT   = 752+8; // 640+16+96
	parameter H_BPORCH_PIXEL_LIMIT = 800+4; // 640+16+96+48

	parameter V_ACTIVE_LINE_LIMIT = 480;
	parameter V_FPORCH_LINE_LIMIT = 490; // 480+10
	parameter V_SYNC_LINE_LIMIT   = 492; // 480+10+2
	parameter V_BPORCH_LINE_LIMIT = 521+6; // 480+10+2+29

	reg actives;
	//reg [3:0] activefd;
	// 
always @(posedge dotclk) begin
	if (hcount < H_BPORCH_PIXEL_LIMIT) hcount <= hcount + 1;
	else begin
		hcount <= 0; 
		if (vcount < V_BPORCH_LINE_LIMIT) begin
			vcount <= vcount + 1;
			if(cvdot==5'd18) begin cvdot <= 0; cvchr <= cvchr + 1; end
			else          cvdot <= cvdot + 1;
		end else begin
			vcount <= 0; cvdot <= 15; cvchr <= -1;
		end
	end

	if (hcount < H_FPORCH_PIXEL_LIMIT) chdot <= chdot + 1;
	//activefd <= {activefd[2:0],activef};
	//actives <= activefd[2];              // Dlay 4Dot
	if (hcount < H_ACTIVE_PIXEL_LIMIT && vcount < V_ACTIVE_LINE_LIMIT) begin // active video
		actives <= 1;
	end else begin
		actives <= 0;
		case (hcount)
			H_ACTIVE_PIXEL_LIMIT : ; // front porch
			H_FPORCH_PIXEL_LIMIT : VGA_HS_out <= 1'b0; // sync pulse
			H_SYNC_PIXEL_LIMIT   : begin VGA_HS_out <= 1'b1; chdot <= -5; end // back porch
		endcase
	end
	case (vcount)
		V_ACTIVE_LINE_LIMIT : ; // front porch
		V_FPORCH_LINE_LIMIT : VGA_VS_out <= 1'b0;// sync pulse
		V_SYNC_LINE_LIMIT   : VGA_VS_out <= 1'b1;// back porch
	endcase
end

endmodule
