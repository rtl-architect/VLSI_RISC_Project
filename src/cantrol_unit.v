`timescale 1ns / 1ps

module control_unit (
    input wire [5:0] opcode,        // 6-bit instruction opcode (Instruction[31:26])
    input wire [5:0] funct,         // 6-bit function code for R-type (Instruction[5:0])
    
    // Execution (EX) Stage Signals
    output reg reg_dst,             // Selects destination register (rt vs rd)
    output reg alu_src,             // Selects ALU operand B (register vs immediate)
    output reg [3:0] alu_control,   // 4-bit opcode sent to the ALU
    output reg mac_enable,          // Triggers the MAC accumulator update
    
    // Memory (MEM) Stage Signals
    output reg branch,              // Indicates a branch instruction (e.g., BEQ)
    output reg mem_read,            // Enables Data Memory read
    output reg mem_write,           // Enables Data Memory write
    
    // Write-Back (WB) Stage Signals
    output reg mem_to_reg,          // Selects data to write back (ALU result vs Memory data)
    output reg reg_write            // Enables writing to the Register File
);

    // MIPS Standard Opcodes
    localparam OPCODE_R_TYPE = 6'b000000;
    localparam OPCODE_LW     = 6'b100011;
    localparam OPCODE_SW     = 6'b101011;
    localparam OPCODE_BEQ    = 6'b000100;

    // R-Type Function Codes
    localparam FUNCT_ADD = 6'b100000;
    localparam FUNCT_SUB = 6'b100010;
    localparam FUNCT_AND = 6'b100100;
    localparam FUNCT_OR  = 6'b100101;
    localparam FUNCT_SLT = 6'b101010;
    localparam FUNCT_MAC = 6'b101100; // Custom MAC Function Code

    always @(*) begin
        // Default signal initialization to prevent unintended latches
        reg_dst     = 1'b0;
        alu_src     = 1'b0;
        mem_to_reg  = 1'b0;
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        branch      = 1'b0;
        mac_enable  = 1'b0;
        alu_control = 4'b0000;

        case (opcode)
            OPCODE_R_TYPE: begin
                reg_dst   = 1'b1; // R-type uses 'rd' as destination
                reg_write = 1'b1; // Write result back to register
                
                // ALU Decoder for R-Type
                case (funct)
                    FUNCT_ADD: alu_control = 4'b0000;
                    FUNCT_SUB: alu_control = 4'b0001;
                    FUNCT_AND: alu_control = 4'b0010;
                    FUNCT_OR:  alu_control = 4'b0011;
                    FUNCT_SLT: alu_control = 4'b0100;
                    FUNCT_MAC: begin 
                        alu_control = 4'b0101; 
                        mac_enable  = 1'b1; // Turn on the MAC accumulator
                    end
                    default:   alu_control = 4'b0000;
                endcase
            end

            OPCODE_LW: begin
                alu_src    = 1'b1; // Use immediate value for address calculation
                mem_to_reg = 1'b1; // Write memory data to register
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                alu_control = 4'b0000; // ADD operation for base + offset
            end

            OPCODE_SW: begin
                alu_src   = 1'b1; // Use immediate value for address calculation
                mem_write = 1'b1;
                alu_control = 4'b0000; // ADD operation for base + offset
            end

            OPCODE_BEQ: begin
                branch    = 1'b1;
                alu_control = 4'b0001; // SUB operation to compare registers
            end
        endcase
    end
endmodule