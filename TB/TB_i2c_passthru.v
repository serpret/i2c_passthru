`timescale 1ns/100ps

`define MON_EVENT_0 2'b00
`define MON_EVENT_1 2'b01
`define MON_EVENT_P 2'b10
`define MON_EVENT_S 2'b11





module tb();
	//parameters
	
	localparam NS_TB_TIMEOUT      =   300_000_000;
	localparam NS_T_BUS_STUCK_MAX =   200_000_000;
	localparam NS_T_BUS_STUCK_MIN =    25_000_000;
	
	localparam NS_T_HI_MAX      =  700000;
	localparam NS_T_HI_MIN      =   50000;
	localparam NS_T_LOW_MIN     =    4000;
	localparam NS_T_LOW_MAX     =    6000;
	
	
	localparam F_REF_T_R                    = 4;
	localparam F_REF_T_SU_DAT               = 2;
	localparam F_REF_T_HI                   =50;  //max value (timeout)
	localparam F_REF_T_LOW                  = 5;
	localparam F_REF_SLOW_T_STUCK_MAX       = 2;
	localparam WIDTH_F_REF_T_R              = 3;
	localparam WIDTH_F_REF_T_SU_DAT         = 2;
	localparam WIDTH_F_REF_T_HI             = 6;
	localparam WIDTH_F_REF_T_LOW            = 3;
	localparam WIDTH_F_REF_SLOW_T_STUCK_MAX = 2;
	
	//tb signals
	reg f_ref_unsync      ;
	reg f_ref_slow_unsync ;
	
	reg [255:0] current_test_name;
	reg [12:0] current_test_pass_config;
	

	reg [31:0] time_mst_rise        ;
	reg [31:0] time_mst_fall        ;
	reg [31:0] time_mst_sda_ref_rise;
	reg [31:0] time_mst_sda_ref_fall;
	
	reg [31:0] time_slv_rise        ;
	reg [31:0] time_slv_fall        ;
	reg [31:0] time_slv_sda_ref_rise;
	reg [31:0] time_slv_sda_ref_fall;
	

	
	//shared opendrain input signals to both uut and driver
	reg cha_scl         ;
	reg cha_sda         ;
	reg chb_scl         ;
	reg chb_sda         ;
	

	//uut signals
	reg i_clk           ;        
	reg i_rstn          ;       
	reg i_f_ref         ;      
	reg i_f_ref_slow    ; 

	
	wire o_cha_scl      ;
	wire o_cha_sda      ;
	wire o_chb_scl      ;
	wire o_chb_sda      ;
	wire o_cha_ismst    ; 
	wire o_chb_ismst    ; 
	wire o_idle_timeout ; 
	wire o_bit_violation; 
	wire o_cha_stuck    ; 
	wire o_chb_stuck    ;
	
	//which channel will be tested as master
	reg test_cha_mst ;
		
	//master driver signals

	reg       drv_mst_scl_sda_chng_ref      ;  
	reg       drv_mst_start                 ;  
	reg [31:0]drv_mst_timing                ;  
	reg       drv_mst_is_mstr               ;  
	reg       drv_mst_clock_low_by8         ;  
	reg       drv_mst_sda_violate           ;  
	reg       drv_mst_dont_stop             ;  
	reg       drv_mst_dont_start            ;  
	reg [3:0] drv_mst_stop_after_byte       ;  
	reg [3:0] drv_mst_extra_stop_after_byte ;  
	reg [3:0] drv_mst_extra_start_after_byte;  
	reg [8:0] drv_mst_wrbyte_0              ;              
	reg [8:0] drv_mst_wrbyte_1              ;              
	reg [8:0] drv_mst_wrbyte_2              ;              
	reg [8:0] drv_mst_wrbyte_3              ;              
	reg [8:0] drv_mst_wrbyte_4              ;              
	reg [8:0] drv_mst_wrbyte_5              ;              
	reg [8:0] drv_mst_wrbyte_6              ;              
	reg [8:0] drv_mst_wrbyte_7              ;              
	reg [8:0] drv_mst_wrbyte_8              ;              
	reg [8:0] drv_mst_wrbyte_9              ;              
	reg [8:0] drv_mst_wrbyte_10             ;              
	reg [8:0] drv_mst_wrbyte_11             ;              
	reg [8:0] drv_mst_wrbyte_12             ;              
	reg [8:0] drv_mst_wrbyte_13             ;              
	reg [8:0] drv_mst_wrbyte_14             ;              
	reg [8:0] drv_mst_wrbyte_15             ;              
	wire      drv_mst_scl                   ;
	wire      drv_mst_sda                   ;
	wire      drv_mst_idle                  ;
	
	
	//slaver driver signals

	reg       drv_slv_scl_sda_chng_ref      ;   
	reg       drv_slv_start                 ;   
	reg [31:0]drv_slv_timing                ;   
	reg       drv_slv_is_mstr               ;   
	reg       drv_slv_clock_low_by8         ;   
	reg       drv_slv_sda_violate           ;   
	reg       drv_slv_dont_stop             ;   
	reg       drv_slv_dont_start            ;   
	reg [3:0] drv_slv_stop_after_byte       ;   
	reg [3:0] drv_slv_extra_stop_after_byte ;   
	reg [3:0] drv_slv_extra_start_after_byte;   
	reg [8:0] drv_slv_wrbyte_0              ;                
	reg [8:0] drv_slv_wrbyte_1              ;                
	reg [8:0] drv_slv_wrbyte_2              ;                
	reg [8:0] drv_slv_wrbyte_3              ;                
	reg [8:0] drv_slv_wrbyte_4              ;                
	reg [8:0] drv_slv_wrbyte_5              ;                
	reg [8:0] drv_slv_wrbyte_6              ;                
	reg [8:0] drv_slv_wrbyte_7              ;                
	reg [8:0] drv_slv_wrbyte_8              ;                
	reg [8:0] drv_slv_wrbyte_9              ;                
	reg [8:0] drv_slv_wrbyte_10             ;                
	reg [8:0] drv_slv_wrbyte_11             ;                
	reg [8:0] drv_slv_wrbyte_12             ;                
	reg [8:0] drv_slv_wrbyte_13             ;                
	reg [8:0] drv_slv_wrbyte_14             ;                
	reg [8:0] drv_slv_wrbyte_15             ;                
	wire      drv_slv_scl                   ;
	wire      drv_slv_sda                   ;
	wire      drv_slv_idle                  ;


	//master monitor
			
		reg mon_mst_en_timing_check              ;
		reg mon_mst_clr_all                      ;
		wire [ 31:0]  mon_mst_num_events         ;
		wire [255:0]  mon_mst_events             ;
		wire          mon_mst_timing_check_err   ;
		
	//slave monitor
			
		reg mon_slv_en_timing_check              ;
		reg mon_slv_clr_all                      ;
		wire [ 31:0]  mon_slv_num_events         ;
		wire [255:0]  mon_slv_events             ;
		wire          mon_slv_timing_check_err   ;
		
		
	//optional signal monitor
	reg mon_opt_rstn;
	
	wire [31:0] mon_opt_cnt_idle_timeout ;
	wire [31:0] mon_opt_cnt_bit_violation;
	wire [31:0] mon_opt_cnt_cha_stuck    ;
	wire [31:0] mon_opt_cnt_chb_stuck    ;
	
	


	////

	always #160        i_clk            = ~i_clk; //160 ->
	always #500        f_ref_unsync     = ~f_ref_unsync;    
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
		.WIDTH_F_REF_SLOW_T_STUCK_MAX (WIDTH_F_REF_SLOW_T_STUCK_MAX)
		
	
	) uut
	(

		.i_clk           (i_clk           ),        
		.i_rstn          (i_rstn          ),       
		.i_f_ref         (i_f_ref         ),      
		.i_f_ref_slow    (i_f_ref_slow    ), 
		.i_cha_scl       (  cha_scl       ),
		.i_cha_sda       (  cha_sda       ),
		.i_chb_scl       (  chb_scl       ),
		.i_chb_sda       (  chb_sda       ),
		.o_cha_scl       (o_cha_scl       ),
		.o_cha_sda       (o_cha_sda       ),
		.o_chb_scl       (o_chb_scl       ),
		.o_chb_sda       (o_chb_sda       ),
		.o_cha_ismst     (o_cha_ismst     ), 
		.o_chb_ismst     (o_chb_ismst     ), 
		.o_idle_timeout  (o_idle_timeout  ), 
		.o_bit_violation (o_bit_violation ), 
		.o_cha_stuck     (o_cha_stuck     ), 
		.o_chb_stuck     (o_chb_stuck     )  

	);
	
	
	driver_i2c u_driver_i2c_mst(

		.i_scl                   (test_cha_mst ? cha_scl : chb_scl ),
		.i_sda                   (test_cha_mst ? cha_sda : chb_sda ),
		.i_scl_sda_chng_ref      (drv_mst_scl_sda_chng_ref      ),
		.i_start                 (drv_mst_start                 ),    
		.i_timing                (drv_mst_timing                ),   
		//.i_is_mstr               (drv_mst_is_mstr               ),  
		.i_is_mstr               ( 1'b1                         ),
		.i_clock_low_by8         (drv_mst_clock_low_by8         ), 
		.i_sda_violate           (drv_mst_sda_violate           ), 
		.i_dont_stop             (drv_mst_dont_stop             ),
		.i_dont_start            (drv_mst_dont_start            ),
		.i_stop_after_byte       (drv_mst_stop_after_byte       ), 
		.i_extra_stop_after_byte (drv_mst_extra_stop_after_byte ),  
		.i_extra_start_after_byte(drv_mst_extra_start_after_byte), 
		.i_wrbyte_0              (drv_mst_wrbyte_0              ),
		.i_wrbyte_1              (drv_mst_wrbyte_1              ),
		.i_wrbyte_2              (drv_mst_wrbyte_2              ),
		.i_wrbyte_3              (drv_mst_wrbyte_3              ),
		.i_wrbyte_4              (drv_mst_wrbyte_4              ),
		.i_wrbyte_5              (drv_mst_wrbyte_5              ),
		.i_wrbyte_6              (drv_mst_wrbyte_6              ),
		.i_wrbyte_7              (drv_mst_wrbyte_7              ),
		.i_wrbyte_8              (drv_mst_wrbyte_8              ),
		.i_wrbyte_9              (drv_mst_wrbyte_9              ),
		.i_wrbyte_10             (drv_mst_wrbyte_10             ),
		.i_wrbyte_11             (drv_mst_wrbyte_11             ),
		.i_wrbyte_12             (drv_mst_wrbyte_12             ),
		.i_wrbyte_13             (drv_mst_wrbyte_13             ),
		.i_wrbyte_14             (drv_mst_wrbyte_14             ),
		.i_wrbyte_15             (drv_mst_wrbyte_15             ),
		.o_scl                   (drv_mst_scl                   ),
		.o_sda                   (drv_mst_sda                   ),
		.o_idle                  (drv_mst_idle                  )
	);
	
	
	
	driver_i2c u_driver_i2c_slv(

		.i_scl                   (test_cha_mst ? chb_scl : cha_scl ),
		.i_sda                   (test_cha_mst ? chb_sda : cha_sda ),
		.i_scl_sda_chng_ref      (drv_slv_scl_sda_chng_ref      ),
		.i_start                 (drv_slv_start                 ),    
		.i_timing                (drv_slv_timing                ),   
		//.i_is_mstr               (drv_slv_is_mstr               ),  
		.i_is_mstr               ( 1'b0                         ),
		.i_clock_low_by8         (drv_slv_clock_low_by8         ), 
		.i_sda_violate           (drv_slv_sda_violate           ), 
		.i_dont_stop             (drv_slv_dont_stop             ),
		.i_dont_start            (drv_slv_dont_start            ),
		.i_stop_after_byte       (drv_slv_stop_after_byte       ), 
		.i_extra_stop_after_byte (drv_slv_extra_stop_after_byte ),  
		.i_extra_start_after_byte(drv_slv_extra_start_after_byte), 
		.i_wrbyte_0              (drv_slv_wrbyte_0              ),
		.i_wrbyte_1              (drv_slv_wrbyte_1              ),
		.i_wrbyte_2              (drv_slv_wrbyte_2              ),
		.i_wrbyte_3              (drv_slv_wrbyte_3              ),
		.i_wrbyte_4              (drv_slv_wrbyte_4              ),
		.i_wrbyte_5              (drv_slv_wrbyte_5              ),
		.i_wrbyte_6              (drv_slv_wrbyte_6              ),
		.i_wrbyte_7              (drv_slv_wrbyte_7              ),
		.i_wrbyte_8              (drv_slv_wrbyte_8              ),
		.i_wrbyte_9              (drv_slv_wrbyte_9              ),
		.i_wrbyte_10             (drv_slv_wrbyte_10             ),
		.i_wrbyte_11             (drv_slv_wrbyte_11             ),
		.i_wrbyte_12             (drv_slv_wrbyte_12             ),
		.i_wrbyte_13             (drv_slv_wrbyte_13             ),
		.i_wrbyte_14             (drv_slv_wrbyte_14             ),
		.i_wrbyte_15             (drv_slv_wrbyte_15             ),
		.o_scl                   (drv_slv_scl                   ),
		.o_sda                   (drv_slv_sda                   ),
		.o_idle                  (drv_slv_idle                  )
	);
	
	

	mon_i2c u_monitor_mst(
		.i_scl( test_cha_mst ? cha_scl : chb_scl),
		.i_sda( test_cha_mst ? cha_sda : chb_sda),
		
		.i_en_timing_check( mon_mst_en_timing_check),
		.i_clr_all        ( mon_mst_clr_all        ),
		
		.i_t_low          ( 4700                   ),
		.i_t_su           (  250                   ),
		
		.o_num_events      (mon_mst_num_events      ), 
		.o_events          (mon_mst_events          ),
		.o_timing_check_err(mon_mst_timing_check_err)
	);
	
	
	mon_i2c u_monitor_slv(
		.i_scl( test_cha_mst ? chb_scl : cha_scl),
		.i_sda( test_cha_mst ? chb_sda : cha_sda),
		
		.i_en_timing_check( mon_slv_en_timing_check),
		.i_clr_all        ( mon_slv_clr_all        ),
		
		.i_t_low          ( 4700                   ),
		.i_t_su           (  250                   ),
		
		.o_num_events      (mon_slv_num_events      ), 
		.o_events          (mon_slv_events          ),
		.o_timing_check_err(mon_slv_timing_check_err)
	);
	
	
	
	mon_passthru_optional_outputs u_mon_opt(
		.i_clk (i_clk),
		.i_rstn(mon_opt_rstn),
		.i_idle_timeout  (o_idle_timeout ),
		.i_bit_violation (o_bit_violation),
		.i_cha_stuck     (o_cha_stuck    ),
		.i_chb_stuck     (o_chb_stuck    ),
	

		.o_cnt_idle_timeout  (mon_opt_cnt_idle_timeout ),
		.o_cnt_bit_violation (mon_opt_cnt_bit_violation),
		.o_cnt_cha_stuck     (mon_opt_cnt_cha_stuck    ),
		.o_cnt_chb_stuck     (mon_opt_cnt_chb_stuck    )
	
	);
	

	//master/slave channela/channelb switching, opendrain delays, 
	//and reference signal creation for drivers
	//channel A
	//always @( o_cha_scl, drv_mst_scl, drv_slv_scl) begin
	always @(*) begin
		if( test_cha_mst) begin
			if( o_cha_scl & drv_mst_scl) cha_scl <= #time_mst_rise 1'b1;
			else                         cha_scl <= #time_mst_fall 1'b0;
		end
		else begin
			if( o_cha_scl & drv_slv_scl) cha_scl <= #time_slv_rise 1'b1;
			else                         cha_scl <= #time_slv_fall 1'b0;
		end
	end
	
	//always @( o_cha_scl, o_chb_scl, drv_mst_scl) begin
	always @(*) begin
		if( test_cha_mst) begin
			if( o_cha_scl & drv_mst_scl) drv_mst_scl_sda_chng_ref <= #(time_mst_sda_ref_rise) 1'b1;
			else                         drv_mst_scl_sda_chng_ref <= #(time_mst_sda_ref_fall) 1'b0;
		end
		else begin
			if( o_chb_scl & drv_mst_scl) drv_mst_scl_sda_chng_ref <= #(time_mst_sda_ref_rise) 1'b1;
			else                         drv_mst_scl_sda_chng_ref <= #(time_mst_sda_ref_fall) 1'b0;
		end
	end
	
	//wait why does cha_sda not have a timing delay... oh because it messes with sda_ref... need to think on this
	//always @( drv_mst_sda, drv_slv_sda ) begin
	//always @(*) begin
	//	if( test_cha_mst) begin
	//		if( o_cha_sda & drv_mst_sda) cha_sda = 1'b1;
	//		else                         cha_sda = 1'b0;
	//	end
	//	else begin
	//		if( o_cha_sda & drv_slv_sda) cha_sda = 1'b1;
	//		else                         cha_sda = 1'b0;
	//	end
	//end
	
	always @(o_cha_sda) begin
		if( test_cha_mst) begin
			if( o_cha_sda & drv_mst_sda) cha_sda <= #time_mst_rise 1'b1;
			else                         cha_sda <= #time_mst_fall 1'b0;
		end
		else begin
			if( o_cha_sda & drv_slv_sda) cha_sda <= #time_slv_rise 1'b1;
			else                         cha_sda <= #time_slv_fall 1'b0;
		end
	end
	
	always @(drv_mst_sda, drv_slv_sda) begin
		if( test_cha_mst) begin
			if( o_cha_sda & drv_mst_sda) cha_sda = 1'b1;
			else                         cha_sda = 1'b0;
		end
		else begin
			if( o_cha_sda & drv_slv_sda) cha_sda = 1'b1;
			else                         cha_sda = 1'b0;
		end
	end

	//channel B
	//always @( o_chb_scl, drv_mst_scl, drv_slv_scl) begin
	always @(*) begin
		if( test_cha_mst) begin
			if( o_chb_scl & drv_slv_scl) chb_scl <= #time_slv_rise 1'b1;
			else                         chb_scl <= #time_slv_fall 1'b0;
		end
		else begin
			if( o_chb_scl & drv_mst_scl) chb_scl <= #time_mst_rise 1'b1;
			else                         chb_scl <= #time_mst_fall 1'b0;
		end
	end
	
	//always @( o_chb_scl, drv_mst_scl, drv_slv_scl) begin
	always @(*) begin
		if( test_cha_mst) begin
			if( o_chb_scl & drv_slv_scl) drv_slv_scl_sda_chng_ref <= #(time_slv_sda_ref_rise) 1'b1;
			else                         drv_slv_scl_sda_chng_ref <= #(time_slv_sda_ref_fall) 1'b0;
		end
		else begin
			if( o_cha_scl & drv_slv_scl) drv_slv_scl_sda_chng_ref <= #(time_slv_sda_ref_rise) 1'b1;
			else                         drv_slv_scl_sda_chng_ref <= #(time_slv_sda_ref_fall) 1'b0;
		end
	end
	

	//always @( drv_mst_sda, drv_mst_scl, drv_slv_sda ) begin
	//always @(*) begin
	//	if( test_cha_mst) begin
	//		if( o_chb_sda & drv_slv_sda) chb_sda = 1'b1;
	//		else                         chb_sda = 1'b0;
	//	end
	//	else begin
	//		if( o_chb_sda & drv_mst_sda) chb_sda = 1'b1;
	//		else                         chb_sda = 1'b0;
	//	end
	//end
	
	always @(o_chb_sda) begin
		if( test_cha_mst) begin
			if( o_chb_sda & drv_slv_sda) chb_sda <= #time_slv_rise 1'b1;
			else                         chb_sda <= #time_slv_fall 1'b0;
		end
		else begin
			if( o_chb_sda & drv_mst_sda) chb_sda <= #time_mst_rise 1'b1;
			else                         chb_sda <= #time_mst_fall 1'b0;
		end
	end
	
	always @(drv_slv_sda,drv_mst_sda) begin
		if( test_cha_mst) begin
			if( o_chb_sda & drv_slv_sda) chb_sda = 1'b1;
			else                         chb_sda = 1'b0;
		end
		else begin
			if( o_chb_sda & drv_mst_sda) chb_sda = 1'b1;
			else                         chb_sda = 1'b0;
		end
	end
	
	

	
	

	integer failed = 0;
	//integer subtest_failed ;
	initial begin
		$timeformat(-6,3, "us", 12);
		init_vars();
		
		rst_uut();
		i2c_protocol_test();

		//init_drv_mst_wrbytes();
		//init_drv_slv_wrbytes();
		//
		//mon_mst_en_timing_check = 0;
		//mon_mst_clr_all         = 0;
		//#1;
		//mon_mst_en_timing_check = 1;
		//mon_mst_clr_all         = 1;
		//
		//test_cha_mst = 1;
		//#10_000;
		//
		//
		//drv_mst_start                  = 1'b1    ;
		//drv_mst_timing                 = 32'd5000;
		//drv_mst_is_mstr                = 1'b1    ;
		//drv_mst_clock_low_by8          = 1'b0    ;
		//drv_mst_sda_violate            = 1'b0    ;
		//drv_mst_dont_stop              = 1'b0    ;
		//drv_mst_dont_start             = 1'b0    ;
		//drv_mst_stop_after_byte        = 4'b1    ;
		//drv_mst_extra_stop_after_byte  = 4'hF    ;
		//drv_mst_extra_start_after_byte = 4'hF    ;
		//
		//drv_mst_wrbyte_0= { 7'h55, 1'b0, 1'b1};
		//drv_mst_wrbyte_1= {       8'h55, 1'b1};
		//
		//
		//drv_slv_start                  = 1'b1    ;
		//drv_slv_timing                 = 32'd5000;
		//drv_slv_is_mstr                = 1'b0    ;
		//drv_slv_clock_low_by8          = 1'b0    ;
		//drv_slv_sda_violate            = 1'b0    ;
		//drv_slv_dont_stop              = 1'b0    ;
		//drv_slv_dont_start             = 1'b0    ;
		//drv_slv_stop_after_byte        = 4'b1    ;
		//drv_slv_extra_stop_after_byte  = 4'hF    ;
		//drv_slv_extra_start_after_byte = 4'hF    ;
		//
		//drv_slv_wrbyte_0= { 7'hFF, 1'b1, 1'b0};
		//drv_slv_wrbyte_1= {       8'hFF, 1'b0};
		//
		//
		//
		//@(posedge drv_mst_idle);
		//
		////print_i2c_events( mon_mst_num_events, mon_mst_events);
		//
		//#5000;
		//
		//print_i2c_events( mon_mst_num_events, mon_mst_events);

		
		


	
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
			

			
			cha_scl       = 1;
			cha_sda       = 1;
			chb_scl       = 1;
			chb_sda       = 1;
			
			drv_mst_scl_sda_chng_ref = 1;
			drv_slv_scl_sda_chng_ref = 1;
			
			time_mst_rise         = 32'h0000_0000;
			time_mst_fall         = 32'h0000_0000;
			time_mst_sda_ref_rise = 32'h0000_0000;
			time_mst_sda_ref_fall = 32'h0000_0000;
			
			time_slv_rise         = 32'h0000_0000;
			time_slv_fall         = 32'h0000_0000;
			time_slv_sda_ref_rise = 32'h0000_0000;
			time_slv_sda_ref_fall = 32'h0000_0000;
			
			
			mon_mst_en_timing_check = 0;
			mon_slv_en_timing_check = 0;

			
			init_drv_mst();
			init_drv_slv();
			#1;
			
			
		end
	endtask
	
	
	task init_drv_mst;
		begin
			drv_mst_scl_sda_chng_ref      = 0;
			drv_mst_start                 = 0;
			drv_mst_timing                = 32'd5000; //ns
			drv_mst_is_mstr               = 0;
			drv_mst_clock_low_by8         = 0;
			drv_mst_sda_violate           = 0;
			drv_mst_dont_stop             = 0;
			drv_mst_dont_start            = 0;
			drv_mst_stop_after_byte       = 0;
			drv_mst_extra_stop_after_byte  = 4'hF;
			drv_mst_extra_start_after_byte = 4'hF;
			init_drv_mst_wrbytes();

			
		end
	endtask
	
	
	task init_drv_slv;
		begin
			drv_slv_scl_sda_chng_ref      = 0;
			drv_slv_start                 = 0;
			drv_slv_timing                = 32'd5000; //ns
			drv_slv_is_mstr               = 0;
			drv_slv_clock_low_by8         = 0;
			drv_slv_sda_violate           = 0;
			drv_slv_dont_stop             = 0;
			drv_slv_dont_start            = 0;
			drv_slv_stop_after_byte       = 0;
			drv_slv_extra_stop_after_byte  = 4'hF;
			drv_slv_extra_start_after_byte = 4'hF;
			init_drv_slv_wrbytes();

		end
	endtask
	
	
	task init_drv_mst_wrbytes;
		begin
			drv_mst_wrbyte_0  = 9'h1FF;
			drv_mst_wrbyte_1  = 9'h1FF;
			drv_mst_wrbyte_2  = 9'h1FF;
			drv_mst_wrbyte_3  = 9'h1FF;
			drv_mst_wrbyte_4  = 9'h1FF;
			drv_mst_wrbyte_5  = 9'h1FF;
			drv_mst_wrbyte_6  = 9'h1FF;
			drv_mst_wrbyte_7  = 9'h1FF;
			drv_mst_wrbyte_8  = 9'h1FF;
			drv_mst_wrbyte_9  = 9'h1FF;
			drv_mst_wrbyte_10 = 9'h1FF;
			drv_mst_wrbyte_11 = 9'h1FF;
			drv_mst_wrbyte_12 = 9'h1FF;
			drv_mst_wrbyte_13 = 9'h1FF;
			drv_mst_wrbyte_14 = 9'h1FF;
			drv_mst_wrbyte_15 = 9'h1FF;

		end
	endtask
	
	
	
	task init_drv_slv_wrbytes;
		begin
			drv_slv_wrbyte_0  = 9'h1FF;
			drv_slv_wrbyte_1  = 9'h1FF;
			drv_slv_wrbyte_2  = 9'h1FF;
			drv_slv_wrbyte_3  = 9'h1FF;
			drv_slv_wrbyte_4  = 9'h1FF;
			drv_slv_wrbyte_5  = 9'h1FF;
			drv_slv_wrbyte_6  = 9'h1FF;
			drv_slv_wrbyte_7  = 9'h1FF;
			drv_slv_wrbyte_8  = 9'h1FF;
			drv_slv_wrbyte_9  = 9'h1FF;
			drv_slv_wrbyte_10 = 9'h1FF;
			drv_slv_wrbyte_11 = 9'h1FF;
			drv_slv_wrbyte_12 = 9'h1FF;
			drv_slv_wrbyte_13 = 9'h1FF;
			drv_slv_wrbyte_14 = 9'h1FF;
			drv_slv_wrbyte_15 = 9'h1FF;

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
	
	
	
	task rst_all_mon;
		begin
			mon_mst_clr_all = 0;
			mon_slv_clr_all = 0;
			mon_opt_rstn    = 1;
			#1;
			mon_mst_clr_all = 1;
			mon_slv_clr_all = 1;
			mon_opt_rstn    = 0;
			#1;
			mon_mst_clr_all = 0;
			mon_slv_clr_all = 0;
			mon_opt_rstn    = 1;

		end
	endtask
	
	
	task i2c_protocol_test;
	
		reg [8:0] mst_dat;
		reg [8:0] slv_dat;
		begin
			current_test_name = "i2c_protocol_test";
			
			current_test_pass_config = {1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0, 2'h0, 2'h0};
			
			case( current_test_pass_config[0 +:2] ) 
				2'b00: mst_dat = 9'b0_0000_0000;
				2'b01: mst_dat = 9'b1_0101_0101;
				2'b10: mst_dat = 9'b0_1010_1010;
				2'b11: mst_dat = 9'b1_1111_1111;
			endcase
			
			case( current_test_pass_config[2 +:2] ) 
				2'b00: slv_dat = 9'b0_0000_0000;
				2'b01: slv_dat = 9'b1_0101_0101;
				2'b10: slv_dat = 9'b0_1010_1010;
				2'b11: slv_dat = 9'b1_1111_1111;
			endcase
			
			
			//i2c_protocol_test_pass(0,0,0,0,0,0,0,0,0, 9'h1_55, 9'h0_AA);
			i2c_protocol_test_pass(
				current_test_pass_config[ 12],
				current_test_pass_config[ 11],
				current_test_pass_config[ 10],
				current_test_pass_config[ 09],
				current_test_pass_config[ 08],
				current_test_pass_config[ 07],
				current_test_pass_config[ 06],
				current_test_pass_config[ 05],
				current_test_pass_config[ 04],
				mst_dat[8:0],
				slv_dat[8:0]
			);

		end
	endtask
	
	
	
	function [17:0] i2cbyte_to_i2c_event;
		input [8:0] data;
		begin
			repeat(9) begin
				i2cbyte_to_i2c_event = i2cbyte_to_i2c_event << 2;
				i2cbyte_to_i2c_event[1:0] = data[8] ? `MON_EVENT_1 : `MON_EVENT_0;
				data = data << 1;
			end
		end
	endfunction
		
	
	
	
	task i2c_protocol_test_pass;
		input en_rst_between_tran;
		input en_mst_time_violations;
		input en_slv_time_violations;
		input en_no_stops;
		input en_clk_stretch;
		input en_long_risefall_time;
		input en_chb_is_mst;
		input en_bit_violation; //perform slave bit violations on writes, perform master bit violations on reads
		input en_mst_fast;
		input [8:0] mst_dat;
		input [8:0] slv_dat;

		begin
	
			test_cha_mst = ~en_chb_is_mst;
			
	
			rst_all_mon();
			if(en_rst_between_tran) begin
				rst_uut();
				//#NS_T_BUS_STUCK_MAX;
				#NS_T_HI_MIN;
			end
			
	
			init_drv_mst_wrbytes();
			init_drv_slv_wrbytes();
			
			
			case( {en_mst_fast, en_mst_time_violations})
				2'b00: mon_mst_en_timing_check = 1;
				2'b01: mon_mst_en_timing_check = 0;
				2'b10: mon_mst_en_timing_check = 0;
				2'b11: mon_mst_en_timing_check = 0;
			endcase
			
			case( {en_mst_fast, en_slv_time_violations})
				2'b00: mon_slv_en_timing_check = 1;
				2'b01: mon_slv_en_timing_check = 0;
				2'b10: mon_slv_en_timing_check = 1;
				2'b11: mon_slv_en_timing_check = 0;
			endcase
			
			
			drv_mst_timing = en_mst_fast ? 32'd1000: 32'd5000;
			drv_slv_timing = 32'd5000;
			
			drv_slv_clock_low_by8 = en_clk_stretch ;
			drv_mst_clock_low_by8 = 1'b0;
			
	
			drv_mst_sda_violate = en_mst_time_violations;
			drv_slv_sda_violate = en_slv_time_violations;
			
	
			
			case( {en_mst_time_violations, en_long_risefall_time})
				2'b00: begin
					time_mst_rise         = 0;
					time_mst_fall         = 0;
					time_mst_sda_ref_rise = 0;
					time_mst_sda_ref_fall = 0;
				end
				
				2'b01: begin
					time_mst_rise           = 1000;
					time_mst_fall           = 1000;
					time_mst_sda_ref_rise   = 1000;
					time_mst_sda_ref_fall   = 1000;
				end
				
				2'b10: begin
					time_mst_rise          = 100;
					time_mst_fall          = 100;
					time_mst_sda_ref_rise  = 200;
					time_mst_sda_ref_fall  =   0;
				end
				
				2'b11: begin
					time_mst_rise         = 1000;
					time_mst_fall         = 1000;
					time_mst_sda_ref_rise = 1100;
					time_mst_sda_ref_fall =  900;
				end
	
			endcase
			
			
			case( {en_slv_time_violations, en_long_risefall_time})
				2'b00: begin
					time_slv_rise         = 0;
					time_slv_fall         = 0;
					time_slv_sda_ref_rise = 0;
					time_slv_sda_ref_fall = 0;
				end
				
				2'b01: begin
					time_slv_rise           = 1000;
					time_slv_fall           = 1000;
					time_slv_sda_ref_rise   = 1000;
					time_slv_sda_ref_fall   = 1000;
				end
				
				2'b10: begin
					time_slv_rise          = 100;
					time_slv_fall          = 100;
					time_slv_sda_ref_rise  = 200;
					time_slv_sda_ref_fall  =   0;
				end
				
				2'b11: begin
					time_slv_rise         = 1000;
					time_slv_fall         = 1000;
					time_slv_sda_ref_rise = 1100;
					time_slv_sda_ref_fall =  900;
				end
	
			endcase
			
			drv_mst_dont_stop = en_no_stops;
	
			
			
			//---- write address only, no ack ----------------
			
			drv_mst_stop_after_byte        = 4'b0    ;
			drv_mst_extra_stop_after_byte  = 4'hF    ;
			drv_mst_extra_start_after_byte = 4'hF    ;
			
			drv_mst_wrbyte_0= { mst_dat[8:2], 1'b0, 1'b1};
			//drv_mst_wrbyte_1= {       8'h55, 1'b1};
			
	
			drv_slv_stop_after_byte        = 4'b0    ;
			drv_slv_extra_stop_after_byte  = 4'hF    ;
			drv_slv_extra_start_after_byte = 4'hF    ;
			
			drv_slv_wrbyte_0= { 7'hFF, 1'b1, 1'b1};
			//drv_slv_wrbyte_1= {       8'hFF, 1'b0};
			
			
			drv_mst_start                  = 1'b1    ;
			drv_slv_start                  = 1'b1    ;
			#1;
			//@(posedge drv_mst_idle);
			
			//wait for mst and slv to be idle
			while( !drv_mst_idle || !drv_slv_idle) begin
				@(posedge i_clk);
			end
			
			
			
			
			//check_expctd_i2c_events( 
			//	.num_expctd(32'd11) , 
			//	.num_actual(mon_mst_num_events), 
			//	.expctd({
			//		MON_EVENT_S,
			//		i2cbyte_to_i2c_event( {mst_dat[8:2], 1'b0, 1'b1} ),
			//		MON_EVENT_P
			//	}),
			//	
			//	.actual(mon_mst_events) 
			//);
			
			
			check_expctd_i2c_events( 
				32'd11 ,                     //	.num_expctd
				mon_mst_num_events,          //	.num_actual
				{                            //	.expctd({
					`MON_EVENT_S,                                           
					i2cbyte_to_i2c_event( {mst_dat[8:2], 1'b0, 1'b1} ),    
					`MON_EVENT_P                                            
				},                                                         
				mon_mst_events               //	.actual
			);                               //);
			

		end
	
	endtask
	
	

	task check_expctd_i2c_events;
		input [31:0] num_expctd;
		input [31:0] num_actual;

		input [255:0] expctd;
		input [255:0] actual;
		reg        break_loop;
		reg [31:0] i;
		begin
		
			if( num_expctd !== num_actual) begin
				$display("-------  Failed test: %s ------", current_test_name);
				$display("-------  subpass config: %h ------", current_test_pass_config);
				$display("    time: %t", $realtime);
				$display("    number of expected events dont match actual");
				$display("    expected: %d", num_expctd);
				$display("    actual  : %d", num_actual);
				failed = 1;
			end
			
			break_loop = 0;
			for( i=0; (i< num_expctd) && !break_loop; i=i+1'b1) begin
			
				if( expctd[ 2*i +: 2] !== actual[ 2*i +: 2]) begin
					$display("-------  Failed test: %s ------", current_test_name);
					$display("-------  subpass config: %h ------", current_test_pass_config);
					$display("    time: %t", $realtime);
					$display("    expected events don't match actual");
					$write  ("    expected: ");
					print_i2c_events( num_expctd, expctd);
					$display("");
					$write  ("    actual  : ");
					print_i2c_events( num_actual, actual);
					$display("");
					failed = 1;
					break_loop = 1;
					
				end
			end
			
		end
	endtask

		
		
	
	

	
	
	function realtime time_elapsed;
		input realtime start;
		begin
			time_elapsed = $realtime - start;
		end
	endfunction
	
	
	task print_i2c_events;
		input [31:0] num_events;
		input [255:0] events;
		
		reg [31:0] idx;
		begin
			
			//$display("num events: %d", num_events);
			for(idx=0; idx<num_events; idx=idx+1'b1)begin
				//$write("%d ", idx);
				//$write("%d", (num_events-idx-1)*2); 
				case(events[ (num_events-idx-1)*2 +:2])
					`MON_EVENT_0: $write("0" );
					`MON_EVENT_1: $write("1" );
					`MON_EVENT_P: $write("P ");
					`MON_EVENT_S: $write(" S");
				endcase
			end
		end
	endtask
	
	
endmodule



module driver_i2c(

	input i_scl,
	input i_sda,
	
	//this is the scl reference used for sda transitions.  It is not optional.
	//it can be identical to i_sda. 
	//The rising edge must rise at the same time 
	//or after i_scl.  
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
	input        i_dont_stop    ,
	input        i_dont_start   ,
	
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
	input [8:0] i_wrbyte_0  ,
	input [8:0] i_wrbyte_1  ,
	input [8:0] i_wrbyte_2  ,
	input [8:0] i_wrbyte_3  ,
	input [8:0] i_wrbyte_4  ,
	input [8:0] i_wrbyte_5  ,
	input [8:0] i_wrbyte_6  ,
	input [8:0] i_wrbyte_7  ,
	input [8:0] i_wrbyte_8  ,
	input [8:0] i_wrbyte_9  ,
	input [8:0] i_wrbyte_10 ,
	input [8:0] i_wrbyte_11 ,
	input [8:0] i_wrbyte_12 ,
	input [8:0] i_wrbyte_13 ,
	input [8:0] i_wrbyte_14 ,
	input [8:0] i_wrbyte_15 ,

	output reg o_scl,
	output reg o_sda,
	
	output reg o_idle
	

);
	//localparam VIOLATE_TIME = 100; //assuming 

	reg [3:0] bit_cnt;
	reg [3:0] byte_cnt;
	reg [8:0] cur_byte; 
	//reg       ref_scl_for_sda;
	wire final_byte;
	wire stop_byte;
	wire start_byte;
	wire last_bit;
	wire second_to_last_bit;
	wire nxt_bit_ctrl;

	
	assign final_byte = (i_stop_after_byte       ) === byte_cnt;
	assign  stop_byte = (i_extra_start_after_byte) === byte_cnt && ( stop_byte !== 4'hF);
	assign start_byte = (i_extra_stop_after_byte ) === byte_cnt && (start_byte !== 4'hF);
	
	assign last_bit           = (4'h9 === bit_cnt);
	assign second_to_last_bit = (4'h8 === bit_cnt);
	
	assign nxt_bit_ctrl = (final_byte || stop_byte || start_byte) && last_bit;

	initial begin
		o_idle = 1'b1;
		o_scl = 1'b1;
		o_sda = 1'b1;
	end
	
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
		if( !o_idle) begin
			if( i_clock_low_by8) o_scl <= #(8*i_timing) 1'b1;
			else                 o_scl <= #(  i_timing) 1'b1;
		end

	end
	
	//if i_clock_low_by8 and slave that means we are clock stretching
	always @(negedge i_scl) begin
		if( !o_idle) begin
			if(!i_is_mstr && i_clock_low_by8) o_scl = 1'b0; 
		end
	end
	
	//generate o_scl next falling edge
	always @(posedge i_scl) begin
		if( !o_idle) begin
			if(i_is_mstr) begin
				if( nxt_bit_ctrl) begin //control event bit
					if(      final_byte)               o_scl  =               1'b1;   //do nothing
					else if ( stop_byte && start_byte) o_scl <= #(3*i_timing) 1'b0;
					else if ( stop_byte || start_byte) o_scl <= #(2*i_timing) 1'b0;
				end
				else begin
					o_scl <= #(i_timing) 1'b0; //normal data bit
				end
			end
		end
	end
	
	
	//byte count and bit count
	always @( posedge i_scl_sda_chng_ref) begin
		if( !o_idle) begin
			if( last_bit ) begin
			
				if( nxt_bit_ctrl) bit_cnt <= 4'h0;
				else              bit_cnt <= 4'h1;
				
				byte_cnt <= byte_cnt + 1'b1;
			end
			else begin
				bit_cnt <= bit_cnt + 1'b1;
			end
		end
	end
	

	
	//handle cur_byte
	always @( posedge i_scl_sda_chng_ref) begin
		if( !o_idle) begin
			if( second_to_last_bit) begin
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
			else if( !nxt_bit_ctrl) begin
				cur_byte <= (cur_byte[7:0] << 1);
			end
		end
		
	end
	
	
	//handle o_sda data transitions 
	always @( i_scl_sda_chng_ref) begin
		if( !o_idle) begin
			if( i_sda_violate) begin
				if( i_scl_sda_chng_ref) begin //rising edge of reference scl
					if( nxt_bit_ctrl ) begin //control event bit
						if( i_is_mstr) begin
							if(      final_byte) begin
								o_sda <= #i_timing 1'b1;
								o_idle <= #(2*i_timing) 1'b1;
								//o_sda <= #(2*i_timing) 1'b1;
								//o_idle <= #(3*i_timing) 1'b1;
							end
							else if ( stop_byte && start_byte) begin
								
								o_sda <= #(  i_timing) 1'b1;
								o_sda <= #(2*i_timing) 1'b0;
							end
							else if ( stop_byte )               o_sda <= #i_timing 1'b1;
							else if ( start_byte)               o_sda <= #i_timing 1'b0;
						end
						else begin //not master
							if(  final_byte) o_idle <= 1'b1;
							o_sda <= 1'b1;
						end
						
					end
					else begin 
						o_sda <= cur_byte[8];
					end
				end
				else begin // falling edge of reference scl
					o_sda <= ~o_sda;
					//o_sda <= 1'bX;
				end
			end
			else begin // if( !i_sda_violate)
				if( i_scl_sda_chng_ref) begin //rising edge of reference scl
					//o_sda <= o_sda; //no change, ignore
					if( nxt_bit_ctrl ) begin //control event bit
						if( i_is_mstr) begin
							if(      final_byte) begin
								o_sda <= #i_timing 1'b1;
								o_idle <= #(2*i_timing) 1'b1;
								//o_sda <= #(2*i_timing) 1'b1;
								//o_idle <= #(3*i_timing) 1'b1;
							end
							else if ( stop_byte && start_byte) begin
								
								o_sda <= #(  i_timing) 1'b1;
								o_sda <= #(2*i_timing) 1'b0;
							end
							else if ( stop_byte )               o_sda <= #i_timing 1'b1;
							else if ( start_byte)               o_sda <= #i_timing 1'b0;
						end
						else begin //not master
							if(  final_byte) o_idle <= 1'b1;
							o_sda <= 1'b1;
						end
						
					end
					
				end
				else begin // falling edge of reference scl
					
					
					if( nxt_bit_ctrl ) begin //control event bit
						if( i_is_mstr) begin
							if(      final_byte) begin                
								o_sda <=               1'b0;
								//o_sda <= #(2*i_timing) 1'b1;
								//o_idle <= #(2*i_timing) 1'b1;
							
							end
							else if ( stop_byte && start_byte) begin
								o_sda <=               1'b0;
								//o_sda <= #(2*i_timing) 1'b1;
								//o_sda <= #(3*i_timing) 1'b0;
							end
							else if ( stop_byte ) begin
								o_sda <=               1'b0;
								//o_sda <= #(2*i_timing) 1'b1;
							end
							else if ( start_byte) begin
								o_sda <=               1'b1;
								//o_sda <= #(2*i_timing) 1'b0;
							end
						end
						else begin //not master
							o_sda <= 1'b1;
						end
					end
					else begin 
						o_sda <= cur_byte[8];
					end
					
				end
			end
		end
		
	end
	

endmodule






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




module mon_i2c(
	input i_scl,
	input i_sda,
	
	input i_en_timing_check       ,
	input i_clr_all               ,
	
	input [63:0] i_t_low        ,
	input [63:0] i_t_su         ,
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
			o_events[1:0] = i_sda ? `MON_EVENT_1: `MON_EVENT_0;
		end
	end
	
	always @( i_sda) begin
		if(i_scl) begin
			psbl_data = 1'b0;
			o_num_events  = o_num_events + 1'b1;
			o_events      = o_events << 2;
			o_events[1:0] = i_sda ? `MON_EVENT_P: `MON_EVENT_S;
		end
	end
	
	//timing check logic
	always @(posedge i_scl) begin
	
		if( i_en_timing_check) begin
			if( time_elapsed( t_low_start) < i_t_low) task_t_low_violation();
			if( time_elapsed( t_su_start ) < i_t_low) task_t_su_violation();
			t_low_start = $realtime;
		end
	
	end
	
	always @(negedge i_scl) begin
		if( i_en_timing_check) begin
			if( time_elapsed( t_low_start) < i_t_low) task_t_low_violation();
			t_low_start = $realtime;
		end
	end
	
	always @(i_sda) begin
		if( i_en_timing_check) begin
			if( i_scl) begin
				if( time_elapsed( t_low_start) < i_t_low) task_t_low_violation();
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
	
	
	task task_t_low_violation;
		begin
			$display("-------  Failed test: task_t_low_violation ------");
			$display("    time: %t", $realtime);
			o_timing_check_err = 1'b1;
		end
	endtask
	
	task task_t_su_violation;
		begin
			$display("-------  Failed test: task_t_su_violation ------");
			$display("    time: %t", $realtime);
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


	
