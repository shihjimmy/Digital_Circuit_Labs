module I2cInitializer (
    input i_rst_n,
    input i_clk,
    input i_start,
    output o_finished,
    output o_sclk,  // I2C SCL
    inout io_sdat,  // I2C SDA
    output o_oen  // I2C OE (output enable)
);
  localparam S_IDLE = 0;
  localparam S_START = 1;
  localparam S_WRITE = 2;
  localparam S_TRANSMIT = 3;
  localparam S_ACK = 4;
  localparam S_FINISH = 5;

  localparam RESET_REGISTER = 24'b0011_0100_000_1111_0_0000_0000;
  localparam LEFT_LINE_IN = 24'b0011_0100_000_0000_0_1001_0111;
  localparam RIGH_LINE_IN = 24'b0011_0100_000_0001_0_1001_0111;
  localparam LEFT_HEADPHONE_OUT = 24'b0011_0100_000_0010_0_0111_1001;
  localparam RIGHT_HEADPHONE_OUT = 24'b0011_0100_000_0011_0_0111_1001;
  localparam ANALOGUE_AUDIO_PATH_CONTROL = 24'b0011_0100_000_0100_0_0001_0101;
  localparam DIGITAL_AUDIO_PATH_CONTROL = 24'b0011_0100_000_0101_0_0000_0000;
  localparam POWER_DOWN_CONTROL = 24'b0011_0100_000_0110_0_0000_0000;
  localparam DIGITAL_AUDIO_INTERFACE_FOEMAT = 24'b0011_0100_000_0111_0_0100_0010;
  localparam SAMPLING_CONTROL = 24'b0011_0100_000_1000_0_0001_1001;
  localparam ACTIVE_CONTROL = 24'b0011_0100_000_1001_0_0000_0001;

  logic [0:23] config_data[0:10];  // MBS first

  assign config_data[0]  = RESET_REGISTER;
  assign config_data[1]  = LEFT_LINE_IN;
  assign config_data[2]  = RIGH_LINE_IN;
  assign config_data[3]  = LEFT_HEADPHONE_OUT;
  assign config_data[4]  = RIGHT_HEADPHONE_OUT;
  assign config_data[5]  = ANALOGUE_AUDIO_PATH_CONTROL;
  assign config_data[6]  = DIGITAL_AUDIO_PATH_CONTROL;
  assign config_data[7]  = POWER_DOWN_CONTROL;
  assign config_data[8]  = DIGITAL_AUDIO_INTERFACE_FOEMAT;
  assign config_data[9]  = SAMPLING_CONTROL;
  assign config_data[10] = ACTIVE_CONTROL;

  logic [2:0] state_r, state_w;
  logic finished_r, finished_w;
  // I2C
  logic sclk_r, sclk_w;
  logic sdat_r, sdat_w;
  logic oen_r, oen_w;
  // counters
  logic [3:0] data_counter_r, data_counter_w;  // 0~10 config_data
  logic [4:0] bit_counter_r, bit_counter_w;  // 0~23
  logic acked_r, acked_w;  // mark has/hasn't acked (true even if receive unACKed)
  logic erroer_mark_r, error_mark_w;  // true if error occurred
  logic twice_counter_r, twice_counter_w;  // make sure finish change and transfer


  assign o_finished = finished_r;
  assign o_sclk = sclk_r;
  assign io_sdat = sdat_r;
  assign o_oen = oen_r;

  // === Combinational Circuits ===
  always_comb begin
    case (state_r)
      S_IDLE: begin
        sclk_w = 1'b1;
        oen_w = 1'b1;  // as master
        acked_w = 1'b0;
        error_mark_w = 1'b0;
        data_counter_w = data_counter_r;
        bit_counter_w = 5'd0;
        twice_counter_w = 0;

        if (!i_start && data_counter_r == 4'd0) begin  // IDLE
          finished_w = finished_r;
          state_w = S_IDLE;
          sdat_w = 1'b1;
        end else begin  // start initialization
          finished_w = 1'b0;
          state_w = S_START;
          sdat_w = 1'b0;  // pull SDA low
        end
      end

      S_START: begin
        state_w = S_WRITE;
        finished_w = 1'b0;
        acked_w = 1'b0;
        error_mark_w = 1'b0;
        sclk_w = 1'b0;  // SCL low
        sdat_w = 1'b0;  // begin writing data
        oen_w = 1'b1;
        data_counter_w = data_counter_r;
        bit_counter_w = 5'd0;
        twice_counter_w = 0;
      end

      S_WRITE: begin
        finished_w = 1'b0;
        data_counter_w = data_counter_r;
        acked_w = acked_r;
        error_mark_w = erroer_mark_r;
        bit_counter_w = bit_counter_r;
        /*if (twice_counter_r == 0) begin
          state_w = S_WRITE;
          sclk_w = 1'b0;  // SCL low
          sdat_w = 1'b1;  // begin writing data
          oen_w = 1'b1;
          twice_counter_w = 1;
        end else begin*/
        if (acked_r && bit_counter_r == 5'd24) begin  // finish tranmitting 24 bits and 3 ACKs
          state_w = S_FINISH;
          sclk_w  = 1'b1;  // clock constantly high
          sdat_w  = 1'b0;  // prepare to finish
          oen_w   = 1'b1;
        end else begin  // begin ACK | transmission
          sclk_w = 1'b1;  // SCL high
          if (!acked_r && (bit_counter_r == 5'd8 || bit_counter_r == 5'd16 || bit_counter_r == 5'd24)) begin  // begin ACK
            state_w = S_ACK;
            sdat_w  = 1'bz;
            oen_w   = 1'b0;
          end else begin  // begin transmission
            state_w = S_TRANSMIT;
            sdat_w  = config_data[data_counter_r][bit_counter_r];  // begin transmission
            oen_w   = 1'b1;
          end
        end
        twice_counter_w = 0;
        //end
      end

      S_TRANSMIT: begin
        /*if (twice_counter_r == 0) begin
          state_w = S_TRANSMIT;
          finished_w = 0;
          acked_w = 0;
          error_mark_w = erroer_mark_r;
          sclk_w = 1'b1;
          sdat_w = sdat_r;  // begin transmission
          oen_w = 1'b1;
          twice_counter_w = 1;
        end else begin*/
        state_w = S_WRITE;
        finished_w = 1'b0;
        acked_w = 1'b0;  // unACKed
        error_mark_w = erroer_mark_r;
        sclk_w = 1'b0;
        sdat_w = sdat_r;
        oen_w = 1'b1;
        data_counter_w = data_counter_r;
        bit_counter_w = bit_counter_r + 5'd1;
        twice_counter_r = 0;
        //end
      end

      S_ACK: begin
        finished_w = 1'b0;
        sclk_w = 1'b0;
        sdat_w = 1'b0;
        oen_w = 1'b1;
        state_w = S_WRITE;
        acked_w = 1'b1;
        data_counter_w = data_counter_r;
        bit_counter_w = bit_counter_r;
        if (sdat_r == 1'b0) begin  // ACKed
          error_mark_w = erroer_mark_r;
        end else begin  // unACKed
          // error_mark_w = 1'b1;  // mark unACKed error
          error_mark_w = erroer_mark_r;
        end
      end

      S_FINISH: begin
        state_w = S_IDLE;
        sclk_w = 1'b1;
        sdat_w = 1'b1;
        oen_w = 1'b1;
        acked_w = 1'b0;
        error_mark_w = 1'b0;
        if (data_counter_r == 4'd10 && !erroer_mark_r) begin  // finish initialization
          finished_w = 1'b1;
          data_counter_w = 4'd0;
          bit_counter_w = 5'd0;
        end else begin  // contionue initialization
          finished_w = 1'b0;
          data_counter_w = (erroer_mark_r == 1'b0) ? data_counter_r + 4'd1 : data_counter_r;  // resend if error occurred
          bit_counter_w = 5'd0;
        end
      end
    endcase
  end

  // === Sequential Circuits ===
  always_ff @(negedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      state_r <= S_IDLE;
      finished_r <= 1'b0;
      acked_r <= 1'b0;
      erroer_mark_r <= 1'b0;
      sclk_r <= 1'b1;
      //sdat_r <= 1'b1;  // SDA released
      oen_r <= 1'b1;  // outputing data (as master)
      data_counter_r <= 3'd0;
      bit_counter_r <= 5'd0;
    end else begin
      state_r <= state_w;
      finished_r <= finished_w;
      acked_r <= acked_w;
      erroer_mark_r <= error_mark_w;
      sclk_r <= sclk_w;
      //sdat_r <= sdat_w;
      oen_r <= oen_w;
      data_counter_r <= data_counter_w;
      bit_counter_r <= bit_counter_w;
    end
  end

  always_ff @(posedge i_clk) begin
    if (!i_rst_n) begin
      sdat_r <= 1'b1;  // SDA released
    end else begin
      sdat_r <= sdat_w;
    end
  end



endmodule
