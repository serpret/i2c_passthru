//////////////////////////////////////////////////////////////////////////////
//Copyright 2022 Sergy Pretetsky
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





module i2c_passthru_infilter #(

	//enable 2 flip flop asynchronous signal filtering
	//to avoid metastability.  Add 2 clock cycle delay
	//(recommended if external signals connected
	// directly to this module)
	parameter EN_2FF_SYNC = 0,
	
	//width required for NUM_CLKS_XXX parameters below
	parameter NUM_CLKS_WIDTH =4,
	
	//number of clocks to count of i_sda/i_scl before out_sda/out_scl are output hi/lo
	//(hi and lo have separate counts, so, for example, transition from hi->lo can
	// be very fast, while transition from lo->hi can be slow
	
	// recommend numbers for 100khz i2c:  i_clk / value , clk / value ,   clk / value
	parameter NUM_CLKS_HI2LO_SDA = 6, //  4MHz / 2      16MHz / 5       66MHz / 10
	parameter NUM_CLKS_LO2HI_SDA = 6, //  4MHz / 2      16MHz / 5       66MHz / 10
	parameter NUM_CLKS_HI2LO_SCL = 4, //  4MHz / 1      16MHz / 3       66MHz / 6
	parameter NUM_CLKS_LO2HI_SCL = 8  //  4MHz / 3      16MHz / 7       66MHz / 14
	
	
	// recommend for 400khz i2c:  i_clk / value             ,  clk / value ,   clk / value
	// NUM_CLKS_HI2LO_SDA = 6; //  4MHz / not recommend      16MHz / 2       66MHz / 5
	// NUM_CLKS_LO2HI_SDA = 6; //  4MHz / not recommend      16MHz / 2       66MHz / 5
	// NUM_CLKS_HI2LO_SCL = 4; //  4MHz / not recommend      16MHz / 1       66MHz / 3
	// NUM_CLKS_LO2HI_SCL = 8; //  4MHz / not recommend      16MHz / 3       66MHz / 7
	
	
	
)(
	input i_clk,
	//input i_rstn,
	input i_sda,
	input i_scl,
	
	output o_sda,
	output o_scl

);

	reg [NUM_CLKS_WIDTH-1:0] sda_cnt;
	reg [NUM_CLKS_WIDTH-1:0] scl_cnt;
	
	reg out_sda ;
	reg out_scl ;
	
	//for simulation
	initial begin
		sda_cnt = 0;
		scl_cnt = 0;
		out_sda = 0;
		out_scl = 0;
	end
	
	reg i_scl_2ff;
	reg i_sda_2ff;
	
	reg scl_buf;
	reg sda_buf;
	
	assign o_sda = out_sda;
	assign o_scl = out_scl;
	
	generate
	if( EN_2FF_SYNC) begin

		always @( posedge i_clk) begin
			scl_buf <= i_scl;
			sda_buf <= i_sda;
			
			i_scl_2ff <= scl_buf;
			i_sda_2ff <= sda_buf;
		end
	
	end
	else begin
		always @( *) begin

			i_scl_2ff = i_scl;
			i_sda_2ff = i_sda;
		end
	end
	endgenerate
	
	
	always @(posedge i_clk) begin
		if( out_sda) begin
			if( ~i_sda_2ff ) begin
					sda_cnt   <= (NUM_CLKS_HI2LO_SDA != sda_cnt) ? (sda_cnt + 1'b1) : 0;
					out_sda   <= (NUM_CLKS_HI2LO_SDA != sda_cnt) ?            out_sda : 0;
			end else 
			begin
				sda_cnt <= (0 != sda_cnt) ? (sda_cnt - 1'b1) : sda_cnt;
			end
		end 
		else begin // !out_sda
			if(  i_sda_2ff ) begin
					sda_cnt   <= (NUM_CLKS_LO2HI_SDA != sda_cnt) ? (sda_cnt + 1'b1) : 0;
					out_sda   <= (NUM_CLKS_LO2HI_SDA != sda_cnt) ?            out_sda : 1;
			end else 
			begin
				sda_cnt <= (0 != sda_cnt) ? (sda_cnt - 1'b1) : sda_cnt;
			end
		end
	end
	
	
	always @(posedge i_clk) begin
		if( out_scl) begin
			if( ~i_scl_2ff ) begin
					scl_cnt   <= (NUM_CLKS_HI2LO_SCL != scl_cnt) ? (scl_cnt + 1'b1)   : 0;
					out_scl   <= (NUM_CLKS_HI2LO_SCL != scl_cnt) ?            out_scl : 0;
			end else 
			begin
				scl_cnt <= (0 != scl_cnt) ? (scl_cnt - 1'b1) : scl_cnt;
			end
		end 
		else begin // !out_scl
			if(  i_scl_2ff ) begin
					scl_cnt   <= (NUM_CLKS_LO2HI_SCL != scl_cnt) ? (scl_cnt + 1'b1)   : 0;
					out_scl   <= (NUM_CLKS_LO2HI_SCL != scl_cnt) ?            out_scl : 1;
			end else 
			begin
				scl_cnt <= (0 != scl_cnt) ? (scl_cnt - 1'b1) : scl_cnt;
			end
		end
	end
	

	//reg [7:0] scl_pipe;
	//reg [5:0] sda_pipe;
	//
	//always @(posedge i_clk) begin
	//	scl_pipe <= {scl_pipe[6:0], i_scl};
	//	sda_pipe <= {sda_pipe[4:0], i_sda};
	//end
	//
	//always @(posedge i_clk) begin
	//	if(        4'h0 == scl_pipe[3:0]) out_scl <= 1'b0;
	//	else if ( 8'hFF == scl_pipe[7:0]) out_scl <= 1'b1;
	//end
	//
	//always @(posedge i_clk) begin
	//	if(       6'h00 == sda_pipe[5:0])  out_sda <= 1'b0;
	//	else if ( 6'h3F == sda_pipe[5:0])  out_sda <= 1'b1;
	//end

	




endmodule
