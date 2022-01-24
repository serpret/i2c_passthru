`timescale 1ns/100ps


module tb();
	//parameters
	localparam NS_TB_TIMEOUT    = 100000;
	localparam NS_T_LOW_MIN     = 4000;
	localparam NS_T_LOW_MAX     = 6000;
	localparam NS_T_SU_DAT_MIN  =  250;
	localparam NS_T_SU_DAT_MAX  = 6000;

	
	localparam F_REF_T_R      = 7 ; //assume f_ref 4mhz
	localparam F_REF_T_SU_DAT = 2 ;
	localparam F_REF_T_LOW    = 20;
	localparam WIDTH_F_REF_T_R          = 3 ;
	localparam WIDTH_F_REF_T_SU_DAT     = 2 ;
	localparam WIDTH_F_REF_T_LOW        = 5 ;


	reg f_ref_unsync;
	realtime time_start_fall_scl;
	realtime time_start_rise_scl;
	realtime time_start_chng_sda;
	
	
	
	//uut intputs
	reg i_clk     ;
	reg i_rstn    ;
	reg i_f_ref   ;
	
	reg i_start_tx         ;
	reg i_tx_is_to_mst     ;
	reg i_rx_sda_init_valid;
	reg i_rx_sda_init      ;
	reg i_rx_sda_mid_change;
	reg i_rx_sda_final     ;
	reg i_rx_done          ;
	reg i_scl              ;
	reg i_sda              ;
   
	//uut outputs
	wire o_scl        ;      
	wire o_sda        ;      
	wire o_tx_done    ;      
	wire o_violation  ;   

	
	always #10 i_clk = ~i_clk;
	always #125 f_ref_unsync = ~f_ref_unsync;
	
	always @(posedge i_clk) begin
		i_f_ref <= f_ref_unsync;
	end
	

	

	i2c_passthru_bittx #(
	
	
		.F_REF_T_R           (F_REF_T_R           ),
		.F_REF_T_SU_DAT      (F_REF_T_SU_DAT      ),
		.F_REF_T_LOW         (F_REF_T_LOW         ),
		.WIDTH_F_REF_T_R     (WIDTH_F_REF_T_R     ),
		.WIDTH_F_REF_T_SU_DAT(WIDTH_F_REF_T_SU_DAT),
		.WIDTH_F_REF_T_LOW   (WIDTH_F_REF_T_LOW   )
	
	
	)  uut
	(
		.i_clk (i_clk ), 
		.i_rstn(i_rstn), 
		.i_f_ref            (i_f_ref            ),
		.i_start_tx         (i_start_tx         ),
		.i_tx_is_to_mst     (i_tx_is_to_mst     ),
		.i_rx_sda_init_valid(i_rx_sda_init_valid),
		.i_rx_sda_init      (i_rx_sda_init      ),
		.i_rx_sda_mid_change(i_rx_sda_mid_change),
		.i_rx_sda_final     (i_rx_sda_final     ),
		.i_rx_done          (i_rx_done          ),
		.i_scl              (i_scl              ),
		.i_sda              (i_sda              ),
		.o_scl              (o_scl              ),
		.o_sda              (o_sda              ),
		.o_tx_done          (o_tx_done          ),
		.o_violation        (o_violation        )
		
	
	);
	
	always @(negedge i_scl) begin
		time_start_fall_scl = $realtime;
	end
	
	always @(posedge i_scl) begin
		time_start_rise_scl = $realtime;
	end
	
	always @(i_sda) begin
		time_start_chng_sda = $realtime;
	end

	

	integer failed = 0;
	//integer subtest_failed ;
	initial begin
		$timeformat(-6,3, "us", 12);
		init_vars();
		rst_uut();

		test_tx_to_mst1();
		test_tx_to_mst2();
		test_tx_to_mst3();
		test_tx_to_mst4();
		#1_000;
		reinit_start_times();
		rst_uut();
		test_tx_to_slv1();
		test_tx_to_slv2();
		test_tx_to_slv3();
		
	
		if( failed) $display(" ! ! !  TEST FAILED ! ! !");
		else        $display(" Test Passed ");
		$stop();

	
	end
	
	task reinit_start_times;
		begin
			time_start_fall_scl = $realtime;
			time_start_rise_scl = $realtime;
			time_start_chng_sda = $realtime;
		
		end
	endtask


	task init_vars;
		begin
			i_clk = 0;
			i_rstn = 0;
			f_ref_unsync  =0;
			
			time_start_fall_scl = 0;
			time_start_rise_scl = 0;
			time_start_chng_sda = 0;
			
			i_start_tx          = 0;
			i_tx_is_to_mst      = 0;
			i_rx_sda_init_valid = 0;
			i_rx_sda_init       = 0;
			i_rx_sda_mid_change = 0;
			i_rx_sda_final      = 0;
			i_rx_done           = 0;
			i_scl               = 0;
			i_sda               = 0;
			      
			
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
	
	
	//rx_done very early, go through full bit transaction
	task test_tx_to_mst1;
		begin
			//subtest_failed = 0;
			$display("--- test_tx_to_mst1 ---");
			
			i_start_tx = 1;
			i_tx_is_to_mst = 1;
			repeat(1) @(posedge i_clk);
			i_start_tx = 0;
			i_rx_sda_init_valid = 1;
			i_rx_sda_init  = 1;
			i_rx_sda_final = 1;
			i_rx_done = 1;
			i_scl = 0;
			i_sda = 0;
			
			#1;
			if (
				o_scl       !== 0 ||
				//o_sda       !== 1 ||
				o_tx_done   !== 0  ||
				o_violation !== 0
			) begin
				$display("    fail 0 %t", $realtime);
				failed = 1;
			end
			
			repeat(1) @(posedge i_clk);
			#1;
			if (
				o_scl       !== 0 ||
				o_sda       !== 1 ||
				o_tx_done   !== 0 ||
				o_violation !== 0
			) begin
				$display("    fail 1 %t", $realtime);
				failed = 1;
			end
			
			i_scl = 0;
			i_sda = 1;
			
			//check o_scl does not rise before N_T_LOW_MIN
			while( time_elapsed( time_start_fall_scl) < NS_T_LOW_MIN) begin
				if (
					o_scl       !== 0 ||
					o_sda       !== 1 ||
					o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 2 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			//wait for o_scl to rise by NS_T_LOW_MAX
			while( o_scl !== 1 && (time_elapsed( time_start_fall_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			
			if (
				o_scl       !== 1 ||
				o_sda       !== 1 ||
				o_tx_done   !== 0 ||
				o_violation !== 0
			) begin
				$display("    fail 3 %t", $realtime);
				failed = 1;
			end
			
			i_scl = 1;
			i_sda = 1;
			#1;
			
			//check outputs dont change until i_scl falls
			while( time_elapsed( time_start_rise_scl) < NS_T_LOW_MIN) begin
				if (
					o_scl       !== 1 ||
					o_sda       !== 1 ||
					o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 4 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			i_scl = 0;

			//o o_scl should be locked low, after that changes in i_scl should have no effect.
			repeat(4) begin
				@(posedge i_clk);
				#1;
				if (
					o_scl       !== 0 ||
					//o_sda       !== 1 ||
					//o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 5 %t", $realtime);
					$display("    o_scl %b", o_scl);
					$display("    o_violation %b", o_violation);
					failed = 1;
				end
				i_scl = ~i_scl;

			end
			
			
			
			@(posedge i_clk);
			#1;
			if (
				o_scl       !== 0 ||
				//o_sda       !== 1 ||
				o_tx_done   !== 1 ||
				o_violation !== 0
			) begin
				$display("    fail 6 %t", $realtime);
				failed = 1;
			end
		
		end
	endtask
	
	//rx_done and rx_sda_init_valid done later.  check sda follows sda_init at beginning.
	task test_tx_to_mst2;
		begin
			//subtest_failed = 0;
			$display("--- test_tx_to_mst2 ---");
			
			i_start_tx = 1;
			i_tx_is_to_mst = 1;
			
			i_rx_sda_init_valid = 0;
			i_rx_sda_init  = 0;
			i_rx_sda_final = 0;
			i_rx_done = 0;
			i_scl = 0;
			i_sda = 1;
			repeat(1) @(posedge i_clk);
			i_start_tx = 0;
			repeat(1) @(posedge i_clk);
			#1;
			
			//o_scl should stay low while i_rx_sda_init_valid low.  
			//o_sda should follow i_rx_sda_init
			while(  (time_elapsed( time_start_fall_scl) < NS_T_LOW_MAX) ) begin
				
				#1;
				if (
					o_scl       !== 0             ||
					o_sda       !== i_rx_sda_init ||
					o_tx_done   !== 0             ||
					o_violation !== 0
				) begin
					$display("    fail 0 %t", $realtime);
					failed = 1;
				end
				
				repeat(10) @(posedge i_clk);
				i_sda = i_rx_sda_init;
				repeat(1) @(posedge i_clk);
				i_rx_sda_init = ~i_rx_sda_init;
				repeat(1) @(posedge i_clk);
				
			end
			
			i_rx_sda_init = 0;
			i_sda         = 0;
			repeat(1) @(posedge i_clk);
			
			i_rx_sda_init_valid = 1;
			#1;
			//scl should not rise until T_SU_DAT
			while( (time_elapsed( time_start_chng_sda) < NS_T_SU_DAT_MIN) ) begin
				if (
					o_scl       !== 0             ||
					o_sda       !== i_rx_sda_init ||
					o_tx_done   !== 0             ||
					o_violation !== 0
				) begin
					$display("    fail 1 %t", $realtime);
					failed = 1;
				end
				
				#100;
			end
			
			
			//wait for o_scl to rise by NS_T_SU_DAT_MAX
			while( o_scl !== 1 && (time_elapsed( time_start_chng_sda) < NS_T_SU_DAT_MAX) ) begin
				#100;
			end
			
			if (
				o_scl       !== 1             ||
				o_sda       !== i_rx_sda_init ||
				o_tx_done   !== 0             ||
				o_violation !== 0
			) begin
				$display("    fail 2 %t", $realtime);
				failed = 1;
			end
			
			//test violation by making sda change in middle while scl is high
			i_scl = 1;
			repeat(1) @(posedge i_clk);
			i_sda = 1;
			repeat(2) @(posedge i_clk);
			#1;
			if (
				//o_scl       !== 1             ||
				//o_sda       !== i_rx_sda_init ||
				//o_tx_done   !== 0             ||
				o_violation !== 1
			) begin
				$display("    fail 3 %t", $realtime);
				failed = 1;
			end
			
			i_rstn = 0;
			repeat(1) @(posedge i_clk);
			i_rstn = 1;
			repeat(1) @(posedge i_clk);

		end
	endtask
			
			
	//i_rx_init_valid not right away, but t_su_dat is satisifed from slave side
	//and o_scl rises immediately.
	//keep i_scl low long time to test mst clock stretch
	task test_tx_to_mst3;
		begin
			//subtest_failed = 0;
			$display("--- test_tx_to_mst3 ---");
			
			
			i_start_tx = 1;
			i_tx_is_to_mst = 1;
			
			i_rx_sda_init_valid = 0;
			i_rx_sda_init  = 0;
			i_rx_sda_final = 0;
			i_rx_done = 0;
			i_scl = 0;
			i_sda = 0;
			repeat(1) @(posedge i_clk);
			i_start_tx = 0;
			repeat(1) @(posedge i_clk);
			#1;
			
			
			
			//just wait till timing is satisifed
			while(  (time_elapsed( time_start_fall_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			
			//bring i_rx_sda_init_valid high, o_scl should rise following clock, but keep i_scl low to test clock stretch
			i_rx_sda_init_valid = 1;
			repeat(1) @(posedge i_clk);
			
			#1;
			while( (time_elapsed( time_start_fall_scl) < NS_TB_TIMEOUT) ) begin
				if (
					o_scl       !== 1             ||
					o_sda       !== i_rx_sda_init ||
					o_tx_done   !== 0             ||
					o_violation !== 0
				) begin
					$display("    fail 0 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			
			
			
			i_scl = 1;
			i_sda = 0;
			#1;
			
			//check outputs dont change until i_scl falls
			while( time_elapsed( time_start_rise_scl) < NS_T_LOW_MIN) begin
				if (
					o_scl       !== 1 ||
					o_sda       !== 0 ||
					o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 1 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			i_scl = 0;


			@(posedge i_clk);
			#1;
			if (
				o_scl       !== 0 ||
				//o_sda       !== 1 ||
				//o_tx_done   !== 0 ||
				o_violation !== 0
			) begin
				$display("    fail 2 %t", $realtime);
				failed = 1;
			end
				

			@(posedge i_clk);
			#1;
			if (
				o_scl       !== 0 ||
				//o_sda       !== 1 ||
				o_tx_done   !== 1 ||
				o_violation !== 0
			) begin
				$display("    fail 3 %t", $realtime);
				failed = 1;
			end
			

			
		end

	endtask
	
	
	//test mst holds sda low and scl rises.
	task test_tx_to_mst4;
		begin
			//subtest_failed = 0;
			$display("--- test_tx_to_mst4 ---");
			
			
			i_start_tx = 1;
			i_tx_is_to_mst = 1;
			
			i_rx_sda_init_valid = 0;
			i_rx_sda_init  = 1;
			i_rx_sda_final = 0;
			i_rx_done = 0;
			i_scl = 0;
			i_sda = 0;
			repeat(1) @(posedge i_clk);
			i_start_tx = 0;
			repeat(1) @(posedge i_clk);
			i_rx_sda_init_valid = 1;
			
			
			
			//wait for o_scl to rise by NS_T_LOW_MAX
			while( o_scl !== 1 && (time_elapsed( time_start_fall_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			
			
			#1;
			if (
				o_scl       !== 0 ||
				//o_sda       !== 1 ||
				o_tx_done   !== 0 ||
				o_violation !== 0
			) begin
				$display("    fail 0 %t", $realtime);
				failed = 1;
			end
			
			
		end
	endtask
	
	
	task test_tx_to_slv1;
		begin
		
		//subtest_failed = 0;
			$display("--- test_tx_to_slv1 ---");
			
			i_start_tx = 1;
			i_tx_is_to_mst = 0;
			repeat(1) @(posedge i_clk);
			i_start_tx = 0;
			i_rx_sda_init_valid = 1;
			i_rx_sda_mid_change = 0;
			i_rx_sda_init  = 1;
			i_rx_sda_final = 1;
			i_rx_done = 1;
			i_scl = 0;
			i_sda = 0;
			
			#1;
			if (
				o_scl       !== 0 ||
				//o_sda       !== 1 ||
				o_tx_done   !== 0  ||
				o_violation !== 0
			) begin
				$display("    fail 0 %t", $realtime);
				failed = 1;
			end
			
			repeat(1) @(posedge i_clk);
			#1;
			if (
				o_scl       !== 0 ||
				o_sda       !== 1 ||
				o_tx_done   !== 0 ||
				o_violation !== 0
			) begin
				$display("    fail 1 %t", $realtime);
				failed = 1;
			end
			
			i_scl = 0;
			i_sda = 1;
			
			//check o_scl does not rise before N_T_LOW_MIN
			while( time_elapsed( time_start_fall_scl) < NS_T_LOW_MIN) begin
				if (
					o_scl       !== 0 ||
					o_sda       !== 1 ||
					o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 2 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			//wait for o_scl to rise by NS_T_LOW_MAX
			while( o_scl !== 1 && (time_elapsed( time_start_fall_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			
			if (
				o_scl       !== 1 ||
				o_sda       !== 1 ||
				o_tx_done   !== 0 ||
				o_violation !== 0
			) begin
				$display("    fail 3 %t", $realtime);
				failed = 1;
			end
			
			i_scl = 1;
			i_sda = 1;
			#1;
			
			//check outputs dont change until i_scl falls
			while( time_elapsed( time_start_rise_scl) < NS_T_LOW_MIN) begin
				if (
					o_scl       !== 1 ||
					o_sda       !== 1 ||
					o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 4 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			
			//wait for o_scl to fall by NS_T_LOW_MAX
			while( o_scl !== 0 && (time_elapsed( time_start_rise_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			//i_scl = 0;

			//o o_scl should be locked low, after that changes in i_scl should have no effect.
			repeat(4) begin
				@(posedge i_clk);
				#1;
				if (
					o_scl       !== 0 ||
					//o_sda       !== 1 ||
					//o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 5 %t", $realtime);
					$display("    o_scl %b", o_scl);
					$display("    o_violation %b", o_violation);
					failed = 1;
				end
				i_scl = ~i_scl;

			end
			
			
			
			@(posedge i_clk);
			#1;
			if (
				o_scl       !== 0 ||
				//o_sda       !== 1 ||
				o_tx_done   !== 1 ||
				o_violation !== 0
			) begin
				$display("    fail 6 %t", $realtime);
				failed = 1;
			end
		

		
		end
	endtask
	
	
	
	task test_tx_to_slv2;
		begin
		
		//subtest_failed = 0;
			$display("--- test_tx_to_slv2 ---");
			
			//i_start_tx = 1;
			//i_tx_is_to_mst = 0;
			//repeat(1) @(posedge i_clk);
			//i_start_tx = 0;
			//i_rx_sda_init_valid = 1;
			//i_rx_sda_mid_change = 0;
			//i_rx_sda_init  = 1;
			//i_rx_sda_final = 1;
			//i_rx_done = 1;
			//i_scl = 0;
			//i_sda = 0;
			
			set_state_tx_to_slv_sdainit(1);
			i_rx_sda_mid_change = 1;
			i_rx_sda_final = 0;
			i_rx_done = 1;
			
			
			//check o_sda does not change before t_low
			while( time_elapsed( time_start_rise_scl) < NS_T_LOW_MIN) begin
				if (
					o_scl       !== 1 ||
					o_sda       !== 1 ||
					o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 0 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			
			//wait for o_sda to change
			while( o_sda !== 0 && (time_elapsed( time_start_rise_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			i_sda = 0;
			#1;
			
			
			//check o_sda does not change before t_low
			while( time_elapsed( time_start_chng_sda ) < NS_T_LOW_MIN) begin
				if (
					o_scl       !== 1 ||
					o_sda       !== 0 ||
					o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 1 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			
			//wait for o_scl to change
			while( o_scl !== 0 && (time_elapsed( time_start_chng_sda) < NS_T_LOW_MAX) ) begin
				#100;
			end
			i_scl = 0;

			#1;
			if (
				o_scl       !== 0 ||
				o_sda       !== 0 ||
				//o_tx_done   !== 0 ||
				o_violation !== 0
			) begin
				$display("    fail 2 %t", $realtime);
				failed = 1;
			end
			repeat(1) @(posedge i_clk);
			
			#1;
			if (
				o_scl       !== 0 ||
				o_sda       !== 0 ||
				o_tx_done   !== 1 ||
				o_violation !== 0
			) begin
				$display("    fail 3 %t", $realtime);
				failed = 1;
			end
			
			#1;
		end
	endtask
	
	
	task test_tx_to_slv3;
		begin
		
		//subtest_failed = 0;
			$display("--- test_tx_to_slv3 ---");
			
			//i_start_tx = 1;
			//i_tx_is_to_mst = 0;
			//repeat(1) @(posedge i_clk);
			//i_start_tx = 0;
			//i_rx_sda_init_valid = 1;
			//i_rx_sda_mid_change = 0;
			//i_rx_sda_init  = 1;
			//i_rx_sda_final = 1;
			//i_rx_done = 1;
			//i_scl = 0;
			//i_sda = 0;
			
			set_state_tx_to_slv_sdamid(1);
			i_rx_sda_final = 1;
			i_rx_done = 1;
			
			#1;
			//check o_sda does not change before t_low
			while( time_elapsed( time_start_chng_sda) < NS_T_LOW_MIN) begin
				if (
					o_scl       !== 1 ||
					o_sda       !== 0 ||
					o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 0 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			
			//wait for o_sda to change
			while( o_sda !== 1 && (time_elapsed( time_start_chng_sda) < NS_T_LOW_MAX) ) begin
				#100;
			end
			i_sda = 1;
			#1;
			
			
			//check o_scl does not change before t_low
			while( time_elapsed( time_start_chng_sda ) < NS_T_LOW_MIN) begin
				if (
					o_scl       !== 1 ||
					o_sda       !== 1 ||
					o_tx_done   !== 0 ||
					o_violation !== 0
				) begin
					$display("    fail 1 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			
			//wait for o_scl to change
			while( o_scl !== 0 && (time_elapsed( time_start_chng_sda) < NS_T_LOW_MAX) ) begin
				#100;
			end
			i_scl = 0;

			#1;
			if (
				o_scl       !== 0 ||
				o_sda       !== 1 ||
				//o_tx_done   !== 0 ||
				o_violation !== 0
			) begin
				$display("    fail 2 %t", $realtime);
				failed = 1;
			end
			repeat(1) @(posedge i_clk);
			
			#1;
			if (
				o_scl       !== 0 ||
				o_sda       !== 1 ||
				o_tx_done   !== 1 ||
				o_violation !== 0
			) begin
				$display("    fail 3 %t", $realtime);
				failed = 1;
			end
			
			#1;
		end
	endtask
	
	
	task set_state_tx_to_slv_sdainit;
		input sda_init;
		begin
			rst_uut();
			i_start_tx = 1;
			i_tx_is_to_mst = 0;
			
			i_rx_sda_init_valid = 1;
			i_rx_sda_init  = sda_init;
			i_rx_sda_mid_change = 0;
			i_rx_sda_final = 0;
			i_rx_done = 0;
			i_scl = 0;
			i_sda = 0;
			repeat(1) @(posedge i_clk);
			i_start_tx = 0;
			repeat(1) @(posedge i_clk);
			
			
		
			i_sda = i_rx_sda_init;
			
			//wait for o_scl to rise by NS_T_LOW_MAX
			while( o_scl !== 1 && (time_elapsed( time_start_fall_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			
			
			
			#1;
			if (
				o_scl       !== 1             ||
				o_sda       !== i_rx_sda_init ||
				o_tx_done   !== 0             ||
				o_violation !== 0
			) begin
				$display("    set_state_tx_to_slv_sdainit fail 0  %t", $realtime);
				failed = 1;
			end
			
			i_scl = 1;
			repeat(1) @(posedge i_clk);
			
		
		end
	endtask
	
	
	
	task set_state_tx_to_slv_sdamid;
		input sda_init;
	
		begin
			set_state_tx_to_slv_sdainit(sda_init);
			i_rx_sda_mid_change = 1;
			
			//wait for o_sda to do mid change by NS_T_LOW_MAX
			while( o_sda === sda_init && (time_elapsed( time_start_rise_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			
			
						#1;
			if (
				o_scl       !== 1             ||
				o_sda       === sda_init      ||
				o_tx_done   !== 0             ||
				o_violation !== 0
			) begin
				$display("    set_state_tx_to_slv_sdamid fail 0  %t", $realtime);
				failed = 1;
			end
			i_sda = ~sda_init;
			#1;
			
		
		end
	endtask
			
	
	
	function realtime time_elapsed;
		input realtime start;
		begin
			time_elapsed = $realtime - start;
		end
	endfunction
	
	
	

		




endmodule