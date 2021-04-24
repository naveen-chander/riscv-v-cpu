`timescale 1ns / 1ps
`include "defines.v"

module fet_dec_ex(rst,clk, lsustall_o,store_data_out,lsu_op_port1,amo_load_val_i,lsu_op_port2,proc_addr_port2,
                  freeze_int,icache_freeze,pc_cache,instruction,sc_o,ll_o,stall_mul,stall,
                  proc_addr_port1,eret_ack,tick_en,addr_exception,led,proc_data_port1_int,interrupt,icache_en_o
                `ifdef itlb_def
                ,vpn_to_ppn_req 
                `endif            
                  );

input clk;
input rst;
input [31:0] amo_load_val_i;
input freeze_int;
input icache_freeze;
input [31:0] instruction;

output lsustall_o;              //mem stage stall
output [31:0] store_data_out;   //data to be stored(only used for memory stage)
output [4:0] lsu_op_port1;          //memory stage operation signals to lsu
output  [4:0] lsu_op_port2;
output reg [31:0] proc_addr_port2;         //contents of rs1 sent to dcache to read dcache
output [31:0] pc_cache;         //send pc to data-cache
output ll_o;         //to register file
output sc_o;
output stall_mul;
output reg stall;
output reg [31:0] proc_addr_port1;  //to memory stage

output eret_ack;

`ifdef itlb_def
output vpn_to_ppn_req;
`endif

output tick_en;
input addr_exception;
input [31:0] interrupt;

input [31:0] proc_data_port1_int;

output [31:0] led;
output icache_en_o;

wire br_nop;
wire [31:0] pc_if_id;
wire [31:0] next_pc;
reg nop_dec_i;
wire nop;
wire [4:0] nop_rd_i;
reg [4:0] rd_id_o_if_d;
wire [31:0] wb_data_if_d;
wire [31:0] proc_addr_port2_int;
wire [31:0] csr_mtvec;
wire irq_ctrl_dec;              //Use shadow registers for decoding
reg alu_lsu_wb_stall;
reg [4:0] rd_id_o;           //destination register id for write-back stage
 
 wire [31:0] opr1;
 wire [31:0] opr2;

 
// mem/wb register forwarding of data
always @(posedge clk) begin
    if(~((stall_mul || freeze_int) || icache_freeze)) begin
        rd_id_o_if_d <= rd_id_o;
    end
end

wire [31:0] pc_forw;
wire [31:0] rs1_data;
wire [31:0] rs2_data;
wire [31:0] imm;
wire [31:0] store_data;
wire [6:0] alu_op1;
wire [6:0] alu_op2;
wire [5:0] shamt;
wire [4:0] rd_id;
wire [4:0] lsu_op;
wire [4:0] lsu_op_prev;
wire [2:0] alu_fn;
wire [1:0] selA;
wire [1:0] selB;
wire branchchk;
wire forw_rs1_mem;
wire forw_rs1_wb;
wire forw_rs2_mem;
wire forw_rs2_wb;
wire jal;
wire jalr; 
wire wb_op;
wire [31:0] result_int;
reg [31:0] result_int2;
wire [31:0] count;                 //System timers/counter value. RDCYC[H], RDTIM[H], RDINST[H] instructions
/////////////////////////////////////
//inputs of alu coming from register
reg  [31:0] src0_alu;//first input register content
reg  [31:0] src1_alu; //2nd input register content
reg  [5:0] shamt_alu;
reg  [31:0] imm_alu; //31 bit immediate from decode stage register
reg  [6:0] opcode;//opcode last 7 bits
reg  [6:0] opcode1;//opcode1 first 7 bits
reg  [2:0] control;//opcode control 3 bits
reg  jal_alu;
reg  jalr_alu;
reg  [31:0] pc_id_ex;
reg  [1:0] selA_alu;
reg  [1:0] selB_alu;
reg  forw_rs1_wb_alu;
reg  forw_rs2_wb_alu;
reg  forw_rs1_mem_alu;
reg  forw_rs2_mem_alu;
reg  branchchk_alu;
reg  [4:0] lsu_op_in;
reg  [4:0] lsu_op_out;
reg  [31:0] store_data_in;
reg  wb_op_in;
reg  lsustall_i;
reg  wb_stall_i;
reg  [4:0] rd_id_i;
wire wb_op_out_int;
//output reg [4:0] lsu_op_out;                   //recirculate lsu_op signals between dec/ex for stall chk
wire [4:0] rd_id_o_int;
wire branch_taken_int;
wire [31:0] branchaddrtarget_int;
wire [4:0] rs1_id;
wire [4:0] rs2_id;
wire alu_lsu_wb_stall_int;                       //stall signal to fetch stage                   
wire wb_op_forw_int;
wire [31:0] wb_data_int;
//wires for multiplier and divider unit
wire [1:0] mul_op_int;            
wire [1:0] div_op_int;            
wire mul_kill_int;                
wire div_kill_int;                
wire [6:0] preop;
wire pre_func;
wire [6:0] preop2;
wire irq_ctrl_int;
reg irq_ctrl_int2;

