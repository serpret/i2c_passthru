//////////////////////////////////////////////////////////////////////////////
//Copyright 2021 Sergy Pretetsky
//
//Permission is hereby granted, free of charge, to any person obtaining a 
//copy of this software and associated documentation files (the "Software"),
//to deal in the Software without restriction, including without 
//limitation the rights to use, copy, modify, merge, publish, distribute,
//sublicense, and/or sell copies of the Software, and to permit persons to
//whom the Software is furnished to do so, subject to the following 
//conditions:
//
//The above copyright notice and this permission notice shall be included 
//in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
//EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
//MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
//IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
//OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE 
//USE OR OTHER DEALINGS IN THE SOFTWARE.
//////////////////////////////////////////////////////////////////////////////





module i2c_passthru_infilter(
	input i_clk,
	input i_rstn,
	input i_sda,
	input i_scl,
	
	output reg o_sda,
	output reg o_scl

);

	reg [7:0] scl_pipe;
	reg [5:0] sda_pipe;
	
	always @(posedge i_clk) begin
		scl_pipe <= {scl_pipe[6:0], i_scl};
		sda_pipe <= {sda_pipe[4:0], i_sda};
	end
	
	always @(posedge i_clk) begin
		if(        4'h0 == scl_pipe[3:0]) o_scl <= 1'b0;
		else if ( 8'hFF == scl_pipe[7:0]) o_scl <= 1'b1;
	end
	
	always @(posedge i_clk) begin
		if(       6'h00 == sda_pipe[5:0])  o_sda <= 1'b0;
		else if ( 6'h3F == sda_pipe[5:0])  o_sda <= 1'b1;
	end





endmodule
