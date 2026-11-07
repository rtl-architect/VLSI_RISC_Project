`timescale 1ns / 1ps

module register_file #(
    parameter DATA_WIDTH = 32,
    parameter REG_COUNT = 32
)(
    input wire clk,
    input wire reset,
    
    // Read Port 1 (rs)
    input wire [4:0] read_reg1,
    output wire [DATA_WIDTH-1:0] read_data1,
    
    // Read Port 2 (rt)
    input wire [4:0] read_reg2,
    output wire [DATA_WIDTH-1:0] read_data2,
    
    // Write Port (rd or rt depending on instruction format)
    input wire write_enable,
    input wire [4:0] write_reg,
    input wire [DATA_WIDTH-1:0] write_data
);

    // The register array: 32 registers, each 32 bits wide
    reg [DATA_WIDTH-1:0] registers [0:REG_COUNT-1];
    
    integer i;

    // 1. Combinational Read (with Write-Through Internal Forwarding)
    // If a read and write happen on the same register in the same clock cycle,
    // bypass the old register state and instantly forward the new write_data.
    assign read_data1 = (read_reg1 == 5'd0) ? {DATA_WIDTH{1'b0}} : 
                        (write_enable && (write_reg == read_reg1)) ? write_data : 
                        registers[read_reg1];
                        
    assign read_data2 = (read_reg2 == 5'd0) ? {DATA_WIDTH{1'b0}} : 
                        (write_enable && (write_reg == read_reg2)) ? write_data : 
                        registers[read_reg2];
    // 2. Sequential Write
    // Updates the register state on the positive clock edge during the Write-Back (WB) stage.
    always @(posedge clk) begin
        if (reset) begin
            // Clear all registers on reset (crucial for accurate RTL simulation and ASIC initialization)
            for (i = 0; i < REG_COUNT; i = i + 1) begin
                registers[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (write_enable && write_reg != 5'd0) begin
            // The condition (write_reg != 5'd0) acts as a hardware lock to prevent 
            // any rogue instruction from overwriting Register 0.
            registers[write_reg] <= write_data;
        end
    end

endmodule