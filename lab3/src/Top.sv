module Top (
	input i_rst_n,
	input i_clk,
	input i_key_0, // start
	input i_key_1, // pause
	input i_key_2, // stop
	input i_key_4, // play backward
	// input [3:0] i_speed, // design how user can decide mode on your own
	input i_mode,  
	// 0 is play 1 is record
	input i_slowPlayMode,
	input [13:0] i_speed,
	output o_i2c_fin,
	output o_i2c_start,
	
	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT,
	
	// SEVENDECODER (optional display)
	output [1:0] o_state,
	output [4:0] o_sec_display
	// output [5:0] o_record_time,
	// output [5:0] o_play_time,

	// LCD (optional display)
	// input        i_clk_800k,
	// inout  [7:0] o_LCD_DATA,
	// output       o_LCD_EN,
	// output       o_LCD_RS,
	// output       o_LCD_RW,
	// output       o_LCD_ON,
	// output       o_LCD_BLON

	// LED
	// output  [8:0] o_ledg,
	// output [17:0] o_ledr
);

// design the FSM and states as you like
parameter S_IDLE       = 0;
parameter S_I2C        = 1;
parameter S_RECD       = 2;
parameter S_PLAY       = 3;

logic [2:0] state_w, state_r ;
logic i2c_oen;
wire i2c_sdat;
logic [19:0] addr_record, addr_play;
logic [15:0] data_record, data_play, dac_data;

assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

assign o_SRAM_ADDR = (state_r == S_RECD) ? addr_record : addr_play;
assign io_SRAM_DQ  = (state_r == S_RECD) ? data_record : 16'dz; // sram_dq as output
assign data_play   = (state_r != S_RECD) ? io_SRAM_DQ : 16'd0; // sram_dq as input

assign o_SRAM_WE_N = (state_r == S_RECD) ? 1'b0 : 1'b1;
assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;

// 
logic [2:0] dsp_speed ;
logic [2:0] dsp_f_s ; // {fast,slow0,slow1}
logic dsp_start, rec_start ;
logic i2c_start, i2c_finish, ply_en ; // TBD : i2c_start, ply_en

assign dsp_start = (!i_mode) && i_key_0 ;
assign o_state = state_r;
assign o_i2c_fin = i2c_finish ;
assign o_i2c_start = rec_start;
assign o_sec_display = (i_mode ? addr_record[19:15] : addr_play[19:15]);

// below is a simple example for module division
// you can design these as you like

// === I2cInitializer ===
// sequentially sent out settings to initialize WM8731 with I2C protocal
I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(i2c_start),
	.o_finished(i2c_finish),
	.o_sclk(o_I2C_SCLK),
	.io_sdat(i2c_sdat),
	.o_oen(i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
);

// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
AudDSP dsp0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk),
	.i_start(dsp_start),
	.i_pause(i_key_1),
	.i_stop(i_key_2),
	.i_speed(dsp_speed),
	.i_fast(dsp_f_s[2]),
	.i_slow_0(dsp_f_s[1]), // constant interpolation
	.i_slow_1(dsp_f_s[0]), // linear interpolation
	.i_daclrck(i_AUD_DACLRCK),
	.i_sram_data(data_play),
	.max_addr(addr_record),
	.i_back(i_key_4),
	.o_dac_data(dac_data),
	.o_sram_addr(addr_play)
);

// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
AudPlayer player0(
	.i_rst_n(i_rst_n),
	.i_bclk(i_AUD_BCLK),
	.i_daclrck(i_AUD_DACLRCK),
	.i_en(ply_en), // enable AudPlayer only when playing audio, work with AudDSP
	.i_dac_data(dac_data), //dac_data
	.o_aud_dacdat(o_AUD_DACDAT)
);

// === AudRecorder ===
// receive data from WM8731 with I2S protocal and save to SRAM
AudRecorder recorder0(
	.i_rst_n(i_rst_n), 
	.i_clk(i_AUD_BCLK),
	.i_lrc(i_AUD_ADCLRCK),
	.i_start(rec_start),
	.i_pause(i_key_1),
	.i_stop(i_key_2),
	.i_data(i_AUD_ADCDAT),
	.o_address(addr_record),
	.o_data(data_record)
);

always_comb begin
	// design your control here
	if (i_speed >= 1<<7) begin // slow mode
		dsp_f_s = (i_slowPlayMode)? 3'b001 : 3'b010 ;
		// i_slowPlayMode == 1 : linear
		// i_slowPlayMode == 0 : constant
		if(i_speed[7]) 		 dsp_speed = 1 ;
		else if(i_speed[8])  dsp_speed = 2 ;
		else if(i_speed[9])  dsp_speed = 3 ;
		else if(i_speed[10]) dsp_speed = 4 ;
		else if(i_speed[11]) dsp_speed = 5 ;
		else if(i_speed[12]) dsp_speed = 6 ;
		else if(i_speed[13]) dsp_speed = 7 ;
		else dsp_speed = 0 ;
	end
	else begin
		dsp_f_s = 3'b100 ;
		if(i_speed[0]) 		dsp_speed = 1 ;
		else if(i_speed[1]) dsp_speed = 2 ;
		else if(i_speed[2]) dsp_speed = 3 ;
		else if(i_speed[3]) dsp_speed = 4 ;
		else if(i_speed[4]) dsp_speed = 5 ;
		else if(i_speed[5]) dsp_speed = 6 ;
		else if(i_speed[6]) dsp_speed = 7 ;
		else dsp_speed = 0 ;
	end
	
	state_w = state_r ;
	rec_start = 0 ;
	i2c_start = 0 ;
	ply_en	 = 1 ;

	case(state_r) 
		S_IDLE : begin
			if(i_key_0) begin
				state_w = S_I2C ;
				i2c_start = 1 ;
			end
		end

		S_I2C : begin
			if(i2c_finish) begin
				if(i_mode) begin
					rec_start = 1 ;
					state_w = S_RECD ;
				end
				else begin
					state_w = S_PLAY ;
				end
			end
			else begin
				i2c_start = 1;
				state_w = S_I2C;
			end
		end

		S_RECD : begin
			if(i_key_2 | &addr_record) begin
				ply_en = 0 ;
				state_w = S_IDLE;
				rec_start = 0;
			end
			else if(rec_start) begin
				rec_start = (i_key_1 ? 0 : 1);
			end
			else begin
				rec_start = (i_key_0 ? 1 : 0);
			end
		end

		S_PLAY : begin
			ply_en = 1 ;
			if(i_key_2 | (~|(addr_play ^ addr_record))) begin 
			// all data played
				state_w = S_IDLE ;
			end
			else begin
				state_w = S_PLAY;
			end
		end
	endcase

end

always_ff @(posedge i_AUD_BCLK or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r <= S_IDLE ;
	end
	else begin
		state_r <= state_w ;
	end
end

endmodule