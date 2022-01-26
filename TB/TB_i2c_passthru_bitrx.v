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

	reg i_start_rx   ;
	reg i_rx_frm_slv ;
	reg i_tx_done    ;
	reg i_scl        ;
	reg i_sda        ;

	//uut outputs
	wire o_rx_sda_init_valid ;
	wire o_rx_sda_init       ;
	wire o_rx_sda_mid_change ;
	wire o_rx_sda_final      ;

	wire o_scl               ;
	wire o_sda               ;
	wire o_rx_done           ;
	wire o_violation         ;
	
	
	always #10 i_clk = ~i_clk;
	always #125 f_ref_unsync = ~f_ref_unsync;
	
	always @(posedge i_clk) begin
		i_f_ref <= f_ref_unsync;
	end
	

	

	i2c_passthru_bitrx #(
	
		.F_REF_T_LOW         (F_REF_T_LOW         ),
		.WIDTH_F_REF_T_LOW   (WIDTH_F_REF_T_LOW   )

	)  uut
	(
		.i_clk (i_clk ), 
		.i_rstn(i_rstn), 
		.i_f_ref            (i_f_ref            ),
		
		.i_start_rx         (i_start_rx   )      ,
		.i_rx_frm_slv       (i_rx_frm_slv )      ,
		.i_tx_done          (i_tx_done    )      ,
		.i_scl              (i_scl        )      ,
		.i_sda              (i_sda        )      ,
		
		.o_rx_sda_init_valid(o_rx_sda_init_valid),  //output reg 
		.o_rx_sda_init      (o_rx_sda_init      ),  //output reg 
		.o_rx_sda_mid_change(o_rx_sda_mid_change),  //output reg 
		.o_rx_sda_final     (o_rx_sda_final     ),  //output reg 
		.o_scl              (o_scl              ),  //output reg 
		.o_sda              (o_sda              ),  //output reg 
		.o_rx_done          (o_rx_done          ),  //output reg 
		.o_violation        (o_violation        )   //output reg 
		
	
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


		test_rx_frm_slv1();
		test_rx_frm_slv2();


	
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
			
			i_start_rx   = 0;
			i_rx_frm_slv = 0;
			i_tx_done    = 0;
			i_scl        = 0;
			i_sda        = 0;
			
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
	
	
	//slv rx
	task test_rx_frm_slv1;
		begin
			$display("--- test_rx_frm_slv1 %t ---", $realtime);
			set_state_rx_frm_slv_sdainit( 0);
			
			
			#1;
			//make sure values stay stable entire time scl is high
			while( time_elapsed( time_start_rise_scl) < NS_T_LOW_MIN) begin

				if (
					o_rx_sda_init_valid !== 1 ||
					o_rx_sda_init       !== 0 ||
					o_rx_sda_mid_change !== 0 ||
					//o_rx_sda_final      !==  ||
	
					o_scl       !== 1  ||
					o_sda       !== 1  ||
					o_rx_done   !== 0  ||
					o_violation !== 0  
	
				) begin
					$display("    fail 0 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			//wait for o_scl to fall
			while( o_scl !== 0 && (time_elapsed( time_start_rise_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			
			//check multiple times that values are good. 
			repeat( 4) begin
				if (
					o_rx_sda_init_valid !== 1 ||
					o_rx_sda_init       !== 0 ||
					o_rx_sda_mid_change !== 0 ||
					//o_rx_sda_final      !==  ||
		
					o_scl       !== 0  ||
					o_sda       !== 1  ||
					o_rx_done   !== 1  ||
					o_violation !== 0  
				) begin
					$display("    fail 1 %t", $realtime);
					failed = 1;
				end
				i_scl = 0;
				
				repeat(1) @(posedge i_clk);
			end
			
			//set i_tx_done to finish
			i_tx_done = 1;
			repeat(1) @(posedge i_clk)
			
			#1;
			if (
				o_rx_sda_init_valid !== 0 ||
				//o_rx_sda_init       !== 0 ||
				o_rx_sda_mid_change !== 0 ||
				//o_rx_sda_final      !==  ||
			
				o_scl       !== 0  ||
				o_sda       !== 1  ||
				o_rx_done   !== 1  ||
				o_violation !== 0  
			) begin
				$display("    fail 2 %t", $realtime);
				failed = 1;
			end


		end
	endtask
	
	
	//slv rx test sda violation
	task test_rx_frm_slv2;
		begin
			$display("--- test_rx_frm_slv2 %t ---", $realtime);
			set_state_rx_frm_slv_sdainit( 1);
			i_sda = 0;
			repeat(1) @(posedge i_clk);
			
			#1;
			if (
				//o_rx_sda_init_valid !== 0 ||
				//o_rx_sda_init       !== 0 ||
				//o_rx_sda_mid_change !== 0 ||
				//o_rx_sda_final      !==  ||
			
				//o_scl       !== 0  ||
				//o_sda       !== 1  ||
				//o_rx_done   !== 1  ||
				o_violation !== 1  
			) begin
				$display("    fail 0 %t", $realtime);
				failed = 1;
			end
		end
	endtask
	
	
	
	
	task set_state_rx_frm_slv_sdainit;
		input sda_init;
		begin
			//$display("--- set_state_rx_frm_slv_sdainit %t ---", $realtime);
			//rst_uut();
			set_state_idle_low();
			i_start_rx   = 1;
			i_rx_frm_slv = 1;
			i_tx_done    = 1;
			i_scl        = 0;
			i_sda        = sda_init;
			repeat(1) @(posedge i_clk);
			i_start_rx   = 0;
			i_rx_frm_slv = 0;
			
			i_tx_done    = 0;
			
			//check values before T_LOW minimum
			#1;
			while( time_elapsed( time_start_fall_scl) < NS_T_LOW_MIN) begin

				if (
					o_rx_sda_init_valid !== 0 ||
					//o_rx_sda_init       !==  ||
					o_rx_sda_mid_change !== 0 ||
					//o_rx_sda_final      !==  ||
	
					o_scl       !== 0  ||
					o_sda       !== 1  ||
					o_rx_done   !== 0  ||
					o_violation !== 0  
	
				) begin
					$display("    set_state_rx_frm_slv_sdainit fail 0 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			
			//wait for o_scl to rise by NS_T_LOW_MAX
			while( o_scl !== 1 && (time_elapsed( time_start_fall_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			
			if (
				o_rx_sda_init_valid !== 0 ||
				//o_rx_sda_init       !== 0 ||
				o_rx_sda_mid_change !== 0 ||
				//o_rx_sda_final      !==  ||
	
				o_scl       !== 1  ||
				o_sda       !== 1  ||
				o_rx_done   !== 0  ||
				o_violation !== 0  
			) begin
				$display("    set_state_rx_frm_slv_sdainit fail 1 %t", $realtime);
				failed = 1;
			end
			
			i_scl = 1;
			repeat(1) @(posedge i_clk)
			#1;
			if (
				o_rx_sda_init_valid !== 1        ||
				o_rx_sda_init       !== sda_init ||
				o_rx_sda_mid_change !== 0        ||
				//o_rx_sda_final      !==  ||
	
				o_scl       !== 1  ||
				o_sda       !== 1  ||
				o_rx_done   !== 0  ||
				o_violation !== 0  
			) begin
				$display("    set_state_rx_frm_slv_sdainit fail 2 %t", $realtime);
				failed = 1;
			end
			

		end
	endtask
	
	
	
	task set_state_rx_frm_mst_sdainit;
		input sda_init;
		begin
			//$display("--- set_state_rx_frm_mst_sdainit %t ---", $realtime);
			//rst_uut();
			set_state_idle_low();
			i_start_rx   = 1;
			i_rx_frm_slv = 0;
			i_tx_done    = 1;
			i_scl        = 0;
			i_sda        = sda_init;
			repeat(1) @(posedge i_clk);
			i_start_rx   = 0;
			i_rx_frm_slv = 0;
			
			i_tx_done    = 0;
			
			//check values before T_LOW minimum
			#1;
			while( time_elapsed( time_start_fall_scl) < NS_T_LOW_MIN) begin

				if (
					o_rx_sda_init_valid !== 0 ||
					//o_rx_sda_init       !==  ||
					o_rx_sda_mid_change !== 0 ||
					//o_rx_sda_final      !==  ||
	
					o_scl       !== 0  ||
					o_sda       !== 1  ||
					o_rx_done   !== 0  ||
					o_violation !== 0  
	
				) begin
					$display("    set_state_rx_frm_mst_sdainit fail 0 %t", $realtime);
					failed = 1;
				end
				#100;
			end
			
			
			//wait for o_scl to rise by NS_T_LOW_MAX
			while( o_scl !== 1 && (time_elapsed( time_start_fall_scl) < NS_T_LOW_MAX) ) begin
				#100;
			end
			
			if (
				o_rx_sda_init_valid !== 0 ||
				//o_rx_sda_init       !== 0 ||
				o_rx_sda_mid_change !== 0 ||
				//o_rx_sda_final      !==  ||
	
				o_scl       !== 1  ||
				o_sda       !== 1  ||
				o_rx_done   !== 0  ||
				o_violation !== 0  
			) begin
				$display("    set_state_rx_frm_mst_sdainit fail 1 %t", $realtime);
				failed = 1;
			end
			
			i_scl = 1;
			repeat(1) @(posedge i_clk)
			#1;
			if (
				o_rx_sda_init_valid !== 1        ||
				o_rx_sda_init       !== sda_init ||
				o_rx_sda_mid_change !== 0        ||
				//o_rx_sda_final      !==  ||
	
				o_scl       !== 1  ||
				o_sda       !== 1  ||
				o_rx_done   !== 0  ||
				o_violation !== 0  
			) begin
				$display("    set_state_rx_frm_mst_sdainit fail 2 %t", $realtime);
				failed = 1;
			end
			

		end
	endtask
	
	
	
	
	task set_state_idle_low;
		begin

			i_start_rx   = 0;
			i_rx_frm_slv = 0;
			i_tx_done    = 0;
			i_scl        = 1;
			i_sda        = 1;
			
			
			
			rst_uut();
			repeat(1)@(posedge i_clk)
			
			#1;
			if (
				o_rx_sda_init_valid !== 1        ||
				o_rx_sda_init       !== 1        ||
				//o_rx_sda_mid_change !== 0        ||
				//o_rx_sda_final      !==  ||
	
				o_scl       !== 1  ||
				o_sda       !== 1  ||
				o_rx_done   !== 0  ||
				o_violation !== 0  
			) begin
				$display("    set_state_idle_low fail 0 %t", $realtime);
				failed = 1;
			end
			
			i_scl = 1;
			i_sda = 0;
			repeat(1)@(posedge i_clk);
			
			#1;
			
			if (
				o_rx_sda_init_valid !== 1        ||
				o_rx_sda_init       !== 1        ||
				o_rx_sda_mid_change !== 1        ||
				//o_rx_sda_final      !==  ||
	
				o_scl       !== 1  ||
				o_sda       !== 1  ||
				o_rx_done   !== 0  ||
				o_violation !== 0  
			) begin
				$display("    set_state_idle_low fail 1 %t", $realtime);
				failed = 1;
			end
			
			i_scl = 0;
			i_sda = 0;
			
			repeat(1)@(posedge i_clk);
			
			#1;
			if (
				o_rx_sda_init_valid !== 1        ||
				o_rx_sda_init       !== 1        ||
				o_rx_sda_mid_change !== 1        ||
				//o_rx_sda_final      !==  ||
	
				o_scl       !== 0  ||
				o_sda       !== 1  ||
				o_rx_done   !== 1  ||
				o_violation !== 0  
			) begin
				$display("    set_state_idle_low fail 2 %t", $realtime);
				failed = 1;
			end
			
			i_tx_done    = 1;
			i_scl        = 0;
			i_sda        = 1;
			repeat(1) @(posedge i_clk);
			
			repeat(2) begin
						#1;
				if (
					o_rx_sda_init_valid !== 0        ||
					//o_rx_sda_init       !== 1        ||
					o_rx_sda_mid_change !== 0        ||
					//o_rx_sda_final      !==  ||
		
					o_scl       !== 0  ||
					o_sda       !== 1  ||
					o_rx_done   !== 1  ||
					o_violation !== 0  
				) begin
					$display("    set_state_idle_low fail 3 %t", $realtime);
					failed = 1;
				end
				
				i_tx_done    = 0;

			
			end
			

		end
	endtask
	
	//rx_done very early, go through full bit transaction
	//task test_tx_to_mst1;
	//	begin
	//		//subtest_failed = 0;
	//		$display("--- test_tx_to_mst1 %t ---", $realtime);
	//		
	//		i_start_tx = 1;
	//		i_tx_is_to_mst = 1;
	//		repeat(1) @(posedge i_clk);
	//		i_start_tx = 0;
	//		i_rx_sda_init_valid = 1;
	//		i_rx_sda_init  = 1;
	//		i_rx_sda_final = 1;
	//		i_rx_done = 1;
	//		i_scl = 0;
	//		i_sda = 0;
	//		
	//		#1;
	//		if (
	//			o_scl       !== 0 ||
	//			//o_sda       !== 1 ||
	//			o_tx_done   !== 0  ||
	//			o_violation !== 0
	//		) begin
	//			$display("    fail 0 %t", $realtime);
	//			failed = 1;
	//		end
	//		
	//		repeat(1) @(posedge i_clk);
	//		#1;
	//		if (
	//			o_scl       !== 0 ||
	//			o_sda       !== 1 ||
	//			o_tx_done   !== 0 ||
	//			o_violation !== 0
	//		) begin
	//			$display("    fail 1 %t", $realtime);
	//			failed = 1;
	//		end
	//		
	//		i_scl = 0;
	//		i_sda = 1;
	//		
	//		//check o_scl does not rise before N_T_LOW_MIN
	//		while( time_elapsed( time_start_fall_scl) < NS_T_LOW_MIN) begin
	//			if (
	//				o_scl       !== 0 ||
	//				o_sda       !== 1 ||
	//				o_tx_done   !== 0 ||
	//				o_violation !== 0
	//			) begin
	//				$display("    fail 2 %t", $realtime);
	//				failed = 1;
	//			end
	//			#100;
	//		end
	//		
	//		//wait for o_scl to rise by NS_T_LOW_MAX
	//		while( o_scl !== 1 && (time_elapsed( time_start_fall_scl) < NS_T_LOW_MAX) ) begin
	//			#100;
	//		end
	//		
	//		if (
	//			o_scl       !== 1 ||
	//			o_sda       !== 1 ||
	//			o_tx_done   !== 0 ||
	//			o_violation !== 0
	//		) begin
	//			$display("    fail 3 %t", $realtime);
	//			failed = 1;
	//		end
	//		
	//		i_scl = 1;
	//		i_sda = 1;
	//		#1;
	//		
	//		//check outputs dont change until i_scl falls
	//		while( time_elapsed( time_start_rise_scl) < NS_T_LOW_MIN) begin
	//			if (
	//				o_scl       !== 1 ||
	//				o_sda       !== 1 ||
	//				o_tx_done   !== 0 ||
	//				o_violation !== 0
	//			) begin
	//				$display("    fail 4 %t", $realtime);
	//				failed = 1;
	//			end
	//			#100;
	//		end
	//		
	//		i_scl = 0;
	//
	//		//o o_scl should be locked low, after that changes in i_scl should have no effect.
	//		repeat(4) begin
	//			@(posedge i_clk);
	//			#1;
	//			if (
	//				o_scl       !== 0 ||
	//				//o_sda       !== 1 ||
	//				//o_tx_done   !== 0 ||
	//				o_violation !== 0
	//			) begin
	//				$display("    fail 5 %t", $realtime);
	//				$display("    o_scl %b", o_scl);
	//				$display("    o_violation %b", o_violation);
	//				failed = 1;
	//			end
	//			i_scl = ~i_scl;
	//
	//		end
	//		
	//		
	//		
	//		@(posedge i_clk);
	//		#1;
	//		if (
	//			o_scl       !== 0 ||
	//			//o_sda       !== 1 ||
	//			o_tx_done   !== 1 ||
	//			o_violation !== 0
	//		) begin
	//			$display("    fail 6 %t", $realtime);
	//			failed = 1;
	//		end
	//	
	//	end
	//endtask
	

	
	
	function realtime time_elapsed;
		input realtime start;
		begin
			time_elapsed = $realtime - start;
		end
	endfunction
	
	
	

		




endmodule
