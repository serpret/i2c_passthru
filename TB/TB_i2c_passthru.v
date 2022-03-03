`timescale 1ns/100ps


module tb();
	//parameters
	
	localparam NS_TB_TIMEOUT      =   300_000_000;
	localparam NS_T_BUS_STUCK_MAX =   200_000_000;
	localparam NS_T_BUS_STUCK_MIN =    25_000_000;
	
	localparam NS_T_HI_MAX      =  700000;
	localparam NS_T_HI_MIN      =   50000;
	localparam NS_T_LOW_MIN     = 4000;
	localparam NS_T_LOW_MAX     = 6000;
	
	
	localparam F_REF_T_R                   = 2;
	localparam F_REF_T_SU_DAT              = 2;
	localparam F_REF_T_HI                  =50;  //max value (timeout)
	localparam F_REF_T_LOW                 = 5;
	localparam F_REF_SLOW_T_STUCK_MAX      = 2;
	localparam WIDTH_F_REF_T_R              = 2;
	localparam WIDTH_F_REF_T_SU_DAT         = 2;
	localparam WIDTH_F_REF_T_HI             = 6;
	localparam WIDTH_F_REF_T_LOW            = 3;
	localparam WIDTH_F_REF_SLOW_T_STUCK_MAX = 2;
	
	
	
	
	



	always #160        i_clk         = ~i_clk; //160 ->
	always #500        f_ref_unsync  = ~f_ref_unsync;    
	always #8_000_000 f_ref_slow_unsync = ~f_ref_slow_unsync; // 16ms period. 
	
	always @(posedge i_clk) begin
		i_f_ref      <= f_ref_unsync;
		i_f_ref_slow <= f_ref_slow_unsync;
	end
	
	
	i2c_passthru #(
	
		.REG_OUTPUTS                  (0  ),
		.F_REF_T_R                    (F_REF_T_R                   ),
		.F_REF_T_SU_DAT               (F_REF_T_SU_DAT              ),
		.F_REF_T_HI                   (F_REF_T_HI                  ),
		.F_REF_T_LOW                  (F_REF_T_LOW                 ),
		.F_REF_SLOW_T_STUCK_MAX       (F_REF_SLOW_T_STUCK_MAX      ),    
		.WIDTH_F_REF_T_R              (WIDTH_F_REF_T_R             ),
		.WIDTH_F_REF_T_SU_DAT         (WIDTH_F_REF_T_SU_DAT        ),
		.WIDTH_F_REF_T_HI             (WIDTH_F_REF_T_HI            ),
		.WIDTH_F_REF_T_LOW            (WIDTH_F_REF_T_LOW           ),
		.WIDTH_F_REF_SLOW_T_STUCK_MAX (WIDTH_F_REF_SLOW_T_STUCK_MAX),
		
	
	) uut
	(
	
	
		input i_clk,        
		input i_rstn,       
		input i_f_ref,      
		input i_f_ref_slow, 
		
	
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
	

	



	integer failed = 0;
	//integer subtest_failed ;
	initial begin
		$timeformat(-6,3, "us", 12);
		init_vars();
		rst_uut();
		



	
		if( failed) $display(" ! ! !  TEST FAILED ! ! !");
		else        $display(" Test Passed ");
		$stop();
	
	end
	
	//task reinit_start_times;
	//	begin
	//		time_start_fall_scl = $realtime;
	//		time_start_rise_scl = $realtime;
	//		time_start_chng_sda = $realtime;
	//	
	//	end
	//endtask


	task init_vars;
		begin
			i_clk = 0;
			i_rstn = 0;
			f_ref_unsync  =0;
			f_ref_slow_unsync =0;
			
			reset_scl_count = 0;
			
			//time_start_fall_scl = 0;
			//time_start_rise_scl = 0;
			//time_start_chng_sda = 0;
			
			i_scl        = 1;
			i_sda        = 1;
			
		end
	endtask
	
	
	
	task rst_uut;
		begin
		
		i_rstn = 0;
		repeat(1) @(posedge i_clk);
		i_rstn = 1;
		repeat(1) @(posedge i_clk);
		
		end
	endtask
	
	
	
	
	
	

	
	
	
	
	function realtime time_elapsed;
		input realtime start;
		begin
			time_elapsed = $realtime - start;
		end
	endfunction
	
	
endmodule



module driver_i2c(

	input i_scl,
	input i_sda,
	
	//scl timing reference to violate sda timing (see "i_sda_violate")
	input i_scl_sda_chng_ref,
	
	input        i_start,    //set high to start
	
	//options during transaction, set these before i_start goes high
	//and keep them valid until o_idle goes high
	
	
	//timing used for t_low, t_high, and delay used between clock edges and start/stop conditions
	//(only t_low applicable to slave)
	input [31:0] i_timing,   
	
	//set high before i_start to perform a master operation (else slave)
	input        i_is_mstr,  
	
	//set high before i_start to have 8 times longer 
	//clock low periods (valid for master and slave)
	input        i_clock_low_by8, 
	                               
	//set i_sda_violate high before i_start to have sda perform its changes for data 
	//a data transaction shortly after scl rises or shortly before scl falls 
	//This violates setup and hold times. For slaves i_sda_violate only violates scl rises.
	//set i_sda_violate_time to preferred time for sda to transition before scl falls
	//("i_sda_violate_time" only used by master for falling scl transition, for rising
	// scl transition and for slaves see "i_scl_sda_chng_ref")
	input        i_sda_violate, 
	//input [31:0] i_sda_violate_time,
	                                   
	                                   
	//set high to not start/stop at begin/end of transaction
	input        i_dont_stop    
	input        i_dont_start   
	
	//max 15, set to 0 for just 1 byte. number of bytes to write. a byte in i2c context is 9bits.
	//(address byte is considered a write byte, expected read bytes should be filled with 9'h1FE )
	input [3:0] i_stop_after_byte, 
	
	//options to insert extra start/stop after specified byte
	//set all bits high to ignore (not insert extra start/stop)
	//if both are set to same byte and not ignored
	//then stop is performed first, then start follows.
	//to do extra stop/start immediately after first byte set to 0
	input [3:0] i_extra_stop_after_byte,  
	input [3:0] i_extra_start_after_byte, 

	//data for write bytes.  i_wrbyte_0 is first to be written.  
	//msb is written out first. bit0 is typically the ack bit.
	input [8:0] i_wrbyte_0  ;
	input [8:0] i_wrbyte_1  ;
	input [8:0] i_wrbyte_2  ;
	input [8:0] i_wrbyte_3  ;
	input [8:0] i_wrbyte_4  ;
	input [8:0] i_wrbyte_5  ;
	input [8:0] i_wrbyte_6  ;
	input [8:0] i_wrbyte_7  ;
	input [8:0] i_wrbyte_8  ;
	input [8:0] i_wrbyte_9  ;
	input [8:0] i_wrbyte_10 ;
	input [8:0] i_wrbyte_11 ;
	input [8:0] i_wrbyte_12 ;
	input [8:0] i_wrbyte_13 ;
	input [8:0] i_wrbyte_14 ;
	input [8:0] i_wrbyte_15 ;

	output o_scl,
	output o_sda,
	
	output reg o_idle
	

);
	localparam VIOLATE_TIME = 100; //assuming 

	reg [3:0] bit_cnt;
	reg [3:0] byte_cnt;
	reg [8:0] cur_byte;
	//reg       ref_scl_for_sda;
	wire final_byte;
	wire stop_byte;
	wire start_byte;

	
	assign final_byte = (i_stop_after_byte       ) == byte_cnt;
	assign  stop_byte = (i_extra_start_after_byte) == byte_cnt;
	assign start_byte = (i_extra_stop_after_byte ) == byte_cnt;

	
	always @(posedge i_start) begin
		bit_cnt  = 0;
		byte_cnt = 0;
		cur_byte = i_wrbyte_0;
		//state    = 
		o_idle = 1'b0;
		//ref_scl_for_sda = 1'b1;
		o_scl = 1'b1;
		o_sda = 1'b1;
		
		if( i_is_mstr) begin
			if( i_dont_start) begin
				o_sda    = 1'b1;
				//ref_scl_for_sda <= #i_timing 1'b0;
				o_scl <= #i_timing 1'b0;
			end 
			else begin
				o_sda   <= #i_timing 1'b0;
				//ref_scl_for_sda <= #(2*i_timing) 1'b0;
				o_scl <= #(2*i_timing) 1'b0;
			end
		end 
	end
	
	//generate o_scl next rising edge
	always @(negedge i_scl) begin
		
		if( i_clock_low_by8) o_scl <= #(8*i_timing) 1'b1;
		else                 o_scl <= #(  i_timing) 1'b1;

	end
	
	//if i_clock_low_by8 and slave that means we are clock stretching
	always @(negedge i_scl) begin
		if(!i_is_mstr && i_clock_low_by8) o_scl = 1'b0; 
	end
	
	//generate o_scl next falling edge
	always @(posedge i_scl) begin
		if(i_is_mstr) begin
			if( 4'hA == bit_cnt) begin //control event bit
				if(      final_byte)               o_scl  =               1'b1;   //do nothing
				else if ( stop_byte && start_byte) o_scl <= #(3*i_timing) 1'b0;
				else if ( stop_byte || start_byte) o_scl <= #(2*i_timing) 1'b0;
			end
			else begin
				o_scl <= #(i_timing) 1'b0; //normal data bit
			end
		end
	end
	
	//bit count and byte count
	always @(negedge i_scl) begin
		if( 4'hA == bit_cnt ) //ctrl bit
			bit_cnt <= 4'h1;
			byte_cnt <= byte_cnt + 1'b1;
		else if (4'h9 == bit_cnt) begin
			if(stop_byte || start_byte) begin
				bit_cnt <= bit_cnt + 1'b1;
			end
			else begin
				bit_cnt  <= 4'h1;
				byte_cnt <= byte_cnt + 1'b1;
			end
		end
		else begin
			bit_cnt <= bit_cnt + 1'b1;
		
		end
	end
	
	//handle cur_byte
	always @(negedge i_scl) begin
		if(   //4'h0 == bit_cnt 
		        4'hA == bit_cnt 
			|| (4'h9 == bit_cnt && !(stop_byte || start_byte)) 
		) begin
			case( byte_cnt)
				0  : cur_byte <= i_wrbyte_1 ;
				1  : cur_byte <= i_wrbyte_2 ;
				2  : cur_byte <= i_wrbyte_3 ;
				3  : cur_byte <= i_wrbyte_4 ;
				4  : cur_byte <= i_wrbyte_5 ;
				5  : cur_byte <= i_wrbyte_6 ;
				6  : cur_byte <= i_wrbyte_7 ;
				7  : cur_byte <= i_wrbyte_8 ;
				8  : cur_byte <= i_wrbyte_9 ;
				9  : cur_byte <= i_wrbyte_10;
				10 : cur_byte <= i_wrbyte_11;
				11 : cur_byte <= i_wrbyte_12;
				12 : cur_byte <= i_wrbyte_13;
				13 : cur_byte <= i_wrbyte_14;
				14 : cur_byte <= i_wrbyte_15;
				15 : cur_byte <= cur_byte; //last byte. ignore.
			endcase
		end
		else begin
			cur_byte <= (cur_byte[7:0] << 1);
		end
		
	end
	
	//handle o_sda data transitions 
	always @( i_scl_sda_chng_ref) begin
		if( i_sda_violate) begin
			if( i_scl_sda_chng_ref) begin //rising edge of reference scl
				if( 4'hA == bit_cnt && final_byte && !i_dont_stop
				    4'hA == bit_cnt &&
				o_sda <= cur_byte[8];
			end
			else begin // falling edge of reference scl
				o_sda <= ~o_sda;
			end
		end
		else begin
			if( i_scl_sda_chng_ref) begin //rising edge of reference scl
				o_sda <= o_sda; //no change, ignore
			end
			else begin // falling edge of reference scl
				o_sda <= cur_byte[8];
			end

		end
	end
	
	
	//handle sda_o data transitions if i_sda_violate is low
	//always @(negedge i_scl) begin
	//	if( !i_sda_violate) begin
	//	
	//
	//	end
	//end
	
	////generate ref_scl_for_sda
	//always @(negedge i_scl) begin
	//	if( !o_idle) begin
	//		ref_scl_for_sda  = i_scl;
	//	end
	//end
	//
	//always @(posedge i_scl) begin
	//	if( !o_idle) begin
	//		if( i_is_mstr) ref_scl_for_sda <= #i_timing 1'b0;
	//	end
	//end
	//
	//always @(negedge i_scl_violate_ref) begin
	//	
	//end
	//
	////generate o_sda
	//always @(ref_scl_for_sda) begin
	//	if( i_sda_violate) begin
	//		o_sda 
	//	end
	//	else begin
	//	
	//	end
	//end
	//
	////generate o_scl
	//always @(
	//
	//always @(negedge ref_scl_for_sda) begin
	//	if( i_sda_violate) begin
	//		o_sda = ~o_sda;
	//		o_scl <= #i_sda_violate_time 1'b0;
	//		
	//	end 
	//	else begin
	//		o_scl = 1'b0;
	//		o_sda = cur_byte[8];
	//	end
	//end
	//
	//always @(negedge i_scl) begin
	//	if( 4'h9 == bit_cnt) begin
	//		if(  i_extra_stop_after_byte == byte_cnt) begin
	//			o_sda = 0;
	//			ref_scl_for_sda =
	//			o_sda <= 
	//			
	//		end
	//	end
	//	else if (4'hA == bit_cnt) begin
	//	
	//	
	//	end
	//	else begin
	//		bit_cnt <= bit_cnt + 1'b1;
	//	end
	//
	//end
	//
	//
	//always @(posedge i_scl) begin
	//
	//end
	
	
	

endmodule





	
