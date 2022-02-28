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
	
	
	
	task test_idle_high;
		realtime start_time;
		begin
			$display("--- test_idle_high %t ---", $realtime);
	
			//do a start with no stop but release the bus
			i_sda = 1'b1;
			i_scl = 1'b1;
			repeat(2)@(posedge i_clk);
			i_sda = 1'b0;
			repeat(1)@(posedge i_clk);
			i_scl = 1'b0;
			repeat(1)@(posedge i_clk);
			i_sda = 1'b1;
			repeat(1)@(posedge i_clk);
			i_scl = 1'b1;
			repeat(1)@(posedge i_clk);



			
			//idle shouldn't rise immediately
				start_time = $realtime;
	
			while( time_elapsed( start_time) < NS_T_HI_MIN) begin
			
				#1;
				if(
					o_idle_timeout !== 1'b0 ||
					o_idle         !== 1'b0 ||
					o_stuck        !== 1'b0
				) begin
					$display("    fail 0 %t", $realtime);
					failed = 1;
				end
				@(posedge i_clk);
			end
			
			
			//wait for o_idle_timeout pulse
			while( !o_idle_timeout && (time_elapsed( start_time) < NS_T_HI_MAX) ) begin
				@(posedge i_clk) #1;
			end
			
			if( !o_idle_timeout  ) begin
				$display("    fail 1 %t", $realtime);
				failed = 1;
			end
			@(posedge i_clk);
			
			#1;
			//wait for o_idle to rise
			while( (!o_idle || o_stuck) && (time_elapsed( start_time) < NS_T_HI_MAX) ) begin
				@(posedge i_clk) #1;
			end
			
			if(
				o_idle_timeout !== 1'b0 ||
				o_idle         !== 1'b1 ||
				o_stuck        !== 1'b0
			) begin
				$display("    fail 2 %t", $realtime);
				failed = 1;
			end
			
			//make sure signals dont change
			start_time = $realtime;
			#1;
			while( time_elapsed( start_time) < NS_T_HI_MAX) begin
			
				#1;
				if(
					o_idle  !== 1'b1 ||
					o_stuck !== 1'b0
				) begin
					$display("    fail 3 %t", $realtime);
					failed = 1;
				end
				@(posedge i_clk);
			end
		end
	endtask
	
	
	
	task test_stop;
		realtime start_time;
		begin
			$display("--- test_stop %t ---", $realtime);
			
			//do a start with no stop but release the bus
			i_sda = 1'b1;
			i_scl = 1'b1;
			repeat(2)@(posedge i_clk);
			i_sda = 1'b0;
			repeat(1)@(posedge i_clk);
			i_scl = 1'b0;
			repeat(1)@(posedge i_clk);

			
			#1
			if(
				o_idle  !== 1'b0 //||
				//o_stuck !== 1'b0
			) begin
				$display("    fail 0 %t", $realtime);
				failed = 1;
			end
			
			i_sda = 1'b1;
			start_time = $realtime;

			//scl is low, bring sda high and make sure this isn't used as a stop condition
			while( time_elapsed( start_time) < NS_T_LOW_MAX) begin
				#1
				if(
					o_idle_timeout !== 1'b0 ||
					o_idle         !== 1'b0 ||
					o_stuck        !== 1'b0
				) begin
					$display("    fail 1 %t", $realtime);
					failed = 1;
				end
				@(posedge i_clk);
			end
			
			//now bring scl high and try a valid stop condition
			i_sda = 1'b0;
			@(posedge i_clk);
			i_scl = 1'b1;
			repeat(2)@(posedge i_clk);
			i_sda = 1'b1;
			@(posedge i_clk);
			
			start_time = $realtime;
			//wait for o_idle to go high
			while( (!o_idle || o_stuck) && ~o_idle_timeout && (time_elapsed( start_time) < NS_T_LOW_MAX) ) begin
				@(posedge i_clk) #1;
			end
			
			if(
				o_idle_timeout !== 1'b0 ||
				o_idle         !== 1'b1 ||
				o_stuck        !== 1'b0
			) begin
				$display("    fail 2 %t", $realtime);
				failed = 1;
			end

		end
	endtask
	
	
	
	task test_stuck_scllow;
		realtime start_time;
		begin
			$display("--- test_stuck_scllow %t ---", $realtime);
			rst_uut();
			i_sda = 1'b1;
			i_scl = 1'b0;
			@(posedge i_clk);
			
			//stuck should not rise before stuck min time
			start_time = $realtime;
			#1;
			while( time_elapsed( start_time) < NS_T_BUS_STUCK_MIN) begin
				#1
				if(
					//o_idle  !== 1'b0 ||
					o_stuck !== 1'b0 ||
					o_scl   !== 1'b1 ||
					o_sda   !== 1'b1
				) begin
					$display("    fail 0 %t", $realtime);
					failed = 1;
				end
				@(posedge i_clk);
			end
			
			//wait for stuck to go high
			while( !o_stuck && (time_elapsed( start_time) < NS_T_BUS_STUCK_MAX) ) begin
				#1;
				if(
					//o_idle  !== 1'b0 //||
					//o_stuck !== 1'b0
					o_scl   !== 1'b1 ||
					o_sda   !== 1'b1
				) begin
					$display("    fail 1 %t", $realtime);
					failed = 1;
				end
				@(posedge i_clk) ;
			end
			
			
			//make sure outputs dont change for 20us
			start_time = $realtime;
			while( time_elapsed( start_time) < 20_000) begin
				#1
				if(
					//o_idle  !== 1'b0 ||
					o_stuck !== 1'b1
				) begin
					$display("    fail 2 %t", $realtime);
					failed = 1;
				end
				@(posedge i_clk);
			end
			
			//make sure outputs done change and module is creating stop events at least every 20us
			start_time = $realtime;
			while( time_elapsed( start_time) < NS_T_BUS_STUCK_MIN) begin
				#1
				if(
					//o_idle  !== 1'b0 ||
					o_stuck !== 1'b1
				) begin
					$display("    fail 3 %t", $realtime);
					failed = 1;
				end
				
				if( time_elapsed(time_last_stop) > 20_000) begin
					$display("    fail 4 %t", $realtime);
					failed = 1;
				end
				
				@(posedge i_clk);
			end
			
			i_scl = 1'b1;
			i_sda = 1'b1;
			
			//wait for stuck to go low
			start_time = $realtime;
			while( o_stuck && (time_elapsed( start_time) < NS_T_BUS_STUCK_MAX) ) begin
				@(posedge i_clk) ;
			end
			
			//make sure stuck is low
			#1
			if(
				//o_idle  !== 1'b0 ||
				o_stuck !== 1'b0
			) begin
				$display("    fail 5 %t", $realtime);
				failed = 1;
			end
			@(posedge i_clk);
			
			
			//wait 20 us and make sure stop events stop
			#20_000;
			start_time = $realtime;
			while( time_elapsed( start_time) < 20_000) begin
			//while( time_elapsed( start_time) < NS_T_BUS_STUCK_MIN ) begin
				#1
				if(
					//o_idle  !== 1'b1 ||
					o_scl   !== 1'b1 ||
					o_sda   !== 1'b1 ||
					o_stuck !== 1'b0
				) begin
					$display("    fail 6 %t", $realtime);
					failed = 1;
				end
				
				if( time_elapsed(time_last_stop) < 5_000) begin
					$display("    fail 7 %t", $realtime);
					failed = 1;
				end
				
				@(posedge i_clk);
			end
			
		end
	endtask
	
	
	
	
	task test_stuck_sdalow;
		realtime start_time;
		begin
			$display("--- test_stuck_sdalow %t ---", $realtime);
			rst_uut();
			i_sda = 1'b0;
			i_scl = 1'b1;
			@(posedge i_clk);
			
			
			//wait for stuck to go high
			start_time = $realtime;
			while( !o_stuck && (time_elapsed( start_time) < NS_T_BUS_STUCK_MAX) ) begin
				#1;
				if(
					//o_idle  !== 1'b0 //||
					//o_stuck !== 1'b0
					o_scl   !== 1'b1 ||
					o_sda   !== 1'b1
				) begin
					$display("    fail 0 %t", $realtime);
					failed = 1;
				end
				@(posedge i_clk) ;
			end
			
			//make sure stuck is hi
			#1
			if(
				//o_idle  !== 1'b0 ||
				o_stuck !== 1'b1
			) begin
				$display("    fail 1 %t", $realtime);
				failed = 1;
			end
			@(posedge i_clk);
			
			
			////make sure outputs dont change for 20us
			//start_time = $realtime;
			//while( time_elapsed( start_time) < 20_000) begin
			//	#1
			//	if(
			//		//o_idle  !== 1'b0 ||
			//		o_stuck !== 1'b1
			//	) begin
			//		$display("    fail 2 %t", $realtime);
			//		failed = 1;
			//	end
			//	@(posedge i_clk);
			//end
			
			reset_scl_count = 1;
			#1;
			reset_scl_count = 0;
			//wait 500us, there should only be 16 clocks counted
			start_time = $realtime;
			while( time_elapsed( start_time) < 500_000) begin
				i_scl = o_scl;
				@(posedge i_clk);
			end
			
			#1
			if(
				o_idle  !== 1'b0 ||
				o_scl   !== 1'b1 ||
				o_sda   !== 1'b1 ||
				o_stuck !== 1'b1 ||
				scl_count > 32'h0000_0010 ||
				scl_count < 32'h0000_000C
				
			) begin
				$display("    fail 2 %t", $realtime);
				failed = 1;
			end
			i_scl = 1'b1;
			//there should now be long period with no o_scl or o_sda output

			start_time = $realtime;
			while( time_elapsed( start_time) < NS_T_BUS_STUCK_MIN) begin
			
				#1
				if(
					//o_idle  !== 1'b1 ||
					o_scl   !== 1'b1 ||
					o_sda   !== 1'b1 ||
					o_stuck !== 1'b1
				) begin
					$display("    fail 3 %t", $realtime);
					failed = 1;
				end

				@(posedge i_clk);
			end
			
			//wait for stop events to start again
			start_time = $realtime;
			while( (o_sda !== 1'b0) && (time_elapsed( start_time) < NS_TB_TIMEOUT) ) begin
				@(posedge i_clk) ;
			end
			if (time_elapsed( start_time) >= NS_TB_TIMEOUT) begin
					$display("    fail 4 %t", $realtime);
					failed = 1;
			end
			
			reset_scl_count = 1;
			#1;
			reset_scl_count = 0;
			//wait at least 2 scl counts and release the bus, module should then go back to idle
			start_time = $realtime;
			while( (scl_count <3) && (time_elapsed( start_time) < NS_TB_TIMEOUT) ) begin
				@(posedge i_clk) ;
			end
			if (time_elapsed( start_time) >= NS_TB_TIMEOUT) begin
					$display("    fail 5 %t", $realtime);
					failed = 1;
			end
			
			i_scl = 1'b1;
			i_sda = 1'b1;
			

			start_time = $realtime;
			while( (o_idle !== 1'b1) && (time_elapsed( start_time) < NS_T_HI_MAX) ) begin
				@(posedge i_clk) ;
			end
			if (time_elapsed( start_time) >= NS_TB_TIMEOUT) begin
					$display("    fail 6 %t", $realtime);
					failed = 1;
			end
			
			
			
			
		end
	endtask
	
	
	
	task test_stuck_sdalow_release_after_16;
		realtime start_time;
		begin
			$display("--- test_stuck_sdalow_release_after_16 %t ---", $realtime);
			rst_uut();
			i_sda = 1'b0;
			i_scl = 1'b1;
			@(posedge i_clk);
			
			
			//wait for stuck to go high
			start_time = $realtime;
			while( !o_stuck && (time_elapsed( start_time) < NS_T_BUS_STUCK_MAX) ) begin
				#1;
				if(
					//o_idle  !== 1'b0 //||
					//o_stuck !== 1'b0
					o_scl   !== 1'b1 ||
					o_sda   !== 1'b1
				) begin
					$display("    fail 0 %t", $realtime);
					failed = 1;
				end
				@(posedge i_clk) ;
			end
			
			//make sure stuck is hi
			#1
			if(
				//o_idle  !== 1'b0 ||
				o_stuck !== 1'b1
			) begin
				$display("    fail 1 %t", $realtime);
				failed = 1;
			end
			@(posedge i_clk);
			

			reset_scl_count = 1;
			#1;
			reset_scl_count = 0;
			//wait 500us, there should only be 16 clocks counted
			start_time = $realtime;
			while( time_elapsed( start_time) < 500_000) begin
				i_scl = o_scl;
				@(posedge i_clk);
			end
			
			#1
			if(
				o_idle  !== 1'b0 ||
				o_scl   !== 1'b1 ||
				o_sda   !== 1'b1 ||
				o_stuck !== 1'b1 ||
				scl_count > 32'h0000_0010 ||
				scl_count < 32'h0000_000C
				
			) begin
				$display("    fail 2 %t", $realtime);
				failed = 1;
			end
			i_scl = 1'b1;
			
			//there should now be long period with no o_scl or o_sda output
			//wait a little bit and release scl and sda
			#20_000;
			i_scl = 1'b1;
			i_sda = 1'b1;

			

			start_time = $realtime;
			while( (o_idle !== 1'b1) && (time_elapsed( start_time) < NS_T_HI_MAX) ) begin
				@(posedge i_clk) ;
			end
			if (time_elapsed( start_time) >= NS_TB_TIMEOUT) begin
					$display("    fail 6 %t", $realtime);
					failed = 1;
			end
			

			
		end
	endtask
	
	
	
	
	function realtime time_elapsed;
		input realtime start;
		begin
			time_elapsed = $realtime - start;
		end
	endfunction
	
	
endmodule




module mon_last_stop  (	
	input i_clk,
	input i_scl,
	input i_sda,
	
	output realtime time_last_stop
);

	reg setup_level_good;
	reg hold_level_good;
	reg in_stop;
	
	realtime setup_start_time ;
	realtime hold_start_time  ;
	
	
	always @(i_scl, i_sda) begin
		if( i_scl & ~i_sda) begin
			setup_level_good = 1;
			hold_level_good  = 0;

			setup_start_time = $realtime;
		end
		else if( i_scl & i_sda) begin
			
			if( setup_level_good && time_elapsed( setup_start_time) > 3000) begin
				hold_level_good  = 1;
				hold_start_time = $realtime;
			end
			else begin
				setup_level_good = 0;
				hold_level_good  = 0;

			end
		end
		else begin
			setup_level_good = 0;
			hold_level_good  = 0;
		end

	end
	
	
	always @(posedge i_clk) begin
		if( setup_level_good && hold_level_good && time_elapsed( hold_start_time) > 3000) begin
			in_stop <= 1'b1;
			if(!in_stop) time_last_stop <= $realtime;
			
		end
		else begin
			in_stop <= 1'b0;
			
		end
	end
	
	
		
	function realtime time_elapsed;
		input realtime start;
		begin
			time_elapsed = $realtime - start;
		end
	endfunction
	
endmodule



module mon_count_posedge (
	input i_rst,
	input i_signal,
	
	output reg [31:0] o_cnt
);

	always @(posedge i_rst) begin
		o_cnt = 0;
	end
	
	always @(posedge i_signal) begin
		o_cnt = o_cnt + 1'b1;
	end

endmodule
	
