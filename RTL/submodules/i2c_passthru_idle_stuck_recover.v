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

//module detects if bus connected on lines "i_sda" and "i_scl" is idle or stuck.
//uses stop condition or bus high timeout to detect idle condition.
//if bus is stuck (i_scl or i_sda are low for timeout without changing) then
//connect the "o_sda" and "o_scl" signals in this module to the bus.
//this module will attempt to recover the bus.
module i2c_passthru_idle_stuck_recover #(

	//number of periods of i_f_ref required for smbus timing
	//example: for t_r=1us ( rise time) and i_f_ref is 8mhz
	// 8mhz * 1us = 8
	// set to greater than 8
	parameter F_REF_T_LOW     = 38, // t_low clock low period minimum 
	                                //   (also used for
	                                //     t_buf   , t_hd:sta, t_su_sta, 
	                                //     t_su_sto, t_high             )
									
	parameter F_REF_T_HI     = 400, //t_high clock high period maximum
	
	
	//number of periods of i_f_ref_slow required for smbus timing
	//example: t_stuck_max = 64ms
	// 4khz * 64ms = 256.  255 fits in single 8bit register
	parameter F_REF_SLOW_T_STUCK_MAX=255,    // t_stuck_max. time to detect stuck condition (scl/sda stuck low)
	                                         // t_stuck_max is not found in i2c or smbus spec.
   	                                         // recommend set higher than t_low_sext + t_low_mext.

	

	
	//WIDTH required to binary count F_REF values above.
	// calculation: CEILING ( LOG2 ( F_REF+1) )

	parameter WIDTH_F_REF_T_LOW   = 6,
	parameter WIDTH_F_REF_T_HI    = 9,
	parameter WIDTH_F_REF_SLOW_T_STUCK_MAX    = 8
	//parameter WIDTH_F_REF_SLOW_T_HI_MAX    = 9
	//parameter WIDTH_F_REF_SLOW_T_STUCK_MAX = 5

) (
	input i_clk,
	input i_rstn,
	
	input i_f_ref,
	input i_f_ref_slow,
	
	input i_sda,
	input i_scl,
	
	//output scl and sda, used for when o_stuck is high to help recover bus
	output reg o_sda,
	output reg o_scl,
	
	//o_idle_timeout: single clock pulse to signify the bus became idle because 
	// of timeout as oppose to stop detection.
	output reg o_idle_timeout, 
	output reg o_idle,
	output reg o_stuck
	

);
	reg [WIDTH_F_REF_T_HI      -1:0]       timer_thi   , nxt_timer_thi   ;
	reg [WIDTH_F_REF_T_LOW     -1:0]       timer_tlow  , nxt_timer_tlow  ;
	reg [WIDTH_F_REF_SLOW_T_STUCK_MAX-1:0] timer_stuck, nxt_timer_stuck;
	
	wire timer_thi_rst;
	reg timer_thi_tc;
	reg timer_tlow_rst;
	wire timer_tlow_tc;
	wire timer_stuck_rst;
	wire timer_stuck_tc;


	reg [3:0] recov_bit_cnt , nxt_recov_bit_cnt;
	reg  recov_bit_cnt_rst;
	reg  recov_bit_cnt_inc;
	wire recov_bit_cnt_tc;
	
	reg prev_sda;
	reg prev_scl;
	
	reg [3:0] state, nxt_state;
	
	
	reg prev_f_ref;
	reg prev_f_ref_slow;
	
	wire pulse_f_ref;
	wire pulse_f_ref_slow;
	
	reg nxt_stuck;
	
	wire negedge_sda;
	wire posedge_sda;
	//wire anyedge_sda;
	wire anyedge_scl;
	wire start;
	wire stop;
	
	
	//for simulation
	initial begin
		timer_thi   = -1;
		timer_tlow  = -1;
		timer_stuck = -1;

	end
	
	assign negedge_sda =  prev_sda && ~i_sda;
	assign posedge_sda = ~prev_sda &&  i_sda;
	//assign anyedge_sda =  prev_sda !=  i_sda;
	assign anyedge_scl =  prev_scl !=  i_scl;
	
	assign start = i_scl & negedge_sda;
	assign stop  = i_scl & posedge_sda;
	
	assign timer_stuck_rst = ( posedge_sda || negedge_sda || anyedge_scl || (i_scl && i_sda) );
	assign timer_thi_rst   = (~i_sda || ~i_scl);
	
	
	assign timer_tlow_tc = ( 0 == timer_tlow );
	assign timer_stuck_tc= ( 0 == timer_stuck);
	assign timer_thi_tc  = ( 0 == timer_thi  );
	
	//assign o_stuck = timer_stuck_tc;

	assign pulse_f_ref      = ~prev_f_ref      & i_f_ref     ;
	assign pulse_f_ref_slow = ~prev_f_ref_slow & i_f_ref_slow;
	
	

	//timer_stuck logic
	always @(*) begin
		if(       timer_stuck_rst                   ) nxt_timer_stuck = F_REF_SLOW_T_STUCK_MAX;
		else if( !timer_stuck_tc && pulse_f_ref_slow) nxt_timer_stuck = timer_stuck - 1'b1;
		else                                          nxt_timer_stuck = timer_stuck;
	end
	
	
	//timer_tlow
	always @(*) begin
		if(timer_tlow_rst)     nxt_timer_tlow = F_REF_T_LOW;
		else if (pulse_f_ref ) nxt_timer_tlow = timer_tlow - 1'b1;
		else                   nxt_timer_tlow = timer_tlow;
	end
	
	
	//timer_thi logic
	always @(*) begin
		if(       timer_thi_rst                   ) nxt_timer_thi = F_REF_T_HI;
		else if( !timer_thi_tc && pulse_f_ref     ) nxt_timer_thi = timer_thi - 1'b1;
		else                                        nxt_timer_thi = timer_thi;
	end
	
	//bit count used for recover from stuck condition
	always @(*) begin
		if(      recov_bit_cnt_rst) nxt_recov_bit_cnt = 4'hF;
		else if (recov_bit_cnt_inc) nxt_recov_bit_cnt = recov_bit_cnt - 1'b1;
		else                        nxt_recov_bit_cnt = recov_bit_cnt;
	end
	
	assign recov_bit_cnt_tc = (recov_bit_cnt == 4'h0);

	
	//states where bus behavior is considered normal
	//           you go to sleep and everything is good, everything is fine....
	localparam ST_NORM_IDLE        = 0;
	localparam ST_NORM_ACTIVE      = 1;
	localparam ST_NORM_ACTIVE_STOP = 2;
	localparam ST_NORM_IDLE_TIMEOUT= 3;
	
	//states where bus is considered stuck (try to recover)
	//           you wake up and you're on fire!
	localparam ST_STUCK_INIT0 =4 ;
	localparam ST_STUCK_INIT1 =5 ;
	localparam ST_STUCK_0     =6 ;
	localparam ST_STUCK_1     =7 ;
	localparam ST_STUCK_2     =8 ;
	localparam ST_STUCK_3     =9 ;
	localparam ST_STUCK_4     =10;
	localparam ST_STUCK_5     =11;
	localparam ST_STUCK_WAIT  =12;
	

	always @(*) begin
		//default else case
		nxt_state = state;
		
		timer_tlow_rst    = 0;
		recov_bit_cnt_rst = 0;
		recov_bit_cnt_inc = 0;
		o_idle            = 0;
		o_idle_timeout    = 0;
		o_stuck           = 0;
		
		o_sda = 1;
		o_scl = 1;
		
		case( state) 
		
			ST_NORM_IDLE        :
			begin
				o_idle = 1;
				if(     timer_stuck_tc   )       nxt_state = ST_STUCK_INIT0;
				else if( start           )       nxt_state = ST_NORM_ACTIVE;
			end
			
			ST_NORM_ACTIVE      :
			begin
			 	//timer_tlow_rst = 1;

				if(      timer_stuck_tc  )       nxt_state = ST_STUCK_INIT0;
				else if( timer_thi_tc    )       nxt_state = ST_NORM_IDLE_TIMEOUT;
				else if (stop            )       nxt_state = ST_NORM_IDLE;
				//else if (stop            )       nxt_state = ST_NORM_ACTIVE_STOP;

			end
			
			//ST_NORM_ACTIVE_STOP :
			//begin
			//	if(      timer_stuck_tc  )       nxt_state = ST_STUCK_INIT0;
			//	else if( ~i_sda || ~i_scl)       nxt_state = ST_NORM_ACTIVE;
			//	else if( timer_tlow_tc   )       nxt_state = ST_NORM_IDLE;
			//end
			
			ST_NORM_IDLE_TIMEOUT: 
			begin
				o_idle = 1;
				o_idle_timeout = 1;
				
				if( timer_stuck_tc       )       nxt_state = ST_STUCK_INIT0;
				else                             nxt_state = ST_NORM_IDLE;
			end
			
			
			
			ST_STUCK_INIT0:
			begin
				o_stuck = 1;
				timer_tlow_rst = 1;
				recov_bit_cnt_rst = 1;
				
				o_scl = 1;
				o_sda = 1;
				
				//                            nxt_state = ST_STUCK_INIT1;
				                            nxt_state = ST_STUCK_1;

			end
			
			//ST_STUCK_INIT1:
			//begin
			//	o_stuck = 1;
			//	
			//	o_scl = 1;
			//	o_sda = 0;
			//	
			//	if( timer_tlow_tc)          nxt_state = ST_STUCK_0;
			//	
			//end
			
			ST_STUCK_0    :
			begin
				o_stuck        = 1;
				timer_tlow_rst = 1;
				o_scl = 1;
				o_sda = 0;
				
				                            nxt_state = ST_STUCK_1;
			end
			
			ST_STUCK_1    :
			begin
				
				o_stuck = 1;
				o_scl = 1;
				o_sda = 1;
				if( i_sda && i_scl)         nxt_state = ST_NORM_ACTIVE;
				else if( timer_tlow_tc) begin
					if( recov_bit_cnt_tc)   nxt_state = ST_STUCK_WAIT;
					else                    nxt_state = ST_STUCK_2;
				end
			end
			
			ST_STUCK_2    :
			begin
				o_stuck = 1;
				timer_tlow_rst = 1;
				o_scl = 1;
				o_sda = 1;
				
				                            nxt_state = ST_STUCK_3;
				
				
			end
			
			ST_STUCK_3    :
			begin
				o_stuck = 1;
				o_scl = 0;
				o_sda = 0;
				
				if( timer_tlow_tc)          nxt_state = ST_STUCK_4;
			end
			
			ST_STUCK_4    :
			begin
				o_stuck = 1;
				timer_tlow_rst = 1;
				o_scl = 1;
				o_sda = 0;
				recov_bit_cnt_inc = 1;

				
				                            nxt_state = ST_STUCK_5;

			end
			
			ST_STUCK_5    :
			begin
				o_stuck = 1;
				o_scl = 1;
				o_sda = 0;
				//recov_bit_cnt_inc = 1;
				
				if( timer_tlow_tc)          nxt_state = ST_STUCK_0;

			end
			
			ST_STUCK_WAIT :
			begin
				o_scl = 1;
				o_sda = 1;
				o_stuck = 1;
				
				if( timer_stuck_tc)         nxt_state = ST_STUCK_2;
				else if( i_sda && i_scl)    nxt_state = ST_NORM_ACTIVE;
				
			end
			
			
			
			default:
			begin
				nxt_state = ST_NORM_ACTIVE;
			end
			
		
		endcase
	
	end
	
	

	
	//sequential logic with reset
	always @(posedge i_clk) begin
		if( i_rstn) begin
			state       <= nxt_state;
			timer_stuck <= nxt_timer_stuck;
			
			
		end
		else begin
			state       <= ST_NORM_IDLE;
			timer_stuck <= F_REF_SLOW_T_STUCK_MAX;

		end
	
	end
	
	
	//sequential logic no reset required
	always @(posedge i_clk) begin
		prev_sda      <= i_sda            ;
		prev_scl      <= i_scl            ;
		timer_tlow    <= nxt_timer_tlow   ;
		timer_thi     <= nxt_timer_thi    ;
		recov_bit_cnt <= nxt_recov_bit_cnt;
		

		prev_f_ref      <= i_f_ref        ;
		prev_f_ref_slow <= i_f_ref_slow   ;
		
		
	end
	


endmodule

