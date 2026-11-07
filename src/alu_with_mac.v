`timescale 1ns / 1ps

module alu_with_mac #(
    parameter DATA_WIDTH = 32
)(
    input wire clk,                           // Pipeline clock
    input wire reset,                         // Active high synchronous reset
    input wire [DATA_WIDTH-1:0] a,            // Operand 1 (rs from Forwarding Unit)
    input wire [DATA_WIDTH-1:0] b,            // Operand 2 (rt or Immediate)
    input wire [3:0] alu_control,             // 4-bit ALU operation code
    input wire mac_enable,                    // Control signal from ID stage to update accumulator
    
    output reg [DATA_WIDTH-1:0] alu_result,   // Standard 32-bit ALU output for Write-Back
    output wire zero                          // Zero flag for branch resolution
);

    // Internal 64-bit Accumulator for high-precision MAC operations
    reg [(DATA_WIDTH*2)-1:0] accumulator;
    
    // 64-bit hardware multiplier output
    wire [(DATA_WIDTH*2)-1:0] mult_result = a * b;

    // ALU Opcodes (Local Parameters for clean RTL)
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_SLT = 4'b0100;
    localparam ALU_MAC = 4'b0101; // Our Custom MAC Opcode

    // 1. Combinational Logic: Arithmetic and Logic Operations
    always @(*) begin
        case (alu_control)
            ALU_ADD: alu_result = a + b;
            ALU_SUB: alu_result = a - b;
            ALU_AND: alu_result = a & b;
            ALU_OR:  alu_result = a | b;
            ALU_SLT: alu_result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            
            // For MAC, bypass the accumulator's lower 32 bits to the pipeline
            ALU_MAC: alu_result = accumulator[DATA_WIDTH-1:0]; 
            
            default: alu_result = {DATA_WIDTH{1'b0}};
        endcase
    end

    // Continuous assignment for Zero Flag (used in Branch target calculation)
    assign zero = (alu_result == {DATA_WIDTH{1'b0}});

    // 2. Sequential Logic: Accumulator State Management
    always @(posedge clk) begin
        if (reset) begin
            accumulator <= {(DATA_WIDTH*2){1'b0}};
        end else if (mac_enable) begin
            // Perform the MAC calculation and store the 64-bit result
            accumulator <= accumulator + mult_result;
        end
    end

endmodule