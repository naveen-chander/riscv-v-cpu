`timescale 1ns / 1ps

`include "defines.v"

module execute(rst,clk,
 alu_stall,
 src0,//first input register content
 src1, //2nd input register content
 shamt,
 imm, //31 bit immediate from decode stage register
 opcode,//opcode last 7 bits
 opcode1,//opcode1 first 7 bits
 control,//opcode control 3 bits
 jal,jalr,pc_id_ex, result,selA,selB,
 forw_rs1_wb,forw_rs2_wb,forw_rs1_mem,forw_rs2_mem,memdata,wbdata,branchchk,branch_taken,branchaddrtarget,br_in,
 lsu_op_in,lsu_op_out,lsu_forw,store_data_in,store_data_out,wb_op_in,wb_op_out,lsustall_i,lsustall_o,
 rd_id_i,rd_id_o,nop,wb_data,preop,pre_func,preop2,amo_i, 
 sc_o,amo_load_val_i, irq_ctrl,csr_indata,csr_wrdata,trap_en,eret,eret_o,mul_state_freeze,div_kill,mul_kill,
 stall_mul_int2,mul_op,div_op,mul_freeze
 );

//data to be forwarded by ex stage 
 input wb_op_in;
 input lsustall_i;
 input rst;
 input clk;
 input [4:0]rd_id_i;
 input [31:0] store_data_in;
 input br_in;
 output reg wb_op_out;
 output reg lsustall_o;
 output reg [31:0] store_data_out;
 output reg [4:0] lsu_op_out;                   //recirculate lsu_op signals between dec/ex for stall chk
 output reg [4:0] lsu_forw;                     //send lsu_op signals to lsu
 output reg [4:0] rd_id_o;

//////////////////////////////////

 //alu inputs
 input amo_i;
// input [31:0] amo_wb_addr;
 input alu_stall;
 input forw_rs1_mem;
 input forw_rs2_mem;
 input forw_rs1_wb;
 input forw_rs2_wb;
 input [4:0] lsu_op_in;
 input [31:0] memdata;
 input [31:0] wbdata;
 input [1:0] selA;
 input [1:0] selB;
 input [31:0] pc_id_ex;
 input jalr;
 input jal;
 input [31:0] src0;
 input [31:0] src1;
 input[5:0] shamt;
 input [31:0] imm;
 input [6:0] opcode;
 input[6:0] opcode1;
 input [2:0] control;
 input branchchk;
 input nop;                             //nop from decode stage
 input [31:0] amo_load_val_i;
////////////////
//to fetch stage
 output reg branch_taken;
 output reg [31:0] branchaddrtarget;
 output reg [6:0] preop;
 output reg pre_func;
 output reg [6:0] preop2;
////////////////
//to writeback/mem stage
 output reg [31:0] result;
 output reg [31:0] wb_data;
///////////////////////
//multiplier divider results input
//////////////////////////////////
//Irq_ctrl from decode stage. This signal disengages the branch signal so that the state saving instructions are not nop'ed by a jump
//instruction already in the pipeline
input irq_ctrl;
input eret;
output reg eret_o;
/////////////////////////////////////
//Signal the Dcache to check reservation and process
output reg sc_o;
output trap_en;
input [31:0] csr_indata;
output [31:0] csr_wrdata;

input mul_state_freeze;
input div_kill;
input mul_kill;
input mul_freeze;
input [1:0] mul_op;
input [1:0] div_op;
output reg stall_mul_int2;

/////////////////
 
// fsm for multiplier activation
parameter idle = 2'b00;
parameter act  = 2'b01;
parameter stay = 2'b10;
parameter div_stay = 2'b11;
 
reg [31:0] in1_mux;
reg [31:0] in2_mux;
wire br;
wire [4:0] lsu_op_int;
wire wb_op_int;

