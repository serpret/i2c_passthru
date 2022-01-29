//////////////////////////////////////////////////////////////////////////////
//Copyright 2021 Sergy Pretetsky
//
//Permission is hereby granted, free of charge, to any person obtaining a 
//copy of this software and associated documentation files (the "Software"),
//to deal in the Software without restriction, including without 
//limitation the rights to use, copy, modify, merge, publish, distribute,
//sublicense, and/or sell copies of the Software, and to permit persons to
//whom the Software is furnished to do so, subject to the following 
//conditions:
//
//The above copyright notice and this permission notice shall be included 
//in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
//EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
//MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
//IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
//OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE 
//USE OR OTHER DEALINGS IN THE SOFTWARE.
//////////////////////////////////////////////////////////////////////////////



module i2c_passthru_tran_ctrl(
	input i_clk,
	input i_rstn,
	
	input i_mst_scl,
	input i_mst_sda,
	
	output o_go_mst_tx,
	output o_go_slv_tx
	
	output 
	
	//input i_slv_sda
	//input i_slv_scl
	//input i_mst_sda
	//input i_mst_scl
	//input i_slv_sda_is_set
	//input i_slv_scl_is_set
	//input i_mst_sda_is_set
	//input i_mst_scl_is_set
	//
	//output o_slv_nxt_sda
	//output o_slv_nxt_scl
	//output o_slv_sda_enforce
	//output o_slv_scl_enforce
	//output o_mst_nxt_sda
	//output o_mst_nxt_scl
	//output o_mst_sda_enforce
	//output o_mst_scl_enforce

);



reg [3:0] bit_cnt, nxt_bit_cnt;
reg read_bit_captured;
reg read_bit;





//sequential logic that requires reset
always @(posedge clk) begin
	if(rstn) begin
		bit_cnt <= 4'h0;
	end
	else begin
		bit_cnt <= nxt_bit_cnt;
	end

end

always




	

endmodule
	
	
	