reg [1:0] mul_op;            //multiplication operation
reg [1:0] div_op;            //division operations
reg mul_kill;                //multiplier unit reset
reg div_kill;                //division unit reset
reg nop_int3;                //br_nop signal forwarded to execute stage from decode stage

reg wb_op_out_int2;
reg [31:0] wb_data_o;          //data to be written back
reg branch_taken_int2;
reg [31:0] branchaddrtarget_int2;
reg [3:0] wr_sel;

//atomic instruction signals
wire amo_o;
reg amo_i;
////////////////////////////
wire [31:0] csr_wrdata;
reg [11:0] csr_adr;
wire [11:0] csr_adr_int;
wire [31:0] csr_indata;
wire [31:0] csr_indata_intr;
reg  csr_wr_en;
reg  mepc_res;
wire  trap_en;
wire  csr_wr_en_int;
wire  mepc_res_int;
wire  mret_int;
reg  mret;
//////////////////////

wire [3:0] count_sel_int;
wire mul_state_freeze;

wire badaddr;
reg eret;

wire tick_en_int;

wire [31:0] wb_data_int2;
wire [5:0] device_id;
wire [31:0] inst_inj;              //Injected instruction stream
reg irq_ctrl_o;
reg  [31:0] wb_data_int3;
reg [4:0] lsu_op_mem;       //to keep track of lsuop in the current instr in mem. decides whether wb_data to be used or loaded value.
reg  sc;


assign mul_state_freeze = ( ((stall_mul || freeze_int) || icache_freeze) && ~stall_mul);
assign tick_en  = tick_en_int && mtie;
assign badaddr = ((~proc_addr_port1[0] && ~proc_addr_port1[1]) || (~pc_id_ex[0] && ~pc_id_ex[1])) ;
assign wb_data_int2 = (((~lsu_op_mem[1]) & (lsu_op_mem[0])) | sc) ? proc_data_port1_int : wb_data_o;         //For conventional loads
assign  icache_en_o = ~stall_mul & ~freeze_int & ~irq_icache_freeze;

always @(*) begin
    proc_addr_port1 <= amo_i ? (forw_rs1_mem_alu ? (result_int2) : (forw_rs1_wb_alu ? wb_data_int3 : src0_alu)) : result_int;
    proc_addr_port2 <= forw_rs1_mem ? wb_data_int : (forw_rs1_wb ? wb_data_int2 : opr1);    //forwarding for rs1 of amo
    stall <= ((stall_mul || freeze_int) || icache_freeze) ? 1'b0 : alu_lsu_wb_stall_int;
    end


