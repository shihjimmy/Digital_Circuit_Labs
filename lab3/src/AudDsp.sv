// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
module AudDSP(
	input  i_rst_n,
	input  i_clk,
	input  i_start,                     // start sending data
	input  i_pause,                     // stop sending data 
	input  i_stop,                      // end of the DSP process (same as i_rst)
	input  [3:0] i_speed,               // 0,2,4,8 speed
	input  i_fast,        
	input  i_slow_0,                    // constant interpolation
	input  i_slow_1,                    // linear interpolation
    // if i_fast is 1 means fast playing, while 0 means slow playing
    // two modes for slow playing--> constant or linear
	input  i_daclrck,     
	input  signed [15:0] i_sram_data,   // data from SRAM
	input  [19:0] max_addr,             // data in SRAM stored from 0 to max_addr
    input  i_back,
    output [15:0] o_dac_data,
	output [19:0] o_sram_addr           // next data's address in SRAM
);

localparam IDLE = 3'b000;
localparam FAST = 3'b001;
localparam SLOW_0 = 3'b010;
localparam SLOW_1 = 3'b011;
localparam PAUSE =  3'b100;
// since AudPlayer works when i_daclrck falls after 1 clk
// DSP only processes data when i_dalrck rises after 1 clk
// set a state to check whether it is time to do so 
localparam WAIT = 3'b101;
localparam BACK = 3'b110;

logic [3:0]  state_r,state_w;
// since we  need to do interpolation
// we need to remember last input data
logic [15:0] pre_input_r,pre_input_w;
logic [15:0] output_r,output_w;
logic [19:0] addr_r,addr_w;
logic [19:0] back_addr_r,back_addr_w;
logic [0:0]  check_dalrck;
// since we need to do slow down at 1/2 1/4 1/8 speed
// we need a counter for slow play to count how many points to interpolate
logic [3:0]  count_r,count_w;

assign o_dac_data = output_r;
assign o_sram_addr = addr_r;

task FastPlay;
    addr_w = addr_r + i_speed + 1; // new address to access
    output_w = i_sram_data;
    state_w = WAIT;
    
    if(addr_w >= max_addr - i_speed - 1) begin
        // last data
        addr_w = max_addr;
    end
endtask

task SlowPlay_0;
    output_w = i_sram_data;
    state_w = WAIT;

    if(count_r == i_speed) begin
        // means interpolate just enough points
        // only changes addr_w when interpolation finished
        addr_w = addr_r + 1;
        count_w = 0;
    end
    else begin
        count_w  = count_r + 1;
    end
endtask

// only linear interpolation needs last input data
task SlowPlay_1;
    output_w = $signed(pre_input_r) + ( $signed( count_r*( $signed(i_sram_data) - $signed(pre_input_r) ) ) / $signed(i_speed+1) );
    state_w = WAIT;

    if(count_r == i_speed) begin
        // means interpolate just enough points
        // only changes addr_w when interpolation finished
        addr_w = addr_r + 1;
        pre_input_w = i_sram_data;
        count_w = 0;
    end
    else begin
        count_w  = count_r + 1;
    end
endtask

task check_finished;
    if(addr_w >= max_addr) begin
        // finish processing all data
        state_w = IDLE;
    end
endtask

always_comb begin
    state_w = state_r;
    addr_w = addr_r;
    output_w = output_r;
    pre_input_w = pre_input_r;
    count_w = count_r;
    back_addr_w = back_addr_r;
    
    case(state_r)
        IDLE: begin
            pre_input_w = 0;
            output_w = 0;
            count_w = 0;
        end

        FAST: begin
            FastPlay();
            check_finished();
        end

        SLOW_0: begin
            SlowPlay_0();
            check_finished();
        end

        SLOW_1: begin
            SlowPlay_1();
            check_finished();
        end

        PAUSE: begin
            // do nothing
        end

        WAIT: begin
            if((!check_dalrck) && i_daclrck) begin
                if(i_fast && i_back) begin
                    state_w = BACK;
                end
                else if(i_fast && (!i_back)) begin
                    state_w = FAST;
                end
                else if(i_slow_0) begin
                    state_w = SLOW_0;
                end
                else if(i_slow_1) begin
                    state_w = SLOW_1;
                end
                else begin
                    state_w = FAST;
                end     
            end
        end

        BACK: begin
            back_addr_w = back_addr_r - 1;
            addr_w = back_addr_r;
            output_w = i_sram_data;
            state_w = WAIT;

            if(addr_r <= 0) begin
                state_w = IDLE;
            end 
        end

        default: begin
            state_w = IDLE;
            output_w = 0;
            pre_input_w = 0;
            addr_w = 0;
            count_w = 0;
        end
    endcase

    // whenever i_start is 1,it should start and go back to its previous state
    if(i_start) begin
        if(i_back && i_fast) begin
            state_w = BACK;
        end
        else if(i_fast && (!i_back)) begin
            state_w = FAST;
        end
        else if(i_slow_0) begin
            state_w = SLOW_0;
        end
        else if(i_slow_1) begin
            state_w = SLOW_1;
        end
        else begin
            state_w = FAST;
        end          
    end
    else if(i_pause) begin
        state_w = PAUSE;
    end
end

always_ff @(posedge i_clk or negedge i_rst_n or posedge i_stop) begin
    if(!i_rst_n || i_stop) begin
        state_r <= IDLE;
        pre_input_r <= 0;
        output_r <= 0;
        addr_r <= 0;
        back_addr_r <= max_addr;
        count_r <= 0;
        check_dalrck <= i_daclrck;
    end
    else begin
        state_r <= state_w;
        pre_input_r <= pre_input_w;
        output_r <= output_w;
        addr_r <= addr_w;
        back_addr_r <= back_addr_w;
        count_r <= count_w;
        check_dalrck <= i_daclrck;
    end
end

endmodule