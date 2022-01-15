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


//detect if signal input and output mismatch (usefull for checking slow changing
//signals like opendrain to see if some other "master" is holding the bus).
//Uses timeout after pad output change to determine if there is mismatch
module i2c_passthru_sda_mismatch #(

	//F_REF values should always be at least 2.
	
	//number of periods of i_f_ref required for smbus t_r timing
	//example: for t_r=1us and i_f_ref is 8mhz
	// 8mhz * 1us = 8
	// set to greater than 8 (recommend double just in case)
	parameter F_REF_T_R =15,
	
	//WIDTH required to binary count largest F_REF value above.
	// calculation: CEILING ( LOG2 ( F_REF+1) )
	parameter WIDTH_F_REF = 4
	
	
) (
	input i_clk,
	input i_rstn,
	input i_f_ref,
	
	input i_padin_sig, //signal coming into FPGA
	input i_padout_sig, //signal leaving FPGA
	
	output o_mismatch

);
	reg [WIDTH_F_REF-1:0] timer, nxt_timer;
	reg [1:0] state, nxt_state;
	wire timer_tc;
	
	reg prev_f_ref_t_r;
	wire pulse_ref_t_r;
	
	reg prev_padout_sig;
	reg prev_padin_sig;
	wire change_padout_sig;
	wire change_padin_sig;

	
	assign pulse_ref_t_r     = (~prev_f_ref_t_r   & i_f_ref);
	assign change_padout_sig = ( prev_padout_sig != i_padout_sig);
	assign change_padin_sig  = ( prev_padin_sig  != i_padin_sig );
	
	localparam ST_MATCH    = 0;
	localparam ST_WAIT     = 1;
	localparam ST_MISMATCH = 2;
	
	//FSM next state and output logic
	always @(*) begin
		//default else case
		nxt_state = state;
		o_mismatch= 0;
		
		case( state) 
			ST_MATCH    :
			begin
				if(       change_padout_sig)           nxt_state = ST_WAIT;
				else if ( change_padin_sig )           nxt_state = ST_MISMATCH;
			end
			
			ST_WAIT     :
			begin
				if(       timer_tc                   ) nxt_state = ST_MISMATCH;
				else if ( i_padin_sig == i_padout_sig) nxt_state = ST_MATCH;
			end
			
			ST_MISMATCH :
			begin
				o_mismatch = 1;
				
				if ( i_padin_sig == i_padout_sig)      nxt_state = ST_MATCH;

			end
			
			default: 
			begin
				nxt_state = ST_MATCH;
			end
			
	
		
		endcase
	
	end
	
	//timer logic
	always @(*) begin
		if( i_padin_sig == i_padout_sig) nxt_timer = F_REF_T_R
		else if( pulse_ref_t_r )         nxt_timer = timer - 1'b1;
	end
	
	
	
	
	always @(posedge i_clk) begin
		if(rstn) begin
			state <= nxt_state;
		end
		else begin
			state <= ST_MATCH;
		end
	end
	
	
	
	always @(posedge i_clk) begin
		prev_f_ref_t_r  <= i_f_ref     ;
		prev_padout_sig <= i_padout_sig;
		prev_padin_sig  <= i_padin_sig ;
		timer           <= nxt_timer   ;
	end
	
	



endmodule