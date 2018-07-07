// EP2C5(ID=0x020B100D)
`timescale 1ns / 1ps
module td4(
      input CLOCK,
      input RESET,
		input  srx,
		output stx,
		input  ps2c,ps2d,
		//
		output reg [7:0]  ioad,
		output reg [15:0] iowdt,
		input wire [15:0] iordt,
		output reg        ior,iow,
		//
      input [7:0] IN,      // BTN[2:0]
      output reg [7:0] OUT // LED[7:0]
      );
  reg [15:0] PC,SP,MP,regm,regw; // Program Counter/ Stack Pointer
  reg [15:0] regx[0:31];   // ragA,regB,regC,regD
  //reg [15:0] varRG[0:31]; // regA/B + VTL A - Z + %/&/*/_
  wire [15:0] ALU, memadr, RPC;
  reg [7:0]  dbw_hi, op_hold;
  reg [2:0]  memsel;

  wire [7:0] memout, prgout;
  wire [1:0] opsel;
  wire       regno,mdsel;
  wire [5:0] varno, calno;
  reg [5:0]  varnot;
  reg [3:0]  op_cycl, op_cyclm, op_cyofs, op_holdct; 
  reg        setnop, op_bofs;
  
  reg [31:0] sd_addr;
  reg [15:0] sd_data;
  reg [7:0]  sd_req = 0; 

  wire [11:0] PC8,PCM8;
  assign PC8 = PC[11:0];
  assign PCM8 = memadr[11:0];
  assign RPC = PC + 2;

  assign memadr = (memsel == 0) ? PC : (memsel == 1) ? MP : //
                  (memsel == 2) ? SP : (memsel == 7) ? PC : //
                  0;
  assign memout = (setnop!=0) ? 8'h0F :ramout[7:0]; // JMPの最後にNOP($0F)を挿入
  assign prgout = (op_holdct==0) ? memout : op_hold;
  assign opsel = prgout[7:6];
  assign regno = prgout[5];
  assign mdsel = prgout[5];
  assign varno = prgout[4:0];
  // ALUによる計算
  assign calno = {prgout[5],prgout[3:0]}; // 計算コマンド
  assign ALU =  (calno == 5'd1)  ? regx[0] + regx[1] : // ragA=ragA + regB
				(calno == 5'd2)  ? regx[0] - regx[1] : // ragA=ragA - regB
				(calno == 5'd3)  ? regx[0] & regx[1] : // ragA=ragA & regB
				(calno == 5'd4)  ? regx[0] | regx[1] : // ragA=ragA | regB
				(calno == 5'd5)  ? regx[0] ^ regx[1] : // ragA=ragA ^ regB
				(calno == 5'd6)  ? regx[0] * regx[1] : // ragA=ragA * regB
				(calno == 5'd7)  ? regx[0] >> regx[1]: // ragA=ragA >> regB
				(calno == 5'd8)  ? regx[0] == regx[1]: // ragA=ragA== regB
				(calno == 5'd9)  ? regx[0] >  regx[1]: // ragA=ragA > regB
				(calno == 5'd10) ? regx[0] >= regx[1]: // ragA=ragA >=regB
				(calno == 5'd11) ? regx[0] <  regx[1]: // ragA=ragA < regB
				(calno == 5'd12) ? regx[0] <= regx[1]: // ragA=ragA <=regB
				(calno == 5'd13) ? regx[0] != regx[1]: // ragA=ragA <>regB
				(calno == 5'd14) ? 0 - regx[0]       : // ragA=-ragA
				regx[0];
// Data transfar
always @(posedge CLOCK) begin

  if(RESET==1) 
    begin PC <= 0; op_cycl <= 0; memsel <= 0; mwe <= 0; op_cyclm <= 7; 
    setnop <= 0; op_cyofs <= 0; op_holdct <= 0; op_bofs <= 0; end
  else 
  begin
  if(opsel != 2'b11) PC <= PC + 1;
  case(opsel[1:0])
    2'b00: begin
      if(varno[4]==0) regx[regno] <= ALU; // 計算結果の代入
      else 
        if(varno[3]==0) // LD Rc
          ;
		  else 
            case(varno[2:0])
              3'b000:
                if(mdsel==0) regx[0] <= SP; // ST SP -> regA ($18)
		        else         SP <= regx[0]; // LD SP <- regA ($38)
              3'b001:
                if(mdsel==0) regx[1] <= regx[0]; // B <- A($19)
		        else         regx[0] <= regx[1]; // A <- B($39)
              3'b010:
                if(mdsel==0) 
                  begin regx[1] <= regx[0]; regx[0] <= regx[1]; end // A <-> B($1A)
		        
				  3'b111: 
                if(regno==0) begin             // Ra <- Input 
						ior <= 1;
						case(regx[1][7:0])
							8'd0: begin
								if(rxrdy) begin regx[0] <= {8'd0, rxdata}; srxreq  <= 1; end // シリアル入力
									else   begin regx[0] <= {8'd0, ps2_kb}; ps2_req <= 1; end // PS2入力
							end  
							8'd1: begin regx[0] <= {15'd0, rxrdy | ps2_rdy}; end
							8'd2: begin regx[0] <= {15'd0,txbusy}; end
							8'd3: begin regx[0] <= {8'd0,IN[7:0]}; end
							default: regx[0] <= iordt;
						endcase
					end else begin                       // Output <- Ra
						OUT <= regx[0][7:0]; // Dumy OUT
						iowdt <= regx[0]; ioad <= regx[1][7:0]; iow <= 1; // EX.Output
						case(regx[1][7:0])
							8'd0: begin 
								txdata<= regx[0][7:0]; stxreq <= 1; // シリアル出力
								ioad <= 8'h14;         iow <= 1;    // VDTに表示 
							end
						endcase
					end
            endcase
      end
    2'b01: begin regx[regno] <= regx[varno]; PC <= PC + 1; end // LD Rx,Vx
    2'b10: begin regx[varno] <= regx[regno]; PC <= PC + 1; end // ST Vc,Rx
    2'b11: begin // 3byte/3cycl命令
    
      if(opsel==2'b11 && op_holdct==0) begin op_cyclm <= 3; op_holdct <= 2;op_hold <= memout; end
      if(varno[4]==0) begin // PUSH/POP LDM // 11x0xxxx
        if(mdsel==1) begin // 1110xxxx
          if(varno[3]==0)
                case(op_cycl) // POP
                  0: begin mwe <= 0;  memsel <= 2; SP <= SP + 1; op_cyclm <= 4; op_holdct <= 3; end
                  1: begin SP <= SP + 1; end
                  2: begin regx[{2'b00,varno[2:0]}][15:8] <= memout; end
                  3: begin regx[{2'b00,varno[2:0]}][ 7:0] <= memout; memsel <= 0;  setnop <= 1; end
                  4: PC <= PC + 1;
                endcase
          else
                 case(op_cycl) // PUSH
                  0: begin mwe <= 1; ramin <= regx[{2'b00,varno[2:0]}][ 7:0]; memsel <= 2; op_cyclm <= 2; end
                  1: begin mwe <= 1; ramin <= regx[{2'b00,varno[2:0]}][15:8]; SP <= SP - 1; end
                  2: begin mwe <= 0; SP <= SP - 1; memsel <= 0; setnop <= 1; end
                endcase
          
        end else begin          // 1100xxxx
          if(varno[3]==1) begin // 11001xxx
            if(varno[2]==0)
                   case(op_cycl) // PEEK (SP+n)
                    0: begin mwe <= 0;  memsel <= 1; MP <= SP + {13'd0,varno[1:0],1'b0} + 1; op_cyclm <= 4; op_holdct <= 3; end
                    1: begin MP <= MP + 1; end
                    2: begin regx[0][15:8] <= memout; end
                    3: begin regx[0][ 7:0] <= memout; memsel <= 0;  setnop <= 1; end
                    4: PC <= PC + 1;
                  endcase
            else
                  case(op_cycl) // POKE (SP+n)
                    0: begin mwe <= 1; ramin <= regx[0][ 7:0]; memsel <= 1; op_cyclm <= 2; end
                    1: begin mwe <= 1; ramin <= regx[0][15:8]; MP <= SP + {13'd0,varno[1:0],1'b0} - 1; end
                    2: begin mwe <= 0; MP <= MP - 1; memsel <= 0; setnop <= 1; end
                  endcase
          end else begin        // 11000xxx
            case(varno[3:0])
              //4'b0000:
              //    case(op_cycl) // PEEK (SP)
              //      0: begin mwe <= 0;  memsel <= 1; MP <= SP + 1; op_cyclm <= 4; op_holdct <= 3; end
              //      1: begin MP <= MP + 1; end
              //      2: begin regx[0][15:8] <= memout; end
              //      3: begin regx[0][ 7:0] <= memout; memsel <= 0;  setnop <= 1; end
              //      4: PC <= PC + 1;
              //    endcase
              //4'b0001:
              //    case(op_cycl) // POKE (SP)
              //      0: begin mwe <= 1; ramin <= regx[0][ 7:0]; memsel <= 1; op_cyclm <= 2; end
              //      1: begin mwe <= 1; ramin <= regx[0][15:8]; MP <= SP - 1; end
              //      2: begin mwe <= 0; MP <= MP - 1; memsel <= 0; setnop <= 1; end
              //    endcase
              4'b0010,4'b0011: // RTS 1,(2)
                  case(op_cycl)
                    0: begin mwe <= 0;  memsel <= 2; SP <= SP + 1; op_cyclm <= 4; op_holdct <= 3; end
                    1: begin SP <= SP + 1; end
                    2: begin PC[15:8] <= memout; memsel <= 7; end
                    3: begin PC[ 7:0] <= memout; memsel <= 0; setnop <= 1; end
                    4: PC <= PC + 1;
                  endcase
              4'b0100, 4'b0101: // LDM Ra,(Ra).b,w
                  case(op_cycl)
                    0: begin SP <= SP + 1; mwe <= 0;  memsel <= 2; op_cyclm <= 10; op_holdct <= 9; end
                    1: begin SP <= SP + 1; end
                    2: begin SP <= SP + 1; regw[15:8] <= memout; end // 配列先頭読み出し
                    3: begin SP <= SP + 1; regw[ 7:0] <= memout; end
                    4: begin regm[15:8] <= memout; end               // 配列添え字読み出し
                    5: begin regm[ 7:0] <= memout; end
                    6: begin
                       memsel <= 1;
                       if(varno[0]==1) MP <= regw + {regm[14:0],1'b0};
                       else            MP <= regw + regm;
                       end
                    7: if(varno[0]==1) MP <= MP + 1;
                    8: if(varno[0]==1) regx[0][15:8] <= memout;
                       else            regx[0][15:8] <= 0;
                    9: begin regx[0][ 7:0] <= memout; memsel <= 0; setnop <= 1; end
                    10: ;
                  endcase
              4'b0110, 4'b0111:   // STM (Ra),Rb.b,w
                  case(op_cycl)
                    0: begin SP <= SP + 1; mwe <= 0;  memsel <= 2; op_cyclm <= 9; op_holdct <= 8; end
                    1: begin SP <= SP + 1; end
                    2: begin SP <= SP + 1; regw[15:8] <= memout; end // 配列先頭読み出し
                    3: begin SP <= SP + 1; regw[ 7:0] <= memout; end
                    4: begin regm[15:8] <= memout; end               // 配列添え字読み出し
                    5: begin regm[ 7:0] <= memout; end
                    6: begin
                       mwe <= 1; memsel <= 1;
                       if(varno[0]==1) begin MP <= regw + {regm[14:0],1'b0}; ramin <= regx[0][15:8]; end
                       else            begin MP <= regw + regm; ramin <= regx[0][7:0]; end
                       end
                    7: if(varno[0]==1) begin mwe <= 1;  MP <= MP + 1; ramin <= regx[0][ 7:0]; end
                    8: begin  mwe <= 0; memsel <= 0; setnop <= 1; end
                    9: ;
                  endcase
              endcase
            end
          end

      end else begin // JP  // 11x1xxxx
        if(varno[2:0]==3'b111) // LDI($DF,$FF) Rx,xxxx
          case(op_cycl) 
            0: begin 
              if(varno[3]==1)
                begin MP <= PC + 1; memsel <= 1; op_cyclm <= 2; end
              else
                begin MP <= PC + 1; memsel <= 1; op_holdct <= 1; op_cyclm <= 1; end
              end
            1: begin 
              if(varno[3]==1)
                begin dbw_hi <= memout; MP <= MP + 1; end
              else
                begin regx[regno] <= {8'h00,memout}; memsel <= 0; PC <= PC + 2; end
              end
            2: begin regx[regno] <= {dbw_hi,memout}; memsel <= 0; PC <= PC + 3; end
          endcase
        else
          case({mdsel,varno[2:0]})
            4'b0000,4'b0001: // JZ($D0),JNZ($D1)
              case({op_bofs, op_cycl[1:0]})
                0: if(varno[0]==0)
                     if(regx[0][0]==0) begin op_bofs <= 0; MP <= PC + 1; memsel <= 1; end // JMP
                     else              begin op_bofs <= 1; op_cyclm <= 2; op_holdct <= 1; end
                   else
                     if(regx[0][0]==1) begin op_bofs <= 0; MP <= PC + 1; memsel <= 1; end // JMP
                     else              begin op_bofs <= 1; op_cyclm <= 2; op_holdct <= 1; end
                1: begin dbw_hi <= memout; MP <= MP + 1;   end
                2: begin PC <= {dbw_hi,memout}; memsel <= 0; setnop <= 1; end
                3: begin  end // 1cycl Wait
                //4: ; // op_bofs=1で5に移動
                5: begin PC <= PC + 2; setnop <= 1; op_bofs <= 0; end
                
              endcase
            4'b0110: // JSR($DE) PUSHしてからJMP
              case(op_cycl)
                0: begin mwe <= 1; ramin <= RPC[ 7:0]; memsel <= 2; op_cyclm <= 6; op_holdct <= 5; end
                1: begin mwe <= 1; ramin <= RPC[15:8]; SP <= SP - 1; end
                2: begin mwe <= 0; SP <= SP - 1; memsel <= 0; end
                //
                3: begin MP <= PC + 1; memsel <= 1; end
                4: begin dbw_hi <= memout; MP <= MP + 1;   end
                5: begin PC <= {dbw_hi,memout}; memsel <= 0; setnop <= 1; end
                6: begin  end // 1cycl Wait
              endcase
            4'b1110: // JMP($FE)
              case(op_cycl)
                0: begin MP <= PC + 1; memsel <= 1; end
                1: begin dbw_hi <= memout; MP <= MP + 1;   end
                2: begin PC <= {dbw_hi,memout}; memsel <= 0; setnop <= 1; end
                3: begin  end // 1cycl Wait
              endcase
          endcase
      end
    end
      
  endcase
  if(op_cycl >= op_cyclm) begin op_cycl <= 0; op_cyclm <= 7; end
  else if(opsel[1:0]==2'b11) op_cycl <= op_cycl + 1;
  if(op_holdct) op_holdct <= op_holdct -1 ;
  if(setnop) setnop <= 0; // one shot 
  if(stxreq | srxreq) begin stxreq <= 0; srxreq <= 0; end 
  if(ps2_req) ps2_req <= 0;
  if(ior | iow) begin ior <= 0; iow <= 0; end 
  end
end
	
  // Main RAM(Static R/W)
  reg  [0:0] mwe;
  reg  [7:0] ramin, ramout;
  reg  [7:0] rwmem [0:30719-(2048+2048)]; // メモリ($77ff) - textbf($800) - CG($800) (- Tap($1000))
  //reg  [7:0] rwmem [0:12287]; // 3000 (EP2C5)

  always @(posedge CLOCK) begin
    if(mwe) rwmem[memadr] <= ramin;
    else ramout <= rwmem[memadr];
  end

  initial begin
    $readmemh ( "pram.hex", rwmem);
  end

reg  [7:0] txdata;
wire [7:0] rxdata;
reg        stxreq=0, srxreq=0;
wire       txbusy,rxrdy;
  rs232c rs232c(
	.RESETB(~RESET), .CLK(CLOCK), .TXD(stx), .RXD(srx),
	.TX_DATA(txdata),	.TX_DATA_EN(stxreq),	.TX_BUSY(txbusy),
	.RX_DATA(rxdata),	.RX_DATA_RD(srxreq),	.RX_DATA_RDY(rxrdy));

	wire ps2_rdy;
	reg  ps2_req=0;
	wire [7:0] ps2_kb;
	ps2_rx ps2( .clk(CLOCK), .reseti(RESET), .ps2d( ps2d), .ps2c( ps2c),
			  .rx_en( 1'b1), .acd_out( ps2_kb), .acd_rdy( ps2_rdy), .acd_req(ps2_req));

endmodule
