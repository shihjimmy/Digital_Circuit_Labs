module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, // cipher text y
	input  [255:0] i_d, // private key
	input  [255:0] i_n,
	output [255:0] o_a_pow_d, // plain text x
	output         o_finished
);
// operations for RSA256 decryption
// namely, the Montgomery algorithm

localparam IDLE = 2'b00;
localparam PRO = 2'b01;
localparam MONT = 2'b10;
localparam CALC = 2'b11;

logic [8:0] count_r,count_w; // calculate how many time we stay in mont
logic [1:0] state_r,state_w;
logic [0:0] finish_r,finish_w;
logic [255:0] answer_r,answer_w;

logic [0:0] start_mont_r,start_mont_w;
logic [0:0] check_mont1_r,check_mont1_w;
logic [0:0] start_mont1;
logic [255:0] Mont_1_a_r,Mont_1_a_w;
logic [255:0] Mont_1_b_r,Mont_1_b_w;
logic [255:0] Mont_2_a_r,Mont_2_a_w;
logic [255:0] Mont_2_b_r,Mont_2_b_w;
logic [0:0] mont1_finish;
logic [0:0] mont2_finish;
logic [255:0] mont1_result;  
logic [255:0] mont2_result;  

logic [255:0] pro_result;
logic [0:0] pro_finish;

assign o_a_pow_d = answer_r;
assign o_finished = finish_r;
assign start_mont1 = check_mont1_r && start_mont_r;

PRODUCT Product(.i_clk(i_clk),.i_rst(i_rst),.i_start(i_start),
				.i_n(i_n),.i_a(i_a),.o_finished(pro_finish),
				.pro_result(pro_result));
Montgomery Mont_1(.i_clk(i_clk),.i_rst(i_rst),.i_start(start_mont1),
				  .i_n(i_n),.i_a(Mont_1_a_r),.i_b(Mont_1_b_r),
				  .o_finished(mont1_finish),.mont_result(mont1_result));
Montgomery Mont_2(.i_clk(i_clk),.i_rst(i_rst),.i_start(start_mont_r),
				  .i_n(i_n),.i_a(Mont_2_a_r),.i_b(Mont_2_b_r),
				  .o_finished(mont2_finish),.mont_result(mont2_result));

always_comb begin
	count_w = count_r;
	finish_w = finish_r;
	check_mont1_w = check_mont1_r;
	start_mont_w = start_mont_r;
	Mont_1_a_w = Mont_1_a_r;
	Mont_1_b_w = Mont_1_b_r;
	Mont_2_a_w = Mont_2_a_r;
	Mont_2_b_w = Mont_2_b_r;
	answer_w = answer_r;
	state_w = state_r;

	case(state_r)
		IDLE:begin
			if(i_start) begin
				state_w = PRO;
				start_mont_w = 0;
				count_w = 0;
				answer_w = 0;
				finish_w = 0;
			end
			else begin 
				//do nothing
			end
		end

		PRO:begin
			if(pro_finish) begin
				finish_w = 0;
				count_w = 0;
				state_w = MONT;
				start_mont_w = 1;
				Mont_1_a_w = 1;
				Mont_1_b_w = pro_result;
				Mont_2_a_w = pro_result;
				Mont_2_b_w = pro_result;
				if(i_d[0]) begin
					check_mont1_w = 1;
				end
				else begin
					check_mont1_w = 0;
				end
			end
			else begin 
				//do nothing
			end
		end

		MONT:begin
			start_mont_w = 0;
			finish_w = 0;
			if(mont2_finish) begin
				state_w = CALC;
				count_w = count_r + 1;
			end
			else begin
				//do nothing
			end
		end

		CALC:begin
			if(!count_r[8]) begin
				state_w = MONT;
				start_mont_w = 1;
				if(check_mont1_r)
					Mont_1_a_w = mont1_result;
				else
					Mont_1_a_w = Mont_1_a_r;
				Mont_1_b_w = mont2_result;
				Mont_2_a_w = mont2_result;
				Mont_2_b_w = mont2_result;
				if(i_d[count_r]) begin
					check_mont1_w = 1;
				end
				else begin
					check_mont1_w = 0;
				end
			end
			else begin
				state_w = IDLE;
				answer_w = mont1_result;
				finish_w = 1;
				start_mont_w = 0;
				count_w = 0;
			end
		end

		default:begin
			count_w = 0;
			finish_w = 0;
			start_mont_w = 0;
			Mont_1_a_w = 1;
			Mont_1_b_w = 0;
			Mont_2_a_w = 0;
			Mont_2_b_w = 0;
			answer_w = 0;
			state_w = IDLE;
		end
	endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
	if(i_rst) begin
		state_r <= IDLE;
		count_r <= 0;
		finish_r <= 0;
		answer_r <= 0;
		start_mont_r <= 0;
		check_mont1_r <= 0;
		Mont_1_a_r <= 0;
		Mont_1_b_r <= 0;
		Mont_2_a_r <= 0;
		Mont_2_b_r <= 0;
	end
	else begin
		state_r <= state_w;
		count_r <= count_w;
		finish_r <= finish_w;
		answer_r <= answer_w;
		start_mont_r <= start_mont_w;
		check_mont1_r <= check_mont1_w;
		Mont_1_a_r <= Mont_1_a_w;
		Mont_1_b_r <= Mont_1_b_w;
		Mont_2_a_r <= Mont_2_a_w;
		Mont_2_b_r <= Mont_2_b_w;
	end
