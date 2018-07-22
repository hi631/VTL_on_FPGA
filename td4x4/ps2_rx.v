/////////////////////////////////////////////////////////////////////////////////

// Module Name:PS2_RX
// Target Devices: EP1C3T144
// Tool versions: Quartus II 11.0
// Description: This module implements a PS2 keyboard receiver. Serial data sent from a PS2 keyboad is converted to 8-bit parallel data.

//////////////////////////////////////////////////////////////////////////////////


module ps2_rx( clk, reseti, ps2d, ps2c, rx_en, acd_out, acd_rdy, acd_req );
				  
input wire clk;
input wire reseti;
input wire ps2d;	// data line (350u)
input wire ps2c;	// clock line(50u/dot)
input wire rx_en;	// enable PS2 receiver
output reg acd_rdy;
output wire [7:0] acd_out;
input  wire acd_req;
				  
localparam [1:0]	idle = 2'b00,
						 dps = 2'b01,
						load = 2'b10;

reg [1:0]  state_reg, state_next;
reg [7:0]  filter_reg;
wire[7:0]  filter_next;
reg [3:0]  n_reg,n_next;
reg [10:0] b_reg,b_next;
reg  f_ps2c_reg;
wire f_ps2c_next;
wire fall_edge;

wire [7:0] scd,scd_out;
reg  [7:0] acd;
(* syn_Preserv = 1 *)reg        scd_done;
reg bkset=0,siftin=0, acd_cf=0;
assign scd = b_reg[8:1];
assign scd_out = scd;
assign acd_out = siftin==0 ? acd :
						//acd==8'h2d ? 8'h3d :
						//acd==8'h2f ? 8'h3f :
						acd<8'h30 ? acd + 8'h10:
						acd<8'h40 ? acd - 8'h10 : 
						acd+8'h20;

	reg [27:0] div1msc=0;
	(* syn_Preserv = 1 *)reg       pwon=0;
	wire   reset;
	assign reset = reseti | ~pwon;
	always @(posedge clk) begin // PowerON時のキーを抑制(2s)
		if(div1msc==28'd100000000) begin pwon <= 1; end
		else                      begin pwon <= 0; div1msc <= div1msc + 8'd1;  end
	end

	always@( posedge clk) begin
	if(reset) acd_rdy <= 0;
	else begin
		if(scd_done) begin
			if(scd==8'hf0) begin
				bkset <= 1;
			end else begin
				if(bkset==0) begin
					if(scd==8'h12 || scd==8'h59) siftin <= 1;
					else begin
						case(scd)
							8'h16: acd <= 8'h31; // 1
							8'h1E: acd <= 8'h32; // 2
							8'h26: acd <= 8'h33; // 3
							8'h25: acd <= 8'h34; // 4
							8'h2E: acd <= 8'h35; // 5
							8'h36: acd <= 8'h36; // 6
							8'h3D: acd <= 8'h37; // 7
							8'h3E: acd <= 8'h38; // 8
							8'h46: acd <= 8'h39; // 9
							8'h45: acd <= 8'h30; // 0
							8'h1C: acd <= 8'h41; // A
							8'h32: acd <= 8'h42; // B
							8'h21: acd <= 8'h43; // C
							8'h23: acd <= 8'h44; // D
							8'h24: acd <= 8'h45; // E
							8'h2B: acd <= 8'h46; // F
							8'h34: acd <= 8'h47; // G
							8'h33: acd <= 8'h48; // H
							8'h43: acd <= 8'h49; // I
							8'h3B: acd <= 8'h4A; // J
							8'h42: acd <= 8'h4B; // K
							8'h4B: acd <= 8'h4C; // L
							8'h3A: acd <= 8'h4D; // M
							8'h31: acd <= 8'h4E; // N
							8'h44: acd <= 8'h4F; // O
							8'h4D: acd <= 8'h50; // P
							8'h15: acd <= 8'h51; // Q
							8'h2D: acd <= 8'h52; // R
							8'h1B: acd <= 8'h53; // S
							8'h2C: acd <= 8'h54; // T
							8'h3C: acd <= 8'h55; // U
							8'h2A: acd <= 8'h56; // V
							8'h1D: acd <= 8'h57; // W
							8'h22: acd <= 8'h58; // X
							8'h35: acd <= 8'h59; // Y
							8'h1A: acd <= 8'h5A; // Z
							8'h4E: acd <= 8'h2D; // -
							8'h55: acd <= 8'h5E; // ^
							8'h6A: acd <= 8'h5C; // \
							8'h54: acd <= 8'h40; // @
							8'h5B: acd <= 8'h5B; // [
							8'h4C: acd <= 8'h3B; // ;
							8'h52: acd <= 8'h3A; // :
							8'h5D: acd <= 8'h5D; // ]
							8'h41: acd <= 8'h2C; // ,
							8'h49: acd <= 8'h2E; // .
							8'h4A: acd <= 8'h2F; // /
							8'h51: acd <= 8'h5C; // \
							8'h29: acd <= 8'h20; // " "
							8'h5A: acd <= 8'h0D; // RET
							8'h66: acd <= 8'h08; // BS
							8'h76: acd <= 8'h1b; // ESC
							default: acd <= 8'h00;
						endcase
						acd_rdy <= 1;
					end
				end else begin
					if(scd==8'h12 || scd==8'h59) siftin <= 0;
					bkset <= 0;
				end
			end
		end
		if(acd_req) acd_rdy <= 0;
	end
end

always@( posedge clk )
if( reset )
	begin
		filter_reg <= 0;
		f_ps2c_reg <= 0;
	end
else
	begin
		filter_reg <= filter_next;
		f_ps2c_reg <= f_ps2c_next;
	end

assign filter_next = { ps2c,filter_reg[7:1] };

assign f_ps2c_next  = ( filter_reg == 8'b1111_1111 ) ? 1'b1 :
							 ( filter_reg == 8'b0000_0000 ) ? 1'b0 :
							   f_ps2c_reg;
								
assign fall_edge = f_ps2c_reg & ~f_ps2c_next;


always@( posedge clk )
	if( reset )
		begin
			state_reg <= idle;
			n_reg <= 0;
			b_reg <= 0;
		end
	else
		begin
			state_reg <= state_next;
			n_reg <= n_next;
			b_reg <= b_next;
		end
		
		
		
always@( * )
begin
	state_next = state_reg;
	scd_done = 1'b0;
	n_next = n_reg;
	b_next = b_reg;
	
	case( state_reg )
		idle:
			if( fall_edge & rx_en )
				begin
					b_next = { ps2d,b_reg[10:1] };
					n_next = 4'b1001;
					state_next = dps;
				end
		dps:
			if( fall_edge )
			begin
				b_next = { ps2d,b_reg[10:1] };
				if( n_reg == 0 )
					state_next = load;
				else
					n_next = n_reg - 1;
			end
		load:
			begin
				state_next = idle;
				scd_done = 1'b1;
			end
		endcase
end

endmodule