//////////////////////////////////////
//register between decode/execute stage
always @(posedge clk ) begin
    if(rst) begin
        result_int2 <= 32'b0;               
        branch_taken_int2  <= 1'b0;
        branchaddrtarget_int2  <= 32'b0;
        wb_op_out_int2  <= 1'b0;
        rd_id_o  <= 5'b0;
        nop_int3 <= 1'b0;                                       //nop from if/id stage
        alu_lsu_wb_stall <= 1'b0;
        src0_alu <= 32'b0;
        src1_alu <= 32'b0;
        shamt_alu <= 6'b0;
        imm_alu <= 32'b0;
        opcode <= 7'b0;
        opcode1 <= 7'b0;
        control <= 3'b0;
        jal_alu <= 1'b0;
        jalr_alu <= 1'b0;
        pc_id_ex <= 32'b0;
        selA_alu <= 2'b0;
        selB_alu <= 2'b0;       
        forw_rs1_wb_alu <= 1'b0;
        forw_rs2_wb_alu <= 1'b0;
        forw_rs1_mem_alu <= 1'b0;
        forw_rs2_mem_alu <= 1'b0;
        branchchk_alu <= 1'b0;
        lsu_op_in <= 5'b0;
        wb_op_in <= 1'b0;
        wb_stall_i <= 1'b0;
        rd_id_i <= 5'b0; 
        rd_id_i <= 5'b0;
        wb_data_o <= 32'b0; 
        mul_op <= 2'b00;
        div_op <= 2'b00;
        mul_kill <= 1'b1;
        div_kill <= 1'b1;
        amo_i <= 1'b0;
//        amo_wb_addr <= 32'b0;
        irq_ctrl_int2 <= 1'b0;
        store_data_in <= 0;
        irq_ctrl_o <= 1'b0;
        wr_sel <= 3'b0;
        csr_wr_en <= 1'b0;
        mepc_res <= 1'b0;
        mret <= 1'b0;
        csr_adr <= 12'b0;
        eret <= 1'b0;
    end
    else if(~((stall_mul || freeze_int) || icache_freeze)) begin
            alu_lsu_wb_stall <= alu_lsu_wb_stall_int;
            src0_alu <= rs1_data;
            src1_alu <= rs2_data;
            shamt_alu <= shamt;
            imm_alu <= imm;
            opcode <= alu_op1;
            opcode1 <= alu_op2;
            control <= alu_fn;
            jal_alu <= jal;
            jalr_alu <= jalr;
            pc_id_ex <= pc_forw;
            selA_alu <= selA;
            selB_alu <= selB;       
            forw_rs1_wb_alu <= forw_rs1_wb;
            forw_rs2_wb_alu <= forw_rs2_wb;
            forw_rs1_mem_alu <= forw_rs1_mem;
            forw_rs2_mem_alu <= forw_rs2_mem;            
            branchchk_alu <= branchchk;
            lsu_op_in <= lsu_op;
            store_data_in <= store_data;
            wb_op_in <= wb_op;
            rd_id_i <= rd_id; 
            mul_op <= mul_op_int;
            div_op <= div_op_int;
            div_kill <= div_kill_int;
            mul_kill <= mul_kill_int;
            amo_i <= amo_o;
//            amo_wb_addr <= opr1;
/////////////////////////////////////////
///////assigning output of execute stage to outputs of module
            result_int2 <= result_int;               
            branch_taken_int2  <= branch_taken_int;
            branchaddrtarget_int2  <= branchaddrtarget_int;
            wb_op_out_int2  <= wb_op_out_int;
            rd_id_o  <= rd_id_o_int;
            nop_int3 <= br_nop;                                       //nop from decode to execute stage
            wb_data_o <= wb_data_int;
            irq_ctrl_int2 <= irq_ctrl_int;
            irq_ctrl_o <= irq_ctrl_int2;                                //Output of decode_execute stage
            wr_sel <= count_sel_int;
            csr_wr_en <= csr_wr_en_int;
            mepc_res <= mepc_res_int;
            csr_adr <= csr_adr_int;
            mret <= mret_int;
            eret <= eret_int;
        end
    else if(stall_mul) begin
            div_kill <= 1'b1;
    end 
end

always @(posedge clk ) begin
    if(rst) 
        lsustall_i <= 1'b0;
    else
        lsustall_i <= alu_lsu_wb_stall_int;
end

always @(posedge rst or posedge clk) begin
    if(rst) begin
        wb_data_int3 <= 32'b0;
    end
    else begin
        if(~((stall_mul || freeze_int) || icache_freeze) ) begin
            wb_data_int3 <= wb_data_int2;                    
        end    
    end
end

always @(posedge rst or posedge clk) begin
    if(rst) begin
        lsu_op_mem <= 5'b0;
        sc         <= 1'b0;
    end
    else begin
        if(~((stall_mul || freeze_int) || icache_freeze)) begin
            lsu_op_mem <= lsu_op_port1;        
            sc         <= sc_o;
        end
    end
