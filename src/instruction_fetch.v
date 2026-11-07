`timescale 1ns / 1ps

module instruction_fetch #(
    parameter DATA_WIDTH = 32,
    parameter INST_MEM_DEPTH = 256,
    parameter BHT_ENTRIES = 16
)(
    input wire clk,
    input wire reset,
    
    input wire mispredict_flush,          
    input wire [DATA_WIDTH-1:0] correct_pc,
    
    input wire update_bht_en,
    input wire update_bht_taken,
    input wire [3:0] update_bht_index,
    
    output reg [DATA_WIDTH-1:0] pc_current,
    output wire [DATA_WIDTH-1:0] instruction,
    output wire [DATA_WIDTH-1:0] pc_plus_4,
    output wire predict_taken
);

    reg [DATA_WIDTH-1:0] inst_mem [0:INST_MEM_DEPTH-1];
    reg bht [0:BHT_ENTRIES-1];
    
    integer i;
    integer j;

    // FIX: Initialize instruction memory to NOPs to prevent fetching 'X'
    initial begin
        for (j = 0; j < INST_MEM_DEPTH; j = j + 1) begin
            inst_mem[j] = 32'h00000000; 
        end
        
        // LOAD MAC TEST PROGRAM
        inst_mem[0] = 32'h0109502C; // MAC R10, R8, R9 (Accumulator += 2*3 = 6)
        inst_mem[1] = 32'h0109582C; // MAC R11, R8, R9 (Accumulator += 2*3 = 12)
        inst_mem[2] = 32'h0109602C; // MAC R12, R8, R9 (Accumulator += 2*3 = 18)
    end

    assign pc_plus_4 = pc_current + 32'd4;
    assign instruction = inst_mem[pc_current[9:2]]; 
    
    wire [3:0] current_bht_index = pc_current[5:2];
    assign predict_taken = bht[current_bht_index];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_current <= {DATA_WIDTH{1'b0}};
            for (i = 0; i < BHT_ENTRIES; i = i + 1) begin
                bht[i] <= 1'b0; 
            end
        end else begin
            if (update_bht_en) begin
                bht[update_bht_index] <= update_bht_taken;
            end
            
            if (mispredict_flush) begin
                pc_current <= correct_pc;
            end else begin
                pc_current <= pc_plus_4;
            end
        end
    end

endmodule