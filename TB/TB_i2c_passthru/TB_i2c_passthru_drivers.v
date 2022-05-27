`include "timescale.v" 



//i2c master.  does not diffentiate between read or write operations
module driver_msti2c(
	input i_scl,
	input i_sda,
	
	//posedge starts transaction
	input i_start,  
	
	//how long to wait for sda to change after scl changes.
	//see "i_sda_chng_on_rising_scl" to choose which edge to time from.
	input [31:0] i_sda_scl_timing_ref, 
	input [31:0] i_scl_lo_timing,
	input [31:0] i_scl_hi_timing,
	
	 //set high if sda should change using scl rising edge as reference.
	 //else sda will change using scl falling edge as reference.
	input i_sda_chng_on_rising_scl,
	
	//number of bytes for this transaction (including address, write, and read)
	input [2:0] i_num_bytes, 
	
	//insert repeat start control bit or stop control bit
	//after which byte.  Set to 7 to not insert.
	input [2:0] i_repeatstart_after_byte,
	input [2:0] i_stop_after_byte,
	
	//data bytes
	input [8:0] i_byte_0  ,
	input [8:0] i_byte_1  ,
	input [8:0] i_byte_2  ,
	input [8:0] i_byte_3  ,
	input [8:0] i_byte_4  ,
	input [8:0] i_byte_5  ,
	input [8:0] i_byte_6  ,
	
	
	output reg o_scl,
	output reg o_sda,
	
	output reg o_idle


);
	localparam NUM_DAT_BITS = 7*9;
	reg [NUM_DAT_BITS-1:0] all_bytes;
	reg [3:0] bit_cnt;
	reg [3:0] byte_cnt;
	reg       nxt_bit_is_ctrl;
	
	wire final_byte;
	wire stop_byte;
	

	assign       final_byte = (i_num_bytes               === (byte_cnt+1'b1  )    );
	assign        stop_byte = (i_stop_after_byte         ===  byte_cnt            );
	assign repeatstart_byte = (i_repeatstart_after_byte  ===  byte_cnt            );
	
	assign cur_bit_is_last           = (4'h9 == bit_cnt);
	//assign cur_bit_is_almost_last    = (4'h7 === bit_cnt);
	
	assign nxt_bit_is_ctrl = (stop_byte || repeatstart_byte) && cur_bit_is_last;


	initial begin
		o_idle = 1'b1;
		o_scl = 1'b1;
		o_sda = 1'b1;
	end
	
	always @(posedge i_start) begin
		bit_cnt  = 0;
		byte_cnt = 0;
		all_bytes = { 
			i_byte_0  ,
			i_byte_1  ,
			i_byte_2  ,
			i_byte_3  ,
			i_byte_4  ,
			i_byte_5  ,
			i_byte_6  
		};
		o_idle = 0;
		o_scl = 1'b1;
		o_sda = 1'b0;
		
		o_scl <= #i_scl_hi_timing 1'b0;
	end
	
	//generate o_idle
	always @(posedge i_scl) begin
		if( final_byte && cur_bit_is_last) o_idle <= #i_scl_hi_timing 1'b1;
	end
	
	//generate o_scl next rising edge
	always @(negedge i_scl) begin
		o_scl <= #i_scl_lo_timing 1'b1;
	end
	
	//generate o_scl next falling edge
	always @(posedge i_scl) begin
		if( final_byte && cur_bit_is_last) o_scl = 1'b1; //do nothing
		else begin
			if( nxt_bit_is_ctrl) o_scl <= #(2*i_scl_hi_timing) 1'b0;
			else                 o_scl <= #(  i_scl_hi_timing) 1'b0; //normal data bit
		end
	end
	
	//bit_cnt
	always @(posedge i_scl) begin
		//bit_cnt <= ( cur_bit_is_last ) ? 0 : bit_cnt + 1'b1;
		bit_cnt <= (cur_bit_is_last && !nxt_bit_is_ctrl) ? 0 : bit_cnt + 1'b1;
	end
	
	//o_sda  logic 
	always @(i_scl) begin
	
		if(    ( i_sda_chng_on_rising_scl &&  i_scl)
		    || (~i_sda_chng_on_rising_scl && ~i_scl) ) begin
			
			if( nxt_bit_is_ctrl) begin
				o_sda <= #(i_sda_scl_timing_ref) (stop_byte ? 1'b0 : 1'b1);
			end
			else begin
				o_sda <= #i_sda_scl_timing_ref   all_bytes[NUM_DAT_BITS-1];
				all_bytes = (all_bytes << 1);
			end
		end
		
		//posedge i_scl
		if( i_scl) begin
			if( nxt_bit_is_ctrl) begin
				o_sda <= #(i_scl_hi_timing) ( stop_byte ? 1'b1 : 1'b0 );
			end
		end
	end
	
	
	
endmodule




