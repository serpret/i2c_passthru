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


//detect if signal i_padin_sig and i_padout_sig mismatch 
//(usefull for checking slow changing
//signals like opendrain to see if some other "master" is holding the bus).
//Uses timeout after pad output change to determine if there is mismatch.
//
//Also output output o_t_su_dat_ok if i_padin_sig has not changed
//for t_su timing (see F_REF_T_SU_DAT and i_f_ref)
module i2c_passthru_sda_mismatch #(

	//F_REF values should always be at least 2.
	
	//number of periods of i_f_ref required for smbus timing
	//example: for t_r=1us ( rise time) and i_f_ref is 8mhz
	// 8mhz * 1us = 8
	// set to greater than 8
	parameter F_REF_T_R =15,        // t_r rise time
	parameter F_REF_T_SU_DAT  =  2, // t_su:dat dat setup time minimum

	
	//WIDTH required to binary count largest F_REF value above.
	// calculation: CEILING ( LOG2 ( F_REF+1) )
	parameter WIDTH_F_REF_T_R      = 4,
	parameter WIDTH_F_REF_T_SU_DAT = 2
	
	
) (
	input i_clk,
	input i_rstn,
	input i_f_ref,
	
	input i_padin_sig , //signal coming into FPGA
	input i_padout_sig, //signal leaving FPGA
	
	output     o_t_su_dat_ok,
	output reg o_mismatch,
	output reg o_match

);
	// reg and wire declarations
	reg [1:0] state, nxt_state;
	
	reg  prev_f_ref;
	wire pulse_ref;
	
	reg prev_padout_sig;
	reg prev_padin_sig;
	wire change_padout_sig;
	wire change_padin_sig;
	
	reg [WIDTH_F_REF_T_SU_DAT-1:0]  timer_t_su , nxt_timer_t_su ; //timers
	reg [WIDTH_F_REF_T_R     -1:0]  timer_t_r,   nxt_timer_t_r  ;
		
	wire timer_t_r_tc;       //terminal counts for timers
	wire timer_t_su_tc;      //terminal counts for timers

	//reg  timer_t_su_rst ; // resets for timers

	// assignments
	
	assign pulse_ref         = (~prev_f_ref      &  i_f_ref     );
	assign change_padout_sig = ( prev_padout_sig != i_padout_sig);
	assign change_padin_sig  = ( prev_padin_sig  != i_padin_sig );
	assign timer_t_r_tc      = ( timer_t_r       == 0           );     
	assign timer_t_su_tc     = ( timer_t_su      == 0           );     
	assign o_t_su_dat_ok       =  timer_t_su_tc;
	
	
	localparam ST_MATCH           = 0;
	localparam ST_WAIT            = 1;
	localparam ST_MISMATCH        = 2;
	//localparam ST_MATCH_WAIT_T_SU = 3;
	
	//FSM next state and output logic
	always @(*) begin
		//default else case
		nxt_state = state;
		o_mismatch= 1'b0;
		//timer_t_su_rst = 1'b0; 
		o_match = 1'b0;
		
		case( state) 
			ST_MATCH    :
			begin
				o_match     = 1'b1;
				//timer_t_su_rst = 1'b1;
				
				if(                 change_padout_sig )   nxt_state = ST_WAIT;
				else if ( i_padin_sig != i_padout_sig )   nxt_state = ST_MISMATCH;
			end
			
			ST_WAIT     :
			begin
				//timer_t_su_rst = 1'b1;
				if(       timer_t_r_tc               ) begin
					if ( i_padin_sig == i_padout_sig) nxt_state = ST_MATCH;
					else                              nxt_state = ST_MISMATCH;
				end
				//else if ( i_padin_sig == i_padout_sig) nxt_state = ST_MATCH_WAIT_T_SU;
				//else if ( i_padin_sig == i_padout_sig) nxt_state = ST_MATCH;

			end
			
			ST_MISMATCH :
			begin
				o_mismatch     = 1'b1;
				//timer_t_su_rst = 1'b1;
				
				if(                 change_padout_sig)   nxt_state = ST_WAIT;
				else if ( i_padin_sig == i_padout_sig)   nxt_state = ST_MATCH;

			end
			
			//ST_MATCH_WAIT_T_SU:
			//begin
			//	timer_t_su_rst = 1'b0;
			//	
			//	if(       timer_t_su_tc    )           nxt_state = ST_MATCH;
			//	else if ( change_padout_sig)           nxt_state = ST_WAIT;
			//	else if ( change_padin_sig )           nxt_state = ST_MISMATCH;
			//
			//end
			
			default: 
			begin

				nxt_state = ST_MATCH;
			end

		endcase
	end
	
	//timer logic
	always @(*) begin
		if(  change_padout_sig)     nxt_timer_t_r = F_REF_T_R;
		else if( pulse_ref && ~timer_t_r_tc) nxt_timer_t_r = timer_t_r - 1'b1;
		else                                 nxt_timer_t_r = timer_t_r;
	end
	
	always @(*) begin
		if( change_padin_sig )                nxt_timer_t_su = F_REF_T_SU_DAT;
		else if( pulse_ref && ~timer_t_su_tc) nxt_timer_t_su = timer_t_su - 1'b1;
		else                                  nxt_timer_t_su = timer_t_su;
	end
	
	
	always @(posedge i_clk) begin
		if(i_rstn) begin
			state <= nxt_state;
		end
		else begin
			//state <= ST_MATCH;
			state <= ST_WAIT;
		end
	end
	
	
	always @(posedge i_clk) begin
		prev_f_ref      <= i_f_ref         ;
		prev_padout_sig <= i_padout_sig    ;
		prev_padin_sig  <= i_padin_sig     ;
		timer_t_r       <= nxt_timer_t_r   ;
		timer_t_su      <= nxt_timer_t_su  ;
	end
	
	



endmodule