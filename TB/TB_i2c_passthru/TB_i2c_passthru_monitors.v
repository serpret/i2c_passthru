
////////////    mon_i2c: i2c testbench monitor. ////////////////////////////////
//
//i_en_timing_check = 1 
//		to enable timing checks (prints error message and outputs o_timing_check_err)
//
//i_clr_all = 1 
//		to clear all outputs and internal states from previous run 
//		(clears o_num_events, events, and o_timing_check_err)
//
//i_t_low 
//i_t_su  
//		timing values for timing checks.
//		i_t_low is the t_low minimum time for smbus/i2c.  
//			This value is also used as t_high, t_buf, t_su_sto, t_hd_sta, and t_su_sta
//		i_t_su is the t_su_dat minimum time for smbus/i2c.

//o_num_events is the number of events captured since i_clr_all last was set to 1
//
//o_events is the i2c events captured:
//		last event captured is shifted into the lsb
//		events are encoded as 2 bits:
//			MON_EVENT_0
//			MON_EVENT_1
//			MON_EVENT_P
//			MON_EVENT_S
//
//		Example: 1 start bit captured,  1 data bit captured with value 0, 1 stop bit captured
//			o_num_events = 3
//			o_events = { MON_EVENT_S, MON_EVENT_1, MON_EVENT_P}

