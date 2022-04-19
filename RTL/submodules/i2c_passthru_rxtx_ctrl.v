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




module i2c_passthru_rxtx_ctrl(

	input i_clk,
	//input i_rstn,
	input i_cha_scl,
	input i_cha_sda,
	
	input i_chb_scl,
	input i_chb_sda,
	

	input i_rx_done,
	input i_tx_done,
	
	input i_rx_sda_init_valid,
	input i_rx_sda_init,
	
	input i_tx_slv_on_mst_ch,
	
	output reg o_start,
	output reg o_tx_to_mst
);
	reg [1:0] state, nxt_state;
	reg [3:0] bit_cnt, nxt_bit_cnt;
	reg       inc_bit_cnt;
	
	reg first_byte_n   , nxt_first_byte_n   ;
	reg read_mode      , nxt_read_mode      ;
	reg ack_failed     , nxt_ack_failed     ;
	reg slv_on_mst_side, nxt_slv_on_mst_side;
	
	//reg nxt_slv_is_rx;
	//reg set_slv_is_rx;
	//reg clr_slv_is_rx;
	//reg set_mst_is_rx;
	//reg clr_mst_is_rx;
	
	reg bit_willbe_slv_rx;
	wire bit_willbe_ack;
	wire bit_is_ack;
	wire bit_is_read;
	
	reg  prev_cha_sda;
	reg  prev_chb_sda;

	wire cha_negedge_sda;
	wire chb_negedge_sda;
	
	wire cha_start;
	wire chb_start;

	
		//prev_cha_sda <= i_cha_sda;
		//prev_chb_sda <= i_chb_sda;
	
	assign bit_willbe_ack = ( 4'h8 == bit_cnt);
	assign bit_is_ack     = ( 4'h9 == bit_cnt);
	assign bit_is_read    = ( 4'h8 == bit_cnt) && ~first_byte_n;
	
	assign cha_negedge_sda =  prev_cha_sda & ~i_cha_sda      ;
	assign chb_negedge_sda =  prev_chb_sda & ~i_chb_sda      ;

	assign cha_start      =   i_cha_scl    &  cha_negedge_sda;
	assign chb_start      =   i_chb_scl    &  chb_negedge_sda;

	assign nxt_slv_on_mst_side = slv_on_mst_side | i_tx_slv_on_mst_ch;

	always @(*) begin
		case( {slv_on_mst_side, bit_willbe_ack, read_mode, ack_failed} )
			4'b0000: bit_willbe_slv_rx = 0;
			4'b0001: bit_willbe_slv_rx = 0;
			4'b0010: bit_willbe_slv_rx = 0;
			4'b0011: bit_willbe_slv_rx = 1;
			4'b0100: bit_willbe_slv_rx = 1;
			4'b0101: bit_willbe_slv_rx = 1;
			4'b0110: bit_willbe_slv_rx = 0;
			4'b0111: bit_willbe_slv_rx = 0;
			4'b1000: bit_willbe_slv_rx = 0;
			4'b1001: bit_willbe_slv_rx = 0;
			4'b1010: bit_willbe_slv_rx = 0;
			4'b1011: bit_willbe_slv_rx = 0;
			4'b1100: bit_willbe_slv_rx = 0;
			4'b1101: bit_willbe_slv_rx = 0;
			4'b1110: bit_willbe_slv_rx = 0;
			4'b1111: bit_willbe_slv_rx = 0;
			default: bit_willbe_slv_rx = 0;

		endcase
	end
	
	
	localparam ST_MST_RX_WAIT     = 0;
	localparam ST_MST_RX_START    = 1;
	localparam ST_SLV_RX_WAIT     = 2;
	localparam ST_SLV_RX_START    = 3;

	
	always @(*) begin
		//default else case
		nxt_state = state;
		
		o_start         = 1'b0;
		inc_bit_cnt     = 1'b0;
		o_tx_to_mst   = 1'b0;
		
		
		case( state)
		
			ST_MST_RX_WAIT  : 
			begin
				if( i_rx_done && i_tx_done) begin
					if( bit_willbe_slv_rx)  nxt_state = ST_SLV_RX_START;
					else                    nxt_state = ST_MST_RX_START;
				end
			end
			
			ST_MST_RX_START :  
			begin
				o_start     = 1'b1;
				inc_bit_cnt = 1'b1;
				
				nxt_state = ST_MST_RX_WAIT;
			end
			
			ST_SLV_RX_WAIT  :  
			begin
				o_tx_to_mst = 1'b1;

				if( i_rx_done && i_tx_done) begin
					if( bit_willbe_slv_rx)  nxt_state = ST_SLV_RX_START;
					else                    nxt_state = ST_MST_RX_START;
				end
			end
			
			ST_SLV_RX_START :  
			begin		
				o_tx_to_mst = 1'b1;
				o_start       = 1'b1;
				inc_bit_cnt   = 1'b1;
				
				nxt_state = ST_SLV_RX_WAIT;

				
			end
			
			default:
			begin
				nxt_state = ST_MST_RX_WAIT;
			end
		endcase
	
	end
	
	
	//bit count
	always @(*) begin
		if( inc_bit_cnt) begin
			if( 9 == bit_cnt) nxt_bit_cnt = 4'h1;
			else              nxt_bit_cnt = bit_cnt + 1'b1;
			
		end
		else begin
			nxt_bit_cnt = bit_cnt;
		end
	end
	
	
	//determine first_byte_n
	always @(*) begin
		if( 9 == bit_cnt) nxt_first_byte_n = 1'b1;
		else              nxt_first_byte_n = first_byte_n;
	end
	
	//determine read mode
	always @(*) begin
		if( bit_is_read && i_rx_sda_init_valid) 
			nxt_read_mode = i_rx_sda_init;
		else
			nxt_read_mode = read_mode;
	end
	
	
	//determine ack_failed
	always @(*) begin
		if( bit_is_ack && i_rx_sda_init_valid && !ack_failed )
			nxt_ack_failed = i_rx_sda_init;
		else
			nxt_ack_failed = ack_failed;
	end
	
	

	

	//synchronous logic that requires reset
	always @(posedge i_clk) begin
		//if( i_rstn) begin
		//if( cha_start || chb_start ) begin
		if( !(cha_start || chb_start) ) begin
			state           <= nxt_state           ;
			bit_cnt         <= nxt_bit_cnt         ;
			first_byte_n    <= nxt_first_byte_n    ;
			read_mode       <= nxt_read_mode       ;
			ack_failed      <= nxt_ack_failed      ;
			slv_on_mst_side <=  nxt_slv_on_mst_side;

		
		end 
		else begin
			state           <= ST_MST_RX_WAIT;
			bit_cnt         <= 4'h0;
			first_byte_n    <= 1'b0;
			read_mode       <= 1'b0;
			ack_failed      <= 1'b0;
			slv_on_mst_side <=  1'b0;
			
			
		end

	end
	
	//synchronous logic no reset required
	always @(posedge i_clk) begin
		prev_cha_sda <= i_cha_sda;
		prev_chb_sda <= i_chb_sda;

	end
	
	


endmodule