end


instrfetch if1 (.branch(branch_taken_int2),.clk(clk),.branchaddress(branchaddrtarget_int2),.rst(rst),.stall(stall),
               .if_id_freeze(if_id_freeze || freeze_int || icache_freeze || stall_mul),.irq_if_ctrl(irq_if_ctrl),.nop(nop),.nop_rd_id(rd_id_o_if_d)
               ,.nop_rd_o(nop_rd_i),.pc_if_id(pc_if_id),.next_pc(next_pc),.br_nop(br_nop),.pc(pc_cache)
           ,.device_id(device_id),.csr_mtvec(csr_mtvec)
           `ifdef itlb_def
           ,.vpn_to_ppn_req1(vpn_to_ppn_req)
           `endif  
           );
                                                                                    //data coming from the dcache memory                                                                        

decode d1(.clk(clk),.rst(rst | branch_taken_int2),.instruction(instruction),.next_pc(next_pc),.pc_if_id(pc_if_id)
          ,.lsu_op_prev(lsu_op_prev),.jal(jal),.jalr(jalr),.alu_op1(alu_op1),.alu_op2(alu_op2),.alu_fn(alu_fn)
          ,.lsu_op(lsu_op),.wb_op(wb_op),.pc_forw(pc_forw),.rs1_data(rs1_data),.rs2_data(rs2_data),.opr1(opr1)
          ,.opr2(opr2),.rd_id(rd_id),.rs1_id(rs1_id),.rs2_id(rs2_id),.shamt(shamt),.imm(imm),.selA(selA)
          ,.selB(selB),.branchchk(branchchk),.forw_rs1_mem(forw_rs1_mem),.forw_rs1_wb(forw_rs1_wb),
          .forw_rs2_mem(forw_rs2_mem),.forw_rs2_wb(forw_rs2_wb),.store_data(store_data)
          ,.stall_dec(stall_mul),.alu_lsu_wb_stall(alu_lsu_wb_stall_int)
          ,.branch_taken(branch_taken_int2),.branch_rd_id(nop_rd_i),.nop(nop),.wb_op_forw(wb_op_in)
          ,.wb_op_pre_forw(wb_op_out_int2),.rd_id_prev(rd_id_i),.rd_id_pre_prev(rd_id_o)
          ,.mul_op(mul_op_int),.mul_kill(mul_kill_int),.div_op(div_op_int)
          ,.div_kill(div_kill_int),.preop(preop),.pre_func(pre_func),.preop2(preop2)
          ,.lsu_op_port2(lsu_op_port2),.amo_o(amo_o)
          ,.br_nop(br_nop),.ll_o(ll_o),.inst_inj(inst_inj),.irq_ctrl(irq_ctrl),.irq_ctrl_wb(irq_ctrl_wb_i)
          ,.irq_ctrl_o(irq_ctrl_int),.count_sel(count_sel_int),.eret(eret_int),.csr_wr_en(csr_wr_en_int)
          ,.mret(mret_int),.csr_adr(csr_adr_int),.mepc_res(mepc_res_int));
              
