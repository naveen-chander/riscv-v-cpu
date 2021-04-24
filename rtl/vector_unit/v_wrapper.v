`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.04.2021 11:28:03
// Design Name: 
// Module Name: v_wrapper
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


module v_wrapper(
input 			clk 			,
input 			reset 			,
input [8:0]		vl				,		// Vector LENGTH Register
input 			I_clear			,	// Clear all instructions
input [2:0]		I_id			,	// Instruction 0 --> 7
output 			ALU_mon         ,
output 			stall			,
output  		DONE            ,
input 			I_start   		,
input [4:0]		I_vs1     		,
input [4:0]		I_vs2     		,
input [4:0]		I_vd      		,
input [31:0]	I_RS1    		,
input [31:0]	I_RS2    		,
input [4:0]		I_uimm5    		,
input [3:0]		I_funct   		,
input [1:0]		I_permute   	,
input 			I_mask_en 		,
input [1:0]		I_ALUSrc  		,
input 			I_dmr     		,
input 			I_dmw     		,
input 			I_reg_we  		,
input 			I_mem_reg 		,
input [1:0]		I_mode_lsu		
    );

wrapper wrapper_vhd(
	.clk 			(clk 		),
	.reset 			(reset 		),
	.vl				(vl			),
	.I_clear		(I_clear	),
	.I_id			(I_id		),
	.ALU_mon     	(ALU_mon    ),
	.stall			(stall		),
	.DONE        	(DONE       ),
	.I_start   		(I_start   	),
	.I_vs1     		(I_vs1     	),
	.I_vs2     		(I_vs2     	),
	.I_vd      		(I_vd      	),
	.I_RS1    		(I_RS1    	),
	.I_RS2    		(I_RS2    	),
	.I_uimm5    	(I_uimm5   	),
	.I_funct   		(I_funct   	),
	.I_permute   	(I_permute  ),
	.I_mask_en 		(I_mask_en 	),
	.I_ALUSrc  		(I_ALUSrc  	),
	.I_dmr     		(I_dmr     	),
	.I_dmw     		(I_dmw     	),
	.I_reg_we  		(I_reg_we  	),
	.I_mem_reg 		(I_mem_reg 	),
	.I_mode_lsu		(I_mode_lsu	)
	);
endmodule