module mon_i2c #(
	parameter DEF_MON_EVENT_0 = 2'b00,
	parameter DEF_MON_EVENT_1 = 2'b01,
	parameter DEF_MON_EVENT_P = 2'b10,
	parameter DEF_MON_EVENT_S = 2'b11

) (
	input [511:0] test_type,
	input [511:0] test_subtype,
	input [511:0] fail_substr,
	input i_scl,
	input i_sda,
	
	input i_en_timing_check       ,
	input i_clr_all               ,
	
	input [31:0] i_t_low        ,
	input [31:0] i_t_su         ,
	//input realtime i_t_low        , //error
	//input realtime i_t_su         ,
	
	output reg [31:0] o_num_events, 
	output reg [255:0] o_events   ,
	output reg o_timing_check_err
);
	reg psbl_data;
	realtime t_low_start;
	realtime t_su_start;
	
	always @(posedge i_clr_all) begin
		o_num_events       = 32'd0;
		o_events           = {256{1'b0}};
		o_timing_check_err = 1'b0;
		psbl_data          = 1'b0;
	end
	
	// event capture logic
	always @(posedge i_scl) begin
		psbl_data = 1'b1;
		
	end
	
	always @(negedge i_scl) begin
		if( psbl_data) begin
			o_num_events  = o_num_events + 1'b1;
			o_events      = o_events << 2;
			o_events[1:0] = i_sda ? DEF_MON_EVENT_1: DEF_MON_EVENT_0;
		end
	end
	
	always @( i_sda) begin
		if(i_scl) begin
			psbl_data = 1'b0;
			o_num_events  = o_num_events + 1'b1;
			o_events      = o_events << 2;
			o_events[1:0] = i_sda ? DEF_MON_EVENT_P: DEF_MON_EVENT_S;
		end
	end
	
	//timing check logic
	always @(posedge i_scl) begin
	
		if( i_en_timing_check) begin
			if( time_elapsed( t_low_start) < i_t_low) begin 
				task_t_low_violation( $realtime, time_elapsed( t_low_start));
			end
			if( time_elapsed( t_su_start ) < i_t_su) begin
				task_t_su_violation($realtime, time_elapsed( t_low_start));
			end

			t_low_start = $realtime;
		end
	
	end
	
	always @(negedge i_scl) begin
		if( i_en_timing_check) begin
			if( time_elapsed( t_low_start) < i_t_low) task_t_low_violation( $realtime, time_elapsed( t_low_start));

			t_low_start = $realtime;
		end
	end
	
	always @(i_sda) begin
		if( i_en_timing_check) begin
			if( i_scl) begin
				if( time_elapsed( t_low_start) < i_t_low) task_t_low_violation( $realtime, time_elapsed( t_low_start));
				t_low_start = $realtime;
			end
			else begin
				t_su_start = $realtime;
			end
		end
	end
	


	function realtime time_elapsed;
		input realtime start;
		begin
			time_elapsed = $realtime - start;
		end
	endfunction
	
	
	//task task_t_low_violation;
	//	begin
	//		$display("-------  Failed test: task_t_low_violation ------");
	//		$display("    %s", str_lalign( fail_substr) );
	//		$display("    time: %t", $realtime);
	//		o_timing_check_err = 1'b1;
	//	end
	//endtask
	
	task task_t_low_violation;
		input realtime timestamp;
		input realtime duration;
		begin

		
			$display("-------  Failed test: task_t_low_violation ------");
			$display("    %s",               str_lalign( fail_substr ) );
			$display("    test type   : %s", str_lalign( test_type   ) );
			$display("    test subtype: %s", str_lalign( test_subtype) );
			$display("    time        : %t", timestamp);
			$display("    duration    : %t", duration );
			o_timing_check_err = 1'b1;
		end
	endtask
	
	task task_t_su_violation;
		input realtime timestamp;
		input realtime duration;
		begin
			$display("-------  Failed test: task_t_su_violation ------");
			$display("    %s",               str_lalign( fail_substr) );
			$display("    test type   : %s", str_lalign( test_type   ) );
			$display("    test subtype: %s", str_lalign( test_subtype) );
			$display("    time        : %t", timestamp);
			$display("    duration    : %t", duration );
			o_timing_check_err = 1'b1;
		end
	endtask

endmodule
	
	
	
	
	
module mon_passthru_optional_outputs(
	input i_clk,
	input i_rstn,
	input i_idle_timeout  ,
	input i_bit_violation ,
	input i_cha_stuck     ,
	input i_chb_stuck     ,
	

	output reg [31:0] o_cnt_idle_timeout  ,
	output reg [31:0] o_cnt_bit_violation ,
	output reg [31:0] o_cnt_cha_stuck     ,
	output reg [31:0] o_cnt_chb_stuck     
);

	wire tc_idle_timeout ;
	wire tc_bit_violation;
	wire tc_cha_stuck    ;
	wire tc_chb_stuck    ;
	
	assign  tc_idle_timeout  = o_cnt_idle_timeout   === 32'hffff_ffff;
	assign  tc_bit_violation = o_cnt_bit_violation  === 32'hffff_ffff;
	assign  tc_cha_stuck     = o_cnt_cha_stuck      === 32'hffff_ffff;
	assign  tc_chb_stuck     = o_cnt_chb_stuck      === 32'hffff_ffff;


	initial begin
		o_cnt_idle_timeout  = 0;
		o_cnt_bit_violation = 0;
		o_cnt_cha_stuck     = 0;
		o_cnt_chb_stuck     = 0;
	end




	always @(posedge i_clk, negedge i_rstn) begin
		if( i_rstn) begin
			if( i_idle_timeout && !tc_idle_timeout) 
				o_cnt_idle_timeout <= o_cnt_idle_timeout + 1'b1;
		
			if( i_bit_violation && !tc_bit_violation) 
				o_cnt_bit_violation <= o_cnt_bit_violation + 1'b1;
				
			if( i_cha_stuck && !tc_cha_stuck) 
				o_cnt_cha_stuck <= o_cnt_cha_stuck + 1'b1;
				
			if( i_chb_stuck && !tc_chb_stuck) 
				o_cnt_chb_stuck <= o_cnt_chb_stuck + 1'b1;

		end 
		else begin
			o_cnt_idle_timeout  = 0;
			o_cnt_bit_violation = 0;
			o_cnt_cha_stuck     = 0;
			o_cnt_chb_stuck     = 0;
		
		end
		
	end


endmodule



module mon_posedge_cnt (
	input i_sig,
	input i_rst,
	
	output reg [31:0] o_cnt
);

	always @(posedge i_rst) begin
		o_cnt = 0;
	end
	
	always @(posedge i_sig) begin
		o_cnt = o_cnt + 1'b1;
	end

endmodule


	