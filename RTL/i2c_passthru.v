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


module i2c_passthru #(


	//enable 2 flip flop asynchronous signal filtering
	//to avoid metastability.  Add 2 clock cycle delay
	//(recommended if external signals connected
	// directly to this module)
	parameter INFILTER_EN_2FF_SYNC = 0,
	
	//width required for INFILTER_NUM_CLKS_XXX parameters below
	parameter INFILTER_NUM_CLKS_WIDTH =4,
	
	//number of clocks to count of i_sda/i_scl before they are registered as hi/lo
	//(hi and lo have separate counts, so, for example, transition from hi->lo can
	// be very fast, while transition from lo->hi can be slow
	
	// recommend numbers for 100khz i2c:  i_clk / value , clk / value ,   clk / value
	parameter INFILTER_NUM_CLKS_HI2LO_SDA = 6, //  4MHz / 2      16MHz / 5       66MHz / 10
	parameter INFILTER_NUM_CLKS_LO2HI_SDA = 6, //  4MHz / 2      16MHz / 5       66MHz / 10
	parameter INFILTER_NUM_CLKS_HI2LO_SCL = 4, //  4MHz / 1      16MHz / 3       66MHz / 6
	parameter INFILTER_NUM_CLKS_LO2HI_SCL = 8, //  4MHz / 3      16MHz / 7       66MHz / 14


	//register the channel a and b scl and sda outputs 
	//through a single flip flop. recommended for output
	//onto chip external pads to avoid all glitches.
	//(0=off, 1=on)
	parameter REG_OUTPUTS = 1,

		
	//F_REF values should always be at least 2.
	//There are two F_REF paramters: F_REF and F_REF_SLOW.
	//They use i_f_ref and i_f_ref_slow as reference.
	
	//number of periods of i_f_ref required for smbus timing
	//example: for t_r=1us ( rise time) and i_f_ref is 8mhz
	// 8mhz * 1us = 8
	// set to greater than 8
	parameter F_REF_T_R       = 15, // t_r rise time max (recommend double)
	                                // note: there is an extra 8 clock cycle delay
	                                // before this module registers sda/scl inputs.
	                                // please add this delay into f_ref_t_r as well.
	parameter F_REF_T_SU_DAT  =  2, // t_su:dat dat setup time minimum
	parameter F_REF_T_HI      =511,//t_high clock high period maximum
	parameter F_REF_T_LOW     = 38, // t_low clock low period minimum 
	                                //   (also used for
	                                //     t_buf   , t_hd:sta, t_su_sta, 
	                                //     t_su_sto, t_high             )
									
	
									
									
	//number of periods of i_f_ref_slow required for smbus timing
	//example: t_stuck_max = 45ms
	// 4khz * 512us = 2
	
	
	
	// t_stuck_max. time to detect stuck condition (scl/sda stuck low)
	// t_stuck_max is not found in i2c or smbus spec.
	// recommend set higher than t_low_sext + t_low_mext.
	parameter F_REF_SLOW_T_STUCK_MAX=255,    

	
	//WIDTH required to binary count F_REF values above.
	// calculation: CEILING ( LOG2 ( F_REF+1) )
	parameter WIDTH_F_REF_T_R      = 4,
	parameter WIDTH_F_REF_T_SU_DAT = 2,
	parameter WIDTH_F_REF_T_HI     = 9,
	parameter WIDTH_F_REF_T_LOW    = 6,
	
	parameter WIDTH_F_REF_SLOW_T_STUCK_MAX = 8
	

)
(

	//----  required signals ----
	input i_clk,    //system clock.  
	input i_rstn,   //synchrous reset active low
	input i_f_ref,       //see F_REF_     parameters above
	input i_f_ref_slow,  //see F_REF_SLOW parameters above
	
	//opendrain i2c busses channel a and channel b. 
	input i_cha_scl,
	input i_cha_sda,
	input i_chb_scl,
	input i_chb_sda,
	
	output reg o_cha_scl,
	output reg o_cha_sda,
	output reg o_chb_scl,
	output reg o_chb_sda,
	
	//---- optional outputs (useful to get information about bus status) ----
	
	//which channel is currently master.  If both low it means the bus is 
	//either idle or disconnected due to some violation
	output o_cha_ismst, //active high channel a is currently master
	output o_chb_ismst, //active high channel b is currently master 
	
	//single clock pulses.  can be used to count violating conditions
	output o_idle_timeout , // bus became idle by timeout instead of stop
	output o_bit_violation, // bit violation during transfer of sda bit 
	output o_cha_stuck    , // channel a got a stuck condition
	output o_chb_stuck      // channel b got a stuck condition
	

);

	// ********* SIGNAL DECLARATIONS ****************************************
	reg o_cha_scl_prereg;
	reg o_cha_sda_prereg;
	reg o_chb_scl_prereg;
	reg o_chb_sda_prereg;



	
	//rxtx ctrl signals
	wire rxtx_start     ;
	wire rxtx_tx_to_mst ;
	
	//bitrx in and output signals 
	wire bitrx_sda_init_valid   ;
	wire bitrx_sda_init         ;
	wire bitrx_sda_mid_change   ;
	wire bitrx_sda_final        ;
	wire bitrx_scl              ;
	wire bitrx_sda              ;
	reg bitrx_scl_in           ;
	reg bitrx_sda_in           ;
	
	
	wire bitrx_rx_done          ;
	wire bitrx_violation        ;
	
	//bittx in and output signals

	wire bittx_scl         ;
	wire bittx_sda         ;
	reg bittx_scl_in      ;
	reg bittx_sda_in      ;
	
	wire bittx_slv_on_mst_ch;
	wire bittx_tx_done      ;
	wire bittx_violation    ;
	

	
	//filtered inputs
	wire cha_sda_fltrd;
	wire cha_scl_fltrd;
	wire chb_sda_fltrd;
	wire chb_scl_fltrd;
	
	//idle timeout single pulses used for optional output
	wire cha_idle_timeout;
	wire chb_idle_timeout;
	
	
	//master detection signals
	wire disconnect       ;
	wire cha_ismst        ;
	wire chb_ismst        ;

	
	
	
	//recovery outputs and idle and stuck conditions
	wire cha_recover_scl;
	wire cha_recover_sda;
	wire chb_recover_scl;
	wire chb_recover_sda;
	
	wire cha_idle  ;
	wire cha_stuck ;
	wire chb_idle  ;
	wire chb_stuck ;
	
	//misc
	reg cha_ismst_buf;
	reg chb_ismst_buf;
	
	wire cha_ismst_mux;
	wire chb_ismst_mux;
	
	
	
	//flip flop buffers for generating 1 clock pulsed signals
	reg prev_bittx_violation ;
	reg prev_bitrx_violation ;
	reg prev_cha_stuck       ;
	reg prev_chb_stuck       ;
	
	wire bittx_violation_pulse ;
	wire bitrx_violation_pulse ;
	
	
	

	// ********* ASSIGNS ****************************************************
	assign o_idle_timeout  = cha_idle_timeout      || chb_idle_timeout;
	assign o_bit_violation = bittx_violation_pulse || bitrx_violation_pulse;
	
	assign o_cha_stuck = ~prev_cha_stuck & cha_stuck;
	assign o_chb_stuck = ~prev_chb_stuck & chb_stuck;
	
	assign o_cha_ismst = cha_ismst;
	assign o_chb_ismst = chb_ismst;
	
	
	assign bittx_violation_pulse = ~prev_bittx_violation & bittx_violation ;
	assign bitrx_violation_pulse = ~prev_bitrx_violation & bitrx_violation ;

	//add 1 clock cycle delay to chx_ismst
	assign cha_ismst_mux = cha_ismst | cha_ismst_buf;
	assign chb_ismst_mux = chb_ismst | chb_ismst_buf;




	
	// ********* REGISTER OUTPUTS *******************************************
	//flip flop register scl sda outputs or not

	generate
	if(REG_OUTPUTS) begin
		always@(posedge i_clk) begin
			o_cha_scl <= o_cha_scl_prereg;
			o_cha_sda <= o_cha_sda_prereg;
			o_chb_scl <= o_chb_scl_prereg;
			o_chb_sda <= o_chb_sda_prereg;
		end
	end
	else begin
		always @(*) begin
			o_cha_scl = o_cha_scl_prereg;
			o_cha_sda = o_cha_sda_prereg;
			o_chb_scl = o_chb_scl_prereg;
			o_chb_sda = o_chb_sda_prereg;
		end
	end
	endgenerate
	
	
	// ********* TOP LEVEL LOGIC  *******************************************

	//output logic for channel a and b
	
	//not sure how to fix atm.  cha_ismst falls immediately on stop from channel A.
	//but this means channel a scl/sda outputs switch from bitrx to bittx.
	//can use bus idle to filter it.  if the bus is idle and the i2c is not disconnected set 
	//to 1'b1.
	
	
	always @(*) begin
		if( cha_stuck ) begin
			o_cha_scl_prereg = cha_recover_scl;
			o_cha_sda_prereg = cha_recover_sda;
		end
	
		else begin
			case( {cha_ismst_mux, rxtx_tx_to_mst})
				2'b00: begin
					o_cha_scl_prereg = bittx_scl;
					o_cha_sda_prereg = bittx_sda;
				end
				
				2'b01: begin
					o_cha_scl_prereg = bitrx_scl;
					o_cha_sda_prereg = bitrx_sda;
				end
				
				2'b10: begin
					o_cha_scl_prereg = bitrx_scl;
					o_cha_sda_prereg = bitrx_sda;
				end
				
				2'b11: begin
					o_cha_scl_prereg = bittx_scl;
					o_cha_sda_prereg = bittx_sda;
				end
				
				default: begin
					o_cha_scl_prereg = bitrx_scl;
					o_cha_sda_prereg = bitrx_sda;
				end
				
			endcase
		end
	end
	
	
	
	always @(*) begin
		if( chb_stuck ) begin
			o_chb_scl_prereg = chb_recover_scl;
			o_chb_sda_prereg = chb_recover_sda;
		end
		else begin
			case( {chb_ismst_mux, rxtx_tx_to_mst})
				2'b00: begin
					o_chb_scl_prereg = bittx_scl;
					o_chb_sda_prereg = bittx_sda;
				end
				
				2'b01: begin
					o_chb_scl_prereg = bitrx_scl;
					o_chb_sda_prereg = bitrx_sda;
				end
				
				2'b10: begin
					o_chb_scl_prereg = bitrx_scl;
					o_chb_sda_prereg = bitrx_sda;
				end
				
				2'b11: begin
					o_chb_scl_prereg = bittx_scl;
					o_chb_sda_prereg = bittx_sda;
				end
				
				default: begin
					o_chb_scl_prereg = bitrx_scl;
					o_chb_sda_prereg = bitrx_sda;
				end
				
			endcase
		end
	end
	
	
	
	
	
	//always @(*) begin
	//	if( cha_stuck || chb_stuck) begin
	//		o_cha_scl_prereg = cha_recover_scl;
	//		o_cha_sda_prereg = cha_recover_sda;
	//		o_chb_scl_prereg = chb_recover_scl;
	//		o_chb_sda_prereg = chb_recover_sda;
	//
	//	end
	//	else begin
	//		case( {cha_ismst, rxtx_tx_to_mst})
	//			2'b00: begin
	//				o_cha_scl_prereg = bittx_scl;
	//				o_cha_sda_prereg = bittx_sda;
	//				o_chb_scl_prereg = bitrx_scl;
	//				o_chb_sda_prereg = bitrx_sda;
	//			end
	//			
	//			2'b01: begin
	//				o_cha_scl_prereg = bitrx_scl;
	//				o_cha_sda_prereg = bitrx_sda;
	//				o_chb_scl_prereg = bittx_scl;
	//				o_chb_sda_prereg = bittx_sda;
	//			end
	//			
	//			2'b10: begin
	//				o_cha_scl_prereg = bitrx_scl;
	//				o_cha_sda_prereg = bitrx_sda;
	//				o_chb_scl_prereg = bittx_scl;
	//				o_chb_sda_prereg = bittx_sda;
	//			end
	//			
	//			2'b11: begin
	//				o_cha_scl_prereg = bittx_scl;
	//				o_cha_sda_prereg = bittx_sda;
	//				o_chb_scl_prereg = bitrx_scl;
	//				o_chb_sda_prereg = bitrx_sda;
	//			end
	//			
	//			default: begin
	//				o_cha_scl_prereg = 1'b1;
	//				o_cha_sda_prereg = 1'b1;
	//				o_chb_scl_prereg = 1'b1;
	//				o_chb_sda_prereg = 1'b1;
	//			end
	//			
	//		endcase
	//	end
	//end
	
	

	
	
	//input logic for bit tx module
	//wire bitrx_scl_in           ;
	//wire bitrx_sda_in           ;
	//
	//wire bittx_scl_in      ;
	//wire bittx_sda_in      ;
		//output logic for channel a
	always @(*) begin

		case( {cha_ismst_mux, chb_ismst_mux,  rxtx_tx_to_mst})
				

			3'b010: begin
				bitrx_scl_in  =  chb_scl_fltrd   ;
				bitrx_sda_in  =  chb_sda_fltrd   ;
			end
			
			3'b011: begin
				bitrx_scl_in  =  cha_scl_fltrd   ;
				bitrx_sda_in  =  cha_sda_fltrd   ;
				
			end
			
			3'b100: begin
				bitrx_scl_in  =  cha_scl_fltrd   ;
				bitrx_sda_in  =  cha_sda_fltrd   ;
				
			end
			
			3'b101: begin
				bitrx_scl_in  =  chb_scl_fltrd   ;
				bitrx_sda_in  =  chb_sda_fltrd   ;
			end
			
			default: begin
				bitrx_scl_in  = 1'b1;
				bitrx_sda_in  = 1'b1;
			end
			
		endcase
	
	end
	
	
	
	
	always @(*) begin

		case( {cha_ismst_mux, chb_ismst_mux, rxtx_tx_to_mst})
			3'b010: begin
				bittx_scl_in  =  cha_scl_fltrd   ;
				bittx_sda_in  =  cha_sda_fltrd   ;
			end
			
			3'b011: begin
				bittx_scl_in  =  chb_scl_fltrd   ;
				bittx_sda_in  =  chb_sda_fltrd   ;
				
			end
			
			3'b100: begin
				bittx_scl_in  =  chb_scl_fltrd   ;
				bittx_sda_in  =  chb_sda_fltrd   ;
				
			end
			
			3'b101: begin
				bittx_scl_in  =  cha_scl_fltrd   ;
				bittx_sda_in  =  cha_sda_fltrd   ;
			end
			
			default: begin
				bittx_scl_in  = 1'b1;
				bittx_sda_in  = 1'b1;
			end
			
		endcase
	
	end
	
	
	
	
	
	
	
	
	// ********* SUBMODULES  ************************************************
	
	//i2c input filters 
	// (glitch suppresion, and start stop detection more reliable)
	i2c_passthru_infilter #(
		.EN_2FF_SYNC        (INFILTER_EN_2FF_SYNC       ),
		.NUM_CLKS_WIDTH     (INFILTER_NUM_CLKS_WIDTH    ),
		.NUM_CLKS_HI2LO_SDA (INFILTER_NUM_CLKS_HI2LO_SDA),
		.NUM_CLKS_LO2HI_SDA (INFILTER_NUM_CLKS_LO2HI_SDA),
		.NUM_CLKS_HI2LO_SCL (INFILTER_NUM_CLKS_HI2LO_SCL),
		.NUM_CLKS_LO2HI_SCL (INFILTER_NUM_CLKS_LO2HI_SCL)
	) u_filter_cha(
		.i_clk (i_clk ),
		//.i_rstn(i_rstn),
		.i_sda (i_cha_sda ),
		.i_scl (i_cha_scl ),
		
		.o_sda(cha_sda_fltrd),
		.o_scl(cha_scl_fltrd)
	);
	
	
	i2c_passthru_infilter #(
		.EN_2FF_SYNC        (INFILTER_EN_2FF_SYNC       ),
		.NUM_CLKS_WIDTH     (INFILTER_NUM_CLKS_WIDTH    ),
		.NUM_CLKS_HI2LO_SDA (INFILTER_NUM_CLKS_HI2LO_SDA),
		.NUM_CLKS_LO2HI_SDA (INFILTER_NUM_CLKS_LO2HI_SDA),
		.NUM_CLKS_HI2LO_SCL (INFILTER_NUM_CLKS_HI2LO_SCL),
		.NUM_CLKS_LO2HI_SCL (INFILTER_NUM_CLKS_LO2HI_SCL)
	)u_filter_chb(
		.i_clk (i_clk ),
		//.i_rstn(i_rstn),
		.i_sda (i_chb_sda ),
		.i_scl (i_chb_scl ),
		
		.o_sda(chb_sda_fltrd),
		.o_scl(chb_scl_fltrd)
	);
	
	

	
	i2c_passthru_idle_stuck_recover #(
		.F_REF_T_LOW                 (F_REF_T_LOW                 ),
		.F_REF_T_HI                  (F_REF_T_HI                  ),
		.F_REF_SLOW_T_STUCK_MAX      (F_REF_SLOW_T_STUCK_MAX      ),
		.WIDTH_F_REF_T_LOW           (WIDTH_F_REF_T_LOW           ),
		.WIDTH_F_REF_T_HI            (WIDTH_F_REF_T_HI            ),
		.WIDTH_F_REF_SLOW_T_STUCK_MAX(WIDTH_F_REF_SLOW_T_STUCK_MAX)

	)  u_idle_stuck_cha   (
		.i_clk         (i_clk                 ),
		.i_rstn        (i_rstn                ),
		.i_f_ref       (i_f_ref               ),
		.i_f_ref_slow  (i_f_ref_slow          ),
		.i_sda         (cha_sda_fltrd         ),
		.i_scl         (cha_scl_fltrd         ),
		.o_sda         (cha_recover_sda       ),
		.o_scl         (cha_recover_scl       ),
		
		.o_idle_timeout(cha_idle_timeout      ), 
		.o_idle        (cha_idle              ),
		.o_stuck       (cha_stuck             )
	);
	
	
	
	i2c_passthru_idle_stuck_recover #(
		.F_REF_T_LOW                 (F_REF_T_LOW                 ),
		.F_REF_T_HI                  (F_REF_T_HI                  ),
		.F_REF_SLOW_T_STUCK_MAX      (F_REF_SLOW_T_STUCK_MAX      ),
		.WIDTH_F_REF_T_LOW           (WIDTH_F_REF_T_LOW           ),
		.WIDTH_F_REF_T_HI            (WIDTH_F_REF_T_HI            ),
		.WIDTH_F_REF_SLOW_T_STUCK_MAX(WIDTH_F_REF_SLOW_T_STUCK_MAX)

	)  u_idle_stuck_chb   (
		.i_clk         (i_clk                 ),
		.i_rstn        (i_rstn                ),
		.i_f_ref       (i_f_ref               ),
		.i_f_ref_slow  (i_f_ref_slow          ),
		.i_sda         (chb_sda_fltrd         ),
		.i_scl         (chb_scl_fltrd         ),
		.o_sda         (chb_recover_sda       ),
		.o_scl         (chb_recover_scl       ),
		
		.o_idle_timeout(chb_idle_timeout      ), 
		.o_idle        (chb_idle              ),
		.o_stuck       (chb_stuck             )
	);
	
	
	//master detection
	i2c_passthru_mstr_det u_mstr_det(
		.i_clk        ( i_clk                             ),
		.i_rstn       ( i_rstn                            ),
		.i_cha_idle   ( cha_idle                          ),
		.i_chb_idle   ( chb_idle                          ),
		.i_violation  ( bittx_violation || bitrx_violation),
		.i_stuck      ( cha_stuck    || chb_stuck         ),
		.o_disconnect ( disconnect                        ),
		.o_cha_ismst  ( cha_ismst                         ),
		.o_chb_ismst  ( chb_ismst                         )
	);
	
	
	//bit control
	i2c_passthru_rxtx_ctrl u_rxtx_ctrl(
		.i_clk( i_clk),
		//.i_rstn( !(cha_idle || chb_idle) ),
		.i_cha_scl          (cha_scl_fltrd        ),
		.i_cha_sda          (cha_sda_fltrd        ),	
		.i_chb_scl          (chb_scl_fltrd        ),
		.i_chb_sda          (chb_sda_fltrd        ),
		.i_rx_done          ( bitrx_rx_done       ),
		.i_tx_done          ( bittx_tx_done       ),
		.i_rx_sda_init_valid(bitrx_sda_init_valid ),
		.i_rx_sda_init      (bitrx_sda_init       ),
		.i_tx_slv_on_mst_ch (bittx_slv_on_mst_ch  ),
		
		.o_start              ( rxtx_start          ),
		.o_tx_to_mst        ( rxtx_tx_to_mst      )
	);
	
	
	//bit rx (ingress data) control
	i2c_passthru_bitrx #(
		.F_REF_T_LOW      ( F_REF_T_LOW       ),
		.WIDTH_F_REF_T_LOW( WIDTH_F_REF_T_LOW )
	) u_bitrx (
		.i_clk              ( i_clk                 )  ,  // clock
		.i_rstn             ( i_rstn && !disconnect )  ,             
		.i_f_ref            (i_f_ref                )  ,
		.i_start_rx         (rxtx_start             ),
		.i_rx_frm_slv       (rxtx_tx_to_mst         ),
		.i_tx_done          (bittx_tx_done          ),
		.i_scl              (bitrx_scl_in           ),
		.i_sda              (bitrx_sda_in           ),
		
		.o_rx_sda_init_valid(bitrx_sda_init_valid   ),
		.o_rx_sda_init      (bitrx_sda_init         ),
		.o_rx_sda_mid_change(bitrx_sda_mid_change   ),
		.o_rx_sda_final     (bitrx_sda_final        ),
		.o_scl              (bitrx_scl              ),
		.o_sda              (bitrx_sda              ),
		.o_rx_done          (bitrx_rx_done          ),
		.o_violation        (bitrx_violation        )
	);
	
	
	//bit tx (egress data) control
	i2c_passthru_bittx #(

		.F_REF_T_R            (F_REF_T_R            ),
		.F_REF_T_SU_DAT       (F_REF_T_SU_DAT       ),
		.F_REF_T_LOW          (F_REF_T_LOW          ),
		.WIDTH_F_REF_T_R      (WIDTH_F_REF_T_R      ),
		.WIDTH_F_REF_T_SU_DAT (WIDTH_F_REF_T_SU_DAT ),
		.WIDTH_F_REF_T_LOW    (WIDTH_F_REF_T_LOW    )
	
	) u_bittx
	(
		.i_clk              ( i_clk                ),
		.i_rstn             ( i_rstn && !disconnect),
		.i_f_ref            (i_f_ref               ),
		.i_start_tx         (rxtx_start            ),
		.i_tx_is_to_mst     (rxtx_tx_to_mst        ),
		.i_rx_sda_init_valid(bitrx_sda_init_valid  ),
		.i_rx_sda_init      (bitrx_sda_init        ),
		.i_rx_sda_mid_change(bitrx_sda_mid_change  ),
		.i_rx_sda_final     (bitrx_sda_final       ),
		.i_rx_done          (bitrx_rx_done         ),
		.i_scl              (bittx_scl_in          ),
		.i_sda              (bittx_sda_in          ),

		.o_scl              (bittx_scl             ),
		.o_sda              (bittx_sda             ),
		.o_slv_on_mst_ch    (bittx_slv_on_mst_ch   ),
		.o_tx_done          (bittx_tx_done         ),
		.o_violation        (bittx_violation       )
		
	);
	
	

	// ********* GENERATE 1 CLOCK PULSES ************************************
	always @(posedge i_clk) begin
	
		// ********* GENERATE 1 CLOCK PULSES ********************************
		prev_bittx_violation <= bittx_violation;
		prev_bitrx_violation <= bitrx_violation;
		prev_cha_stuck       <= cha_stuck;
		prev_chb_stuck       <= chb_stuck;
		
		// ********* MISC                    ********************************
		cha_ismst_buf <= cha_ismst;
		chb_ismst_buf <= chb_ismst;

	end
	

	


endmodule