execute e1(    .clk(clk),.rst(rst),.alu_stall(alu_lsu_wb_stall),.src0(src0_alu),//first input register content
               .src1(src1_alu), //2nd input register content
               .shamt(shamt_alu),
               .imm(imm_alu), //31 bit immediate from decode stage register
               .opcode(opcode),//opcode last 7 bits
               .opcode1(opcode1),//opcode1 first 7 bits
               .control(control),//opcode control 3 bits
               .jal(jal_alu),.jalr(jalr_alu),.pc_id_ex(pc_id_ex),.result(result_int),.selA(selA_alu),.selB(selB_alu)
               ,.eret(eret),.eret_o(eret_o),.forw_rs1_wb(forw_rs1_wb_alu),.forw_rs2_wb(forw_rs2_wb_alu)
               ,.forw_rs1_mem(forw_rs1_mem_alu),.forw_rs2_mem(forw_rs2_mem_alu),.memdata(wb_data_o),.wbdata(wb_data_int3)
               ,.branchchk(branchchk_alu),.branch_taken(branch_taken_int),.branchaddrtarget(branchaddrtarget_int)
               ,.br_in(branch_taken_int2),.lsu_op_in(lsu_op_in),.lsu_op_out(lsu_op_prev),.lsu_forw(lsu_op_port1)
               ,.store_data_in(store_data_in),.store_data_out(store_data_out),.wb_op_in(wb_op_in),.amo_i(amo_i)
               ,.wb_op_out(wb_op_out_int),.lsustall_i(lsustall_i),.lsustall_o(lsustall_o),.rd_id_i(rd_id_i)
               ,.rd_id_o(rd_id_o_int),.nop(nop_int3),.wb_data(wb_data_int),.preop(preop),.pre_func(pre_func)
               ,.preop2(preop2),.sc_o(sc_o),.amo_load_val_i(amo_load_val_i),.irq_ctrl(irq_ctrl_int2)
               //,.amo_wb_addr(amo_wb_addr)
               ,.trap_en(trap_en),.csr_indata(csr_indata | csr_indata_intr | count),.csr_wrdata(csr_wrdata)
               ,.mul_state_freeze(mul_state_freeze),.div_kill(div_kill),.mul_kill(mul_kill)
               ,.stall_mul_int2(stall_mul),.mul_op(mul_op),.div_op(div_op),.mul_freeze(icache_freeze | freeze_int)
                  );

rf rf1( .rst(rst),.clk(clk),.led(led),.p0_addr(rs1_id),.p1_addr(rs2_id),.p0(opr1),.p1(opr2)
        //,.p2(proc_addr_port2_rf),.p2_addr(rs1_amo)
        ,.dst_addr(rd_id_o),.dst_data(wb_data_int2),
        .we(wb_op_out_int2),.mem_wb_freeze((stall_mul || freeze_int)),.irq_ctrl_dec_src1(irq_ctrl_dec_src1),
        .irq_ctrl_dec_src2(irq_ctrl_dec_src2),.irq_ctrl_wb(irq_ctrl_o)
      );

Sys_counter sc1(.proc_clk(clk),.freeze((stall_mul || freeze_int) || icache_freeze),. rst(rst),.count_sel(count_sel_int),.count(count),.wr_sel(wr_sel)
                ,.csr_wrdata(csr_wrdata),.csr_wr_en(csr_wr_en),.tick_en(tick_en_int)
               );

csr c1( .csr_wrdata(csr_wrdata),.csr_wr_en(csr_wr_en),.csr_adr_wr(csr_adr),.csr_adr_rd(csr_adr_int)
        ,.csr_rddata(csr_indata),.clk(clk),.rst(rst),.trap_en(trap_en),.mret(eret_o),.csr_mtvec(csr_mtvec)
        ,.mtie(mtie),.badaddr(badaddr),.pc_id_ex(pc_id_ex),.mepc_res(mepc_res),.addr_exception(addr_exception)
        ,.freeze((stall_mul || freeze_int) || icache_freeze)
      );

irq_interface ii(.clk(clk),.rst(rst),.stall_mul(stall_mul),.freeze(freeze_int),.icache_freeze(icache_freeze),        
                 .irq(irq),.eret(eret_o),.irq_ack(irq_ack),.eret_ack(eret_ack),.inst_inj(inst_inj),.irq_ctrl(irq_ctrl),
                 .irq_ctrl_wb(irq_ctrl_wb_i),.irq_if_ctrl(irq_if_ctrl),.irq_ctrl_dec_src1(irq_ctrl_dec_src1),
                 .irq_ctrl_dec_src2(irq_ctrl_dec_src2),.if_id_freeze(if_id_freeze),
                 .irq_icache_freeze(irq_icache_freeze)
);

interrupt_main i1(.interrupt(interrupt),.clk(clk),.reset(rst),.done(eret),.ic_irq_ack(irq_ack ),.eret_ack(eret_ack),   
                  .icache_stall_out(icache_freeze),.ic_proc_req(irq),.device_id(device_id),
                  .csr_wrdata(csr_wrdata),.csr_wr_en(csr_wr_en),.csr_adr_wr(csr_adr),.csr_adr_rd(csr_adr_int)
                  ,.csr_rddata(csr_indata_intr),.freeze((stall_mul || freeze_int) || icache_freeze)
                  );
 
endmodule