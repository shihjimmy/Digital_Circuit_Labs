module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output [ 4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest
);

  localparam RX_BASE = 0 * 4;
  localparam TX_BASE = 1 * 4;
  localparam STATUS_BASE = 2 * 4;
  localparam TX_OK_BIT = 6;
  localparam RX_OK_BIT = 7;

  // Feel free to design your own FSM!
  localparam S_WAIT_READ_KEY = 0;  // query Rx
  localparam S_WAIT_READ_DATA = 1;  // query Rx
  localparam S_READ_KEY = 2;  // Read (key)
  localparam S_READ_DATA = 3;
  localparam S_WAIT_CALCULATE = 4;  // Calculate
  localparam S_WAIT_WRITE = 5;  // query Tx
  localparam S_WRITE = 6;  // Write

  logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
  logic [2:0] state_r, state_w;
  logic [6:0] bytes_counter_r, bytes_counter_w;
  logic [4:0] avm_address_r, avm_address_w;
  logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

  logic rsa_start_r, rsa_start_w;
  logic rsa_rst_r, rsa_rst_w;
  logic rsa_hybrid_rst;  // rsa_rst | avm_rst
  logic rsa_finished;
  logic [255:0] rsa_dec;

  assign avm_address = avm_address_r;
  assign avm_read = avm_read_r;
  assign avm_write = avm_write_r;
  assign avm_writedata = dec_r[247-:8];  // PC only read for 31 times
  assign rsa_hybrid_rst = rsa_rst_r | avm_rst;

  Rsa256Core rsa256_core (
      .i_clk(avm_clk),
      .i_rst(rsa_hybrid_rst),
      .i_start(rsa_start_r),  // start signal
      .i_a(enc_r),  // cipher text y
      .i_d(d_r),  // private key
      .i_n(n_r),  // what is this?
      .o_a_pow_d(rsa_dec),  // plain text x
      .o_finished(rsa_finished)  // finished signal
  );

  task StartRead;
    input [4:0] addr;
    begin
      avm_read_w = 1;
      avm_write_w = 0;
      avm_address_w = addr;
    end
  endtask
  task StartWrite;
    input [4:0] addr;
    begin
      avm_read_w = 0;
      avm_write_w = 1;
      avm_address_w = addr;
    end
  endtask

  always_comb begin
    // TODO
    // reading order: n -> d -> enc
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    avm_address_w = avm_address_r;

    case (state_r)
      S_WAIT_READ_KEY: begin
        n_w = n_r;
        d_w = d_r;
        enc_w = enc_r;
        dec_w = 0;
        rsa_start_w = 0;
        rsa_rst_w = rsa_rst_r;

        if (!avm_waitrequest && avm_readdata[RX_OK_BIT]) begin  // Rx ready
          state_w = S_READ_KEY;
          bytes_counter_w = bytes_counter_r + 7'd1;
          StartRead(RX_BASE);
        end else begin  //Rx isn't ready
          state_w = state_r;
          bytes_counter_w = bytes_counter_r;
        end
      end
      S_READ_KEY: begin
        enc_w = enc_r;
        dec_w = 0;
        rsa_start_w = 0;
        bytes_counter_w = bytes_counter_r;
        rsa_rst_w = rsa_rst_r;

        if (!avm_waitrequest) begin
          if (bytes_counter_r <= 7'd32) begin
            // read n
            n_w = (n_r << 8) + avm_readdata[7:0];
            d_w = d_r;
            state_w = S_WAIT_READ_KEY;
          end else if (bytes_counter_r <= 7'd63) begin
            // read d
            n_w = n_r;
            d_w = (d_r << 8) + avm_readdata[7:0];
            state_w = S_WAIT_READ_KEY;
          end else begin
            // read last 8 bits of enc
            n_w = n_r;
            d_w = (d_r << 8) + avm_readdata[7:0];
            state_w = S_WAIT_READ_DATA;
          end
          StartRead(STATUS_BASE);
        end else begin
          n_w = n_r;
          d_w = d_r;
          enc_w = enc_r;
          state_w = state_r;
        end
      end
      S_WAIT_READ_DATA: begin
        n_w = n_r;
        d_w = d_r;
        enc_w = enc_r;
        dec_w = 0;
        rsa_start_w = 0;
        rsa_rst_w = rsa_rst_r;

        if (!avm_waitrequest && avm_readdata[RX_OK_BIT]) begin  // Rx ready
          state_w = S_READ_DATA;
          bytes_counter_w = bytes_counter_r + 7'd1;
          StartRead(RX_BASE);
        end else begin  //Rx isn't ready
          state_w = state_r;
          bytes_counter_w = bytes_counter_r;
        end
      end
      S_READ_DATA: begin
        n_w = n_r;
        d_w = d_r;
        dec_w = 0;
        bytes_counter_w = bytes_counter_r;
        rsa_rst_w = rsa_rst_r;

        if (!avm_waitrequest) begin
          if (bytes_counter_r <= 7'd95) begin
            // read enc
            enc_w = (enc_r << 8) + avm_readdata[7:0];
            state_w = S_WAIT_READ_DATA;
            rsa_start_w = 0;
          end else begin
            // read last 8 bits of enc
            enc_w = (enc_r << 8) + avm_readdata[7:0];
            state_w = S_WAIT_CALCULATE;
            rsa_start_w = 1;  // start rsa256_core calculation
          end
          StartRead(STATUS_BASE);
        end else begin
          enc_w = enc_r;
          state_w = state_r;
          rsa_start_w = 0;
        end
      end
      S_WAIT_CALCULATE: begin
        n_w = n_r;
        d_w = d_r;
        enc_w = enc_r;
        bytes_counter_w = 0;  // reset byte_counter
        rsa_start_w = 0;  // start signal is pulse
        rsa_rst_w = rsa_rst_r;

        if (rsa_finished) begin
          dec_w   = rsa_dec;  // get plain text
          state_w = S_WAIT_WRITE;
          StartRead(STATUS_BASE);
        end else begin
          dec_w   = 0;
          state_w = state_r;
        end
      end
      S_WAIT_WRITE: begin
        n_w = n_r;
        d_w = d_r;
        enc_w = enc_r;
        dec_w = dec_r;
        rsa_start_w = 0;
        rsa_rst_w = rsa_rst_r;

        if (!avm_waitrequest && avm_readdata[TX_OK_BIT]) begin  // Rx ready
          state_w = S_WRITE;
          bytes_counter_w = bytes_counter_r + 7'd1;
          StartWrite(TX_BASE);
        end else begin  //Rx isn't ready
          state_w = state_r;
          bytes_counter_w = bytes_counter_r;
        end
      end
      S_WRITE: begin
        n_w = n_r;
        d_w = d_r;
        enc_w = 0;
        rsa_start_w = 0;
        if (bytes_counter_r <= 7'd29) begin  // PC only read for 31 times
          bytes_counter_w = bytes_counter_r;
          rsa_rst_w = rsa_rst_r;
          // write plain text
          if (!avm_waitrequest) begin
            dec_w   = dec_r << 8;
            state_w = S_WAIT_WRITE;
            StartRead(STATUS_BASE);
          end else begin
            dec_w   = dec_r;
            state_w = state_r;
          end
        end else if (bytes_counter_r == 7'd30) begin
          bytes_counter_w = bytes_counter_r;
          // write plain text
          if (!avm_waitrequest) begin
            dec_w = dec_r << 8;
            state_w = S_WAIT_WRITE;
            rsa_rst_w = 1;  // reset RSA256Core
            StartRead(STATUS_BASE);
          end else begin
            dec_w = dec_r;
            state_w = state_r;
            rsa_rst_w = rsa_rst_r;
          end
        end else begin
          // write last 8 bits of plain text
          // return to S_WAIT_READ
          if (!avm_waitrequest) begin
            dec_w = dec_r << 8;
            state_w = S_WAIT_READ_DATA;
            bytes_counter_w = 7'd64;
            rsa_rst_w = 0;
            StartRead(STATUS_BASE);
          end else begin
            dec_w = dec_r;
            state_w = state_r;
            bytes_counter_w = bytes_counter_r;
            rsa_rst_w = rsa_rst_r;
          end
        end
      end
    endcase
  end

  always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin  // reset
      n_r <= 0;
      d_r <= 0;
      enc_r <= 0;
      dec_r <= 0;
      avm_address_r <= STATUS_BASE;
      avm_read_r <= 1;
      avm_write_r <= 0;
      state_r <= S_WAIT_READ_KEY;
      bytes_counter_r <= 0;
      rsa_start_r <= 0;
      rsa_rst_r <= 0;
    end else begin
      n_r <= n_w;
      d_r <= d_w;
      enc_r <= enc_w;
      dec_r <= dec_w;
      avm_address_r <= avm_address_w;
      avm_read_r <= avm_read_w;
      avm_write_r <= avm_write_w;
      state_r <= state_w;
      bytes_counter_r <= bytes_counter_w;
      rsa_start_r <= rsa_start_w;
      rsa_rst_r <= rsa_rst_w;
    end
  end

endmodule
