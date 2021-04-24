`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.04.2021 00:41:42
// Design Name: 
// Module Name: vec_decoder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define OP_VEC_LOAD 			7'b0000111
`define OP_VEC_STORE			7'b0100111
`define OP_VEC_ARITH			7'b1010111

`define funct6__vadd 			6'b000000
`define funct6__vsub 			6'b000010
`define funct6__vslidedown 		6'b001111
`define funct6__vdiv 			6'b100001
`define funct6__vmulhu 			6'b100100
`define funct6__vmul 			6'b100101
`define funct6__vmulhsu 		6'b100110
`define funct6__vmulh	 		6'b100111
`define funct6__vmadd	 		6'b101001
`define funct6__vnmsub	 		6'b101011
`define funct6__vmacc	 		6'b101101
`define funct6__vnmsac	 		6'b101111


`define funct3__OPIVV	 		3'b000		// Integer Vector-Vector
`define funct3__OPIVI	 		3'b011		// Integer Vector-Immediate {simm5}
//`define funct3__OPIVX	 		3'b100		// Integer Vector-Scalar {rs1}
`define funct3__OPIVX	 		3'b110		// Integer Vector-Scalar {rs1}	// Due to compiler error







// Vector Load Store Format
//--------------------------------------------------------------------------------------------
/*
Format for Vector Load Instructions under LOAD-FP major opcode

////
31 29  28  27 26  25  24      20 19       15 14   12 11      7 6     0
 nf  | mew| mop | vm |  lumop   |    rs1    | width |    vd   |0000111| VL*  unit-stride
 nf  | mew| mop | vm |   rs2    |    rs1    | width |    vd   |0000111| VLS* strided
 nf  | mew| mop | vm |   vs2    |    rs1    | width |    vd   |0000111| VLX* indexed
  3     1    2     1      5           5         3         5       7
  
*/ 


// Vector Store Store Format
//--------------------------------------------------------------------------------------------
/*Format for Vector Store Instructions under STORE-FP major opcode
////
31 29  28  27 26  25  24      20 19       15 14   12 11      7 6     0
 nf  | mew| mop | vm |  sumop   |    rs1    | width |   vs3   |0100111| VS*  unit-stride
 nf  | mew| mop | vm |   rs2    |    rs1    | width |   vs3   |0100111| VSS* strided
 nf  | mew| mop | vm |   vs2    |    rs1    | width |   vs3   |0100111| VSX* indexed
  3     1    2     1      5           5         3         5        7
*/

  
// Vector aRITHMETIC INSTRUCTION fORMAT
//--------------------------------------------------------------------------------------------

/*
31       26  25   24      20 19      15 14   12 11      7 6     0
  funct6   | vm  |   vs2    |    vs1   | 0 0 0 |    vd   |1010111| OP-V (OPIVV)
  funct6   | vm  |   vs2    |    vs1   | 0 0 1 |  vd/rd  |1010111| OP-V (OPFVV)
  funct6   | vm  |   vs2    |    vs1   | 0 1 0 |  vd/rd  |1010111| OP-V (OPMVV)
  funct6   | vm  |   vs2    |   simm5  | 0 1 1 |    vd   |1010111| OP-V (OPIVI)
  funct6   | vm  |   vs2    |    rs1   | 1 0 0 |    vd   |1010111| OP-V (OPIVX)
  funct6   | vm  |   vs2    |    rs1   | 1 0 1 |    vd   |1010111| OP-V (OPFVF)
  funct6   | vm  |   vs2    |    rs1   | 1 1 0 |  vd/rd  |1010111| OP-V (OPMVX)
     6        1        5          5        3        5        7
*/


module vec_decoder(	
    input [31:0] 		Instruction     ,
	input 				reset			,
	input				Data_Cache__Stall,
	output reg 			S_VECn			,
	output reg [4:0]	decode__vs1     ,	
	output reg [4:0]	decode__vs2     ,
	output reg [4:0]	decode__vd      ,
	output reg [4:0]	decode__RS1     ,
	output reg [4:0]	decode__RS2     ,
	output reg [4:0]	decode__uimm5   ,
	output reg [3:0]	decode__funct   ,
	output reg [1:0]	decode__permute ,
	output reg 			decode__mask_en ,
	output reg [1:0]	decode__ALUSrc  ,
	output reg 			decode__dmr     ,
	output reg 			decode__dmw     ,
	output reg 			decode__reg_we  ,
	output reg 			decode__mem_reg ,
	output reg [1:0]	decode__mode_lsu
    );
wire [7:0] opcode;
wire [5:0] funct6;
wire [2:0] funct3;
wire [4:0] rs1;
wire [4:0] rs2;
wire [4:0] vs1;
wire [4:0] vs2;
wire [4:0] vd;
wire [4:0] rd;
wire [4:0] uimm5;

wire 	   vector_mask;
//////////////Decode logic		////////////////////

assign opcode 		= Instruction[6:0];
assign funct6 		= Instruction[31:26];
assign funct3 		= Instruction[14:12];
assign vector_mask 	= ~Instruction[25];
assign rs1 	  		= Instruction[19:15];
assign vs1 	  		= Instruction[19:15];
assign vs2 	  		= Instruction[24:20];
assign rs2 	  		= Instruction[24:20];
assign vd  	  		= Instruction[11:7];
assign rd  	  		= Instruction[11:7];
assign uimm5  		= Instruction[19:15];


always @(*) begin
	if (reset|Data_Cache__Stall) 	
		S_VECn				<= 1;	//Scalar Instruction by default
	else
		S_VECn <=  ( (opcode == `OP_VEC_LOAD) || (opcode == `OP_VEC_STORE)  || ((opcode == `OP_VEC_ARITH) && funct3 !=3'b111) )? 1'b0 : 1'b1;
