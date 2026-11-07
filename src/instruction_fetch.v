`timescale 1ns / 1ps

module instruction_fetch #(
    parameter DATA_WIDTH = 32,
    parameter INST_MEM_DEPTH = 256,
    parameter BHT_ENTRIES = 16
)(
    input wire clk,
    input wire reset,
    
    // Correction inputs from EX stage (if prediction was wrong)
    input wire mispredict_flush,          
    input wire [DATA_WIDTH-1:0] correct_pc,
    
    // Inputs from EX stage to update the Branch History Table (BHT)
    input wire update_bht_en,
    input wire update_bht_taken,
    input wire [3:0] update_bht_index,
    
    // Outputs to the Instruction Decode (ID) stage
    output reg [DATA_WIDTH-1:0] pc_current,
    output wire [DATA_WIDTH-1:0] instruction,
    output wire [DATA_WIDTH-1:0] pc_plus_4,
    output wire predict_taken
);

    // Instruction Memory (ROM)
    // In OpenLane synthesis, this array will infer a dedicated SRAM block macro.
    reg [DATA_WIDTH-1:0] inst_mem [0:INST_MEM_DEPTH-1];
    
    // 1-Bit Branch History Table (BHT) Array
    reg bht [0:BHT_ENTRIES-1];
    integer i;

    // Standard PC + 4 Adder
    assign pc_plus_4 = pc_current + 32'd4;
    
    // Continuous Instruction Fetch
    // MIPS is byte-addressable, but memory is word-aligned, so we drop the bottom 2 bits ([1:0])
    assign instruction = inst_mem[pc_current[9:2]]; 
    
    // -------------------------------------------------------------
    // Branch Predictor Logic
    // -------------------------------------------------------------
    // Index the BHT using bits [5:2] of the current PC
    wire [3:0] current_bht_index = pc_current[5:2];
    
    // Output the prediction to the ID stage immediately
    assign predict_taken = bht[current_bht_index];

    // -------------------------------------------------------------
    // Sequential Logic: PC Management and BHT Training
    // -------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            // Strict initialization for ASIC physical design
            pc_current <= {DATA_WIDTH{1'b0}};
            for (i = 0; i < BHT_ENTRIES; i = i + 1) begin
                bht[i] <= 1'b0; // Default to 'predict not taken'
            end
        end else begin
            // 1. Train/Update the BHT based on actual branch results from EX stage
            if (update_bht_en) begin
                bht[update_bht_index] <= update_bht_taken;
            end
            
            // 2. Program Counter Update
            if (mispredict_flush) begin
                // Hardware correction: Pipeline guessed wrong. Flush and jump to the correct PC.
                pc_current <= correct_pc;
            end else begin
                // Normal execution flow (moving to next instruction)
                // Note: Target calculations for predicted branches are handled in the ID stage.
                pc_current <= pc_plus_4;
            end
        end
    end

endmodule