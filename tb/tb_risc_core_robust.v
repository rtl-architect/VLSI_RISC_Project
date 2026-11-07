`timescale 1ns / 1ps

module tb_risc_core_robust;

    // Inputs
    reg clk;
    reg reset;
    
    integer i;

    // Probes (Outputs from your risc_core wrapper)
    wire [31:0] probe_pc;
    wire [31:0] probe_alu_result;

    // Instantiate the Unit Under Test (UUT)
    risc_core uut (
        .clk(clk),
        .reset(reset),
        .probe_pc(probe_pc),
        .probe_alu_result(probe_alu_result)
    );

    // 15.0 ns Clock Generation (Matches OpenLane SDC constraints)
    initial begin
        clk = 0;
        forever #7.5 clk = ~clk; 
    end

    // Test Sequence and Assertion Checking
    initial begin
        // Initialize VCD for GTKWave
        $dumpfile("tb_risc_core_robust.vcd");
        // Dump all variables in the testbench and the UUT
        $dumpvars(0, tb_risc_core_robust);

            // Force Icarus Verilog to dump the 2D register array
        for (i = 0; i < 32; i = i + 1) begin
        $dumpvars(0, uut.REG_FILE.registers[i]);
        end


        $display("Starting Robust Pipeline Verification...");

        // 1. Asynchronous Reset Assertion
        reset = 1;
        #20; 
        reset = 0;

        // INJECT TEST DATA FOR MAC UNIT
        uut.REG_FILE.registers[8] = 32'd2;
        uut.REG_FILE.registers[9] = 32'd3;

        // 2. Allow pipeline to process the corner cases
        #600; 

        // 3. Automated Self-Checking (Hierarchical referencing)
        $display("----------------------------------------");
        $display("VERIFICATION RESULTS:");
        
        // Test: Register 0 must remain hardwired to 0
        if (uut.REG_FILE.registers[0] !== 32'd0)
            $display("[FAILED] R0 is corrupted: %0d", uut.REG_FILE.registers[0]);
        else
            $display("[PASSED] R0 remains hardwired to 0.");

        // Check final MAC Accumulator state
        $display("[INFO] Final MAC / ALU Result: %0d", probe_alu_result);
        $display("----------------------------------------");

        $finish;
    end

    // Safety Watchdog to prevent infinite simulation loops
    initial begin
        #2000;
        $display("[ERROR] Simulation Timeout. Check for infinite stalls or loops.");
        $finish;
    end

endmodule