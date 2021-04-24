`timescale 1ns / 1ps


module SIGN_INJECTION
(
    input [63:0] INPUT_1,
    input [63:0] INPUT_2,
    input SP_DP,
    input [2:0] OPERATION,
    output reg [63:0] OUTPUT
);

wire sign_INPUT_1 = SP_DP ? INPUT_1[63] : INPUT_1[31];
wire sign_INPUT_2 = SP_DP ? INPUT_2[63] : INPUT_2[31];

wire sign = OPERATION[0] ? sign_INPUT_2 : OPERATION[1] ? ~sign_INPUT_2 : OPERATION[2] ? sign_INPUT_1 ^ sign_INPUT_2 : 1'b0;

always @(*) begin
    if(SP_DP == 1) begin
        OUTPUT <= {sign,INPUT_1[62:0]};
    end
    else begin
        OUTPUT <= {{32{1'b0}},sign,INPUT_1[30:0]};
    end
end
endmodule
