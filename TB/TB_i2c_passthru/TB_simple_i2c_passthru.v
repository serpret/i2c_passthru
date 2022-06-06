//`timescale 1ns/100ps
`include "timescale.v"

`define MON_EVENT_0 2'b00
`define MON_EVENT_1 2'b01
`define MON_EVENT_P 2'b10
`define MON_EVENT_S 2'b11


//`define FAST_F_REF   //uncomment to use faster FAST_F_REF and i_clk


module tb();
	//parameters
	
	localparam NS_TB_LONG_TIMEOUT  =   300_000_000;
	localparam NS_TB_NORM_TIMEOUT  =     4_000_000;
	localparam NS_T_BUS_STUCK_MAX  =   200_000_000;
	localparam NS_T_BUS_STUCK_MIN  =    25_000_000;
	
	localparam NS_T_HI_MAX      =  700000;
	localparam NS_T_HI_MIN      =   50000;
	localparam NS_T_LOW_MIN     =    3500;

	localparam NS_T_LOW_MAX     =    6000;
	localparam NS_T_SU_DAT_MIN  =     250;
	
	`ifdef FAST_F_REF /////////////////////////////////
	//	always #50         f_ref_unsync     = ~f_ref_unsync; //period 100ns

		localparam INFILTER_NUM_CLKS_WIDTH     =  5;
		localparam INFILTER_NUM_CLKS_HI2LO_SDA = 12;
		localparam INFILTER_NUM_CLKS_LO2HI_SDA = 12;
		localparam INFILTER_NUM_CLKS_HI2LO_SCL =  4;
		localparam INFILTER_NUM_CLKS_LO2HI_SCL = 20;

		localparam F_REF_T_R                    = 20;
		localparam F_REF_T_SU_DAT               = 15;
		localparam F_REF_T_HI                   =500;  //max value (timeout)
		localparam F_REF_T_LOW                  = 40;
	
		localparam WIDTH_F_REF_T_R              = 5;
		localparam WIDTH_F_REF_T_SU_DAT         = 4;
		localparam WIDTH_F_REF_T_HI             = 9;
		localparam WIDTH_F_REF_T_LOW            = 6;
	
	`else /////////////////////////////////////////////
	
		localparam INFILTER_NUM_CLKS_WIDTH      = 3;
		
		localparam INFILTER_NUM_CLKS_HI2LO_SDA  = 1;
		localparam INFILTER_NUM_CLKS_LO2HI_SDA  = 1;
		localparam INFILTER_NUM_CLKS_HI2LO_SCL  = 0;
		localparam INFILTER_NUM_CLKS_LO2HI_SCL  = 2;
	
		localparam F_REF_T_R                    = 4;
		localparam F_REF_T_SU_DAT               = 2;
		localparam F_REF_T_HI                   =50;  //max value (timeout)
		localparam F_REF_T_LOW                  = 4;
	
		localparam WIDTH_F_REF_T_R              = 3;
		localparam WIDTH_F_REF_T_SU_DAT         = 2;
		localparam WIDTH_F_REF_T_HI             = 6;
		localparam WIDTH_F_REF_T_LOW            = 3;

	`endif ////////////////////////////////////////////
	
	localparam INFILTER_EN_2FF_SYNC         = 0;
	localparam F_REF_SLOW_T_STUCK_MAX       = 2;
	localparam WIDTH_F_REF_SLOW_T_STUCK_MAX = 2;
	

	
	//tb signals
	reg f_ref_unsync      ;
	reg f_ref_slow_unsync ;
	
	//reg [255:0] current_test_name;
	//reg [10:0] current_test_pass_config;
	
	reg [31:0] time_mst_rise        ;
	reg [31:0] time_mst_fall        ;

	reg [31:0] time_slv_rise        ;
	reg [31:0] time_slv_fall        ;


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
		
	//master driver signals

		//cha
	reg              drv_cha_mst_start                 ; 
	reg   [31:0]     drv_cha_mst_scl_lo_timing         ; 
	reg   [31:0]     drv_cha_mst_scl_hi_timing         ; 
	reg   [2:0]      drv_cha_mst_num_bytes             ; 
	reg   [2:0]      drv_cha_mst_repeatstart_after_byte; 
	reg   [2:0]      drv_cha_mst_stop_after_byte       ; 
	reg   [8:0]      drv_cha_mst_byte_0                ; 
	reg   [8:0]      drv_cha_mst_byte_1                ; 
	reg   [8:0]      drv_cha_mst_byte_2                ; 
	reg   [8:0]      drv_cha_mst_byte_3                ; 
	reg   [8:0]      drv_cha_mst_byte_4                ; 
	reg   [8:0]      drv_cha_mst_byte_5                ; 
	reg   [8:0]      drv_cha_mst_byte_6                ; 
	
	wire  drv_cha_mst_scl ;
	wire  drv_cha_mst_sda ;
	wire  drv_cha_mst_idle;
	
		//chb
	reg              drv_chb_mst_start                 ;  
	reg   [31:0]     drv_chb_mst_scl_lo_timing         ; 
	reg   [31:0]     drv_chb_mst_scl_hi_timing         ; 
	reg   [2:0]      drv_chb_mst_num_bytes             ; 
	reg   [2:0]      drv_chb_mst_repeatstart_after_byte; 
	reg   [2:0]      drv_chb_mst_stop_after_byte       ; 
	reg   [8:0]      drv_chb_mst_byte_0                ; 
	reg   [8:0]      drv_chb_mst_byte_1                ; 
	reg   [8:0]      drv_chb_mst_byte_2                ; 
	reg   [8:0]      drv_chb_mst_byte_3                ; 
	reg   [8:0]      drv_chb_mst_byte_4                ; 
	reg   [8:0]      drv_chb_mst_byte_5                ; 
	reg   [8:0]      drv_chb_mst_byte_6                ; 
	
	wire  drv_chb_mst_scl ;
	wire  drv_chb_mst_sda ;
	wire  drv_chb_mst_idle;
	
	
	//slave driver signals
		//cha
	reg drv_cha_slv_en ;

	reg [8:0] drv_cha_slv_byte_0  ; 
	reg [8:0] drv_cha_slv_byte_1  ;
	reg [8:0] drv_cha_slv_byte_2  ;
	reg [8:0] drv_cha_slv_byte_3  ;
	reg [8:0] drv_cha_slv_byte_4  ;
	reg [8:0] drv_cha_slv_byte_5  ;  
	reg [8:0] drv_cha_slv_byte_6  ;
	
	reg [2:0] drv_cha_slv_hiz_after_byte;
	
	wire drv_cha_slv_sda ;
	
		//chb
	reg drv_chb_slv_en ;

	reg [8:0] drv_chb_slv_byte_0  ; 
	reg [8:0] drv_chb_slv_byte_1  ;
	reg [8:0] drv_chb_slv_byte_2  ;
	reg [8:0] drv_chb_slv_byte_3  ;
	reg [8:0] drv_chb_slv_byte_4  ;
	reg [8:0] drv_chb_slv_byte_5  ;  
	reg [8:0] drv_chb_slv_byte_6  ;
	
	reg [2:0] drv_chb_slv_hiz_after_byte;
	
	wire drv_chb_slv_sda ;
	
	

	//channel a timing monitor
	
	
		reg [511:0] mon_cha_test_type   ;
		reg [511:0] mon_cha_test_subtype;
		reg mon_cha_en_timing_check              ;
		reg mon_cha_clr_all                      ;
		wire [ 31:0]  mon_cha_num_events         ;
		wire [255:0]  mon_cha_events             ;
		wire          mon_cha_timing_check_err   ;
		
	//channel b timing monitor
			
		reg [511:0] mon_chb_test_type   ;
		reg [511:0] mon_chb_test_subtype;
		reg mon_chb_en_timing_check              ;
		reg mon_chb_clr_all                      ;
		wire [ 31:0]  mon_chb_num_events         ;
		wire [255:0]  mon_chb_events             ;
		wire          mon_chb_timing_check_err   ;
		
		
	//optional signal monitor
	reg mon_opt_rstn;
	
	wire [31:0] mon_opt_cnt_idle_timeout ;
	wire [31:0] mon_opt_cnt_bit_violation;
	wire [31:0] mon_opt_cnt_cha_stuck    ;
	wire [31:0] mon_opt_cnt_chb_stuck    ;
	
	
	`ifdef FAST_F_REF /////////////////////////////////
		always #5          i_clk            = ~i_clk;        //period 10ns
		always #50         f_ref_unsync     = ~f_ref_unsync; //period 100ns
	
	`else /////////////////////////////////////////////
		always #125        i_clk            = ~i_clk;        //period 250ns
		always #500        f_ref_unsync     = ~f_ref_unsync; //period 1us
	
	`endif ////////////////////////////////////////////
	
	
	always #8_000_000 f_ref_slow_unsync = ~f_ref_slow_unsync; // 16ms period. 
	
	always @(posedge i_clk) begin
		i_f_ref      <= f_ref_unsync;
		i_f_ref_slow <= f_ref_slow_unsync;
	end
	
	
	
	
	// ========    UNIT UNDER TEST ====================================
	// ========    UNIT UNDER TEST ====================================
	// ========    UNIT UNDER TEST ====================================
	i2c_passthru #(
	
		.INFILTER_EN_2FF_SYNC         (INFILTER_EN_2FF_SYNC        ),
		.INFILTER_NUM_CLKS_WIDTH      (INFILTER_NUM_CLKS_WIDTH     ),
		.INFILTER_NUM_CLKS_HI2LO_SDA  (INFILTER_NUM_CLKS_HI2LO_SDA ),
		.INFILTER_NUM_CLKS_LO2HI_SDA  (INFILTER_NUM_CLKS_LO2HI_SDA ),
		.INFILTER_NUM_CLKS_HI2LO_SCL  (INFILTER_NUM_CLKS_HI2LO_SCL ),
		.INFILTER_NUM_CLKS_LO2HI_SCL  (INFILTER_NUM_CLKS_LO2HI_SCL ),
		.REG_OUTPUTS                  (0                           ),
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
	
	
	// ========    DRIVERS ====================================

	driver_msti2c u_driver_cha_mst(
		.i_scl                   ( cha_scl                           ),
		.i_sda                   ( cha_sda                           ),
		.i_start                 (drv_cha_mst_start                 ),  
		.i_scl_lo_timing         (drv_cha_mst_scl_lo_timing         ), //[31:0]
		.i_scl_hi_timing         (drv_cha_mst_scl_hi_timing         ), //[31:0]
		.i_num_bytes             (drv_cha_mst_num_bytes             ), //[2:0] 
		.i_repeatstart_after_byte(drv_cha_mst_repeatstart_after_byte), //[2:0] 
		.i_stop_after_byte       (drv_cha_mst_stop_after_byte       ), //[2:0] 
		.i_byte_0                (drv_cha_mst_byte_0                ), //[8:0] 
		.i_byte_1                (drv_cha_mst_byte_1                ), //[8:0] 
		.i_byte_2                (drv_cha_mst_byte_2                ), //[8:0] 
		.i_byte_3                (drv_cha_mst_byte_3                ), //[8:0] 
		.i_byte_4                (drv_cha_mst_byte_4                ), //[8:0] 
		.i_byte_5                (drv_cha_mst_byte_5                ), //[8:0] 
		.i_byte_6                (drv_cha_mst_byte_6                ), //[8:0] 
	
		.o_scl (drv_cha_mst_scl ),
		.o_sda (drv_cha_mst_sda ),
		.o_idle(drv_cha_mst_idle)
	);
	

	driver_msti2c u_driver_chb_mst(
		.i_scl                   ( chb_scl                           ),
		.i_sda                   ( chb_sda                           ),
		.i_start                 (drv_chb_mst_start                 ),  
		.i_scl_lo_timing         (drv_chb_mst_scl_lo_timing         ), //[31:0]
		.i_scl_hi_timing         (drv_chb_mst_scl_hi_timing         ), //[31:0]
		.i_num_bytes             (drv_chb_mst_num_bytes             ), //[2:0] 
		.i_repeatstart_after_byte(drv_chb_mst_repeatstart_after_byte), //[2:0] 
		.i_stop_after_byte       (drv_chb_mst_stop_after_byte       ), //[2:0] 
		.i_byte_0                (drv_chb_mst_byte_0                ), //[8:0] 
		.i_byte_1                (drv_chb_mst_byte_1                ), //[8:0] 
		.i_byte_2                (drv_chb_mst_byte_2                ), //[8:0] 
		.i_byte_3                (drv_chb_mst_byte_3                ), //[8:0] 
		.i_byte_4                (drv_chb_mst_byte_4                ), //[8:0] 
		.i_byte_5                (drv_chb_mst_byte_5                ), //[8:0] 
		.i_byte_6                (drv_chb_mst_byte_6                ), //[8:0] 
	
		.o_scl (drv_chb_mst_scl ),
		.o_sda (drv_chb_mst_sda ),
		.o_idle(drv_chb_mst_idle)
	);
	
	
	driver_slvi2c u_driver_cha_slv(
		.i_en    (drv_cha_slv_en    ),
		.i_scl   (cha_scl           ),
		.i_sda   (cha_sda           ),
		.i_byte_0(drv_cha_slv_byte_0),
		.i_byte_1(drv_cha_slv_byte_1),
		.i_byte_2(drv_cha_slv_byte_2),
		.i_byte_3(drv_cha_slv_byte_3),
		.i_byte_4(drv_cha_slv_byte_4),
		.i_byte_5(drv_cha_slv_byte_5),   
		.i_byte_6(drv_cha_slv_byte_6),
		
		.i_extra_hiz_bit_after_byte( drv_cha_slv_hiz_after_byte ),
		
		.o_sda   (drv_cha_slv_sda   )
	);
	
	
	driver_slvi2c u_driver_chb_slv(
		.i_en    (drv_chb_slv_en    ),
		.i_scl   (chb_scl           ),
		.i_sda   (chb_sda           ),
		.i_byte_0(drv_chb_slv_byte_0),
		.i_byte_1(drv_chb_slv_byte_1),
		.i_byte_2(drv_chb_slv_byte_2),
		.i_byte_3(drv_chb_slv_byte_3),
		.i_byte_4(drv_chb_slv_byte_4),
		.i_byte_5(drv_chb_slv_byte_5),   
		.i_byte_6(drv_chb_slv_byte_6),
		
		.i_extra_hiz_bit_after_byte( drv_chb_slv_hiz_after_byte ),

		
		.o_sda   (drv_chb_slv_sda   )
	);
	
	
	
	// ========    MONITORS ====================================
	reg [511:0] mon_cha_fail_substr = "channel a timing fail";
	mon_i2c #(
		.DEF_MON_EVENT_0( `MON_EVENT_0),
		.DEF_MON_EVENT_1( `MON_EVENT_1),
		.DEF_MON_EVENT_P( `MON_EVENT_P),
		.DEF_MON_EVENT_S( `MON_EVENT_S)
		
	) u_monitor_cha (
	
		.test_type   ( mon_cha_test_type   ),
		.test_subtype( mon_cha_test_subtype),
		.fail_substr ( mon_cha_fail_substr ),
		
		.i_scl( cha_scl                            ),
		.i_sda( cha_sda                            ),
		
		.i_en_timing_check( mon_cha_en_timing_check),
		.i_clr_all        ( mon_cha_clr_all        ),
		
		.i_t_low          (  NS_T_LOW_MIN           ),
		.i_t_su           (  NS_T_SU_DAT_MIN        ),
		
		.o_num_events      (mon_cha_num_events      ), 
		.o_events          (mon_cha_events          ),
		.o_timing_check_err(mon_cha_timing_check_err)
	);
	
	reg [511:0] mon_chb_fail_substr = "channel b timing fail";
	mon_i2c #(
		.DEF_MON_EVENT_0( `MON_EVENT_0),
		.DEF_MON_EVENT_1( `MON_EVENT_1),
		.DEF_MON_EVENT_P( `MON_EVENT_P),
		.DEF_MON_EVENT_S( `MON_EVENT_S)
		
	) u_monitor_chb(
		.test_type   (),
		.test_subtype(),
	
		.fail_substr( mon_chb_fail_substr),
		.i_scl(  chb_scl ),
		.i_sda(  chb_sda ),
		
		.i_en_timing_check( mon_chb_en_timing_check),
		.i_clr_all        ( mon_chb_clr_all        ),
		
		.i_t_low          (  NS_T_LOW_MIN           ),
		.i_t_su           (  NS_T_SU_DAT_MIN        ),
		
		.o_num_events      (mon_chb_num_events      ), 
		.o_events          (mon_chb_events          ),
		.o_timing_check_err(mon_chb_timing_check_err)
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
	
	
	// ========    SCL / SDA OPEN DRAIN LOGIC ====================================

	//channel A  open-drain logic
	always @(*) begin
		if( o_cha_scl & drv_cha_mst_scl                  ) cha_scl <= #time_mst_rise 1'b1;
		else                                               cha_scl <= #time_mst_fall 1'b0;
	end
	
	always @(*) begin
		if( o_cha_sda & drv_cha_mst_sda & drv_cha_slv_sda) cha_sda <= #time_mst_rise 1'b1;
		else                                               cha_sda <= #time_mst_fall 1'b0;
	end

	//channel B open-drain logic
	always @(*) begin
		if( o_chb_scl & drv_chb_mst_scl                   ) chb_scl <= #time_slv_rise 1'b1;
		else                                                chb_scl <= #time_slv_fall 1'b0;
		
	end

	always @(*) begin
		if( o_chb_sda & drv_chb_mst_sda & drv_chb_slv_sda ) chb_sda <= #time_slv_rise 1'b1;
		else                                                chb_sda <= #time_slv_fall 1'b0;
	end
	
	
	
	// ========    TB ENTRY POINT ====================================
	integer failed = 0;
	initial begin
		$timeformat(-6,3, "us", 12);
		init_vars();
		
		rst_uut();
		i2c_protocol_basic_test();
		//i2c_protocol_test();

		if( failed) $display(" ! ! !  TEST FAILED ! ! !");
		else        $display(" Test Passed ");
		$stop();
	end
	

	// ========   HELPER TASKS AND FUNCTIONS ============================
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
			
			time_mst_rise         = 32'h0000_0000;
			time_mst_fall         = 32'h0000_0000;
			
			time_slv_rise         = 32'h0000_0000;
			time_slv_fall         = 32'h0000_0000;
			
			mon_cha_en_timing_check = 0;
			mon_chb_en_timing_check = 0;
			
			init_drv_cha_mst();
			init_drv_chb_mst();
			init_drv_cha_slv();
			init_drv_chb_slv();
			#1;
			
		end
	endtask
	
	
	task init_drv_cha_mst;
		begin
			
			drv_cha_mst_start                  = 0;  
			drv_cha_mst_scl_lo_timing          = 32'd5000; //[31:0]
			drv_cha_mst_scl_hi_timing          = 32'd5000; //[31:0]
			drv_cha_mst_num_bytes              = 3'h0; //[2:0] 
			drv_cha_mst_repeatstart_after_byte = 3'h0; //[2:0] 
			drv_cha_mst_stop_after_byte        = 3'h0; //[2:0] 
			
			init_drv_cha_mst_bytes();
			
		end
	endtask
	
	
	task init_drv_chb_mst;
		begin
			
			drv_chb_mst_start                  = 0;  
			drv_chb_mst_scl_lo_timing          = 32'd5000; //[31:0]
			drv_chb_mst_scl_hi_timing          = 32'd5000; //[31:0]
			drv_chb_mst_num_bytes              = 3'h0; //[2:0] 
			drv_chb_mst_repeatstart_after_byte = 3'h0; //[2:0] 
			drv_chb_mst_stop_after_byte        = 3'h0; //[2:0] 
			
			init_drv_chb_mst_bytes();
			
		end
	endtask
	
	
	task init_drv_cha_slv;
		begin
			drv_cha_slv_en = 0;
			drv_cha_slv_hiz_after_byte = 3'b111;
			init_drv_cha_slv_bytes();
		end
	endtask
	
	task init_drv_chb_slv;
		begin
			drv_chb_slv_en = 0;
			drv_chb_slv_hiz_after_byte = 3'b111;

			init_drv_chb_slv_bytes();
		end
	endtask
	

	
	task init_drv_cha_mst_bytes;
		begin
			drv_cha_mst_byte_0 = 9'h1FF;      //[8:0] 
			drv_cha_mst_byte_1 = 9'h1FF;      //[8:0] 
			drv_cha_mst_byte_2 = 9'h1FF;      //[8:0] 
			drv_cha_mst_byte_3 = 9'h1FF;      //[8:0] 
			drv_cha_mst_byte_4 = 9'h1FF;      //[8:0] 
			drv_cha_mst_byte_5 = 9'h1FF;      //[8:0] 
			drv_cha_mst_byte_6 = 9'h1FF;      //[8:0] 
		end
	endtask
	
	
	task init_drv_chb_mst_bytes;
		begin
			drv_chb_mst_byte_0 = 9'h1FF;      //[8:0] 
			drv_chb_mst_byte_1 = 9'h1FF;      //[8:0] 
			drv_chb_mst_byte_2 = 9'h1FF;      //[8:0] 
			drv_chb_mst_byte_3 = 9'h1FF;      //[8:0] 
			drv_chb_mst_byte_4 = 9'h1FF;      //[8:0] 
			drv_chb_mst_byte_5 = 9'h1FF;      //[8:0] 
			drv_chb_mst_byte_6 = 9'h1FF;      //[8:0] 
		end
	endtask
	
	
	task init_drv_cha_slv_bytes;
		begin
			drv_cha_slv_byte_0 = 9'h1FF;  
			drv_cha_slv_byte_1 = 9'h1FF;  
			drv_cha_slv_byte_2 = 9'h1FF;  
			drv_cha_slv_byte_3 = 9'h1FF;  
			drv_cha_slv_byte_4 = 9'h1FF;  
			drv_cha_slv_byte_5 = 9'h1FF;  
			drv_cha_slv_byte_6 = 9'h1FF;  
		end
	endtask
	
	
	task init_drv_chb_slv_bytes;
		begin
			drv_chb_slv_byte_0 = 9'h1FF;  
			drv_chb_slv_byte_1 = 9'h1FF;  
			drv_chb_slv_byte_2 = 9'h1FF;  
			drv_chb_slv_byte_3 = 9'h1FF;  
			drv_chb_slv_byte_4 = 9'h1FF;  
			drv_chb_slv_byte_5 = 9'h1FF;  
			drv_chb_slv_byte_6 = 9'h1FF;  
		end
	endtask
	
	
	task copy_drv_cha_mst_args_to_chb;
		begin
			
			drv_chb_mst_start                  = drv_cha_mst_start                  ;
			drv_chb_mst_scl_lo_timing          = drv_cha_mst_scl_lo_timing          ;
			drv_chb_mst_scl_hi_timing          = drv_cha_mst_scl_hi_timing          ;
			drv_chb_mst_num_bytes              = drv_cha_mst_num_bytes              ;
			drv_chb_mst_repeatstart_after_byte = drv_cha_mst_repeatstart_after_byte ;
			drv_chb_mst_stop_after_byte        = drv_cha_mst_stop_after_byte        ;
			
			copy_drv_cha_mst_bytes_to_chb();
			
		end
	endtask
	
	
	task copy_drv_cha_mst_bytes_to_chb;
		begin
			drv_chb_mst_byte_0 = drv_cha_mst_byte_0;  
			drv_chb_mst_byte_1 = drv_cha_mst_byte_1;  
			drv_chb_mst_byte_2 = drv_cha_mst_byte_2;  
			drv_chb_mst_byte_3 = drv_cha_mst_byte_3;  
			drv_chb_mst_byte_4 = drv_cha_mst_byte_4;  
			drv_chb_mst_byte_5 = drv_cha_mst_byte_5;  
			drv_chb_mst_byte_6 = drv_cha_mst_byte_6;  
		
		end
	endtask
	
	
	task copy_drv_cha_slv_args_to_chb;
		begin
		
			drv_chb_slv_hiz_after_byte = drv_cha_slv_hiz_after_byte;
			copy_drv_cha_slv_bytes_to_chb();
		end
	endtask
	
	
	task copy_drv_cha_slv_bytes_to_chb;
		begin
			drv_chb_slv_byte_0 = drv_cha_slv_byte_0;  
			drv_chb_slv_byte_1 = drv_cha_slv_byte_1;  
			drv_chb_slv_byte_2 = drv_cha_slv_byte_2;  
			drv_chb_slv_byte_3 = drv_cha_slv_byte_3;  
			drv_chb_slv_byte_4 = drv_cha_slv_byte_4;  
			drv_chb_slv_byte_5 = drv_cha_slv_byte_5;  
			drv_chb_slv_byte_6 = drv_cha_slv_byte_6;  
		
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
			mon_cha_clr_all = 0;
			mon_chb_clr_all = 0;
			mon_opt_rstn    = 1;
			#1;
			mon_cha_clr_all = 1;
			mon_chb_clr_all = 1;
			mon_opt_rstn    = 0;
			#1;
			mon_cha_clr_all = 0;
			mon_chb_clr_all = 0;
			mon_opt_rstn    = 1;

		end
	endtask
	
	
	task start_cha_mst;
		begin
			drv_cha_mst_start = 1;
			#1;
			drv_cha_mst_start = 0;
		end
	endtask
	
	
	task start_chb_mst;
		begin
			drv_chb_mst_start = 1;
			#1;
			drv_chb_mst_start = 0;
		end
	endtask

	
	function i2c_protocol_test_setaddr;
		input [1:0] conf;
		begin
			case( conf ) 
				2'b00: i2c_protocol_test_setaddr = 9'b0_0000_0000;
				2'b01: i2c_protocol_test_setaddr = 9'b1_0101_0101;
				2'b10: i2c_protocol_test_setaddr = 9'b0_1010_1010;
				2'b11: i2c_protocol_test_setaddr = 9'b1_1111_1111;
			endcase
		end
	endfunction
	
	
	task i2c_protocol_basic_test;
		begin
			//current_test_name = "i2c_protocol_basic_test";
			
			i2c_protocol_addr_r_nack_stop( "i2c test address only", 1'b0);
			i2c_protocol_addr_r_nack_stop( "i2c test address only", 1'b1);
			
			i2c_protocol_addr_w_nack_stop( "i2c test address only", 1'b0);
			i2c_protocol_addr_w_nack_stop( "i2c test address only", 1'b1);
			
			i2c_protocol_addr_r_ack_stop ( "i2c test address only", 1'b0);
			i2c_protocol_addr_r_ack_stop ( "i2c test address only", 1'b1);
			
			i2c_protocol_addr_w_1byte_data( "i2c test write data", 1'b0);
			i2c_protocol_addr_w_1byte_data( "i2c test write data", 1'b1);
			
			i2c_protocol_addr_w_2byte_data( "i2c test write data", 1'b0);
			i2c_protocol_addr_w_2byte_data( "i2c test write data", 1'b1);
			
			i2c_protocol_addr_r_1byte_data( "i2c test write data", 1'b0);
			i2c_protocol_addr_r_1byte_data( "i2c test write data", 1'b1);
			
			i2c_protocol_addr_r_2byte_data( "i2c test write data", 1'b0);
			i2c_protocol_addr_r_2byte_data( "i2c test write data", 1'b1);

			i2c_protocol_addr_w_1byte_sr_addr_r_1byte( "i2c test write data", 1'b0);
			i2c_protocol_addr_w_1byte_sr_addr_r_1byte( "i2c test write data", 1'b1);
			

			//#10_000;
			//i2c_protocol_basic_test_pass( 8'h00, 9'h00, 1'b0);
			//#5000;
			//i2c_protocol_basic_test_pass( 9'h00, 9'h00, 1'b1);
			//i2c_protocol_basic_test_pass( 9'h55, 9'hAA, 1'b0);
			//i2c_protocol_basic_test_pass( 9'h55, 9'hAA, 1'b1);
			//i2c_protocol_basic_test_pass( 9'hAA, 9'h55, 1'b0);
			//i2c_protocol_basic_test_pass( 9'hAA, 9'h55, 1'b1);
			//i2c_protocol_basic_test_pass( 9'hFF, 9'hFF, 1'b0);
			//i2c_protocol_basic_test_pass( 9'hFF, 9'hFF, 1'b1);

		end
	endtask
	

	
	function all_idle;
		input nc;
		begin
			all_idle  = drv_cha_mst_idle && drv_chb_mst_idle && cha_scl && cha_sda && chb_scl && chb_sda;
		end
	endfunction
	
	
	//task tb_timeout_fail;
	//	input [511:0] str_suberr;
	//	begin
	//			$display("-------  Failed test: %s ------", current_test_name);
	//			$display("-------  subpass config: %b ------", current_test_pass_config);
	//			$display("    time: %t", $realtime);
	//			$display("    %s", str_lalign(str_suberr) );
	//			$display("    testbench timeout occured");
	//		failed = 1;
	//	end
	//endtask
	
	
	task i2c_protocol_addr_r_nack_stop;
		input [511:0] test_type;
		input en_chb_is_mst;

		reg   [511:0] test_subtype;
		reg   [  6:0] i2c_addr;
		begin
				mon_cha_test_type    = test_type   ;
				mon_chb_test_type    = test_type   ;
				
				test_subtype = "address, read mode,  no ack, stop" ;
				mon_cha_test_subtype = test_subtype;
				mon_chb_test_subtype = test_subtype;
				
				i2c_addr = 7'h2A;
				
				//setup monitors
				rst_all_mon();
				mon_cha_en_timing_check = 1;
				mon_chb_en_timing_check = 1;
				
				//setup slaves
				init_drv_cha_slv_bytes();
				copy_drv_cha_slv_bytes_to_chb();
				drv_cha_slv_en =  en_chb_is_mst;
				drv_chb_slv_en = !en_chb_is_mst;
				
				//setup master
				drv_cha_mst_scl_lo_timing          = 32'd5000;
				drv_cha_mst_scl_hi_timing          = 32'd4700;
				
				drv_cha_mst_num_bytes             = 3'b001;
				drv_cha_mst_repeatstart_after_byte= 3'b111;
				drv_cha_mst_stop_after_byte       = 3'b000;
				
				init_drv_cha_mst_bytes();
				drv_cha_mst_byte_0                = {i2c_addr, 1'b1, 1'b1};
				
				copy_drv_cha_mst_args_to_chb();
				
				if( en_chb_is_mst)   start_chb_mst();
				else                 start_cha_mst();
				
				wait_all_idle(test_type, test_subtype, NS_T_HI_MAX);
	
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel A"},
					32'd11 ,                     //	.num_expctd
					mon_cha_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {7'h2A, 1'b1, 1'b1} ),    
						`MON_EVENT_P                                            
					},                                                         
					mon_cha_events               //	.actual
				);                               //);
				
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel B"},

					32'd11 ,                     //	.num_expctd
					mon_chb_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {7'h2A, 1'b1, 1'b1} ),    
						`MON_EVENT_P                                            
					},                                                         
					mon_chb_events               //	.actual
				);                               //);
				#5000;
				
		end
	endtask
	
	
	
	task i2c_protocol_addr_w_nack_stop;
		input [511:0] test_type;
		input en_chb_is_mst;

		reg   [511:0] test_subtype;
		reg   [  6:0] i2c_addr;
		begin
				mon_cha_test_type    = test_type   ;
				mon_chb_test_type    = test_type   ;
				
				test_subtype = "address, write mode,  no ack, stop" ;
				mon_cha_test_subtype = test_subtype;
				mon_chb_test_subtype = test_subtype;
				
				i2c_addr = 7'h2A;
				
				//setup monitors
				rst_all_mon();
				mon_cha_en_timing_check = 1;
				mon_chb_en_timing_check = 1;
				
				//setup slaves
				init_drv_cha_slv_bytes();
				copy_drv_cha_slv_bytes_to_chb();
				drv_cha_slv_en =  en_chb_is_mst;
				drv_chb_slv_en = !en_chb_is_mst;
				
				//setup master
				drv_cha_mst_scl_lo_timing          = 32'd5000;
				drv_cha_mst_scl_hi_timing          = 32'd4700;
				
				drv_cha_mst_num_bytes             = 3'b001;
				drv_cha_mst_repeatstart_after_byte= 3'b111;
				drv_cha_mst_stop_after_byte       = 3'b000;
				
				init_drv_cha_mst_bytes();
				drv_cha_mst_byte_0                = {i2c_addr, 1'b0, 1'b1};
				
				copy_drv_cha_mst_args_to_chb();
				
				if( en_chb_is_mst)   start_chb_mst();
				else                 start_cha_mst();
				
				wait_all_idle(test_type, test_subtype, NS_T_HI_MAX);
	
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel A"},

					32'd11 ,                     //	.num_expctd
					mon_cha_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {7'h2A, 1'b0, 1'b1} ),    
						`MON_EVENT_P                                            
					},                                                         
					mon_cha_events               //	.actual
				);                               //);
				
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel B"},

					32'd11 ,                     //	.num_expctd
					mon_chb_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {7'h2A, 1'b0, 1'b1} ),    
						`MON_EVENT_P                                            
					},                                                         
					mon_chb_events               //	.actual
				);                               //);
				#5000;
				
		end
	endtask
	
	
	task i2c_protocol_addr_r_ack_stop;
		input [511:0] test_type;
		input en_chb_is_mst;

		reg   [511:0] test_subtype;
		reg   [  6:0] i2c_addr;
		begin
				mon_cha_test_type    = test_type   ;
				mon_chb_test_type    = test_type   ;
				
				test_subtype = "address, read mode,  ack, stop" ;
				mon_cha_test_subtype = test_subtype;
				mon_chb_test_subtype = test_subtype;
				
				i2c_addr = 7'h2A;
				
				//setup monitors
				rst_all_mon();
				mon_cha_en_timing_check = 1;
				mon_chb_en_timing_check = 1;
				
				//setup slaves
				init_drv_cha_slv_bytes();
				drv_cha_slv_byte_0 = {8'hFF, 1'b0};
				drv_cha_slv_byte_1 = {8'h00, 1'b1};
				copy_drv_cha_slv_bytes_to_chb();
				drv_cha_slv_en =  en_chb_is_mst;
				drv_chb_slv_en = !en_chb_is_mst;
				
				//setup master
				drv_cha_mst_scl_lo_timing          = 32'd5000;
				drv_cha_mst_scl_hi_timing          = 32'd4700;
				
				drv_cha_mst_num_bytes             = 3'b001;
				drv_cha_mst_repeatstart_after_byte= 3'b111;
				drv_cha_mst_stop_after_byte       = 3'b000;
				
				init_drv_cha_mst_bytes();
				drv_cha_mst_byte_0                = {i2c_addr, 1'b1, 1'b1};
				
				copy_drv_cha_mst_args_to_chb();
				
				if( en_chb_is_mst)   start_chb_mst();
				else                 start_cha_mst();
				
				
				if( en_chb_is_mst)  wait_chb_mst_done(test_type, test_subtype, NS_TB_NORM_TIMEOUT);
				else                wait_cha_mst_done(test_type, test_subtype, NS_TB_NORM_TIMEOUT);
				
				#5000;
				
				if( en_chb_is_mst) begin
					check_expctd_i2c_events( 
						test_type,
						{test_subtype[0 +: 480], " channel A"},
						32'd11 ,                     //	.num_expctd
						mon_cha_num_events,          //	.num_actual
						{                            //	.expctd({
							`MON_EVENT_S,                                           
							i2cbyte_to_i2c_event( {7'h2A, 1'b1, 1'b0} ),
							`MON_EVENT_0

						},                                                         
						mon_cha_events               //	.actual
					);                               //);
					
					check_expctd_i2c_events( 
						test_type,
						{test_subtype[0 +: 480], " channel B"},
						32'd10 ,                     //	.num_expctd
						mon_chb_num_events,          //	.num_actual
						{                            //	.expctd({
							`MON_EVENT_S,                                           
							i2cbyte_to_i2c_event( {7'h2A, 1'b1, 1'b0} )
						},                                                         
						mon_chb_events               //	.actual
					);                               //);
				end
				else begin
					check_expctd_i2c_events( 
						test_type,
						{test_subtype[0 +: 480], " channel A"},
						32'd10 ,                     //	.num_expctd
						mon_cha_num_events,          //	.num_actual
						{                            //	.expctd({
							`MON_EVENT_S,                                           
							i2cbyte_to_i2c_event( {7'h2A, 1'b1, 1'b0} )
							
						},                                                         
						mon_cha_events               //	.actual
					);                               //);
					
					check_expctd_i2c_events( 
						test_type,
						{test_subtype[0 +: 480], " channel B"},
						32'd11 ,                     //	.num_expctd
						mon_chb_num_events,          //	.num_actual
						{                            //	.expctd({
							`MON_EVENT_S,                                           
							i2cbyte_to_i2c_event( {7'h2A, 1'b1, 1'b0} ),
							`MON_EVENT_0
						},                                                         
						mon_chb_events               //	.actual
					);                               //);
				
				end
				
				
				wait_all_idle(test_type, test_subtype, NS_T_BUS_STUCK_MAX);

				//#5000;
				#NS_T_HI_MAX;
				
		end
	endtask
	
	
	
	
	task i2c_protocol_addr_w_1byte_data;
		input [511:0] test_type;
		input en_chb_is_mst;

		reg   [511:0] test_subtype;
		reg   [  6:0] i2c_addr;
		reg   [  7:0] i2c_data;
		begin
				mon_cha_test_type    = test_type   ;
				mon_chb_test_type    = test_type   ;
				
				test_subtype = "address, write mode,  ack, data, stop" ;
				mon_cha_test_subtype = test_subtype;
				mon_chb_test_subtype = test_subtype;
				
				i2c_addr = 7'h2A;
				i2c_data = 8'h55;
				
				//setup monitors
				rst_all_mon();
				mon_cha_en_timing_check = 1;
				mon_chb_en_timing_check = 1;
				
				//setup slaves
				init_drv_cha_slv_bytes();
				drv_cha_slv_byte_0 = {8'hFF, 1'b0};
				drv_cha_slv_byte_1 = {8'hFF, 1'b0};
	
				copy_drv_cha_slv_bytes_to_chb();
				drv_cha_slv_en =  en_chb_is_mst;
				drv_chb_slv_en = !en_chb_is_mst;
				
				//setup master
				drv_cha_mst_scl_lo_timing          = 32'd5000;
				drv_cha_mst_scl_hi_timing          = 32'd4700;
				
				drv_cha_mst_num_bytes             = 3'b010;
				drv_cha_mst_repeatstart_after_byte= 3'b111;
				drv_cha_mst_stop_after_byte       = 3'b001;
				
				init_drv_cha_mst_bytes();
				drv_cha_mst_byte_0                = {i2c_addr, 1'b0, 1'b1};
				drv_cha_mst_byte_1                = {      i2c_data, 1'b1};

				copy_drv_cha_mst_args_to_chb();
				
				if( en_chb_is_mst)   start_chb_mst();
				else                 start_cha_mst();
				
				wait_all_idle(test_type, test_subtype, NS_T_HI_MAX);
	
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel A"},
					32'd20 ,                     //	.num_expctd
					mon_cha_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b0, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						`MON_EVENT_P                                            
					},                                                         
					mon_cha_events               //	.actual
				);                               //);
				
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel B"},

					32'd20 ,                     //	.num_expctd
					mon_chb_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b0, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						`MON_EVENT_P                                            
					},                                                         
					mon_chb_events               //	.actual
				);                               //);
				#5000;
				
		end
	endtask
	
	
	
	task i2c_protocol_addr_w_2byte_data;
		input [511:0] test_type;
		input en_chb_is_mst;

		reg   [511:0] test_subtype;
		reg   [  6:0] i2c_addr;
		reg   [  7:0] i2c_data;
		begin
				mon_cha_test_type    = test_type   ;
				mon_chb_test_type    = test_type   ;
				
				test_subtype = "address, write mode,  ack, 2 bytes data, stop" ;
				mon_cha_test_subtype = test_subtype;
				mon_chb_test_subtype = test_subtype;
				
				i2c_addr = 7'h55;
				i2c_data = 8'hAA;
				
				//setup monitors
				rst_all_mon();
				mon_cha_en_timing_check = 1;
				mon_chb_en_timing_check = 1;
				
				//setup slaves
				init_drv_cha_slv_bytes();
				drv_cha_slv_byte_0 = {8'hFF, 1'b0};
				drv_cha_slv_byte_1 = {8'hFF, 1'b0};
				drv_cha_slv_byte_2 = {8'hFF, 1'b0};

	
				copy_drv_cha_slv_bytes_to_chb();
				drv_cha_slv_en =  en_chb_is_mst;
				drv_chb_slv_en = !en_chb_is_mst;
				
				//setup master
				drv_cha_mst_scl_lo_timing          = 32'd5000;
				drv_cha_mst_scl_hi_timing          = 32'd4700;
				
				drv_cha_mst_num_bytes             = 3'b011;
				drv_cha_mst_repeatstart_after_byte= 3'b111;
				drv_cha_mst_stop_after_byte       = 3'b010;
				
				init_drv_cha_mst_bytes();
				drv_cha_mst_byte_0                = {i2c_addr, 1'b0, 1'b1};
				drv_cha_mst_byte_1                = {      i2c_data, 1'b1};
				drv_cha_mst_byte_2                = {      i2c_data, 1'b1};


				copy_drv_cha_mst_args_to_chb();
				
				if( en_chb_is_mst)   start_chb_mst();
				else                 start_cha_mst();
				
				wait_all_idle(test_type, test_subtype, NS_T_HI_MAX);
	
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel A"},
					32'd29 ,                     //	.num_expctd
					mon_cha_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b0, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						`MON_EVENT_P                                            
					},                                                         
					mon_cha_events               //	.actual
				);                               //);
				
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel B"},

					32'd29 ,                     //	.num_expctd
					mon_chb_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b0, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						`MON_EVENT_P                                            
					},                                                         
					mon_chb_events               //	.actual
				);                               //);
				#5000;
				
		end
	endtask
	
	
	
	
	task i2c_protocol_addr_r_1byte_data;
		input [511:0] test_type;
		input en_chb_is_mst;

		reg   [511:0] test_subtype;
		reg   [  6:0] i2c_addr;
		reg   [  7:0] i2c_data;
		begin
				mon_cha_test_type    = test_type   ;
				mon_chb_test_type    = test_type   ;
				
				test_subtype = "address, read mode,  ack, data, stop" ;
				mon_cha_test_subtype = test_subtype;
				mon_chb_test_subtype = test_subtype;
				
				i2c_addr = 7'h55;
				i2c_data = 8'hAA;
				
				//setup monitors
				rst_all_mon();
				mon_cha_en_timing_check = 1;
				mon_chb_en_timing_check = 1;
				
				//setup slaves
				init_drv_cha_slv_bytes();
				drv_cha_slv_byte_0 = {   8'hFF, 1'b0};
				drv_cha_slv_byte_1 = {i2c_data, 1'b1};
				drv_cha_slv_byte_2 = {1'b1, 8'bxxxx_xxxx};

	
				copy_drv_cha_slv_bytes_to_chb();
				drv_cha_slv_en =  en_chb_is_mst;
				drv_chb_slv_en = !en_chb_is_mst;
				
				//setup master
				drv_cha_mst_scl_lo_timing          = 32'd5000;
				drv_cha_mst_scl_hi_timing          = 32'd4700;
				
				drv_cha_mst_num_bytes             = 3'b010;
				drv_cha_mst_repeatstart_after_byte= 3'b111;
				drv_cha_mst_stop_after_byte       = 3'b001;
				
				init_drv_cha_mst_bytes();
				drv_cha_mst_byte_0                = {i2c_addr, 1'b1, 1'b1};
				drv_cha_mst_byte_1                = {         8'hFF, 1'b1};

				copy_drv_cha_mst_args_to_chb();
				
				if( en_chb_is_mst)   start_chb_mst();
				else                 start_cha_mst();
				
				wait_all_idle(test_type, test_subtype, NS_T_HI_MAX);
	
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel A"},
					32'd20 ,                     //	.num_expctd
					mon_cha_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b1, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b1} ),
						`MON_EVENT_P                                            
					},                                                         
					mon_cha_events               //	.actual
				);                               //);
				
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel B"},

					32'd20 ,                     //	.num_expctd
					mon_chb_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b1, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b1} ),
						`MON_EVENT_P                                            
					},                                                         
					mon_chb_events               //	.actual
				);                               //);
				#5000;
				
		end
	endtask
	
	
	
	
	task i2c_protocol_addr_r_2byte_data;
		input [511:0] test_type;
		input en_chb_is_mst;

		reg   [511:0] test_subtype;
		reg   [  6:0] i2c_addr;
		reg   [  7:0] i2c_data;
		begin
				mon_cha_test_type    = test_type   ;
				mon_chb_test_type    = test_type   ;
				
				test_subtype = "address, read mode,  ack, 2 bytes data, stop" ;
				mon_cha_test_subtype = test_subtype;
				mon_chb_test_subtype = test_subtype;
				
				i2c_addr = 7'h2A;
				i2c_data = 8'h55;
				
				//setup monitors
				rst_all_mon();
				mon_cha_en_timing_check = 1;
				mon_chb_en_timing_check = 1;
				
				//setup slaves
				init_drv_cha_slv_bytes();
				drv_cha_slv_byte_0 = {   8'hFF, 1'b0};
				drv_cha_slv_byte_1 = {i2c_data, 1'b1};
				drv_cha_slv_byte_2 = {i2c_data, 1'b1};
				drv_cha_slv_byte_3 = {1'b1, 8'bxxxx_xxxx};

	
				copy_drv_cha_slv_bytes_to_chb();
				drv_cha_slv_en =  en_chb_is_mst;
				drv_chb_slv_en = !en_chb_is_mst;
				
				//setup master
				drv_cha_mst_scl_lo_timing          = 32'd5000;
				drv_cha_mst_scl_hi_timing          = 32'd4700;
				
				drv_cha_mst_num_bytes             = 3'b011;
				drv_cha_mst_repeatstart_after_byte= 3'b111;
				drv_cha_mst_stop_after_byte       = 3'b010;
				
				init_drv_cha_mst_bytes();
				drv_cha_mst_byte_0                = {i2c_addr, 1'b1, 1'b1};
				drv_cha_mst_byte_1                = {         8'hFF, 1'b0};
				drv_cha_mst_byte_2                = {         8'hFF, 1'b1};

				copy_drv_cha_mst_args_to_chb();
				
				if( en_chb_is_mst)   start_chb_mst();
				else                 start_cha_mst();
				
				wait_all_idle(test_type, test_subtype, NS_T_HI_MAX);
	
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel A"},
					32'd29 ,                     //	.num_expctd
					mon_cha_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b1, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b1} ),

						`MON_EVENT_P                                            
					},                                                         
					mon_cha_events               //	.actual
				);                               //);
				
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel B"},

					32'd29 ,                     //	.num_expctd
					mon_chb_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b1, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b1} ),
						`MON_EVENT_P                                            
					},                                                         
					mon_chb_events               //	.actual
				);                               //);
				#5000;
				
		end
	endtask
	
	
	
	task i2c_protocol_addr_w_1byte_sr_addr_r_1byte;
		input [511:0] test_type;
		input en_chb_is_mst;

		reg   [511:0] test_subtype;
		reg   [  6:0] i2c_addr;
		reg   [  7:0] i2c_data;
		begin
				mon_cha_test_type    = test_type   ;
				mon_chb_test_type    = test_type   ;
				
				///////////////"123456789abcdef 123456789abcdef 123456789abcdef 123456789abcdef 
				test_subtype = "addr wr ack, 1 byte , repeat start, addr, rd, 1 byte" ;
				mon_cha_test_subtype = test_subtype;
				mon_chb_test_subtype = test_subtype;
				
				i2c_addr = 7'h2A;
				i2c_data = 8'h55;
				
				//setup monitors
				rst_all_mon();
				mon_cha_en_timing_check = 1;
				mon_chb_en_timing_check = 1;
				
				//setup slaves
				drv_cha_slv_hiz_after_byte = 3'b001;
				
				init_drv_cha_slv_bytes();
				drv_cha_slv_byte_0 = {   8'hFF, 1'b0};
				drv_cha_slv_byte_1 = {   8'hFF, 1'b0};
				drv_cha_slv_byte_2 = {   8'hFF, 1'b0};
				drv_cha_slv_byte_3 = {i2c_data, 1'b1};
				drv_cha_slv_byte_4 = {1'b1, 8'bxxxx_xxxx};

	
				copy_drv_cha_slv_args_to_chb();
				drv_cha_slv_en =  en_chb_is_mst;
				drv_chb_slv_en = !en_chb_is_mst;
				
				//setup master
				drv_cha_mst_scl_lo_timing          = 32'd5000;
				drv_cha_mst_scl_hi_timing          = 32'd4700;
				
				drv_cha_mst_num_bytes             = 3'b100;
				drv_cha_mst_repeatstart_after_byte= 3'b001;
				drv_cha_mst_stop_after_byte       = 3'b011;
				
				init_drv_cha_mst_bytes();
				drv_cha_mst_byte_0                = {i2c_addr, 1'b0, 1'b1};
				drv_cha_mst_byte_1                = {      i2c_data, 1'b1};
				drv_cha_mst_byte_2                = {i2c_addr, 1'b1, 1'b1};
				drv_cha_mst_byte_3                = {         8'hFF, 1'b1};

				copy_drv_cha_mst_args_to_chb();
				
				if( en_chb_is_mst)   start_chb_mst();
				else                 start_cha_mst();
				
				wait_all_idle(test_type, test_subtype, NS_T_HI_MAX);
	
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel A"},
					32'd39 ,                     //	.num_expctd
					mon_cha_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b0, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						`MON_EVENT_S,
						i2cbyte_to_i2c_event( {i2c_addr, 1'b1, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b1} ),
						`MON_EVENT_P                                            
					},                                                         
					mon_cha_events               //	.actual
				);                               //);
				
				check_expctd_i2c_events( 
					test_type,
					{test_subtype[0 +: 480], " channel B"},

					32'd39 ,                     //	.num_expctd
					mon_chb_num_events,          //	.num_actual
					{                            //	.expctd({
						`MON_EVENT_S,                                           
						i2cbyte_to_i2c_event( {i2c_addr, 1'b0, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b0} ),
						`MON_EVENT_S,
						i2cbyte_to_i2c_event( {i2c_addr, 1'b1, 1'b0} ),
						i2cbyte_to_i2c_event( {      i2c_data, 1'b1} ),
						`MON_EVENT_P                                            
					},                                                         
					mon_chb_events               //	.actual
				);                               //);
				#5000;
				
		end
	endtask
	
	
	
	
	//task i2c_protocol_basic_test_pass;
	//	input [7:0] mst_dat;
	//	input [7:0] slv_dat;
	//	input en_chb_is_mst;
	//	
	//	reg [511:0] test_type;
	//	reg [511:0] test_subtype;
	//	begin
	//	
	//		test_type    = "i2c basic read write test";
	//		mon_cha_test_type    = test_type   ;
	//		mon_chb_test_type    = test_type   ;
	//
	//		
	//		// =======  first test =================
	//		test_subtype = "write address only, no ack" ;
	//		mon_cha_test_subtype = test_subtype;
	//		mon_chb_test_subtype = test_subtype;
	//		
	//		//setup monitors
	//		rst_all_mon();
	//		mon_cha_en_timing_check = 1;
	//		mon_chb_en_timing_check = 1;
	//		
	//		//setup slaves
	//		init_drv_cha_slv_bytes();
	//		copy_drv_cha_slv_bytes_to_chb();
	//		drv_cha_slv_en =  en_chb_is_mst;
	//		drv_chb_slv_en = !en_chb_is_mst;
	//		
	//		//setup master
	//		drv_cha_mst_scl_lo_timing          = 32'd5000;
	//		drv_cha_mst_scl_hi_timing          = 32'd4700;
	//		
	//		drv_cha_mst_num_bytes             = 3'b001;
	//		drv_cha_mst_repeatstart_after_byte= 3'b111;
	//		drv_cha_mst_stop_after_byte       = 3'b000;
	//		
	//		init_drv_cha_mst_bytes();
	//		drv_cha_mst_byte_0                = {mst_dat, 1'b1};
	//		
	//		copy_drv_cha_mst_args_to_chb();
	//		
	//		if( en_chb_is_mst)   start_chb_mst();
	//		else                 start_cha_mst();
	//		
	//		wait_all_idle(test_type, test_subtype, NS_TB_LONG_TIMEOUT);
	//
	//		check_expctd_i2c_events( 
	//			test_type,
	//			test_subtype,
	//			32'd11 ,                     //	.num_expctd
	//			mon_cha_num_events,          //	.num_actual
	//			{                            //	.expctd({
	//				`MON_EVENT_S,                                           
	//				i2cbyte_to_i2c_event( {8'h00, 1'b1} ),    
	//				`MON_EVENT_P                                            
	//			},                                                         
	//			mon_cha_events               //	.actual
	//		);                               //);
	//		
	//		check_expctd_i2c_events( 
	//			test_type,
	//			test_subtype,
	//			32'd11 ,                     //	.num_expctd
	//			mon_chb_num_events,          //	.num_actual
	//			{                            //	.expctd({
	//				`MON_EVENT_S,                                           
	//				i2cbyte_to_i2c_event( {8'h00, 1'b1} ),    
	//				`MON_EVENT_P                                            
	//			},                                                         
	//			mon_chb_events               //	.actual
	//		);                               //);
	//		#5000;
	//
	//	end
	//endtask
		

	
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
	

	//align str to left side
	function [511:0] str_lalign;
		input [511:0] str;
		begin
			//$display("str_lalign debug str[511 -:8]: %h", str_lalign[511 -:8]);
			str_lalign = str;
			while( str_lalign[ 511 -:8] == 8'h00  ||
			       str_lalign[ 511 -:8] == 8'h10  ||
			       str_lalign[ 511 -:8] === 8'hXX ||
			       str_lalign[ 511 -:8] === 8'hZZ 
			
			) begin
				str_lalign = str_lalign << 8;
			end
		end
	endfunction
	

	task check_expctd_i2c_events;
		input [511:0] str_err;
		input [511:0] str_suberr;
		input [31:0]  num_expctd;
		input [31:0]  num_actual;

		input [255:0] expctd;
		input [255:0] actual;
		reg        break_loop;
		reg [31:0] i;
		begin
		
			if( num_expctd !== num_actual) begin
				$display("-------  Failed test ------");
				$display("    failure type   : %s", str_lalign( str_err   ));
				$display("    failure subtype: %s", str_lalign( str_suberr));
				$display("    time: %t", $realtime);
				$display("    %s", str_lalign(str_suberr) );
				$display("    number of expected events dont match actual");
				$display("    expected: %d", num_expctd);
				$display("    actual  : %d", num_actual);
				failed = 1;
			end
			
			break_loop = 0;
			for( i=0; (i< num_expctd) && !break_loop; i=i+1'b1) begin
			
				if( expctd[ 2*i +: 2] !== actual[ 2*i +: 2]) begin
					$display("-------  Failed test ------");
					$display("    failure type   : %s", str_lalign( str_err   ));
					$display("    failure subtype: %s", str_lalign( str_suberr));
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


	task check_expctd_opt_events;
		input [31:0] expctd_cnt_idle_timeout ;
		input [31:0] expctd_cnt_bit_violation;
		input [31:0] expctd_cnt_cha_stuck    ;
		input [31:0] expctd_cnt_chb_stuck    ;
		input [31:0] actual_cnt_idle_timeout ;
		input [31:0] actual_cnt_bit_violation;
		input [31:0] actual_cnt_cha_stuck    ;
		input [31:0] actual_cnt_chb_stuck    ;
		begin
		
				if( expctd_cnt_idle_timeout !== actual_cnt_idle_timeout) begin
					//$display("-------  Failed test: %s ------", current_test_name);
					//$display("-------  subpass config: %b ------", current_test_pass_config);
					$display("    time: %t", $realtime);
					$display("    optional idle timeout count mismatch");
					$display("    expected: %d", expctd_cnt_idle_timeout);
					$display("    actual  : %d", actual_cnt_idle_timeout);
					failed = 1;
				end
				
				if( expctd_cnt_bit_violation !== actual_cnt_bit_violation) begin
					//$display("-------  Failed test: %s ------", current_test_name);
					//$display("-------  subpass config: %b ------", current_test_pass_config);
					$display("    time: %t", $realtime);
					$display("    optional idle timeout count mismatch");
					$display("    expected: %d", expctd_cnt_idle_timeout);
					$display("    actual  : %d", actual_cnt_idle_timeout);
					failed = 1;
				end
				
				if( expctd_cnt_cha_stuck !== actual_cnt_cha_stuck) begin
					//$display("-------  Failed test: %s ------", current_test_name);
					//$display("-------  subpass config: %b ------", current_test_pass_config);
					$display("    time: %t", $realtime);
					$display("    optional idle timeout count mismatch");
					$display("    expected: %d", expctd_cnt_idle_timeout);
					$display("    actual  : %d", actual_cnt_idle_timeout);
					failed = 1;
				end
				
				if( expctd_cnt_chb_stuck !== actual_cnt_chb_stuck) begin
					//$display("-------  Failed test: %s ------", current_test_name);
					//$display("-------  subpass config: %b ------", current_test_pass_config);
					$display("    time: %t", $realtime);
					$display("    optional idle timeout count mismatch");
					$display("    expected: %d", expctd_cnt_idle_timeout);
					$display("    actual  : %d", actual_cnt_idle_timeout);
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
	
	
	task wait_all_idle;
		input [511:0] str_err;
		input [511:0] str_suberr;
		input realtime timeout_time;
		
		realtime start_time;
		begin
			start_time = $realtime;
			//while( (!all_idle(0)) && (time_elapsed( start_time) < NS_TB_LONG_TIMEOUT) ) begin
			while( (!all_idle(0)) && (time_elapsed( start_time) < timeout_time) ) begin

				@(posedge i_clk);
			end
			if( !all_idle(0)) fail_tb_timeout(str_err, str_suberr);
		end
	endtask
	
	
	task wait_cha_mst_done;
		input [511:0] str_err;
		input [511:0] str_suberr;
		input realtime timeout_time;
		
		realtime start_time;
		begin
			start_time = $realtime;
			
			while( !drv_cha_mst_idle && (time_elapsed( start_time) < timeout_time) ) begin
				@(posedge i_clk);
			end
			if( !drv_cha_mst_idle) fail_tb_timeout(str_err, str_suberr);
		end
	endtask
	
	
	task wait_chb_mst_done;
		input [511:0] str_err;
		input [511:0] str_suberr;
		input realtime timeout_time;
		
		realtime start_time;
		begin
			start_time = $realtime;
			
			while( !drv_chb_mst_idle && (time_elapsed( start_time) < timeout_time) ) begin
				@(posedge i_clk);
			end
			if( !drv_chb_mst_idle) fail_tb_timeout(str_err, str_suberr);
		end
	endtask
	
	
	//task fail_general;
	//	input [511:0] str_err;
	//	input [511:0] str_suberr;
	//	begin
	//		$display("-------  Failed test  ------", str_err);
	//		$display("    failure type    : %s", str_lalign(str_err   ) );
	//		$display("    failure substype: %s", str_lalign(str_suberr) );
	//		$display("    time            : %t", $realtime);
	//		failed = 1;
	//	end
	//endtask
	
	
	task fail_tb_timeout;
		input [511:0] str_err;
		input [511:0] str_suberr;
		begin
			$display("-------  Failed test  ------", str_err);
			$display("    testbench timeout occured");
			$display("    failure type    : %s", str_lalign(str_err   ) );
			$display("    failure substype: %s", str_lalign(str_suberr) );
			$display("    time            : %t", $realtime);
			failed = 1;
		end
	endtask
	
	
	//task fail_i2c_block_mismatch;
	//	input [511:0] str_err;
	//	input [511:0] str_suberr;
	//	input [8:0]   expctd;
	//	input [8:0]   actual;
	//	begin
	//		$display("-------  Failed test  ------", str_err);
	//		$display("    i2c block mismatch");
	//		$display("    failure type    : %s", str_lalign(str_err   ) );
	//		$display("    failure substype: %s", str_lalign(str_suberr) );
	//		$display("    time            : %t", $realtime);
	//		$display("    expected block  : %h", expctd);
	//		$display("    actual   block  : %h", actual);
	//		failed = 1;
	//	end
	//endtask
	//
	//
	//task check_i2c_block_mismatch;
	//	input [511:0] str_err;
	//	input [511:0] str_suberr;
	//	input [8:0]   expctd;
	//	input [8:0]   actual;
	//	begin
	//		if( expctd !== actual) fail_i2c_block_mismatch(str_err, str_suberr, expctd, actual);
	//	end
	//endtask
	


endmodule


