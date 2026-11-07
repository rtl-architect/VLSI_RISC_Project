`timescale 1ns / 1ps

module tb_risc_core;

    // Testbench signals
    reg clk;
    reg reset;

    // Instantiate the Unit Under Test (UUT)
    risc_core #(
        .DATA_WIDTH(32)
    ) uut (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation: 15ns period (matches our config.json)
    always #7.5 clk = ~clk;

    initial begin
        // Initialize waveform dumping for GTKWave
        $dumpfile("tb_risc_core.vcd");
        $dumpvars(0, tb_risc_core);

        // Initialize signals
        clk = 0;
        reset = 1;

        // Load Machine Code into Instruction Memory (ROM isn't affected by our reset)
        uut.IF_STAGE.inst_mem[0] = 32'h8C010000; // LW $1, 0($0)
        uut.IF_STAGE.inst_mem[1] = 32'h8C020004; // LW $2, 4($0)
        uut.IF_STAGE.inst_mem[2] = 32'h00000000; // NOP 
        uut.IF_STAGE.inst_mem[3] = 32'h0022182C; // MAC $3, $1, $2
        uut.IF_STAGE.inst_mem[4] = 32'h00000000; // NOP
        uut.IF_STAGE.inst_mem[5] = 32'h00000000; // NOP
        uut.IF_STAGE.inst_mem[6] = 32'h0022182C; // MAC $3, $1, $2

        // Wait 20ns, then drop the reset to allow normal operation
        #20;
        reset = 0;

        // NOW load the test data into Data Memory so the reset loop doesn't wipe it!
        uut.DATA_MEM.memory[0] = 32'd3; 
        uut.DATA_MEM.memory[1] = 32'd4; 

        // Allow the pipeline to run
        #300;

        // End simulation
        $display("Simulation completed successfully.");
        $finish;
    end
    
endmodule