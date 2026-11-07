`timescale 1ns / 1ps

module data_memory #(
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH = 256
)(
    input wire clk,
    input wire reset,
    
    // Control signals from the Control Unit (via pipeline registers)
    input wire mem_write,
    input wire mem_read,
    
    // Memory address and data inputs from the Execute (EX) stage
    input wire [DATA_WIDTH-1:0] address,
    input wire [DATA_WIDTH-1:0] write_data,
    
    // Data output to the Write-Back (WB) stage
    output wire [DATA_WIDTH-1:0] read_data
);

    // The data memory array
    // OpenLane synthesis maps this directly to an SRAM standard cell macro.
    reg [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    integer i;

    // 1. Combinational Read
    // MIPS architectures are byte-addressable, meaning the address increments by 4 for each 32-bit word.
    // By dropping the bottom two bits (address[9:2]), we perfectly align the byte address to our word array.
    assign read_data = (mem_read) ? memory[address[9:2]] : {DATA_WIDTH{1'b0}};

    // 2. Sequential Write
always @(posedge clk) begin
    if (reset) begin
        // Explicit initialization for ASIC predictability (Fixed for Verilator)
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            memory[i] = {DATA_WIDTH{1'b0}}; // Changed <= to =
        end
    end else if (mem_write) begin
        // Write the data into the corresponding word-aligned memory slot
        memory[address[9:2]] <= write_data;
    end
end

endmodule