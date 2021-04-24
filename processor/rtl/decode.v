`timescale 1ns / 1ps

`include "defines.v"

module decode(clk,rst,instruction,next_pc,pc_if_id,lsu_op_prev,jal,jalr,alu_op1,alu_op2,alu_fn,lsu_op,wb_op,pc_forw,
              rs1_data,rs2_data,opr1,opr2,rd_id,rs1_id,rs2_id,shamt,imm,selA,selB,branchchk,forw_rs1_mem,forw_rs1_wb,
              forw_rs2_mem,forw_rs2_wb,store_data,alu_lsu_wb_stall,stall_dec,branch_taken,
              branch_rd_id,nop,wb_op_forw,wb_op_pre_forw,rd_id_prev,rd_id_pre_prev,mul_op,
              mul_kill,div_op,div_kill,preop,pre_func,preop2,lsu_op_port2,amo_o,
              br_nop,ll_o,inst_inj,irq_ctrl,irq_ctrl_wb,irq_ctrl_o,count_sel,eret,mret,csr_adr,csr_wr_en,mepc_res);

input clk;
input rst;
input [31:0] instruction;                  //32 bit instruction
input [31:0] next_pc;               //next instruction pc for storing in jal/jalr instructions
input [31:0] pc_if_id;                   //the program counter from fetch stage
input [4:0] lsu_op_prev;            //previous instruction lsu_op
input [31:0] opr1;                  //data(src1) from register file
input [31:0] opr2;                  //data(src2) from register file
input branch_taken;                 //input from alu whether branch taken or not
input [4:0] branch_rd_id;           //branch instructions rd id
input nop;                          //signal for nop
input wb_op_forw;                   //wb_op signal for checking forwarding after branch
input wb_op_pre_forw;               //wb_op signal for checking forwarding after branch
input [4:0] rd_id_prev;             //previous instructions rd_id
input [4:0] rd_id_pre_prev;         //2 instructions previous rd_id
input [6:0] preop;
input pre_func;
input [6:0] preop2;
input br_nop;                       //select signal for branch result forwarding
//outputs to alu
output reg [31:0] pc_forw;          //program counter sent to execute stage 
output reg [1:0] selA;
output reg [1:0] selB;
output reg [6:0] alu_op1;           //alu_opcode[6:0]
output reg [6:0] alu_op2;           //alu_opcode[31:25]
output reg [2:0] alu_fn;            //alu_func[14:12]
output reg jal;                     //enabled if jal instruction
output reg jalr;                    //enabled if jalr instruction
output reg [31:0] rs1_data;         //inputs for alu
output reg [31:0] rs2_data;         //inputs for alu
output reg [5:0] shamt;             //shamt for alu
output reg [31:0] imm;              //immediate for alu
output reg branchchk;               //branch check on detection of conditional branch instruction 
output reg forw_rs1_mem;               //mem stage f/b for rs1
output reg forw_rs1_wb;                //writeback stage f/b for rs1
output reg forw_rs2_mem;               //mem stage f/b for rs2
output reg forw_rs2_wb;                //writeback stage f/b for rs2
output reg alu_lsu_wb_stall;                   //stall signal to alu stage
output reg amo_o;                   //to alu whether current instruction is atomic or not
////////////////////////
//outputs to mem stage
output reg [4:0] lsu_op;            //load store unit operation(read/write)
output reg [31:0] store_data;       //data for store signal
///////////////////////
//outputs to register file 
output reg [4:0] rs1_id;
output reg [4:0] rs2_id;
///////////////////////
//fetch stage outputs
input stall_dec;                    //null the input to decode stage by multiplier or divider stalls
//////////////////////

