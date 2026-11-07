`timescale 1ns / 1ps

module forwarding_unit (
    input wire [4:0] rs_EX,      // Source register 1 in Execute stage
    input wire [4:0] rt_EX,      // Source register 2 in Execute stage
    input wire [4:0] rd_MEM,     // Destination register in Memory stage
    input wire reg_write_MEM,    // Write enable signal in Memory stage
    input wire [4:0] rd_WB,      // Destination register in Write-Back stage
    input wire reg_write_WB,     // Write enable signal in Write-Back stage

    output reg [1:0] forward_A,  // Mux control for ALU input A
    output reg [1:0] forward_B   // Mux control for ALU input B
);

    // Mux Control Values:
    // 2'b00: Normal operation (data comes from Register File)
    // 2'b10: EX Hazard (data forwarded from prior instruction's ALU result)
    // 2'b01: MEM Hazard (data forwarded from instruction 2 cycles ago)

    always @(*) begin
        // Default to normal operation (no forwarding)
        forward_A = 2'b00;
        forward_B = 2'b00;

        // -------------------------------------------------------------
        // Forwarding Logic for ALU Input A (rs)
        // -------------------------------------------------------------
        // EX Hazard (Prioritize the most recent instruction first)
        if (reg_write_MEM && (rd_MEM != 0) && (rd_MEM == rs_EX)) begin
            forward_A = 2'b10;
        end
        // MEM Hazard (Check if instruction 2 cycles ago is the source)
        else if (reg_write_WB && (rd_WB != 0) && (rd_WB == rs_EX)) begin
            forward_A = 2'b01;
        end

        // -------------------------------------------------------------
        // Forwarding Logic for ALU Input B (rt)
        // -------------------------------------------------------------
        // EX Hazard
        if (reg_write_MEM && (rd_MEM != 0) && (rd_MEM == rt_EX)) begin
            forward_B = 2'b10;
        end
        // MEM Hazard
        else if (reg_write_WB && (rd_WB != 0) && (rd_WB == rt_EX)) begin
            forward_B = 2'b01;
        end
    end

endmodule