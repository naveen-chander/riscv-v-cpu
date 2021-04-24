`timescale 1ns / 1ps
`include "defines.v"

module rf(rst,clk,led,p0_addr,p1_addr,p0,p1,
dst_addr,dst_data,we,mem_wb_freeze,irq_ctrl_dec_src1,irq_ctrl_dec_src2,irq_ctrl_wb
//,out_t0,out_t1,out_t2,sp
);
//////////////////////////////////////////////////////////////////
// Triple ported register file.  Two read ports (p0 & p1), and //
// one write port (dst).  Data is written on clock high, and  //
// read on clock low //////////////////////////////////////////
//////////////////////

input rst;
input clk;
output [31:0] led;
input [4:0] p0_addr;
input [4:0] p1_addr;
//input [4:0] p2_addr;
input[4:0] dst_addr;
input[31:0] dst_data;
input we;
input mem_wb_freeze;
input irq_ctrl_dec_src1;
input irq_ctrl_dec_src2;
input irq_ctrl_wb;

output reg[31:0] p0;
output reg[31:0] p1;
//output reg[31:0] p2;
//output [31:0] out_t0;
//output [31:0] out_t1;
//output [31:0] out_t2;
//output [31:0] sp;

reg [31:0] mem[0:31];
reg [31:0] mem_shadow[4:3];
reg [31:0] pc_reg;
wire rst_int;

assign rst_int = ~rst;
assign led = mem[17];
//assign out_t0 = mem[5];
//assign out_t1 = mem[6];
//assign out_t2 = mem[7];
//assign sp = mem[2];

// Register file will come up uninitialized except for //
// register zero which is hardwired to be zero.       //

always @ (posedge clk) begin
        if(~rst_int) begin
            mem[0] <= 32'b0;
            mem[1] <= 32'd10000;               //Return address not 0. Just to check end of program
           ///////  Mem [2] is used as stack pointer /////  20/09/2016 ///
           ////////////// mem[2] <= 32'd00;
            mem[2] <= 32'h65000;      
            mem[3] <= 32'h65500;
            mem[4] <= 32'd00;
            mem[5] <= 32'd00;
            mem[6] <= 32'd0;                  //for testing pipeline. Replace with all zeroes finally
            mem[7] <= 32'd0;                  //
            mem[8] <= 32'd00;
            mem[9] <= 32'd00;
            mem[10] <= 32'd00;
            mem[11] <= 32'b0;
            mem[12] <= 32'd00;
            mem[13] <= 32'd00;
            mem[14] <= 32'd00;
            mem[15] <= 32'd00;
            mem[16] <= 32'd00;
            mem[17] <= 32'd00;
            mem[18] <= 32'd00;                 //
            mem[19] <= 32'd00;                 //for testing pipeline
            mem[20] <= 32'd0;
            mem[21] <= 32'd0;
            mem[22] <= 32'd00;
            mem[23] <= 32'd00;
            mem[24] <= 32'd00;
            mem[25] <= 32'd00;
            mem[26] <= 32'd00;
            mem[27] <= 32'd00;
            mem[28] <= 32'd00;
            mem[29] <= 32'd00;
            //  Mem[30] is changed to normal //  20/09/2016 ///////
           // mem[30] <= 32'd10000;      ////////////////// 
             mem[30] <= 32'd00;            //stack pointer for factorial testing. Not real value
            mem[31] <= 32'd0;
            mem_shadow[3] <= 32'd0;
            mem_shadow[4] <= 32'd0;
        end
        else if (we & |dst_addr & ~irq_ctrl_wb & ~mem_wb_freeze) begin
            mem[dst_addr] <= dst_data;
        end
        else if (we & |dst_addr & irq_ctrl_wb & ~mem_wb_freeze) begin
            mem_shadow[dst_addr] <= dst_data;
        end        
end


/////////////////////////////
// RF is read on clock low //
/////////////////////////////
always @(*) begin
        p0 <= irq_ctrl_dec_src1 ? mem_shadow[p0_addr] : mem[p0_addr];
        p1 <= irq_ctrl_dec_src2 ? mem_shadow[p1_addr] : mem[p1_addr];
//        p2 <= mem[p2_addr];
end
endmodule