//outputs to wb stage
output reg wb_op;                   //write-back stage operation
output reg [4:0] rd_id;             
///////////////////////
//outputs to multiplier
output reg [1:0] mul_op;
output reg mul_kill;
//////////////////////
//outputs to divider
output reg [1:0] div_op;
output reg div_kill;
//////////////////////
//outputs to data cache 
output reg [4:0] lsu_op_port2;
output reg ll_o;               
output reg mret;               
output [11:0] csr_adr;               
output  csr_wr_en;  
output  mepc_res;  
///////////////////////
//I/O from the Interrupt controller interface
input [31:0] inst_inj;          //Injected instruction stream from Interrupt interface
input irq_ctrl;                 //Mux select line
input irq_ctrl_wb;              //Write-back stage signal. Whether to use shadow registers for writeback or normal ones.
output reg irq_ctrl_o;          //Signal to register file and to subsequent stages. For using shadow registers
/////////////////////////////////////////////
//Select Line to the system counters
output reg [3:0] count_sel;     //Counter select lines; For RDCYC[H],RDTIM[H],RDINSTR[H] instructions
////////////////////////////////////
//////////////////////////////////
output eret;                //Signal the irq interface to jump out of interrupt
////////////////
wire [31:0] inst;

wire adder;
wire rs1_read_op;
wire rs2_read_op;
wire stall_int;

wire rs1_mem;
wire rs2_mem;
wire rs1_wb;
wire rs2_wb;

wire [4:0] load_store_op;
wire [4:0] rs1;               //rs1 id
wire [4:0] rs2;               //rs2 id
wire [4:0] rd;                //rd id
wire forw_rs1_mem_int;
wire forw_rs1_wb_int;
wire forw_rs2_mem_int;
wire forw_rs2_wb_int;

//wire forw_rs1_amo_wb_int;
wire c_strt;                    //counter start

reg [4:0] rdarray [0:2];

reg count[5:0];
wire stall_mul;
wire amo;
reg uret;
assign eret = mret;

