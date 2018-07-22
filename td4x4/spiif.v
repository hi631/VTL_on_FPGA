module epcsrw(	
	// cpu io
	input              clk50,reset,
	input  wire [7:0]  ioad,
	input  wire [15:0] iowdt,
	output wire [15:0] iordt,
	input  wire        ior, iow,
	output wire        DCLK, NCS0, ASDO,
	input              DATA0,
	output reg  [7:0]  led	
);

	spi spi( 
  .clk(clk50), .rstb(~reset),
  .sclk(DCLK), .Nss0(NCS0), .mosi(ASDO), .miso(DATA0),     
  .start(spi_req), .busy(spi_busy), .clk_end(spi_sdl),
  .wr_data(spi_sdt), .rd_data(), .rd_data_en(), .rd_1byte(rd_1byte)      
);

	reg rdreq, wereq, wrreq, sereq,irreq,spreq;
	reg ssreq, ssreqx;  
	wire [7:0] sdata;
	wire       sreq,epcs_status;
	wire [7:0] rddata;
	wire       ebusy,eillegal;
	reg [7:0] div10c,div1c,divtxr,wrdata;
	reg [15:0] resseq;
	(* noprune *)reg          clk10M,clk1M;
	reg [23:0] eadr;
	assign iordt = ioad[2:0]==2 ? {15'h00,spi_req|spi_busy} :
						ioad[2:0]==3 ? {8'h00,rd_1byte} :
						               {16'h0000};

always @(posedge clk50) begin // 10MHzを作成
		div10c <= div10c + 1; clk10M <= div10c[1]; 
		//if(div10c==3) begin div10c <= 0; clk10M <=1; end
		//else                begin div10c <= div10c + 1; clk10M <= 0; end
		if(div1c==50) begin div1c <= 0; clk1M <=1; end
		else                begin div1c <= div1c + 1; clk1M <= 0; end
	end

	reg [23:0] epcs_addr;
	reg [7:0]  epcs_data;
	reg        epcs_wreq=0, epcs_rreq=0, epcs_ereq=0,epcs_ireq=0,epcs_preq=0,epcs_sreq=0;       

	always @(posedge clk50) begin
		if(ioad[7:3]==5'b00001) begin // epcs $08 - $0F
			if(iow)
				case(ioad[2:0])
					3'h0: eadr[23:16] <= iowdt[7:0];
					3'h1: eadr[15:0]  <= iowdt[15:0];
					3'h2: begin                  // Write EN($0A)
						spi_wmd <= 1;
						spi_sdl <= 8;
						spi_sdt <= {8'h06,56'd0};
						spi_req <= 1;
					end
					3'h3: begin                  // Write Data($0B)
						spi_sdl <= 40;
						spi_sdt <= {8'h02,eadr[23:0],iowdt[7:0],24'h000000};
						spi_req <= 1;
					end
					3'h4: begin                  // Erase($0C)
						spi_sdl <= 32;
						spi_sdt <= {8'hd8,eadr[23:0],32'd0};
						spi_req <= 1;						
					end
				endcase
			else if(ior) 
				case(ioad[2:0])
					3'h0: begin                   // Read Data
						//epcs_rreq <= 1;
						spi_sdl <= 40;
						spi_sdt <= {8'h03,eadr[23:0],32'h00000000};
						spi_req <= 1;
					end
					3'h1: begin                   // Read Status
						spi_sdl <= 16;
						spi_sdt <= 64'h0500000000000000;
						spi_req <= 1;
					end
				endcase
		end 
		if(epcs_wreq && wrreq) epcs_wreq <= 0;
		if(epcs_rreq && rdreq) epcs_rreq <= 0;
		if(epcs_ereq && sereq) epcs_ereq <= 0;
		if(epcs_ireq && irreq) epcs_ireq <= 0;
		if(epcs_preq && spreq) epcs_preq <= 0;
		if(epcs_sreq && ssreq) epcs_sreq <= 0;
		//
		if(spi_req) spi_req <= 0;
	end


	(* keep = 1 *)wire srx_en, spi_busy;
	(* keep = 1 *)wire [7:0] srx_dt;
	reg stx_req=0, stx_buf=0,stx_hex=0,epcs_sts=0;
	reg [7:0] stx_dt;
	//
	reg spi_req, spi_wmd=0;
	reg [5:0] spi_sdl;
	reg [63:0] spi_sdt;
	(* keep = 1 *)wire [7:0]  rd_1byte;
	
endmodule

//*****************************************************************************
// File Name            : spi_m_if.v
//-----------------------------------------------------------------------------
// Function             : spi master if
//                        
//-----------------------------------------------------------------------------
// Designer             : yokomizo 
//-----------------------------------------------------------------------------
// History
// -.-- 2010/10/27
//******************************************************************************
module spi( 
  clk, rstb,
  sclk,Nss0,mosi,miso,     
  start,busy,
  clk_end,
  wr_data,
  rd_data,rd_data_en,rd_1byte      
);
  input clk;
  input rstb;
  //SPI
  output sclk;
  output Nss0;
  output mosi;
  input miso;
  //interface
  input start;        //通信開始
  output busy;        //通信中
  input [5:0]clk_end; //通信クロック数
  input [63:0] wr_data; //書き込みデータ
  output [63:0] rd_data;//読み出しデータ
  output        rd_data_en; //読み出しデータイネーブル
  output reg [7:0] rd_1byte;
 
  reg   sclk;
  reg   mosi;
  reg   start_d1;
  wire  start_sig;
  reg [5:0]  clk_end_cnt;
  reg        busy;
  reg [63:0] mosi_data;
  reg [63:0] miso_data;
  reg [63:0] rd_data;
  reg [11:0] cnt_1clk;
  reg [5:0]  clk_cnt;
  reg [15:0] state_cnt;
  reg        rd_data_en;
 
  parameter p_1bit_cnt = 12'd10;
  parameter p_mosi_chg = 12'd1;
  parameter p_miso_trg = p_1bit_cnt - 12'd1;
   
// wr,rd 1clk delay   
always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) begin start_d1 <= 1'b0; end
  else            begin start_d1 <= start; end

// strat signal
assign start_sig= ((start==1'b1)&&(start_d1==1'b0))? 1'b1:1'b0;

//end_cnt hold
always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) clk_end_cnt <= 6'd0;
  else
    if (start_sig==1'b1) clk_end_cnt <= clk_end - 6'd1;
    else                     clk_end_cnt <= clk_end_cnt ;

//busy signel
always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) busy <= 1'b0;
  else
    if (start_sig==1'b1)                                       busy <= 1'b1;
    else if ((cnt_1clk == p_1bit_cnt)&&(clk_cnt==clk_end_cnt)) busy <= 1'b0;
    else                                                       busy <= busy;

//SCLK generator
   
always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) begin cnt_1clk <= 12'd0; clk_cnt <= 5'd0; end
  else 
    if (busy==1'b0) 
       begin cnt_1clk <= 12'd0; clk_cnt <= 5'd0; end
    else if (cnt_1clk == p_1bit_cnt) begin 
       cnt_1clk <= 12'd0;
       if (clk_cnt==clk_end_cnt) clk_cnt <= 6'd0;
       else                      clk_cnt <= clk_cnt + 6'd1;
       end
    else begin cnt_1clk <= cnt_1clk + 12'd1; clk_cnt <= clk_cnt; end


always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) sclk <= 1'b0;
  else 
    if (busy==1'b0) sclk <= 1'b0;
    else if (cnt_1clk == p_1bit_cnt)              sclk <= 1'b0;
    else if (cnt_1clk == {1'b0,p_1bit_cnt[11:1]}) sclk <= 1'b1;
    else                                          sclk <= sclk;

//ss
assign Nss0 = ~busy;

always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) mosi_data <= 64'b0;
  else
    if(start_sig==1'b1)            mosi_data <=wr_data;
    else if (cnt_1clk==p_mosi_chg) mosi_data <= {mosi_data[62:0],1'b0};        
    else                           mosi_data <= mosi_data;


always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) mosi <= 1'b0;
  else
    if (busy==1'b1)
      if (cnt_1clk==p_mosi_chg) mosi <= mosi_data[63];
      else                      mosi <= mosi;
    else                        mosi <= 1'b0;

always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) miso_data <= 64'd0;
  else
    if (cnt_1clk==p_miso_trg) miso_data <= {miso_data[62:0],miso};
    else                      miso_data <= miso_data;
                         
always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) rd_data <= 64'd0;
  else
    if ((cnt_1clk == p_1bit_cnt)&&(clk_cnt==clk_end_cnt)) rd_data <= miso_data;
    else                                                  rd_data <= rd_data;
                            
always @ (posedge clk or negedge rstb )
  if (rstb==1'b0) rd_data_en <= 1'b0;
  else
    if ((cnt_1clk == p_1bit_cnt)&&(clk_cnt==clk_end_cnt)) begin rd_1byte <= miso_data[7:0]; rd_data_en <= 1'b1; end
    else                                                  rd_data_en <= 1'b0;
   
endmodule
