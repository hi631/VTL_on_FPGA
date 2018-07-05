/*
  Copyright (c) 2015-2016, miya
  All rights reserved.

  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

`timescale 1ns / 1ps

module testbench;
  localparam STEP = 20; // 20 ns: 50MHz
  localparam TICKS = 20000;

  localparam WIDTH_D = 32;
  localparam WIDTH_REG = 16;
  localparam DEPTH_I = 13;
  localparam DEPTH_D = 13;

  wire [WIDTH_REG-1:0] count;
  integer              i;

  initial
    begin
      $display("\n\nsimend\n");
    end

  initial
    begin
      $dumpfile("wave.vcd");
      $dumpvars(5, testbench);
      for (i = 0; i <= 31; i = i + 1)
        begin
          $dumpvars(0, testbench.uut.regx[i]);
        end
      //for (i = 0; i <= 4; i = i + 1)
      //  begin
      //    $dumpvars(0, testbench.uut.varRG[i]);
      //  end
      for (i = 8176; i <= 8191; i = i + 1) // $1FF0 - $1FFF
        begin
          $dumpvars(0, testbench.uut.rwmem[i]);
        end
      //$monitor("count: %d", count);
    end

  // generate clock signal
  initial
    begin
      CLOCK = 1'b1;
      forever
        begin
          #(STEP / 2) CLOCK = ~CLOCK;
        end
    end

  // generate RESET signal
  initial
    begin
      RESET = 1'b1;
      //repeat (1) @(posedge CLOCK) RESET <= 1'b1;
      @(posedge CLOCK) RESET <= 1'b0;
    end

  // stop simulation after TICKS
  initial
    begin
      $display("\n");
      repeat (TICKS) @(posedge CLOCK);
      $display("\n");
      $finish;
    end


	// Inputs
	reg CLOCK;
	reg RESET;
	reg [7:0] IN;
	// Outputs
	wire [7:0] OUT;

	// Instantiate the Unit Under Test (UUT)
	td4 uut(
		.CLOCK(CLOCK), 
		.RESET(RESET), 
		.IN(IN), 
		.OUT(OUT)
	);


endmodule
