module alu(
             clk_p_i,
             reset_n_i,
             data_a_i,
             data_b_i,
             inst_i,
             data_o
             );
  /* ============================================ */
      input           clk_p_i;
      input           reset_n_i;
      input   [7:0]   data_a_i;
      input   [7:0]   data_b_i;
      input   [2:0]   inst_i;

      output  [15:0]  data_o;

  /* ============================================ */
      wire    [15:0]  out_inst_0;
      wire    [15:0]  out_inst_1;
      wire    [15:0]  out_inst_2;
      wire    [15:0]  out_inst_3;
      wire    [15:0]  out_inst_4;
      wire    [15:0]  out_inst_5;
      wire    [15:0]  out_inst_6;
      wire    [15:0]  out_inst_7;

      reg     [15:0]  ALU_out_inst;
      wire    [15:0]  ALU_d2_w;

      reg     [15:0]  ALU_d2_r;
      
      reg     [7:0]   reg_data_a;
      reg     [7:0]   reg_data_b;
      reg     [2:0]   reg_inst;
      wire    [15:0]  reg_subtraction;

      assign ALU_d2_w = ALU_out_inst;
      assign data_o   = ALU_d2_r;
  
      assign out_inst_0 = {8'b0 , reg_data_a[7:0]} + {8'b0 , reg_data_b[7:0]};
      assign out_inst_1 = {8'b0 , reg_data_b[7:0]} - {8'b0 , reg_data_a[7:0]};
      assign out_inst_2 = {8'b0 , reg_data_a[7:0]} * {8'b0 , reg_data_b[7:0]};
      assign out_inst_3[15:8] = 8'b0;
      assign out_inst_3[ 7:0] = ~reg_data_a[7:0];
      assign out_inst_4[15:8] = 8'b0;
      assign out_inst_4[ 7:0] = reg_data_a[7:0] ^ reg_data_b[7:0];
      assign out_inst_5[15:8] = 8'b0;
      assign out_inst_5[ 7:0] = reg_data_a[7] ? ~reg_data_a[ 7:0]+1 : reg_data_a[ 7:0];
      assign reg_subtraction  = {8'b0 , reg_data_b[7:0]} - {8'b0 , reg_data_a[7:0]};
      assign out_inst_6 = {reg_subtraction[15] , reg_subtraction[15:1]};

  /* ============================================ */
  // The output MUX
      always@ (*)
      begin
          case(reg_inst)
           3'b000:    ALU_out_inst = out_inst_0;           
           3'b001:    ALU_out_inst = out_inst_1;
           3'b010:    ALU_out_inst = out_inst_2;
           3'b011:    ALU_out_inst = out_inst_3;
           3'b100:    ALU_out_inst = out_inst_4;
           3'b101:    ALU_out_inst = out_inst_5;
           3'b110:    ALU_out_inst = out_inst_6;
           3'b111:    ALU_out_inst = out_inst_7;
           default:   ALU_out_inst = 0;
          endcase
      end

  /* ============================================ */
      always@(posedge clk_p_i or negedge reset_n_i)
      begin
          if (reset_n_i == 1'b0)
          begin
              reg_inst   <= 8'd0;
              reg_data_a <= 8'd0;
              reg_data_b <= 8'd0;
              ALU_d2_r   <= 16'd0;
          end
          else
          begin
              ALU_d2_r   <= ALU_d2_w;
              reg_inst   <= inst_i;
              reg_data_a <= data_a_i;
              reg_data_b <= data_b_i;
          end
      end
  /* ============================================ */

endmodule

