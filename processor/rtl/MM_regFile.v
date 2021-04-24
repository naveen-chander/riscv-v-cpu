`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.05.2016 10:20:03
// Design Name: 
// Module Name: MM_regFile
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Register file for instantiating memory mapped control and/or status registers. Currently uses 2 registers for 
// cache control and debug control.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module MM_regFile(
input wb_rst_i,
input wb_clk_i,
output reg [31:0] wb_dat_o,
input wb_cyc_i,
input [31:0] wb_adr_i,
input wb_stb_i,
input wb_we_i,
input [3:0] wb_sel_i,
input [31:0] wb_dat_i,
input [2:0] wb_cti_i,
input [1:0] wb_bte_i,
output reg wb_ack_o,
output reg wb_err_o,
output reg wb_rty_o,
output cache_flush,
output cache_en
);

/// Number of memory mapped registers //
parameter MM_regNum = 2;

reg [2:0] state,nxstate;
reg [3:0] count;
integer i;

reg [$clog2(MM_regNum)-1:0] addra;

reg [31:0] dina;
reg [3:0] wea;
reg ena;
reg [7:0] douta;


reg [7:0] mem[0:MM_regNum-1];

////////////////////////////////// Register Specifications ////////////////////////////////////////////

// Mem[0]           Cache Control               // mem[0][0] = cache_flush_en; '1' flush cache; '0' do not flush cache
//                                              // mem[0][1] = cache_en      ; '0' cache enabled; '1' cache disabled

// Mem[1]           Debug Control       Yet to assign functionality

assign cache_flush = mem[0][0];
assign cache_en = mem[0][1];

always @ (posedge wb_clk_i or posedge wb_rst_i) begin
        if(wb_rst_i) begin
#1          for(i=0; i<MM_regNum; i=i+1) begin
                mem[i] <= 32'd0;
                mem[i] <= 32'd0;
            end
        end
        else if (wea) begin
#1          case(wb_sel_i)
                4'b0001: mem[addra] <= dina[7:0];
                4'b0010: mem[addra] <= dina[15:8];
                4'b0100: mem[addra] <= dina[23:16];
                4'b1000: mem[addra] <= dina[31:24];
                default: mem[addra] <= dina[7:0];
            endcase;
        end        
end

always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if(wb_rst_i) begin
#1      wb_rty_o <= 1'b0;
        wb_err_o <= 1'b0;
        wb_ack_o <= 1'b0;
        douta <= 0;
    end
    else begin
#1      douta <= mem[addra];
/////   This module only supports single cycle/classic transfer cycles. Therefore, cti should always be 7 /////
        if(wb_stb_i & wb_cyc_i & (wb_cti_i == 3'b111) & ((wb_adr_i & `MM_adrMask) == `MM_adrBase)) begin
            wb_rty_o <= 1'b0;
            wb_err_o <= 1'b0;
            wb_ack_o <= 1'b1;
        end
    end
end

always @(*) begin
        addra <= wb_adr_i[$clog2(MM_regNum)-1:0];
        dina <= wb_dat_i;
        wea <= {4{wb_we_i}};
        ena <= ~((wb_adr_i & `MM_adrMask) == `MM_adrBase);
end

always @(*) begin
    case(wb_sel_i)
        4'b0001: wb_dat_o <= {{24'b0},{douta}};
        4'b0010: wb_dat_o <= {{16'b0},{douta},{8'b0}};
        4'b0100: wb_dat_o <= {{8'b0},{douta},{16'b0}};
        4'b1000: wb_dat_o <= {{douta},{24'b0}};
        default: wb_dat_o <= {4{douta}};
    endcase;
end

endmodule
