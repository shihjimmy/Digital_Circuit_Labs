`timescale 1ns/100ps
`include "Lab0_alu.v"

module test_alu;
reg [7:0] inputA,inputB;
reg clk,reset;
reg [2:0] instruction;
wire [15:0] alu_out;
reg	[15:0]	answer_d1,answer_d2;
integer i,j,outfile,pat_error;
integer true_out;
wire	[2:0]	test_instruction;

//////////////////////////////////////////////////////////////////////
// assign the instruction you want to test: 
// from 000 ~ 110 mapping to your instruction 000 ~ 110
// 111 means all instructions will be test
assign	test_instruction = 3'b111;
//////////////////////////////////////////////////////////////////////

alu alu_0( 
		   .clk_p_i(clk),
		   .reset_n_i(reset),
		   .data_a_i(inputA),
		   .data_b_i(inputB),
		   .inst_i(instruction),
		   .data_o(alu_out)
		   );

always #4 clk=~clk;                      //cycle time is 8ns

always@(posedge clk)
begin
	answer_d1 <= true_out[15:0];
	answer_d2 <= answer_d1;
end

initial begin
  $dumpfile("alu.vcd");
  $dumpvars;
  outfile=$fopen("alu_out.txt");          //open one file for writing
  if(!outfile) begin
    $display("Can not write file!");
    $finish;
  end

  pat_error=0;

  reset=1'b1;clk=1'b1;inputA=0;inputB=0;instruction=0;
  #2 reset=1'b0;                            // system reset
  #2 reset=1'b1;

	case(test_instruction)
	3'b000:
	begin
		// test for instruction: Add
		instruction=3'b000;
		for(i=0;i<255;i=i+1)
		begin
		  for(j=0;j<255;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=i+j;
		    #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		        begin
		          $fdisplay(outfile,"instruction:000 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
	end

	3'b001:
	begin
		// test for instruction: Sub
		instruction=3'b001;
		for(i=0;i<256;i=i+1)
		begin
		  for(j=0;j<256;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=j-i;
		    #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		        begin
		          $fdisplay(outfile,"instruction:001 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
	end

	3'b010:
	begin
		// test for instruction: Multiple
		instruction=3'b010;
		for(i=0;i<256;i=i+1)
		begin
		  for(j=0;j<256;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=j*i;
		    #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		        begin
		          $fdisplay(outfile,"instruction:010 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
	end
  
	3'b011:
	begin
		// test for instruction: Not
		instruction=3'b011;
		for(j=-128;j<128;j=j+1)
		begin
		  inputA=j[7:0];
		  true_out=(~j)&32'h000000ff;
		  #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		      begin
		          $fdisplay(outfile,"instruction:011 answer: %b, yours: %b",answer_d2,alu_out);
		        pat_error=pat_error+1;
		      end                           
		end
	end

	3'b100:
	begin
		// test for instruction: XOR
		instruction=3'b100;
		for(i=0;i<256;i=i+1)
		begin
		  for(j=0;j<256;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=(j^i)&32'h000000ff;
		    #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		        begin
		          $fdisplay(outfile,"instruction:100 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
	end

	3'b101:
	begin
		// test for instruction: abs
		instruction=3'b101;
		for(j=-128;j<128;j=j+1)
		begin
		  inputA=j[7:0];
		  true_out=(j<0) ? (~j+1)&32'h000000ff : (j)&32'h000000ff;
		  #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		      begin
		          $fdisplay(outfile,"instruction:101 answer: %b, yours: %b",answer_d2,alu_out);
		        pat_error=pat_error+1;
		      end                           
		end
	end

	3'b110:
	begin
		// test for instruction: Sub/2
		instruction=3'b110;
		for(i=0;i<256;i=i+1)
		begin
		  for(j=0;j<256;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=(j-i)>>1;
		    #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		        begin
		          $fdisplay(outfile,"instruction:110 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
	end

	3'b111:
	begin
		// test for instruction: Add
		instruction=3'b000;
		for(i=0;i<255;i=i+1)
		begin
		  for(j=0;j<255;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=i+j;
		    #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		        begin
		          $fdisplay(outfile,"instruction:000 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
		// test for instruction: Sub
		instruction=3'b001;
		for(i=0;i<256;i=i+1)
		begin
		  for(j=0;j<256;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=j-i;
		    #8
		        if((alu_out !== answer_d2))
		        begin
		          $fdisplay(outfile,"instruction:001 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
		// test for instruction: Multiple
		instruction=3'b010;
		for(i=0;i<256;i=i+1)
		begin
		  for(j=0;j<256;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=j*i;
		    #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		        begin
		          $fdisplay(outfile,"instruction:010 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
		// test for instruction: Not
		instruction=3'b011;
		for(j=-128;j<128;j=j+1)
		begin
		  inputA=j[7:0];
		  true_out=(~j)&32'h000000ff;
		  #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		      begin
		          $fdisplay(outfile,"instruction:011 answer: %b, yours: %b",answer_d2,alu_out);
		        pat_error=pat_error+1;
		      end                           
		end
		// test for instruction: XOR
		instruction=3'b100;
		for(i=0;i<256;i=i+1)
		begin
		  for(j=0;j<256;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=(j^i)&32'h000000ff;
		    #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		        begin
		          $fdisplay(outfile,"instruction:100 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
		// test for instruction: abs
		instruction=3'b101;
		for(j=-128;j<128;j=j+1)
		begin
		  inputA=j[7:0];
		  true_out=(j<0) ? (~j+1)&32'h000000ff : (j)&32'h000000ff;
		  #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		      begin
		          $fdisplay(outfile,"instruction:101 answer: %b, yours: %b",answer_d2,alu_out);
		        pat_error=pat_error+1;
		      end                           
		end
		// test for instruction: Sub/2
		instruction=3'b110;
		for(i=0;i<256;i=i+1)
		begin
		  for(j=0;j<256;j=j+1)
		  begin
		    inputA=i[7:0];inputB=j[7:0];
		    true_out=(j-i)>>1;
		    #8
		        if((alu_out !== answer_d2)&(~((i==0)&(j<=1))))
		        begin
		          $fdisplay(outfile,"instruction:110 answer: %b, yours: %b",answer_d2,alu_out);
		          pat_error=pat_error+1;
		        end                           
		  end
		end
	end
     endcase

     if(!pat_error)
       $display("\nCongratulations!! Your Verilog Code is correct!!\n");
     else
       $display("\nYour Verilog Code has %d errors. \nPlease read alu_out.txt for details.\n",pat_error);
  #10 $finish;
  


end

endmodule