end
always @(*) begin
	if (reset|S_VECn) begin	
		decode__vs1         <= 0;
		decode__vs2         <= 0;
		decode__vd          <= 0;
		decode__RS1         <= 0;
		decode__RS2         <= 0;
		decode__uimm5       <= 0;
		decode__funct       <= 0;
		decode__permute     <= 0;
		decode__mask_en     <= 0;
		decode__ALUSrc      <= 0;
		decode__dmr         <= 0;
		decode__dmw         <= 0;
		decode__reg_we      <= 0;
		decode__mem_reg     <= 0;
		decode__mode_lsu    <= 0;
	end
	else begin
		decode__vs1 <= ((opcode == `OP_VEC_LOAD) || (opcode == `OP_VEC_STORE))? 0 : 
					   ((opcode==`OP_VEC_ARITH)  && ((funct3 == `funct3__OPIVX) || (funct3 == `funct3__OPIVX))) ? 0: vs1;
		decode__vs2 <= ((opcode == `OP_VEC_LOAD) || (opcode == `OP_VEC_STORE))? 0 : vs2;
		decode__vd  <= vd;
		decode__RS1 <= ((opcode == `OP_VEC_LOAD) || (opcode == `OP_VEC_STORE))? rs1 : 
					((opcode==`OP_VEC_ARITH)  && (funct3 == `funct3__OPIVX))? rs1: 0;
		decode__RS2 <= ((opcode == `OP_VEC_LOAD) || (opcode == `OP_VEC_STORE))? 0 : rs2;
		decode__uimm5  <= ((opcode == `OP_VEC_ARITH) &&(funct3 == `funct3__OPIVI)) ? uimm5 : 0;	
		
		if 	(opcode == `OP_VEC_ARITH)
		case(funct6)
			`funct6__vadd 			: decode__funct <= 4'b0;
			`funct6__vsub 			: decode__funct <= 4'b0;	//Yet to be implemented	
			`funct6__vslidedown 	: decode__funct <= 4'b0;	
			`funct6__vdiv 		    : decode__funct <= 4'b1000;
			`funct6__vmulhu 		: decode__funct <= 4'b0100;
			`funct6__vmul 		    : decode__funct <= 4'b0001;
			`funct6__vmulhsu 	    : decode__funct <= 4'b0010;
			`funct6__vmulh	 	    : decode__funct <= 4'b0010;
			`funct6__vmadd	 	    : decode__funct <= 4'b0000;	// Yet to be implemented
			`funct6__vnmsub	 	    : decode__funct <= 4'b0000; //Yet to be implemented
			`funct6__vmacc	 	    : decode__funct <= 4'b0011;
			`funct6__vnmsac	 	    : decode__funct <= 4'b0100;
			default 				: decode__funct <= 4'b0000;  //vadd
		endcase
		decode__permute <= ( (opcode == `OP_VEC_ARITH) && (funct6 ==`funct6__vslidedown) ) ? 2'b01 : 0;	//Fix to slide1down
		decode__mask_en <= vector_mask;
		//-------------decode__ALUSrc-----------------------
		if (opcode == `OP_VEC_ARITH)
		  if (funct3 == `funct3__OPIVX)
		      decode__ALUSrc <= 2'b01;
		  else if (funct3 == `funct3__OPIVI)
		      decode__ALUSrc <= 2'b11;
		  else
		      decode__ALUSrc <= 2'b00;
		else
		  decode__ALUSrc <= 2'b00;
        //-----------------------------------------------------
		decode__dmr		<= (opcode == `OP_VEC_LOAD)   ? 1'b1 :1'b0;
		decode__dmw		<= (opcode == `OP_VEC_STORE)  ? 1'b1 :1'b0;
		decode__reg_we	<= ((opcode == `OP_VEC_LOAD)  || (opcode == `OP_VEC_ARITH))  ? 1'b1 :1'b0;
		decode__mem_reg	<= ((opcode == `OP_VEC_LOAD))  ? 1'b1 :1'b0;
		decode__mode_lsu<= ((opcode == `OP_VEC_LOAD))  ? Instruction[27:26] :1'b0;
	end 
end
endmodule