wire[31:0] src1int;
wire[31:0] resultslti ;
wire[31:0] resultsltiu;
wire[31:0] resultsltu;
wire[31:0] resultslt;
wire[31:0] adderout;
wire [31:0] addout;
wire [31:0] addoutw;
wire [31:0] sll;
wire [31:0] srl;
wire [31:0] sra;
wire [31:0] sllw;
wire [31:0] srlw;
wire [31:0] sraw;
wire [31:0] sllwout;
wire [31:0] srlwout;
wire [31:0] srawout;
wire[31:0] xorout;
wire[31:0] orout;
wire[31:0] andout;
wire[31:0] sllout;
wire[31:0] srlout;
wire[31:0] sraout;
wire beq,bne,blt,bge,bltu,bgeu;
wire [31:0] indata1;
wire [31:0] indata2;
wire [31:0] insrc0;
wire [31:0] insrc1;
wire is32;
reg [31:0] result_int;
wire [31:0] swap_o1;        //signals after performing swapping operations
wire [31:0] swap_o2;        //signals after performing swapping operations
wire [31:0] max;            //signed max of the two numbers
wire [31:0] maxu;           //unsigned max of the two numbers 
wire [31:0] min;            //signed min of the two numbers
wire [31:0] minu;           //unsigned min of the two numbers
wire [31:0] src0_int;
wire [31:0] src1_int;
wire [31:0] csr_wrdata_int;

 // ****
 
reg [1:0] state;
reg [1:0] next_state;
wire [31:0] muldiv_rs1;
wire [31:0] muldiv_rs2;
reg signal_div_kill;
wire div_start;
wire done_div;
reg mul_rst;
wire [63:0] P_int;
wire [31:0] div_res;
wire [31:0] mul_res;
reg mul_res_sel;

assign src0_int = src0;
assign src1_int = src1;

integer shamt_int;

assign indata1 = ((opcode == `op32_branch) | amo_i) ? in1_mux :       //if atomic instruction, dont use forwarding because the data from dcache is to be used, not from the pipeline 
                 (forw_rs1_mem) ? memdata : 
                 (forw_rs1_wb) ? wbdata : in1_mux;       //select usual data or forwarded data(data from ex/mem reg is given priority)

assign indata2 = ((opcode == `op32_branch) | (opcode == `op32_storeop)) ? in2_mux : 
                (forw_rs2_mem) ? memdata : 
                (forw_rs2_wb) ? wbdata : in2_mux;       //select usual data or forwarded data(data from ex/mem reg is given priority)

assign insrc0 = ((forw_rs1_mem) ? memdata : 
                ((forw_rs1_wb) ? wbdata : src0_int));       //select usual data or forwarded data(data from ex/mem reg is given priority)
assign insrc1 = ((forw_rs2_mem) ? memdata : 
                ((forw_rs2_wb) ? wbdata : src1_int));       //select usual data or forwarded data(data from ex/mem reg is given priority)              

assign beq = (insrc0 == insrc1) ? 1'b1 : 1'b0;
assign bne = ~beq;
assign blt = ($signed(insrc0) < $signed(insrc1)) ? 1'b1 : 1'b0;
assign bltu = (insrc0< insrc1) ? 1'b1 : 1'b0;
assign bge = ($signed(insrc0) >= $signed(insrc1)) ? 1'b1 : 1'b0;
assign bgeu = (insrc0 >= insrc1) ? 1'b1 : 1'b0;

//assign max = blt ? indata2 : indata1; 
//assign maxu = bltu ? indata2 : indata1; 
//assign min = bge ? indata2 : indata1;
//assign minu = bgeu ? indata2 : indata1;
// * written on 1 march 2017 AMO MAX and MIN  problem * //
assign max = ($signed(indata1) > $signed(indata2)) ? indata1 : indata2;
assign maxu = (indata1> indata2) ? indata1: indata2;
assign min = ($signed(indata1) <= $signed(indata2)) ? indata1 : indata2;
assign minu = (indata1 <= indata2) ? indata1 : indata2;

assign br = (( ((control==`func_beq) &  beq)
            | ((control==`func_bne) & bne) | ((control==`func_blt) & blt) | ((control==`func_bltu) & bltu) | 
            ((control==`func_bge) & bge) | ((control==`func_bgeu) & bgeu))
            & branchchk) | jal | jalr;
//assign branch_taken = br;                               //condition is valid and branch has to be taken

//assign branchaddrtarget = br ? result_int : pc;
always @(*) begin
    case(selA)
        2'b00:in1_mux <= src0_int;
        2'b01:in1_mux <= pc_id_ex;
        2'b10:in1_mux <= imm;
        2'b11:in1_mux <= amo_load_val_i;
        default:in1_mux <= 32'b0;
    endcase;
    case(selB)
        2'b00:in2_mux <= src1_int;
        2'b01:in2_mux <= pc_id_ex;
        2'b10:in2_mux <= imm;
        2'b11:in2_mux <= csr_indata;
        default:in2_mux <= 32'b0;
    endcase;
end
//lsu_op_int <= br ? 5'b0 : lsu_op_in;                    //if branch taken, then convert memory operations to nop else they continue
//wb_op_int <= br ? 1'b0 : wb_op_in;                      //if branch taken, then convert write back operations to nop, else they continue

assign resultsltu = (indata1 < indata2) ? {{31'b0},{1'b1}} : 32'h0;
assign resultslt = ($signed(indata1) < $signed(indata2))? {{31'b0},{1'b1}}: 32'h0;
assign addout = ((indata1) + (( (opcode == `op32_alu) & (opcode1 == `func_sub)) ? (~(indata2)+1) : indata2)); //select subtraction operation if it is an adder operation and the func7 is 0700000
assign xorout = indata1^indata2;
assign orout = indata1 | indata2;
assign andout = indata1 & indata2;
assign sll = indata1 << ((opcode == `op32_imm_alu) ? shamt_int : indata2[5:0]);
assign srl = indata1 >> ((opcode == `op32_imm_alu) ? shamt_int : indata2[5:0]);
assign sra = $signed(indata1) >>> ((opcode == `op32_imm_alu) ? shamt_int : indata2[5:0]);
assign adderout = addout;

