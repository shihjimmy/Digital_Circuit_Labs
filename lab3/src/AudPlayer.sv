// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
module AudPlayer(
	input  [0:0]  i_rst_n,
	input  [0:0]  i_bclk,              // clk in WM8731
	input  [0:0]  i_daclrck,           // input from WM8731
	input  [0:0]  i_en,                // enable AudPlayer only when playing audio, work with AudDSP
	input  [15:0] i_dac_data,          // dac_data from AudDSP
	output [0:0]  o_aud_dacdat         // output data to WM8731
);

localparam IDLE = 1'b0;
localparam PLAY = 1'b1;

logic [0:0]  state_r, state_w;
logic [3:0]  count_r, count_w;
logic [15:0] output_r,output_w;
logic [0:0]  check_dalrck;

assign o_aud_dacdat = output_r[15];

always_comb begin
    state_w = state_r;
    count_w = count_r;
    output_w = output_r;

    case(state_r) 
        IDLE: begin
            if(i_en && check_dalrck && (!i_daclrck)) begin
                // when i_en is 1 and i_daclrck falls to 0 after 1 clk
                // check_dalrck remember i_dalrck in 1 clk before
                state_w = PLAY;
                count_w = 0;
                output_w = i_dac_data;
            end
            else begin
                // do nothing
            end
        end

        PLAY: begin
            if(&count_r) begin
                //already send 16 bits,so count_r is 1111
                state_w = IDLE;
                count_w = 0;
            end
            else begin
                state_w = PLAY;
                output_w = output_r << 1;
                count_w = count_r + 1;
            end
        end

        default: begin
            state_w = IDLE;
            count_w = 0;
            output_w = 0;
        end
    endcase
end

always_ff @(posedge i_bclk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        state_r <= IDLE;
        output_r <= 0;
        count_r <= 0;
        check_dalrck <= i_daclrck;
    end
    else begin
        state_r <= state_w;
        output_r <= output_w;
        count_r <= count_w;
        check_dalrck <= i_daclrck;
    end
end

endmodule