end

endmodule

module PRODUCT(
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_n,
	input  [255:0] i_a, //cypher text y
	output [0:0]   o_finished,
	output [255:0] pro_result
);

localparam IDLE = 1'b0;
localparam RUN = 1'b1;

logic [0:0] state_r,state_w;
logic [0:0] finish_r,finish_w;
logic [8:0] count_r,count_w;
logic [257:0] m_r,m_w;
logic [257:0] t_r,t_w;

assign pro_result = m_r[255:0];
assign o_finished = finish_r;

always_comb begin
	state_w = state_r;
	m_w = m_r;
	t_w = t_r;
	count_w = count_r;
	finish_w = finish_r;

	case(state_r)
		IDLE:begin
			if(i_start) begin
				state_w = RUN;
				m_w = 0;
				t_w = i_a;
				count_w = 0;
				finish_w = 0;
			end
			else begin
				//do nothing
			end
		end
		
		RUN:begin
			count_w = count_r + 1;
			if(count_r==256) begin
				state_w = IDLE;
				finish_w = 1;
				if(m_r + t_r >= i_n) begin
					m_w = m_r + t_r - i_n;
				end
				else begin
					m_w = m_r + t_r;
				end
			end

			if(t_r + t_r > i_n) begin
				t_w = t_r + t_r - i_n;
			end
			else begin
				t_w = t_r + t_r;
			end
		end
		
		default:begin
			state_w = IDLE;
			m_w = 0;
			t_w = 0;
			count_w = 0;
			finish_w = 0;
		end
	endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
	if(i_rst) begin
		state_r <= IDLE;
		count_r <= 0;
		finish_r <= 0;
		m_r <= 0;
		t_r <= 0;
	end
	else begin
		state_r <= state_w;
		count_r <= count_w;
		finish_r <= finish_w;
		m_r <= m_w;
		t_r <= t_w;
	end
end

endmodule

module Montgomery(
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_n,
	input  [255:0] i_a,
	input  [255:0] i_b,
	output [0:0]   o_finished,
	output [255:0] mont_result
);

localparam IDLE = 2'b00;
localparam RUN = 2'b01;
localparam RUN_2 = 2'b10;

logic [1:0] state_r,state_w;
logic [0:0] finish_r,finish_w;
logic [257:0] m_r,m_w;
logic [8:0] count_r,count_w;

assign mont_result = m_r[255:0];
assign o_finished = finish_r;

always_comb begin
	state_w = state_r;
	finish_w = finish_r;
	m_w = m_r;
	count_w = count_r;

	case(state_r)
		IDLE:begin
			finish_w = 0;
			if(i_start) begin
				m_w = 0;
				state_w = RUN;
				count_w = 0;
			end
			else begin
				//do nothing
			end
		end
	
		RUN:begin
			if(count_r <= 9'd255) begin
				count_w = count_r + 1;
				if(i_a[count_r] == 1'b1) begin
					if((m_r[0]+i_b[0]) == 1'b1) begin
						m_w = (m_r + i_b + i_n) >> 1;
					end
					else begin
						m_w = (m_r + i_b) >> 1;
					end
				end	
				else begin
					if(m_r[0] == 1'b1) begin
						m_w = (m_r + i_n) >> 1;
					end
					else begin
						m_w = m_r >> 1;
					end
				end
			end
			else begin
				state_w = RUN_2;
			end
		end

		RUN_2:begin
			state_w = IDLE;
			finish_w = 1;
			if(m_r >= i_n) begin
				m_w = m_r - i_n;
			end
		end

		default:begin
			state_w = IDLE;
			finish_w = 0;
			m_w = 0;
			count_w = 0;
		end
	endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
	if(i_rst) begin
		state_r <= IDLE;
		m_r <= 0;
		count_r <= 0;
		finish_r <= 0;
	end
	else begin
		state_r <= state_w;
		finish_r <= finish_w;
		m_r <= m_w;
		count_r <= count_w;
	end
end

endmodule