`define REF_MAX_LENGTH              128
`define READ_MAX_LENGTH             128

`define REF_LENGTH                  128
`define READ_LENGTH                 128

//* Score parameters
`define DP_SW_SCORE_BITWIDTH        10

`define CONST_MATCH_SCORE           1
`define CONST_MISMATCH_SCORE        -4
`define CONST_GAP_OPEN              -6
`define CONST_GAP_EXTEND            -1

module SW_Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

// Feel free to design your own FSM!

localparam S_GET_REFFERENCE = 0;
localparam S_GET_READ = 1;
localparam S_WAIT_SW_READY = 2;
localparam S_WAIT_COMPUTE = 3;
localparam S_SEND_RESULT = 4;

reg [255:0] refference_w, refference_r;
reg[255:0] read_w, read_r;
wire signed [9:0] score;
wire [6:0] column;
wire [6:0] row;
reg [247:0] result_w, result_r;
wire o_ready;
reg i_valid_w, i_valid_r;
wire o_valid;
reg i_ready_w, i_ready_r;
reg SW_rst_w, SW_rst_r;

reg [2:0] state_w, state_r;

reg [4:0] avm_address_w;
reg avm_read_w;
reg avm_write_w;

reg [4:0] avm_address_r;
reg avm_read_r;
reg avm_write_r;

reg [5:0] byte_counter_w, byte_counter_r;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = result_r[247-:8];


// Remember to complete the port connection
SW_core sw_core(
    .clk				(avm_clk),
    .rst				(avm_rst|SW_rst_r),

	.o_ready			(o_ready),
    .i_valid			(i_valid_r),
    .i_sequence_ref		(refference_r),
    .i_sequence_read	(read_r),
    .i_seq_ref_length	(8'd128),
    .i_seq_read_length	(8'd128),
    
    .i_ready			(i_ready_r),
    .o_valid			(o_valid),
    .o_alignment_score	(score),
    .o_column			(column),
    .o_row				(row)
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


// TODO
always_comb begin
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    avm_address_w = avm_address_r;
    state_w = state_r;
    byte_counter_w = byte_counter_r;
    refference_w = refference_r;
    read_w = read_r;
    result_w = result_r;
    SW_rst_w = SW_rst_r;
    i_ready_w = i_ready_r;
    i_valid_w = i_valid_r;
    case (state_r)
        S_GET_REFFERENCE: begin
            if(!avm_waitrequest) begin
                case (avm_address_r)
                    STATUS_BASE: begin
                        state_w = state_r;
                        if(avm_readdata[RX_OK_BIT]) begin
                            byte_counter_w = byte_counter_r + 1;
                            StartRead(RX_BASE);
                        end
                    end
                    RX_BASE: begin
                        StartRead(STATUS_BASE);
                        refference_w = {refference_r[247:0], avm_readdata[7:0]};
                        if(byte_counter_r[5]) begin
                            state_w = S_GET_READ;
                            byte_counter_w = 6'd0;
                        end
                    end
                    default: begin
                        
                    end
                endcase
            end
        end
        S_GET_READ: begin
            if(!avm_waitrequest) begin
                case (avm_address_r)
                    STATUS_BASE: begin
                        state_w = state_r;
                        if(avm_readdata[RX_OK_BIT]) begin
                            byte_counter_w = byte_counter_r + 1;
                            StartRead(RX_BASE);
                        end
                    end
                    RX_BASE: begin
                        StartRead(STATUS_BASE);
                        read_w = {read_r[247:0], avm_readdata[7:0]};
                        if(byte_counter_r[5]) begin
                            state_w = S_WAIT_SW_READY;
                            byte_counter_w = 6'd0;
                        end
                    end
                    default: begin
                        
                    end
                endcase
            end
        end
        S_WAIT_SW_READY: begin
            state_w = o_ready ? S_WAIT_COMPUTE : S_WAIT_SW_READY;
            result_w = 256'b0;
            SW_rst_w = 1;
        end
        S_WAIT_COMPUTE: begin
            if(!o_valid) begin
                i_valid_w = 1;
                i_ready_w = 1;
                SW_rst_w = 0;
            end
            else begin
                state_w = S_SEND_RESULT;
                StartRead(STATUS_BASE);
                result_w = {113'b0, column, 57'b0, row, 54'b0, score};
                i_valid_w = 0;
                i_ready_w = 0;
            end
        end
        S_SEND_RESULT: begin
            if(!avm_waitrequest) begin
                case(avm_address_r)
                    STATUS_BASE: begin
                        if(avm_readdata[TX_OK_BIT]) begin
                            StartWrite(TX_BASE);
                            byte_counter_w = byte_counter_r + 1;
                        end
                    end
                    TX_BASE: begin
                        StartRead(STATUS_BASE);
                        result_w = result_r << 8;
                        if (&byte_counter_r[4:0]) begin
                            state_w = S_GET_REFFERENCE;
                            byte_counter_w = 6'd0;
                        end
                    end
                    default: begin
                        
                    end
                endcase
            end
        end
        default: begin
            state_w = S_GET_REFFERENCE;
            byte_counter_w = 6'b0;
        end
    endcase
end

// TODO
always_ff @(posedge avm_clk or posedge avm_rst) begin
    if(avm_rst) begin
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_GET_REFFERENCE;
        byte_counter_r <= 6'b0;
        refference_r <= 256'b0;
        read_r <= 256'b0;
        result_r <= 248'b0;
        SW_rst_r = 0;
        i_ready_r = 0;
        i_valid_r = 0;
    end
	else begin
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        state_r <= state_w;
        byte_counter_r <= byte_counter_w;
        refference_r <= refference_w;
        read_r <= read_w;
        result_r <= result_w;
        SW_rst_r = SW_rst_w;
        i_ready_r = i_ready_w;
        i_valid_r = i_valid_w;
    end
end

endmodule