`include "defines.v"

module instrfetch(

//inputs
branch,
clk,
branchaddress,
rst,
stall,csr_mtvec,
nop_rd_id,if_id_freeze,
irq_if_ctrl,
//outputs
pc_if_id,next_pc,
nop,nop_rd_o,br_nop,
pc,
device_id
`ifdef itlb_def
,vpn_to_ppn_req1
`endif

    );
	 
	 
input branch;
input [31:0] branchaddress;
input [31:0] csr_mtvec;
input clk;
input rst,stall;
input [4:0] nop_rd_id;
input if_id_freeze;
input irq_if_ctrl;      //Sets PC to interrupt vector address

output reg [31:0] pc_if_id;
output reg [31:0] next_pc;
output reg nop;
output reg [4:0] nop_rd_o;
output reg br_nop;
output  [31:0] pc;
//output reg [31:0] pc_cache;
`ifdef itlb_def
output reg vpn_to_ppn_req1;
`endif

input [5:0] device_id;

parameter isr_inst_count = 3;  //for n instruction (log2(n) + 2)

wire [31:0] pc;
wire [31:0] pc4;
reg [31:0] pc_reg;
//reg [5:0] devide_id_int;
reg br_nop_int;
wire [31:0] ISR_ADDRESS;


assign  pc = pc_reg;    //Stall and IRQ functioning

assign ISR_ADDRESS = csr_mtvec + ( device_id << isr_inst_count );

assign  pc4 = pc + 32'd4;


always @(posedge clk or posedge rst) begin
    if(rst) begin
        pc_if_id <= 32'b00;
    end
    else begin
        if( branch) begin
            pc_if_id <= branchaddress;
        end
        else if(~if_id_freeze) begin
            pc_if_id <= stall ? pc - 32'd4 : pc; 
        end
    end
end
//always @(posedge clk or posedge rst) begin
//    if(rst) begin
//        pc_if_id <= 32'b00;
//    end
//    else if(~if_id_freeze) begin                     // condition can be removed not required
//            pc_if_id <= stall ? pc - 32'd4 : pc; 
//        end
//end

`ifdef itlb_def
always @(posedge clk ) begin
    if(rst) begin
        pc_reg <= 32'b00;
        vpn_to_ppn_req1 <= 1'b1;
    end
    else if(~if_id_freeze) begin
            pc_reg <= (branch ? branchaddress : (stall ? (pc_reg - 32'd4) : pc4));
            vpn_to_ppn_req1 <= 1'b1;
        end
        else if(irq_if_ctrl) begin
            pc_reg <=  ISR_ADDRESS;
            vpn_to_ppn_req1 <= 1'b0;
        end
        else begin
            vpn_to_ppn_req1 <= 1'b0;
        end
end
`else
always @(posedge clk or posedge rst) begin
    if(rst) begin
        pc_reg <= 32'b00;
    end
    else begin
        if(~if_id_freeze) begin
            pc_reg <= #1 (branch ? branchaddress : (stall ? (pc_reg - 32'd4) : pc4));
        end
    end
end
`endif


always @(posedge rst or posedge clk)
begin
    if(rst) begin
//        pc <= 32'h0;
        next_pc <= 32'h4;//0;
        nop <= 1'b0;
        nop_rd_o <= 5'b0; 
        br_nop_int <= 1'b0;
        br_nop <= 1'b0;
        end
    else if(irq_if_ctrl)
            nop <= 1'b0;    
    else begin
        if(~if_id_freeze) begin
            next_pc <= stall ? pc : pc4;
            nop <= branch;
            nop_rd_o <= nop_rd_id;
            br_nop_int <= branch;
            br_nop <= br_nop_int;
        end
    end
end

endmodule
