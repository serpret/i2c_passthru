module i2c_passthru_mstr_det(
	input i_clk        ,
	input i_rstn       ,
	
	input i_cha_idle   ,
	input i_chb_idle   ,
	
	input i_violation  ,
	input i_stuck      ,
	
	output reg o_disconnect,
	output reg o_cha_ismst ,
	output reg o_chb_ismst
);

reg [1:0] state, nxt_state;

localparam ST_IDLE       = 0;
localparam ST_A_MST      = 1;
localparam ST_B_MST      = 2;
localparam ST_DISCONNECT = 3;

//FSM next state and output logic
always @(*) begin
	//default else case
	nxt_state    = state;
	o_disconnect = 1'b0;
	o_cha_ismst  = 1'b0;
	o_chb_ismst  = 1'b0;
	
	case( state) 
		ST_IDLE      :
		begin
			o_disconnect = 1'b1;
			
			if(      !i_cha_idle && !i_chb_idle) nxt_state = ST_DISCONNECT;
			else if( !i_cha_idle &&  i_chb_idle) nxt_state = ST_A_MST;
			else if(  i_cha_idle && !i_chb_idle) nxt_state = ST_B_MST;
		end
		
		ST_A_MST     :
		begin
			o_cha_ismst = 1'b1;
			
			if( i_violation || i_stuck       ) nxt_state = ST_DISCONNECT;
			else if( i_cha_idle && i_chb_idle) nxt_state = ST_IDLE;
			
		end
		
		ST_B_MST     :
		begin
			o_chb_ismst = 1'b1;
			
			if( i_violation || i_stuck       ) nxt_state = ST_DISCONNECT;
			else if( i_cha_idle && i_chb_idle) nxt_state = ST_IDLE;
		end
		
		ST_DISCONNECT:
		begin
			o_disconnect = 1'b1;
			
			if( i_cha_idle && i_chb_idle) nxt_state = ST_IDLE;
		end
		
		default:
		begin
			nxt_state = ST_IDLE;
		end
		
	endcase

end


always @(posedge i_clk) begin
	if(i_rstn) begin
		state <= nxt_state;
	end 
	else begin
		state <= ST_IDLE;
	end
end


endmodule
