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



module i2c_passthru_bitrx #(

	//F_REF values should always be at least 2.
	
	//number of periods of i_f_ref required for smbus timing
	//example: for t_r=1us ( rise time) and i_f_ref is 8mhz
	// 8mhz * 1us = 8
	// set to greater than 8
	parameter F_REF_T_LOW     = 38, // t_low clock low period minimum 
	                                //   (also used for
	                                //     t_buf   , t_hd:sta, t_su_sta, 
	                                //     t_su_sto, t_high             )
	
	//WIDTH required to binary count F_REF values above.
	// calculation: CEILING ( LOG2 ( F_REF+1) )

	parameter WIDTH_F_REF_T_LOW    = 6



)(
	input i_clk,  // clock
	input i_rstn, // synchronous active low reset
	
	input i_f_ref            ,

	
	input i_start_rx         ,
	input i_rx_frm_slv       ,
	input i_tx_done          ,

	input i_scl              ,
	input i_sda              ,
	
	output reg o_rx_sda_init_valid,
	output reg o_rx_sda_init      ,
	output reg o_rx_sda_mid_change,
	output reg o_rx_sda_final     ,
	
	
	output reg o_scl         ,
	output reg o_sda         ,
	output reg o_rx_done     ,
	output reg o_violation
);
	reg [3:0] state, nxt_state;
	reg rx_frm_slv, nxt_rx_frm_slv;
	
	
	reg nxt_rx_sda_init  ;   //o_rx_sda_init  
	reg nxt_rx_sda_final ;   //o_rx_sda_final 
	

	reg prev_f_ref;
	wire pulse_ref;
	
	reg [WIDTH_F_REF_T_LOW -1:0]  timer_t_low    , nxt_timer_t_low    ; //timers
	wire timer_t_low_tc ; // terminal count for timers	
	reg  timer_t_low_rst; // resets for timers
	
	reg set_sda_init;
	reg set_sda_final;
	
	assign 	pulse_ref = ~prev_f_ref && i_f_ref;
	assign timer_t_low_tc     = timer_t_low     == 0;
	
	
	always @(*) begin
		if( timer_t_low_rst )                  nxt_timer_t_low = F_REF_T_LOW;
		else if( pulse_ref && ~timer_t_low_tc) nxt_timer_t_low = timer_t_low - 1'b1;
		else                                   nxt_timer_t_low = timer_t_low;
	end
	
	
	always @(*) begin
		if( set_sda_init ) nxt_rx_sda_init = i_sda;
		else               nxt_rx_sda_init = o_rx_sda_init;
	end
	
	always @(*) begin
		if( set_sda_final ) nxt_rx_sda_final = i_sda;
		else                nxt_rx_sda_final = o_rx_sda_final;
	end
	
	
	
	localparam ST_IDLE                 = 0;
	localparam ST_SCL0_A               = 1; //o_scl and i_scl 0
	localparam ST_SCL0_B               = 2; //o_scl is 1, waiting for i_scl to rise
	localparam ST_SCL1_INIT_FRM_SLV    = 3; //mid init part of transaction from slave
	localparam ST_SCL1_INIT            = 4; //mid init part of transaction from master
	localparam ST_SCL1_INIT_DONE       = 5; //transaction done, init only
	localparam ST_SCL1_MID             = 6; //transferring to mid part of transaction (mid sda change, only frm master)
	localparam ST_SCL1_MID_DONE        = 7; //transaction done, init and mid sda change
	localparam ST_SCL1_FIN_DONE             = 8; //transferring to fin part of transaction (mid sda change twice, wait for done)
	localparam ST_VIOLATION            = 9; //violation detected
	
	
	always @(*) begin
		//default else case
		nxt_state = state;
		
		nxt_rx_frm_slv = rx_frm_slv;
		timer_t_low_rst = 0;
		
		set_sda_init   = 0;
		set_sda_final  = 0;
		
		o_scl       = 1   ;
		o_sda       = 1   ;
		
		o_rx_sda_init_valid = 0;
		o_rx_sda_mid_change = 0;
		
		o_rx_done   = 0   ;
		o_violation = 0   ;
		
		case( state) 
			ST_IDLE             : 
			begin
			
				o_scl            = 0   ;
				o_sda            = 1   ;
				o_rx_done        = 1   ;
				timer_t_low_rst  = 1   ;
				nxt_rx_frm_slv   = i_rx_frm_slv;
				
				if( i_start_rx)  nxt_state = ST_SCL0_A;
				
			end
			
			ST_SCL0_A           : 
			begin
				o_scl            = 0   ;
				o_sda            = 1   ;
				set_sda_init     = 1;
				if( timer_t_low_tc) nxt_state = ST_SCL0_B;
			end
			   
			ST_SCL0_B           : 
			begin
				o_scl            = 1 ;
				o_sda            = 1 ;
				set_sda_init     = 1 ;
				timer_t_low_rst  = 1 ;
				if( i_scl) begin
					if( rx_frm_slv) nxt_state = ST_SCL1_INIT_FRM_SLV;
					else            nxt_state = ST_SCL1_INIT;
				end
			end
			   
			ST_SCL1_INIT_FRM_SLV: 
			begin
				o_scl            = 1 ;
				o_sda            = 1 ;
				o_rx_sda_init_valid = 1;
				set_sda_final       = 1;
				
				if( ~i_scl || (i_sda != o_rx_sda_init) ) nxt_state = ST_VIOLATION;
				else if( timer_t_low_tc )                nxt_state = ST_SCL1_INIT_DONE;
			end
			   
			ST_SCL1_INIT        : 
			begin
				o_scl            = 1 ;
				o_sda            = 1 ;
				o_rx_sda_init_valid = 1;
				set_sda_final       = 1;
				
				if( ~i_scl)                      nxt_state = ST_SCL1_INIT_DONE;
				else if( i_sda != o_rx_sda_init) nxt_state = ST_SCL1_MID ;
			end
			   
			ST_SCL1_INIT_DONE   : 
			begin
				o_rx_done        = 1 ;
				o_scl            = 0 ;
				o_sda            = 1 ;
				o_rx_sda_init_valid = 1;
				
				if( i_tx_done) nxt_state = ST_IDLE;
				
			end
			   
			ST_SCL1_MID         : 
			begin
				o_scl            = 1 ;
				o_sda            = 1 ;
				o_rx_sda_init_valid = 1;
				o_rx_sda_mid_change = 1;
				set_sda_final = 1;
				
				if( ~i_scl) begin
					if( i_sda == o_rx_sda_init) nxt_state = ST_SCL1_FIN_DONE;
					else                        nxt_state = ST_SCL1_MID_DONE;
				end
			end
			   
			ST_SCL1_MID_DONE    : 
			begin
				o_rx_done        = 1 ;
				o_scl            = 0 ;
				o_sda            = 1 ;
				o_rx_sda_init_valid = 1;
				o_rx_sda_mid_change = 1;
				
				
				if( i_tx_done) nxt_state = ST_IDLE;
			end
			   
			ST_SCL1_FIN_DONE         : 
			begin
				o_rx_done        = 1 ;
				o_scl            = 0 ;
				o_sda            = 1 ;
				o_rx_sda_init_valid = 1;
				o_rx_sda_mid_change = 1;
				
				if( i_tx_done) nxt_state = ST_IDLE;
				
			end
			   
			ST_VIOLATION        : 
			begin
				o_violation = 1;
			end
			

			default:
			begin
				nxt_state = ST_IDLE;
			end

		endcase
	
	end
	
	
	
	
	
	
	//sequential logic that requires reset
	always @(posedge i_clk) begin
		if( i_rstn) begin
			state          <= nxt_state;
			o_rx_sda_init  <= nxt_rx_sda_init ;

		end
		else begin
			//start state assume bus is idle and main ctrl switches master to this module
			state          <= ST_SCL1_INIT;
			o_rx_sda_init  <= 1'b1 ;

		end
	
	end
	
	
	//sequential logic without reset
	always @(posedge i_clk) begin
		rx_frm_slv        <= nxt_rx_frm_slv  ;
		prev_f_ref        <= i_f_ref         ;
		timer_t_low       <= nxt_timer_t_low ;
		//o_rx_sda_init     <= nxt_rx_sda_init ;
		o_rx_sda_final    <= nxt_rx_sda_final;
		
	end
	
	
	
	
	
	


endmodule