assign inst = irq_ctrl ? inst_inj : instruction;
assign rs1_read_op = ((inst[6:0] == `jalr) | (inst[6:0] == `op32_branch) | (inst[6:0] == `op32_loadop) | (inst[6:0] == `op32_storeop) | (inst[6:0] == `op32_imm_alu) |    
                     (inst[6:0] == `op32_alu) | (inst[6:0] == `op64_imm_alu) | (inst[6:0] == `op64_alu) | (inst[6:0] == `amo)  | ((inst[6:0] == `sys) && (inst[14] == 1'b0))) ? 1'b1 :   
                     (((inst[6:0] == `op_lui) | (inst[6:0] == `op_auipc) | (inst[6:0] == `jal)) ? 1'b0 : 1'b0); // whether rs1 has to be read or not
assign rs2_read_op = ((inst[6:0] == `op32_branch) | (inst[6:0] == `op32_storeop) | (inst[6:0] == `op32_alu) | (inst[6:0] == `op64_alu) | amo) ? 1'b1 : 1'b0; 
                                                                     //whether rs2 has to be read or not 


assign csr_adr = ((inst[6:0] == `sys) && (alu_fn != 3'b0)) ? inst[31:20] : 12'b0;
assign csr_wr_en = ((inst[6:0] == `sys) && (alu_fn != 3'b0) && (rs1 != 5'b0)) ? 1'b1 : 1'b0;
assign mepc_res = irq_ctrl && (inst== 32'h341021F3);

assign forw_rs1_mem_int = (rdarray[1] == rs1) & (rs1 != 0) & (br_nop ? 1'b1 : (wb_op_forw ? 1'b1 : 1'b0));
assign forw_rs1_wb_int = (rdarray[2] == rs1) & (rs1 != 0) & (wb_op_pre_forw ? 1'b1 : 1'b0);
assign forw_rs2_mem_int = (rdarray[1] == rs2) & (rs2 != 0) & (br_nop ? 1'b1 : (wb_op_forw ? 1'b1 : 1'b0));
assign forw_rs2_wb_int = (rdarray[2] == rs2) & (rs2 != 0) & (wb_op_pre_forw ? 1'b1 : 1'b0);
//assign forw_rs1_amo_wb_int = (rdarray[3] == rs1) & (rs1 != 0) & (br_nop ? 1'b1 : (wb_op_forw ? 1'b1 : 1'b0));
//stall generation-load operation followed by any operation on same register 
assign stall_int = (  (lsu_op_prev[1:0] == 2'b01) & ( (rs2_read_op & (rdarray[1] == rs2)) | ((rs1_read_op) & (rdarray[1] == rs1)) ) ) ? 1'b1 : 1'b0;
//assign stall = stall_int;
//assign alu_stall = stall_int;
//assign lsu_stall = stall_int;
//assign wb_stall = stall_int;
//

assign amo = (inst[6:0] == `amo);

//computation of shift register inputs 
assign rd = ((inst[6:0] == `op32_branch) | (inst[6:0] == `op32_storeop)) ? 5'b0 : inst[11:7];
assign rs1 = ((inst[6:0] == `op_lui) | (inst[6:0] == `op_auipc) | (inst[6:0] == `jal)) ? 5'b0 : inst[19:15];
assign rs2 = ((inst[6:0] == `op32_branch) | (inst[6:0] == `op32_storeop) | (inst[6:0] == `op32_alu) | (inst[6:0] == `op32_alu) | (inst[6:0] == `amo)) ? inst[24:20] : 5'b0;


assign stall_mul= stall_int ? 1'b0 : ((inst[6:0] == `op32_muldiv) & (~inst[14]) & (inst[31:25] == 7'b0000001));


always @(*) begin
            if(rst) begin
                rdarray[2] <= 5'b0;      
                rdarray[1] <= 5'b0;      
                rdarray[0] <= 5'b0;         
            end
            else begin
                rdarray[2] <= rd_id_pre_prev;
                rdarray[1] <= rd_id_prev;
                rdarray[0] <= rd;             //if branch is taken, then its a nop
            end
        end

always @(*) begin
    if((rst | branch_taken | nop | stall_dec)) begin
        alu_lsu_wb_stall <= 1'b0;
    end
    else begin
        alu_lsu_wb_stall <= stall_int;
    end
end


always @(*) begin
    if((rst | branch_taken | nop | stall_dec | stall_int)) begin    
        branchchk <= 1'b0;
        pc_forw <= 32'b0;
        alu_op1 <= 7'b0;
        alu_op2 <= 7'b0;
        alu_fn <= 3'b0;
        lsu_op <= 5'b0;
        wb_op <= 1'b0;
        jal <= 1'b0;
        jalr <= 1'b0;  
        rs1_data <= 32'b0;
        rs2_data <= 32'b0;
        forw_rs1_mem = 1'b0;
        forw_rs1_wb= 1'b0;  
        forw_rs2_mem = 1'b0;
        forw_rs2_wb = 1'b0;
        branchchk <= 1'b0;
        pc_forw <= 32'b0;   
        rs1_id <= 5'b0;
        rs2_id <= 5'b0;
        shamt <= 6'b0;     
        imm <= 32'b0;
        selA <= 2'b11;
        selB <= 2'b11;
        wb_op <= 1'b0;
        rd_id <= 5'b0;
        store_data <= 32'b0;
        mul_op <= 2'b11;
        div_op <= 1'b1;
        mul_kill <= 1'b1;
        div_kill <= 1'b1;
        lsu_op_port2 <= 5'b0;
        amo_o <= 1'b0;
        ll_o <= 1'b0;
        irq_ctrl_o <= 1'b0;
        count_sel <= 4'b1111;
        uret <= 1'b0;
        mret <= 1'b0;
    end
    else begin
    uret <= (inst[6:0] == `sys) & (inst[31:20] == 12'b000000000010);
    mret <= (inst[6:0] == `sys) & (inst[31:20] == 12'b001100000010);
    irq_ctrl_o <= irq_ctrl_wb;
    ll_o <= (inst[6:0] == `amo) & (inst[31:27] == 5'b00010);
    amo_o <= amo;
    lsu_op_port2 <= (amo & ~(inst[31:27] == 5'b00011)) ? 5'b01001 : 5'b0;   //No loading operation for SC instruction
    rs1_data <= opr1;          //replace operand by loaded value from cache
    rs2_data <= opr2;
//    nop_forw <= nop;
//store-unit data generation
    store_data <= stall_int ? 32'b0 : ((inst[6:0] == `jalr) | (inst[6:0] == `jal)) ? next_pc : opr2;
//


//forwarding signals assignment
forw_rs1_mem = (rs1_read_op) ? forw_rs1_mem_int : 1'b0;       //rs1 feedback from ex/mem stage
forw_rs1_wb= rs1_read_op ? forw_rs1_wb_int : 1'b0;           //rs1 feedback from mem/wb stage
forw_rs2_mem = rs2_read_op ? forw_rs2_mem_int : 1'b0;         //rs2 feedback from ex/mem stage
forw_rs2_wb = rs2_read_op ? forw_rs2_wb_int : 1'b0;          //rs2 feedback from mem/wb stage
//forw_rs1_rd_wr = rs1_read_op ? forw_rs1_rd_wr_int : 1'b0;    //forward before the mem/wb stage register; all others are after the register
///////////////////////////////

//branchchk is enabled if instruction detected is a conditional branch instruction
    branchchk <= (inst[6:0] == `op32_branch); 
//forward the program counter
    pc_forw <= pc_if_id;
//decoding of src and dest register addresses
    rd_id <= stall_int ? 5'b0 : rd;
    rs1_id <= rs1;
    rs2_id <= rs2;
    shamt <= {1'b0,inst[24:20]};


//jal and jalr instructions
    case(inst[6:0]) 
        `jal: begin
            jal <= stall_int ? 1'b0 : 1'b1; 
            jalr <= stall_int ? 1'b0 : 1'b0;
        end
        `jalr: begin
            jal <= stall_int ? 1'b0 : 1'b0;
            jalr <= stall_int ? 1'b0 : 1'b1;
        end
        default: begin
            jal <= 1'b0;
            jalr <= 1'b0;
        end
    endcase;
    
//decoding for load-store operation
    casez({inst[6:0],inst[14:12]}) 
       ({`op32_loadop,`func_lb}):
            lsu_op <= stall_int ? 5'b0 : 5'b00001;
       ({`op32_loadop,`func_lh}):
            lsu_op <= stall_int ? 5'b0 : 5'b00101;
       ({`op32_loadop,`func_lw}):
            lsu_op <= stall_int ? 5'b0 : 5'b01001;
       ({`op32_loadop,`func_ld}):
            lsu_op <= stall_int ? 5'b0 : 5'b01101;
       ({`op32_loadop,`func_lbu}):
            lsu_op <= stall_int ? 5'b0 : 5'b10001;
       ({`op32_loadop,`func_lhu}):
            lsu_op <= stall_int ? 5'b0 : 5'b10101;
       ({`op32_loadop,`func_lwu}):        
            lsu_op <= stall_int ? 5'b0 : 5'b11001;
       ({`op32_storeop, `func_sb}):
            lsu_op <= stall_int ? 5'b0 : 5'b00010;
       ({`op32_storeop, `func_sh}):
            lsu_op <= stall_int ? 5'b0 : 5'b00110;
       ({`op32_storeop, `func_sw}):
            lsu_op <= stall_int ? 5'b0 : 5'b01010;
       ({`op32_storeop, `func_sd}):
            lsu_op <= stall_int ? 5'b0 : 5'b01110;
       ({`amo,3'b010}):
            lsu_op <= (inst[31:27] == 5'b00010) ? 5'b00000 : 5'b01010;      //store for all atomic instructions except LR             
        default:
            lsu_op <= 5'b00000;
    endcase;

//decoding for writeback operation
    case(inst[6:0]) 
        `op_lui:    wb_op <= stall_int ? 1'b0 : 1'b1;
        `op_auipc:  wb_op <= stall_int ? 1'b0 : 1'b1;
        `jal:    wb_op <= stall_int ? 1'b0 : 1'b1;
        `jalr:        wb_op <=  stall_int ? 1'b0 : 1'b1;
        `op32_branch:   wb_op <=  stall_int ? 1'b0 : 1'b0;
        `op32_loadop:   wb_op <=  stall_int ? 1'b0 : 1'b1;
        `op32_storeop:  wb_op <=  stall_int ? 1'b0 : 1'b0;
        `op32_imm_alu:   wb_op <= stall_int ? 1'b0 : 1'b1;
        `op32_alu:       wb_op <= stall_int ? 1'b0 : 1'b1;
        `op64_imm_alu:   wb_op <= stall_int ? 1'b0 : 1'b1;
        `op64_alu:       wb_op <= stall_int ? 1'b0 : 1'b1;
        `amo:            wb_op <= stall_int ? 1'b0 : 1'b1;
        `sys:            wb_op <= stall_int ? 1'b0 : 1'b1;
        default:
            wb_op <= 1'b0;
    endcase;
//decoding for alu-operation 
alu_op1 <= inst[6:0];
alu_op2 <= inst[31:25];                      //for SLLI,SRLI,SRAI instructions, the ALU should ignore the LSB of alu_op2 and only use upper 6 bits. 
alu_fn <= inst[14:12];                       //hence, modify ALU for that
    
//imm_i <= {{44{inst[31]}},inst[31:20]}; 
//imm_s <= {{44{inst[31]}},{inst[31:25]},{inst[11:7]}};
//imm_sb <= {{44{inst[31]}},{inst[31]},{inst[7]},{inst[30:25]},{inst[11:8]},1'b0};
//imm_u <= {{52{inst[31]}},inst[31:12]};
//imm_uj <= {{44{inst[31]}},{inst[19:12]},{inst[20]},inst[30:21],1'b0};

//immediate generation logic

    case(inst[6:0]) 
        `jal:
            imm <= {{11{inst[31]}},{inst[31]},{inst[19:12]},inst[20],inst[30:21],1'b0};
        `jalr:
            imm <= {{20{inst[31]}},inst[31:20]}; 
        `op32_imm_alu:
            imm <= {{20{inst[31]}},inst[31:20]};
        `op_lui:
            imm <= {{inst[31:12]},12'b0};    
        `op_auipc:
            imm <= {{inst[31:12]},12'b0};
        `op32_branch:
            imm <= {{19{inst[31]}},{inst[31]},{inst[7]},{inst[30:25]},{inst[11:8]},1'b0};
        `op32_loadop:
            imm <= {{20{inst[31]}},inst[31:20]};  
        `op32_storeop:
            imm <= {{20{inst[31]}},{inst[31:25]},{inst[11:7]}};  
        `sys:
            imm <= { {27'b0} , {inst[19:15]}};  
        default:        
            imm <= 32'b0;
    endcase;

     case(inst[6:0]) 
        `op_lui: begin
            selA <= 2'b00;                      //dummy values
            selB <= 2'b00;                      //dummy values
        end
        `op_auipc: begin
            selA <= 2'b10;                      //select immediate from mux
            selB <= 2'b01;                      //select program counter from mux
        end
        `jal: begin
            selA <= 2'b10;                      //select immediate from mux
            selB <= 2'b01;                      //select program counter from mux
        end
        `jalr: begin
            selA <= 2'b00;                      //select rs1 from mux
            selB <= 2'b10;                      //select immediate from mux
        end
        `op32_branch: begin
            selA <= 2'b10;                       //select immediate from mux
            selB <= 2'b01;                       //select program counter from mux
        end             
        `op32_loadop: begin
            selA <= 2'b00;                      //select rs1 as one of the inputs
            selB <= 2'b10;                      //select immediate as the second input
        end
        `op32_storeop: begin
            selA <= 2'b00;                      //select rs1 as one of the inputs
            selB <= 2'b10;                      //select immediate as the second input
        end
        `op32_imm_alu: begin
            selA <= 2'b00;                      //select rs1 as input
            selB <= 2'b10;                      //select immediate as input
        end
        `op32_alu: begin
            selA <= 2'b00;                      //select rs1 as input
            selB <= 2'b00;                      //select rs2 as input
        end     
        `amo: begin
            selA <= 2'b11;                      //select rs1 data as input
            selB <= 2'b00;                      //select rs2 data as input
        end
        `sys: begin
            selB <= 2'b11;                      
            if ((alu_fn == 3'b001) ||(alu_fn == 3'b010) || (alu_fn ==3'b011))
                selA <= 2'b00; 
            else                     
                selA <= 2'b10; 
        end
        default: begin
            selA <= 2'b00;
            selB <= 2'b00;
        end
    endcase; 
    
//multiplier and divider module commands
    casez({inst[31:25],inst[14:12],inst[6:0]}) 
        {7'b0000001,`func_mul,`op32_muldiv}: begin
            mul_kill <= stall_int ? 1'b1 : 1'b0;
            div_kill <= stall_int ? 1'b1 : 1'b1;
            mul_op <= 2'b00;                                                //00 for signed multiplication
            div_op <= 2'b00;                                                 //dummy value
        end
        {7'b0000001,`func_mulh,`op32_muldiv}: begin
            mul_kill <= stall_int ? 1'b1 : 1'b0;
            div_kill <= stall_int ? 1'b1 : 1'b1;
            mul_op <= 2'b10;                                                //00 for signed multiplication - higher 32 bits
            div_op <= 2'b00;                                                 //dummy value
        end
        {7'b0000001,`func_mulhsu,`op32_muldiv}: begin
            mul_kill <= stall_int ? 1'b1 : 1'b0;
            div_kill <= stall_int ? 1'b1 : 1'b1;
            mul_op <= 2'b01;                                                //for signed*unsigned multiplication
            div_op <= 2'b0;                                                 //dummy value
        end
        {7'b0000001,`func_mulhu,`op32_muldiv}: begin
            mul_kill <= stall_int ? 1'b1 : 1'b0;
            div_kill <= stall_int ? 1'b1 : 1'b1;
            mul_op <= 2'b11;                                                //for unsigned*unsigned multiplication
            div_op <= 2'b0;                                                 //dummy value
        end
        {7'b0000001,`func_div,`op32_muldiv}: begin
            mul_kill <= stall_int ? 1'b1 : 1'b1;
            div_kill <= stall_int ? 1'b1 : 1'b0;
            mul_op <= 2'b11;                                                //dummy value
            div_op <= 2'b11;                                                 //signed quotient
        end
        {7'b0000001,`func_divu,`op32_muldiv}: begin
            mul_kill <= stall_int ? 1'b1 : 1'b1;
            div_kill <= stall_int ? 1'b1 : 1'b0;
            mul_op <= 2'b11;                                                //dummy value
            div_op <= 2'b10;                                                 //unsigned quotient
        end
        {7'b0000001,`func_rem,`op32_muldiv}: begin
            mul_kill <= stall_int ? 1'b1 : 1'b1;
            div_kill <= stall_int ? 1'b1 : 1'b0;
            mul_op <= 2'b11;                                                //dummy value
            div_op <= 2'b01;                                                 //signed remainder
        end
        {7'b0000001,`func_remu,`op32_muldiv}: begin
            mul_kill <= stall_int ? 1'b1 : 1'b1;
            div_kill <= stall_int ? 1'b1 : 1'b0;
            mul_op <= 2'b11;                                                //dummy value
            div_op <= 2'b00;                                                 //unsigned remainder
        end
        default: begin
            mul_kill <= 1'b1;
            div_kill <= 1'b1;        
            mul_op <= 2'b11;
            div_op <= 2'b00; 
        end
    endcase;

        case(inst[31:20])
            `mcycle    : count_sel <= (inst[6:0] == `sys) ? 4'b0000 : 4'b1111;   
            `mcycleh   : count_sel <= (inst[6:0] == `sys) ? 4'b0001 : 4'b1111;   
            `minstret  : count_sel <= (inst[6:0] == `sys) ? 4'b0100 : 4'b1111;   
            `minstreth : count_sel <= (inst[6:0] == `sys) ? 4'b0101 : 4'b1111;   
            `mtime     : count_sel <= (inst[6:0] == `sys) ? 4'b1000 : 4'b1111;   
            `mtimeh    : count_sel <= (inst[6:0] == `sys) ? 4'b1001 : 4'b1111;   
            `mtimecmp  : count_sel <= (inst[6:0] == `sys) ? 4'b1010 : 4'b1111;   
            `mtimecmph : count_sel <= (inst[6:0] == `sys) ? 4'b1011 : 4'b1111;   
            `counttick : count_sel <= (inst[6:0] == `sys) ? 4'b1100 : 4'b1111;   
            `Num_tick  : count_sel <= (inst[6:0] == `sys) ? 4'b1101 : 4'b1111;
            default : count_sel <= 4'b1111;   //Nothing selected; Garbage value   
        endcase;
  
end
end
endmodule
