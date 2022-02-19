`timescale 1ns/100ps


module tb();
	//parameters
	
	localparam NS_TB_TIMEOUT      = 1_000_000_000;
	localparam NS_T_BUS_STUCK_MAX =   200_000_000;
	localparam NS_T_BUS_STUCK_MIN =    25_000_000;
	
	localparam NS_T_HI_MAX      =  700000;
	localparam NS_T_HI_MIN      =   50000;
	localparam NS_T_LOW_MIN     = 4000;
	localparam NS_T_LOW_MAX     = 6000;


	
	//f_ref 4mhz
	//f_ref_slow 
	localparam F_REF_T_LOW                  = 20 ; // 5 us
	localparam F_REF_T_HI                   = 300 ; // ~75us
	localparam F_REF_SLOW_T_STUCK_MAX       = 127; // ~32ms
	localparam WIDTH_F_REF_T_LOW            = 5  ;
	localparam WIDTH_F_REF_T_HI             = 9  ;
	localparam WIDTH_F_REF_SLOW_T_STUCK_MAX = 7  ;
	

	reg f_ref_unsync;
	reg f_ref_slow_unsync;
	//realtime time_start_fall_scl;
	//realtime time_start_rise_scl;
	//realtime time_start_chng_sda;
	
	realtime time_last_stop;
	
	reg    reset_scl_count;
	wire [31:0] scl_count ;
	
	
	//uut inputs
	reg i_clk       ;
	reg i_rstn      ;
	reg i_f_ref     ;
	reg i_f_ref_slow;

	reg i_scl        ;
	reg i_sda        ;

	//uut outputs
	wire o_sda;
	wire o_scl;
	
	
	wire o_idle_timeout;
	wire o_idle  ;
	wire o_stuck ;
	
	
	always #40         i_clk         = ~i_clk;
	always #125        f_ref_unsync  = ~f_ref_unsync;      //125 -> 4mhz. 250ns
	always #125000 f_ref_slow_unsync = ~f_ref_slow_unsync; //125000 -> 4 khz. 250us
	
	always @(posedge i_clk) begin
		i_f_ref      <= f_ref_unsync;
		i_f_ref_slow <= f_ref_slow_unsync;
	end
	

	
	i2c_passthru_idle_stuck_recover #(
	
		.F_REF_T_LOW                 (F_REF_T_LOW                  ),
		.F_REF_T_HI                  (F_REF_T_HI                   ),
		.F_REF_SLOW_T_STUCK_MAX      (F_REF_SLOW_T_STUCK_MAX       ),
		.WIDTH_F_REF_T_LOW           (WIDTH_F_REF_T_LOW            ),
		.WIDTH_F_REF_T_HI            (WIDTH_F_REF_T_HI             ),
		.WIDTH_F_REF_SLOW_T_STUCK_MAX(WIDTH_F_REF_SLOW_T_STUCK_MAX )

	) uut (
		.i_clk          (i_clk         )  , 
		.i_rstn         (i_rstn        )  , 
		.i_f_ref        (i_f_ref       )  ,
		.i_f_ref_slow   (i_f_ref_slow  )  ,
		.i_sda          (i_sda         )  ,
		.i_scl          (i_scl         )  ,
		
		.o_sda          (o_sda         )  ,
		.o_scl          (o_scl         )  ,
		.o_idle_timeout (o_idle_timeout)  ,
		.o_idle         (o_idle        )  ,
		.o_stuck        (o_stuck       )
	);
	
	
	
	mon_last_stop u_mon_last_stop (
		.i_clk (i_clk),
		.i_scl (o_scl),
		.i_sda (o_sda),
		
		.time_last_stop(time_last_stop)
	);
	
	
	mon_count_posedge u_mon_count_posedge (
		.i_rst   ( reset_scl_count),
		.i_signal( i_scl          ),
		.o_cnt   ( scl_count      )
	
	);
		

	integer failed = 0;
	//integer subtest_failed ;
	initial begin
		$timeformat(-6,3, "us", 12);
		init_vars();
		rst_uut();
		
		test_idle_high();
		test_stop();
		test_stuck_scllow(); //still need to finish this test.  stuck high is good, but at end need to check o_scl and o_sda function
		test_stuck_sdalow();


	
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
				scl_count > 32'h0000_0010
				
			) begin
				$display("    fail 2 %t", $realtime);
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
	
