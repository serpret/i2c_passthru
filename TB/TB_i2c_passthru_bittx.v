`timescale 1ns/100ps


module tb();
	//parameters
	localparam F_REF_T_R      = 15;
	localparam F_REF_T_SU_DAT = 2 ;
	localparam F_REF_T_LOW    = 38;
	localparam WIDTH_F_REF_T_R          = 4 ;
	localparam WIDTH_F_REF_T_SU_DAT     = 2 ;
	localparam WIDTH_F_REF_T_LOW        = 6 ;


	reg f_ref_unsync;
	
	
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

	
	always #5 i_clk = ~i_clk;
	always #1000 f_ref_unsync = ~f_ref_unsync;
	
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

	

	integer failed = 0;
	integer subtest_failed ;
	initial begin
		$timeformat(-6,3, "us", 12);
		init_vars();
		rst_uut();
		//repeat(10) @(posedge i_clk) #1;
		
		//test_rqst_start();
		//failed = subtest_failed || failed;
		//
		//test_sda_change_scl_low();
		//failed = subtest_failed || failed;
		test_tx_to_mst1();
		#100_000_000;
		
	
		if( failed) $display(" ! ! !  TEST FAILED ! ! !");
		else        $display(" Test Passed ");
		$stop();

	
	end


	task init_vars;
		begin
			i_clk = 0;
			i_rstn = 0;
			f_ref_unsync  =0;
			
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
	
	
	task test_tx_to_mst1;
		begin
			subtest_failed = 0;
			$display("--- test_tx_to_mst1 ---");
			
			i_start_tx = 1;
			i_tx_is_to_mst = 1;
			repeat(1) @(posedge i_clk);
			i_start_tx = 0;
			i_rx_sda_init_valid = 1;
			i_rx_sda_init  = 1;
			i_rx_sda_final = 1;
			i_rx_done = 1;
			if( o_tx_done
			repeat(1) @(posedge i_clk);
			#1;
			if( o_sda !== 1) begin
				$display("    fail 2 %t", $realtime);
				subtest_failed = 1;
			end
			if (
				o_scl       !== 0 ||
				o_sda       !== 1 ||
				o_tx_done   !==   ||
				o_violation !==
			)
			
			
			
			
			
			#10_000;
			repeat(1) @(posedge i_clk);
			#1;
			if( o_scl !== 0) begin
				$display("    fail 2 %t", $realtime);
				subtest_failed = 1;
			end
			i_sda = 1;
			
			
			
			
		
		end
	endtask
	
	
	

		




endmodule