assign trap_en = 1'b0;
assign csr_wrdata = trap_en ? pc_id_ex : csr_wrdata_int;
assign csr_wrdata_int =  ((control == 3'b001) || (control == 3'b101)) ? indata1 :
                 ( ((control == 3'b010) || (control == 3'b110)) ?  in2_mux | indata1 :
                 (((control == 3'b011) || (control == 3'b111)) ? (in2_mux & (~indata1)) : 32'b0)) ;

assign swap_o1 = indata2;           //swap indata1 and indata2
assign swap_o2 = indata1;           // "      "     "     "

assign sllout = sll;              //whether sllw or normal sll operation has to be performed
assign srlout = srl;              //whether srlw or normal srl operation has to be performed
assign sraout = sra;              //whether sraw or normal sra operation has to be performed

always @(*) begin
    if(( alu_stall | rst | br_in)) begin
        result <= 32'b0;
        eret_o <= 1'b0;
    end
    else begin
        result <= amo_i ? src0 : result_int;    
        eret_o <= eret;          //condition for store address in case of atomic instruction
    end
end

always @(*) begin
    casex({{opcode1},{control},{opcode}})
        {{7'b???????},{3'b???},{`op_lui}}:                   result_int <= imm;
        {{7'b???????},{3'b???},{`op_auipc}}:                 result_int <= adderout;
        {{7'b???????},{3'b???},{`jal}}:                      result_int <= adderout;
        {{7'b???????},{3'b???},{`jalr}}:                     result_int <= {{adderout[30:1]},1'b0};
        {{7'b???????},{3'b???},{`op32_branch}}:              result_int <= adderout;
        {{7'b???????},{3'b???},{`op32_loadop}}:              result_int <= adderout;
        {{7'b???????},{3'b???},{`op32_storeop}}:             result_int <= adderout;
        {{7'b???????},{`alu_addsub},{`op32_imm_alu}}:        result_int <= adderout;
        {{7'b0000000},{`alu_addsub},{`op32_alu}}:            result_int <= adderout;
        {{7'b0100000},{`alu_addsub},{`op32_alu}}:            result_int <= adderout;
        {{7'b???????},{`alu_slt},{`op32_imm_alu}}:           result_int <= resultslt;
        {{7'b0000000},{`alu_slt},{`op32_alu}}:               result_int <= resultslt;
        {{7'b???????},{`alu_sltu},{`op32_imm_alu}}:          result_int <= resultsltu;
        {{7'b0000000},{`alu_sltu},{`op32_alu}}:              result_int <= resultsltu;
        {{7'b0000000},{`alu_sll},{`op32_imm_alu}}:           result_int <= sllout;
        {{7'b0000000},{`alu_sll},{`op32_alu}}:               result_int <= sllout;
        {{7'b0000000},{`alu_srlsra},{`op32_imm_alu}}:           result_int <= srlout;
        {{7'b0000000},{`alu_srlsra},{`op32_alu}}:               result_int <= srlout;
        {{7'b0100000},{`alu_srlsra},{`op32_imm_alu}}:           result_int <= sraout;
        {{7'b0100000},{`alu_srlsra},{`op32_alu}}:               result_int <= sraout;
        {{7'b???????},{`alu_or},{`op32_imm_alu}}:               result_int <= orout;
        {{7'b0000000},{`alu_or},{`op32_alu}}:                   result_int <= orout;

        {{7'b???????},{`alu_xor},{`op32_imm_alu}}:   result_int <= xorout;
        {{7'b0000000},{`alu_xor},{`op32_alu}}:   result_int <= xorout;

        {{7'b???????},{`alu_and},{`op32_imm_alu}}:   result_int <= andout;
        {{7'b0000000},{`alu_and},{`op32_alu}}:   result_int <= andout;  
        {{7'b0000001},{3'b000},{`op32_muldiv}}:  result_int <= mul_res;
        {{7'b0000001},{3'b001},{`op32_muldiv}}:  result_int <= mul_res;
        {{7'b0000001},{3'b010},{`op32_muldiv}}:  result_int <= mul_res;
        {{7'b0000001},{3'b011},{`op32_muldiv}}:  result_int <= mul_res;
        {{7'b0000001},{3'b100},{`op32_muldiv}}:  result_int <= div_res;                              
        {{7'b0000001},{3'b101},{`op32_muldiv}}:  result_int <= div_res;                              
        {{7'b0000001},{3'b110},{`op32_muldiv}}:  result_int <= div_res;                              
        {{7'b0000001},{3'b111},{`op32_muldiv}}:  result_int <= div_res;                              
        {{7'b00001??},{3'b010},{`amo}}:          result_int <= swap_o1;         //amoswap instructions
        {{7'b00000??},{3'b010},{`amo}}:          result_int <= adderout;        //amoadd instructions
        {{7'b00100??},{3'b010},{`amo}}:          result_int <= xorout;          //amoxor instructions
        {{7'b01100??},{3'b010},{`amo}}:          result_int <= andout;          //amoand instructions
        {{7'b01000??},{3'b010},{`amo}}:          result_int <= orout;           //amoor instructions
        {{7'b10000??},{3'b010},{`amo}}:          result_int <= min;             //amomin instructions
        {{7'b10100??},{3'b010},{`amo}}:          result_int <= max;             //amomax instructions
        {{7'b11000??},{3'b010},{`amo}}:          result_int <= minu;            //amominu instructions
        {{7'b11100??},{3'b010},{`amo}}:          result_int <= maxu;            //amomaxu instructions        
        default:
            result_int <= 32'b0;
    endcase;
end 

always @(*) begin
    if((alu_stall | rst | br_in)) begin                                 // Stall implementation
        shamt_int <= 5'b0;
        branch_taken <= 1'b0;                               
        branchaddrtarget <= 32'b0;
        lsu_op_out <= 5'b0;
        lsu_forw <= 5'b0;
        store_data_out <= 32'b0;
        wb_op_out <= 1'b0;
        lsustall_o <= lsustall_i;                          //stall signal for mem and wb stages should not be interfered with
        rd_id_o <= 5'b0;
        sc_o <= 1'b0;                   
    end
    else begin
        shamt_int <= shamt;
        branch_taken <= br;                               //condition is valid and branch has to be taken
        branchaddrtarget <= br ? adderout : pc_id_ex;
        lsu_op_out <= lsu_op_in;
        lsu_forw <= lsu_op_in;
        store_data_out <= amo_i ? result_int : ((forw_rs2_mem) ? memdata : ((forw_rs2_wb) ? wbdata : store_data_in));
        wb_op_out <= wb_op_in;
        lsustall_o <= lsustall_i;
        rd_id_o <= rd_id_i;
        sc_o <= (opcode == `amo) & (opcode1[6:2] == 5'b00011);  //High for SC instruction  
    end
end


always @(*) begin
    if((alu_stall | rst | br_in)) begin
        preop <= 7'b0;
        pre_func <= 1'b0;
        preop2 <= 7'b0;
    end
    else begin
        preop <= opcode;
        pre_func <= control[2]; 
        preop2 <= opcode1;
    end
end

always @(*) begin
    if((alu_stall | rst | br_in)) begin
        wb_data <= 32'b0;    
    end
    else begin
        case(opcode)
            (`jal) : wb_data <= store_data_in ;
            (`jalr): wb_data <= store_data_in ;
            (`op32_branch) : wb_data <= 32'b0;
            (`op32_storeop): wb_data <= 32'b0;
            (`amo) : wb_data <= indata1;
            (`sys) : wb_data <= indata2;        // csr_indata can be used directly 
            default: wb_data <= result;
        endcase;
    end
end



assign muldiv_rs1 = forw_rs1_mem ? memdata : forw_rs1_wb ? wbdata : src0;
assign muldiv_rs2 = forw_rs2_mem ? memdata : forw_rs2_wb ? wbdata : src1;



always @( posedge clk) begin
    if(rst) begin
        state <= idle;
    end
    else if(~mul_state_freeze) begin
        state <= next_state;
    end
end

//edge detector logic for div_kill signal. We want to use only the 1-to-0 transition of div_kill for starting the fsm.
always @(posedge clk ) begin
    if(rst) begin
        signal_div_kill <= 1'b0;
    end
    else begin
        signal_div_kill <= div_kill;
    end
end
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign div_start = (signal_div_kill) & (~div_kill); 

always @(*) begin
case(state) 
    idle :  begin
            mul_rst <= mul_kill;                //mul_kill given by decode unit
            mul_res_sel <= 1'b0;
            if(~mul_kill) begin
#2              stall_mul_int2 <= 1'b1;
                next_state <= stay;
            end
            else if(div_start) begin
                next_state <= div_stay;
                stall_mul_int2 <= 1'b1;
            end
            else begin
#2              stall_mul_int2 <= 1'b0;
                next_state <= idle;
            end
            end
    stay :  begin
            mul_rst <= 1'b0;
            stall_mul_int2 <= 1'b1;
            next_state <= act;
            mul_res_sel <= 1'b0;
            end
    div_stay :  begin
            mul_rst <= 1'b0;
            mul_res_sel <= 1'b0;
            next_state <= done_div ? idle : div_stay;
            stall_mul_int2 <= ~done_div;            
           end
    act :  begin
            mul_rst <= 1'b0;
#2          stall_mul_int2 <= 1'b0;
            next_state <= idle;
            mul_res_sel <= 1'b0;
          end
           
    default : begin
            next_state <= idle;
            mul_res_sel <= 1'b0;
            mul_rst <= 1'b0;
            stall_mul_int2 <= 1'b0;            
            end
endcase
end



or1200_amultp2_32x32 or1( .X(muldiv_rs1), .Y(muldiv_rs2), .RST(mul_rst), .CLK(clk)
                            ,.mul_op(mul_op),.result_mul(mul_res),.FREEZE(mul_freeze)
                          );

divider div1(.dividend(muldiv_rs1),.divisor(muldiv_rs2),.clk(clk),.result(div_res),.sign(div_op[0])
                        ,.rst(),.op(div_op[1]),.start(div_start),.done(done_div)); 



endmodule
