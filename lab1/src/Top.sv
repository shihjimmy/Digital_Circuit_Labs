module Top (
	input        i_clk,
	input        i_rst_n,
	input		 i_stop_n,
	input        i_start,
	output [3:0] o_random_out,
	output [3:0] o_random_out_2
);
    parameter IDLE = 1'b0;
	parameter RUN = 1'b1;

	logic [0:0] state_r,state_w;
	logic [3:0] o_random_r,o_random_w;
	logic [3:0] o_random_2_r,o_random_2_w;          // previous random value
	logic [15:0] rand_seed_r,rand_seed_w;
	logic [15:0] seed_r,seed_w;
	logic [31:0] counter_r,counter_w;
	logic [31:0] trigger_r,trigger_w;
	logic [0:0] bits_combine1,bits_combine2;
	logic [0:0] bit_new_value;

	assign o_random_out = o_random_r;
	assign o_random_out_2 = o_random_2_r;

	always_comb begin 
		state_w = state_r;
		counter_w = counter_r;
		trigger_w = trigger_r;
		o_random_w = o_random_r;
		o_random_2_w = o_random_2_r;
		rand_seed_w  = rand_seed_r;
		seed_w = seed_r + 1;
		bits_combine1 = rand_seed_r[13] ^ rand_seed_r[15];
		bits_combine2 = rand_seed_r[12] ^ bits_combine1;
		bit_new_value = rand_seed_r[10] ^ bits_combine2;
	
		case(state_r)
			IDLE: begin
				if(i_start) begin
					state_w = RUN;
					counter_w = 32'd0;    
					trigger_w = 32'd196000;
					o_random_2_w = o_random_r; 
				end
				else begin
					// not change anything
				end
			end

			RUN: begin
				if(trigger_r >= 32'd9800000) begin
					// stop at the certain number
					state_w = IDLE;
				end
				else if(trigger_r == counter_r) begin
					// change the random number and output
					counter_w = 32'd0;
					trigger_w = trigger_r + 32'd196000;
					rand_seed_w = {rand_seed_r[14:0],bit_new_value};
				end
				else begin
					o_random_w = {rand_seed_r[10],rand_seed_r[12],rand_seed_r[13],rand_seed_r[15]};  
					counter_w = counter_r + 1;
				end
			end 
			
			default: begin
				counter_w = 0;
				trigger_w = 0;
				o_random_w = 0;
				o_random_2_w = 0;
				rand_seed_w = 0;
				state_w = IDLE;
			end
		endcase
	end

	always_ff @(posedge i_clk or negedge i_rst_n or negedge i_stop_n) begin
		if(!i_rst_n) begin
			state_r <= IDLE;
			o_random_r <= 0;
			o_random_2_r <= 0;
			counter_r <= 0;
			trigger_r <= 0;
			rand_seed_r <= seed_r;
		end
		else if(!i_stop_n) begin
			state_r <= IDLE;
			o_random_r <= o_random_w;
			o_random_2_r <= o_random_2_w;
			counter_r <= 0;
			trigger_r <= 0;
			rand_seed_r <= rand_seed_w;
		end
		else begin
			state_r <= state_w;
			o_random_r <= o_random_w;
			o_random_2_r <= o_random_2_w;
			counter_r <= counter_w;
			trigger_r <= trigger_w;
			rand_seed_r <= rand_seed_w;
		end
		seed_r <= seed_w;
	end

endmodule

// LAB1 Q&A:
// Q:寫在case前面和寫default是不一樣的對嗎?
// A:Yes
// Q:後面在case有改到值的話是會覆蓋case前面寫的吧? 合成會長怎樣?
// A:Yes,首先case會是一個大mux，再來如果遇到多個input要去賦值的話，會再合成一個mux去選
// Q:維持不變的話還要重寫一次嗎?
// A:No
// Q:如果沒有多得case可以不用default嗎? 電路會不會有X Z出現?
// A:會，所以還是要用default