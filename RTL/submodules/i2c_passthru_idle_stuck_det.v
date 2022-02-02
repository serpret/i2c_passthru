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

module i2c_passthru_idle_stuck_det #(

	//number of periods of i_f_ref required for smbus timing
	//example: for t_r=1us ( rise time) and i_f_ref is 8mhz
	// 8mhz * 1us = 8
	// set to greater than 8
	parameter F_REF_T_LOW     = 38, // t_low clock low period minimum 
	                                //   (also used for
	                                //     t_buf   , t_hd:sta, t_su_sta, 
	                                //     t_su_sto, t_high             )
	
	
	//number of periods of i_f_ref_slow required for smbus timing
	//example: t_stuck_max = 45ms
	// 4khz * 512us = 2
	parameter F_REF_SLOW_T_HI_MAX   = 2, // t_high  clock high period max. 
	                                     // must be less than F_REF_SLOW_T_STUCK_MAX
	

	// 4khz * 64ms = 256.  255 fits in single 8bit register
	parameter F_REF_SLOW_T_STUCK_MAX=255,    // t_stuck_max. time to detect stuck condition (scl/sda stuck low)
	                                         // t_stuck_max is not found in i2c or smbus spec.
   	                                         // recommend set higher than t_low_sext + t_low_mext.

	

	
	//WIDTH required to binary count F_REF values above.
	// calculation: CEILING ( LOG2 ( F_REF+1) )

	parameter WIDTH_F_REF_T_LOW   = 6,
	parameter WIDTH_F_REF_SLOW    = 8
	//parameter WIDTH_F_REF_SLOW_T_HI_MAX    = 9
	//parameter WIDTH_F_REF_SLOW_T_STUCK_MAX = 5

) (
	input i_clk,
	input i_rstn,
	
	input i_f_ref,
	input i_f_ref_slow,
	
	input i_sda,
	input i_scl,
	
	output reg o_idle,
	output reg o_stuck
	

);
	reg [F_REF_T_LOW     -1:0] timer_tlow  , nxt_timer_tlow  ;
	reg [WIDTH_F_REF_SLOW-1:0] timer_change, nxt_timer_change;
	
	reg timer_tlow_rst;
	wire timer_tlow_tc;
	
	reg prev_sda;
	reg prev_scl;
	
	reg [1:0] state, nxt_state;
	
	
	reg prev_f_ref;
	reg prev_f_ref_slow;
	
	wire pulse_f_ref;
	wire pulse_f_ref_slow;
	
	reg nxt_stuck;
	
	wire posedge_sda;
	wire anyedge_sda;
	wire anyedge_scl;
	
	assign posedge_sda = ~prev_sda && i_sda;
	assign anyedge_sda =  prev_sda != i_sda;
	assign anyedge_scl =  prev_scl != i_scl;
	
	assign timer_tlow_tc = ( 0 == timer_tlow );


	assign pulse_f_ref      = ~prev_f_ref      & i_f_ref     ;
	assign pulse_f_ref_slow = ~prev_f_ref_slow & i_f_ref_slow;
	

	//timer_change logic
	always @(*) begin
		if( anyedge_sda || anyedge_scl)
		begin
			nxt_timer_change = 0;
		end
		else begin
			if( F_REF_SLOW_T_STUCK_MAX != timer_change) begin
				if(pulse_f_ref_slow) nxt_timer_change = timer_change + 1'b1;
				else                 nxt_timer_change = timer_change;
			end
		end
	end
	
	//o_stuck logic
	always @(*) begin
		if( anyedge_sda || anyedge_scl) begin
			nxt_stuck = 1'b0;
		end
		else if( F_REF_SLOW_T_STUCK_MAX == timer_change && (~prev_scl || ~prev_sda)) begin
			nxt_stuck = 1'b1;
		end
		else begin
			nxt_stuck = o_stuck;
		end
	end
	
	//o_idle logic
	localparam ST_IDLE        = 0;
	localparam ST_ACTIVE      = 1;
	localparam ST_ACTIVE_STOP = 2;

	always @(*) begin
		//default else case
		nxt_state = state;
		
		timer_tlow_rst = 0;
		o_idle         = 0;
		
		case( state) 
		
			ST_IDLE        :
			begin
				o_idle = 1;
				if( ~i_sda || ~i_scl) nxt_state = ST_ACTIVE;
			end
			
			ST_ACTIVE      :
			begin
			 	timer_tlow_rst = 1;

				if( F_REF_SLOW_T_HI_MAX == timer_change && (prev_scl && prev_sda)) 
					nxt_state = ST_IDLE;
				else if (posedge_sda )
				//else if (posedge_sda && i_scl)
					nxt_state = ST_ACTIVE_STOP;
			end
			
			ST_ACTIVE_STOP :
			begin
				if( ~prev_sda || ~prev_scl)  nxt_state = ST_ACTIVE;
				else if( timer_tlow_tc)      nxt_state = ST_IDLE;
			end
			
			default:
			begin
				nxt_state = ST_ACTIVE;
			end
			
		
		endcase
	
	end
	
	
	//timer_tlow
	always @(*) begin
		if(timer_tlow_rst)     nxt_timer_tlow = F_REF_T_LOW;
		else if (pulse_f_ref ) nxt_timer_tlow = timer_tlow - 1'b1;
		else                   nxt_timer_tlow = timer_tlow;
	end
	

	
	//sequential logic with reset
	always @(posedge i_clk) begin
		if( i_rstn) begin
			timer_change <= nxt_timer_change;
			o_stuck      <= nxt_stuck;
			
		end
		else begin
			timer_change <= 0;
			o_stuck      <= 0;

		end
	
	end
	
	
	//sequential logic no reset required
	always @(posedge i_clk) begin
		prev_sda   <= i_sda;
		prev_scl   <= i_scl;
		timer_tlow <= nxt_timer_tlow;
		state      <= nxt_state;

		
		
		prev_f_ref      <= i_f_ref     ;
		prev_f_ref_slow <= i_f_ref_slow;
		
		
	end
	


	

endmodule

