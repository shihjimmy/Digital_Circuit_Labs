module AudRecorder (
    input i_rst_n,
    input i_clk,  // BCLK
    input i_lrc,  // ADCLRCK
    input i_start,
    input i_pause,
    input i_stop,
    input i_data,  // ADCDAT
    output [19:0] o_address,  // SRAM record address
    output [15:0] o_data  // SRAM record data
);

  localparam S_IDLE = 0;  // wait for start
  localparam S_RECORD = 1;  // record, and hasn't finished yet
  localparam S_NOT_RECORD = 2;  // doesn't record, but hasn't finished yet
  localparam S_FINISHED = 3;  // finished

  localparam MAX_MEMORY_SIZE = 20'b1111_1111_1111_1111_1111;

  logic [1:0] state_r, state_w;
  logic pulse_r, pulse_w;  // record pulse signal
  logic stop_r, stop_w;  // record stop signal
  logic [5:0] bit_counter_r, bit_counter_w;  // 16-bit data
  logic discrd_r, discard_w;  // discard the first frame record
  logic ltoh_r, ltoh_w;  // mark lrc from low to high

  logic [19:0] o_address_r, o_address_w;
  logic [0:15] o_data_r, o_data_w;

  assign o_address = o_address_r;
  assign o_data = o_data_r;

  // === Combinational Circuits ===
  always_comb begin

    state_w = state_r;
    pulse_w = pulse_r;
    stop_w = stop_r;
    discard_w = discrd_r;
    bit_counter_w = bit_counter_r;
    o_address_w = o_address_r;
    o_data_w = o_data_r;

    case (state_r)
      S_IDLE: begin
        pulse_w = 1'b0;
        stop_w = 1'b0;
        o_address_w = o_address_r;
        o_data_w = o_data_r;
        bit_counter_w = 5'd0;  // read from the middle
        discard_w = 1'b1;
        ltoh_w = 0;

        if (!i_start) begin
          state_w = S_IDLE;
        end else begin
          state_w = S_RECORD;
        end
      end

      S_RECORD: begin  // only record left channel
        pulse_w = (i_pause) ? 1'b1 : pulse_r;
        stop_w  = (i_stop) ? 1'b1 : stop_r;
        if (i_lrc == 1'b1) begin  // right channel
          state_w = (stop_r || o_address_r==MAX_MEMORY_SIZE) ? S_FINISHED : ((pulse_r) ? S_NOT_RECORD : S_RECORD);
          bit_counter_w = 5'd0;
          o_data_w = o_data_r;
          discard_w = 1'b0;
          if (ltoh_r) begin
            o_address_w = o_address_r + 5'd1;
          end else begin
            o_address_w = o_address_r;
          end
          ltoh_w = 0;
        end else begin  // left channel (what we want)
          discard_w = 1'b0;
          if (bit_counter_r == 5'd0) begin  // MSB first write
            state_w = S_RECORD;
            bit_counter_w = 5'd1;  // 5'd1
            o_address_w = o_address_r;  // move to address that we want write
            o_data_w = o_data_r;
          end else if (bit_counter_r >= 5'd16) begin
            state_w = (stop_r || o_address_r==MAX_MEMORY_SIZE) ? S_FINISHED : ((pulse_r) ? S_NOT_RECORD : S_RECORD);
            bit_counter_w = 5'd17;
            o_address_w = o_address_r;
            o_data_w[bit_counter_r-5'd1] = i_data;
          end else begin  // range we should read
            state_w = S_RECORD;
            bit_counter_w = bit_counter_r + 5'd1;
            o_address_w = o_address_r;
            o_data_w[bit_counter_r-5'd1] = i_data;
          end
          ltoh_w = 1;
        end
      end

      S_NOT_RECORD: begin  // pulse
        pulse_w = (i_start) ? 1'b0 : pulse_r;
        stop_w = (i_stop) ? 1'b1 : stop_r;
        state_w = (stop_r || o_address_r==MAX_MEMORY_SIZE) ? S_FINISHED : ((pulse_r) ? S_NOT_RECORD : S_RECORD);
        bit_counter_w = 5'd0;
        o_address_w = o_address_r;
        o_data_w = o_data_r;
        discard_w = 1'b1;
        ltoh_w = 0;
      end

      S_FINISHED: begin
        state_w = S_FINISHED;
        pulse_w = 1'b0;
        stop_w = 1'b0;
        o_address_w = o_address_r;
        o_data_w = o_data_r;
        bit_counter_w = 5'd0;
        discard_w = 1'b1;
        ltoh_w = 0;
      end
    endcase
  end

  // === Sequential Circuits ===
  always_ff @(posedge i_clk or negedge i_rst_n) begin  // BCLK
    if (!i_rst_n) begin
      state_r <= S_IDLE;
      pulse_r <= 1'b0;
      stop_r <= 1'b0;
      o_address_r <= 20'd0;
      o_data_r <= 16'd0;
      bit_counter_r <= 5'd0;
      discrd_r <= 1'b1;
      ltoh_r <= 0;
    end else begin
      state_r <= state_w;
      pulse_r <= pulse_w;
      stop_r <= stop_w;
      o_address_r <= o_address_w;
      o_data_r <= o_data_w;
      bit_counter_r <= bit_counter_w;
      discrd_r <= discard_w;
      ltoh_r <= ltoh_w;
    end
  end
endmodule
