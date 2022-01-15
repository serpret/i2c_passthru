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



module i2c_passthru_bittx (

	//F_REF values should always be at least 2.
	
	//number of periods of i_f_ref required for smbus timing
	//example: for t_r=1us ( rise time) and i_f_ref is 8mhz
	// 8mhz * 1us = 8
	// set to greater than 8
	parameter F_REF_T_R       = 15, // t_r rise time maximum (recommend double the value)
	parameter F_REF_T_SU_DAT  =  2, // t_su:dat dat setup time minimum
	parameter F_REF_T_LOW     = 38, // t_low clock low period minimum 
	                                //   (also used for
	                                //     t_buf   , t_hd:sta, t_su_sta, 
	                                //     t_su_sto, t_high             )
	
	//WIDTH required to binary count F_REF values above.
	// calculation: CEILING ( LOG2 ( F_REF+1) )
	parameter WIDTH_F_REF_T_R    = 4
	parameter WIDTH_F_REF_SU_DAT = 2
	parameter WIDTH_F_REF_T_LOW  = 6

	


)
(
	input i_clk,
	input i_rstn,
	
	input i_start_tx
	input i_tx_is_to_mst
	
	input i_rx_sda_init_valid
	input i_rx_sda_init
	input i_rx_sda_mid_change
	input i_rx_sda_final
	input i_rx_done;
	
	input i_scl,
	input i_sda,
	
	
	
	output reg o_scl
	output reg o_sda
	output reg o_tx_done
	output reg o_violation
	

);

	reg [?:0] state, nxt_state;
	reg tx_to_mst, nxt_tx_to_mst;
	wire sda_mismatch;


	localparam ST_IDLE             = 0  :
	localparam ST_SCL0_A           = 1  :
	localparam ST_SCL0_B           = 2  :
	localparam ST_SCL1_A_TX2MST    = 3  :
	localparam ST_SCL1_A_INIT      = 4  :
	localparam ST_SCL1_B_WAIT      = 5  :
	localparam ST_SCL1_C_MID       = 6  :
	localparam ST_SCL1_D_WAIT      = 7  :
	localparam ST_SCL1_E_FIN       = 8  :
	localparam ST_SCL1_F_VIOLATION = 9  :
	
	//FSM next state and output logic
	always @(*) begin
		//default else case
		nxt_state = state;
		nxt_tx_to_mst = tx_to_mst;
		
		o_tx_done   = 0;
		o_violation = 0;
		
		case( state) 
		
			ST_IDLE               :
			begin
				o_tx_done = 1;
				o_scl = 0;
				o_sda = i_rx_sda_final;
				
				nxt_tx_to_mst = i_tx_is_to_mst;
				if( i_start_tx) nxt_state = ST_SCL0_A;
			
			end
			
			ST_SCL0_A             :
			begin
				o_scl = 0;
				o_sda = i_rx_sda_init;
				
				if( i_start_tx) nxt_state = ST_SCL0_A;
			end
			
			ST_SCL0_B             :
				o_scl = 1;
				o_sda = i_rx_sda_init;
				
				if(i_scl) begin
					if ( tx_to_mst) nxt_state = ST_SCL1_A_TX2MST;
					else            nxt_state = ST_SCL1_A_INIT;
				
				end
			begin
			end
			
			ST_SCL1_A_TX2MST      :
			begin
				o_scl = 1;
				o_sda = i_rx_sda_init;
				
				if( sda_mis
			end
			
			ST_SCL1_A_INIT        :
			begin
			end
			
			ST_SCL1_B_WAIT        :
			begin
			end
			
			ST_SCL1_C_MID         :
			begin
			end
			
			ST_SCL1_D_WAIT        :
			begin
			end
			
			ST_SCL1_E_FIN         :
			begin
			end
			
			ST_SCL1_F_VIOLATION   :
			begin
				o_violation = 1;

			end
			
			default: 
			begin
			end
			
		endcase
	end
	
	
	
	
	
	i2c_passthru_sda_mismatch #(

		.F_REF_T_R  (F_REF_T_R)
		.WIDTH_F_REF(WIDTH_F_REF_T_R)

	) (
		.i_clk  (i_clk  ),
		.i_rstn (i_rstn ),
		.i_f_ref(i_f_ref),
		
		.i_padin_sig ( i_sda), //signal coming into FPGA
		.i_padout_sig( o_sda), //signal leaving FPGA
		
		.o_mismatch(sda_mismatch)
	
	);

	//sequential logic that requires reset
	always @(posedge i_clk) begin
		if( rstn) begin
			state <= nxt_state;
		end
		else begin
			state <= ST_IDLE;
		end
	
	end
	
	
	//sequential logic without reset
	always @(posedge i_clk) begin
		tx_to_mst <= nxt_tx_to_mst;
	end
	

	







endmodule
