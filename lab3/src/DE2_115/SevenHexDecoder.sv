module SevenHexDecoder (
	input        [4:0] i_hex,
	output logic [6:0] o_seven_ten,
	output logic [6:0] o_seven_one
);

/* The layout of seven segment display, 1: dark
 *    00
 *   5  1
 *    66
 *   4  2
 *    33
 */
parameter D0 = 7'b1000000;
parameter D1 = 7'b1111001;
parameter D2 = 7'b0100100;
parameter D3 = 7'b0110000;
parameter D4 = 7'b0011001;
parameter D5 = 7'b0010010;
parameter D6 = 7'b0000010;
parameter D7 = 7'b1011000;
parameter D8 = 7'b0000000;
parameter D9 = 7'b0010000;

always_comb begin
	o_seven_ten = 0; 
	o_seven_one = 0;
	case(i_hex)
		6'h00: begin o_seven_ten = D0; o_seven_one = D0; end
		6'h01: begin o_seven_ten = D0; o_seven_one = D1; end
		6'h02: begin o_seven_ten = D0; o_seven_one = D2; end
		6'h03: begin o_seven_ten = D0; o_seven_one = D3; end
		6'h04: begin o_seven_ten = D0; o_seven_one = D4; end
		6'h05: begin o_seven_ten = D0; o_seven_one = D5; end
		6'h06: begin o_seven_ten = D0; o_seven_one = D6; end
		6'h07: begin o_seven_ten = D0; o_seven_one = D7; end
		6'h08: begin o_seven_ten = D0; o_seven_one = D8; end
		6'h09: begin o_seven_ten = D0; o_seven_one = D9; end
		6'h0a: begin o_seven_ten = D1; o_seven_one = D0; end
		6'h0b: begin o_seven_ten = D1; o_seven_one = D1; end
		6'h0c: begin o_seven_ten = D1; o_seven_one = D2; end
		6'h0d: begin o_seven_ten = D1; o_seven_one = D3; end
		6'h0e: begin o_seven_ten = D1; o_seven_one = D4; end
		6'h0f: begin o_seven_ten = D1; o_seven_one = D5; end
		6'h10: begin o_seven_ten = D1; o_seven_one = D6; end
		6'h11: begin o_seven_ten = D1; o_seven_one = D7; end
		6'h12: begin o_seven_ten = D1; o_seven_one = D8; end
		6'h13: begin o_seven_ten = D1; o_seven_one = D9; end
		6'h14: begin o_seven_ten = D2; o_seven_one = D0; end
		6'h15: begin o_seven_ten = D2; o_seven_one = D1; end
		6'h16: begin o_seven_ten = D2; o_seven_one = D2; end
		6'h17: begin o_seven_ten = D2; o_seven_one = D3; end
		6'h18: begin o_seven_ten = D2; o_seven_one = D4; end
		6'h19: begin o_seven_ten = D2; o_seven_one = D5; end
		6'h1a: begin o_seven_ten = D2; o_seven_one = D6; end
		6'h1b: begin o_seven_ten = D2; o_seven_one = D7; end
		6'h1c: begin o_seven_ten = D2; o_seven_one = D8; end
		6'h1d: begin o_seven_ten = D2; o_seven_one = D9; end
		6'h1e: begin o_seven_ten = D3; o_seven_one = D0; end
		6'h1f: begin o_seven_ten = D3; o_seven_one = D1; end
		6'h20: begin o_seven_ten = D3; o_seven_one = D2; end
		default: begin o_seven_ten = 0; o_seven_one = 0; end
	endcase
end

endmodule
