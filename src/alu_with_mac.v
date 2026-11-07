`timescale 1ns / 1ps

module alu_with_mac #(
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire reset,
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH-1:0] b,
    input wire [3:0] alu_control,
    input wire mac_enable,
    
    output reg [DATA_WIDTH-1:0] alu_result,
    output wire zero
);

    reg [(DATA_WIDTH*2)-1:0] accumulator;
    wire [(DATA_WIDTH*2)-1:0] mult_result = a * b;

    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_SLT = 4'b0100;
    localparam ALU_MAC = 4'b0101; 

    always @(*) begin
        case (alu_control)
            ALU_ADD: alu_result = a + b;
            ALU_SUB: alu_result = a - b;
            ALU_AND: alu_result = a & b;
            ALU_OR:  alu_result = a | b;
            ALU_SLT: alu_result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_MAC: alu_result = accumulator[DATA_WIDTH-1:0]; 
            default: alu_result = {DATA_WIDTH{1'b0}};
        endcase
    end

    assign zero = (alu_result == {DATA_WIDTH{1'b0}});

    // FIX: Asynchronous reset explicitly captures the testbench reset edge
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            accumulator <= {(DATA_WIDTH*2){1'b0}};
        end else if (mac_enable) begin
            accumulator <= accumulator + mult_result;
        end
    end

endmodule