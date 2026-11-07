`timescale 1ns / 1ps

module risc_core #(
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire reset,
    output wire [DATA_WIDTH-1:0] probe_pc,
    output wire [DATA_WIDTH-1:0] probe_alu_result
);

    // =========================================================================
    // Interconnect Wires
    // =========================================================================
    
    // IF Stage Wires
    wire [DATA_WIDTH-1:0] if_pc_current, if_instruction, if_pc_plus_4;
    wire if_predict_taken;
    
    // ID Stage Wires
    wire id_reg_dst, id_alu_src, id_mem_to_reg, id_reg_write, id_mem_read, id_mem_write, id_branch, id_mac_enable;
    wire [3:0] id_alu_control;
    wire [DATA_WIDTH-1:0] id_read_data1, id_read_data2;
    
    // EX Stage Wires
    wire [DATA_WIDTH-1:0] ex_alu_result;
    wire ex_zero;
    wire [1:0] forward_A, forward_B;
    wire [DATA_WIDTH-1:0] alu_operand_a, alu_operand_b_temp, alu_operand_b;
    
    // MEM Stage Wires
    wire [DATA_WIDTH-1:0] mem_read_data;
    
    // WB Stage Wires
    wire [DATA_WIDTH-1:0] wb_write_data;

    // =========================================================================
    // Pipeline Registers
    // =========================================================================
    
    // IF/ID Register
    reg [DATA_WIDTH-1:0] if_id_pc_plus_4, if_id_instruction;
    
    // ID/EX Register
    reg id_ex_reg_dst, id_ex_alu_src, id_ex_mem_to_reg, id_ex_reg_write;
    reg id_ex_mem_read, id_ex_mem_write, id_ex_branch, id_ex_mac_enable;
    reg [3:0] id_ex_alu_control;
    reg [DATA_WIDTH-1:0] id_ex_read_data1, id_ex_read_data2, id_ex_imm_ext;
    reg [4:0] id_ex_rs, id_ex_rt, id_ex_rd;
    
    // EX/MEM Register
    reg ex_mem_mem_to_reg, ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;
    reg [DATA_WIDTH-1:0] ex_mem_alu_result, ex_mem_write_data;
    reg [4:0] ex_mem_dest_reg;
    
    // MEM/WB Register
    reg mem_wb_mem_to_reg, mem_wb_reg_write;
    reg [DATA_WIDTH-1:0] mem_wb_read_data, mem_wb_alu_result;
    reg [4:0] mem_wb_dest_reg;

    // =========================================================================
    // Module Instantiations
    // =========================================================================

    // 1. Instruction Fetch Stage
    instruction_fetch #(
        .DATA_WIDTH(DATA_WIDTH)
    ) IF_STAGE (
        .clk(clk),
        .reset(reset),
        .mispredict_flush(1'b0),          // Tied low for simplified baseline integration
        .correct_pc(32'd0),               
        .update_bht_en(1'b0),             
        .update_bht_taken(1'b0),
        .update_bht_index(4'd0),
        .pc_current(if_pc_current),
        .instruction(if_instruction),
        .pc_plus_4(if_pc_plus_4),
        .predict_taken(if_predict_taken)
    );

    // IF/ID Pipeline Register Update
    always @(posedge clk) begin
        if (reset) begin
            if_id_instruction <= 32'd0;
            if_id_pc_plus_4   <= 32'd0;
        end else begin
            if_id_instruction <= if_instruction;
            if_id_pc_plus_4   <= if_pc_plus_4;
        end
    end

    // 2. Instruction Decode: Control Unit
    control_unit CU (
        .opcode(if_id_instruction[31:26]),
        .funct(if_id_instruction[5:0]),
        .reg_dst(id_reg_dst),
        .alu_src(id_alu_src),
        .alu_control(id_alu_control),
        .mac_enable(id_mac_enable),
        .branch(id_branch),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .mem_to_reg(id_mem_to_reg),
        .reg_write(id_reg_write)
    );

    // 3. Instruction Decode: Register File
    register_file #(
        .DATA_WIDTH(DATA_WIDTH)
    ) REG_FILE (
        .clk(clk),
        .reset(reset),
        .read_reg1(if_id_instruction[25:21]),
        .read_reg2(if_id_instruction[20:16]),
        .read_data1(id_read_data1),
        .read_data2(id_read_data2),
        .write_enable(mem_wb_reg_write),
        .write_reg(mem_wb_dest_reg),
        .write_data(wb_write_data)
    );
    
    // Sign Extension for Immediates
    wire [DATA_WIDTH-1:0] id_imm_ext = {{16{if_id_instruction[15]}}, if_id_instruction[15:0]};

    // ID/EX Pipeline Register Update
    always @(posedge clk) begin
        if (reset) begin
            id_ex_reg_write <= 1'b0; id_ex_mem_write <= 1'b0; // Critical resets
        end else begin
            id_ex_reg_dst     <= id_reg_dst;
            id_ex_alu_src     <= id_alu_src;
            id_ex_mem_to_reg  <= id_mem_to_reg;
            id_ex_reg_write   <= id_reg_write;
            id_ex_mem_read    <= id_mem_read;
            id_ex_mem_write   <= id_mem_write;
            id_ex_branch      <= id_branch;
            id_ex_mac_enable  <= id_mac_enable;
            id_ex_alu_control <= id_alu_control;
            id_ex_read_data1  <= id_read_data1;
            id_ex_read_data2  <= id_read_data2;
            id_ex_imm_ext     <= id_imm_ext;
            id_ex_rs          <= if_id_instruction[25:21];
            id_ex_rt          <= if_id_instruction[20:16];
            id_ex_rd          <= if_id_instruction[15:11];
        end
    end

    // 4. Hazard Management: Forwarding Unit
    forwarding_unit FWD (
        .rs_EX(id_ex_rs),
        .rt_EX(id_ex_rt),
        .rd_MEM(ex_mem_dest_reg),
        .reg_write_MEM(ex_mem_reg_write),
        .rd_WB(mem_wb_dest_reg),
        .reg_write_WB(mem_wb_reg_write),
        .forward_A(forward_A),
        .forward_B(forward_B)
    );

    // Forwarding Multiplexers
    assign alu_operand_a = (forward_A == 2'b10) ? ex_mem_alu_result :
                           (forward_A == 2'b01) ? wb_write_data : id_ex_read_data1;
                           
    assign alu_operand_b_temp = (forward_B == 2'b10) ? ex_mem_alu_result :
                                (forward_B == 2'b01) ? wb_write_data : id_ex_read_data2;
                                
    // ALU Source Multiplexer (Register vs Immediate)
    assign alu_operand_b = (id_ex_alu_src) ? id_ex_imm_ext : alu_operand_b_temp;

    // 5. Execute Stage: ALU with MAC
    alu_with_mac #(
        .DATA_WIDTH(DATA_WIDTH)
    ) ALU (
        .clk(clk),
        .reset(reset),
        .a(alu_operand_a),
        .b(alu_operand_b),
        .alu_control(id_ex_alu_control),
        .mac_enable(id_ex_mac_enable),
        .alu_result(ex_alu_result),
        .zero(ex_zero)
    );

    // Destination Register Multiplexer
    wire [4:0] ex_dest_reg = (id_ex_reg_dst) ? id_ex_rd : id_ex_rt;

    // EX/MEM Pipeline Register Update
    always @(posedge clk) begin
        if (reset) begin
            ex_mem_reg_write <= 1'b0; ex_mem_mem_write <= 1'b0;
        end else begin
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
            ex_mem_reg_write  <= id_ex_reg_write;
            ex_mem_mem_read   <= id_ex_mem_read;
            ex_mem_mem_write  <= id_ex_mem_write;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_write_data <= alu_operand_b_temp;
            ex_mem_dest_reg   <= ex_dest_reg;
        end
    end

    // 6. Memory Stage: Data Memory
    data_memory #(
        .DATA_WIDTH(DATA_WIDTH)
    ) DATA_MEM (
        .clk(clk),
        .reset(reset),
        .mem_write(ex_mem_mem_write),
        .mem_read(ex_mem_mem_read),
        .address(ex_mem_alu_result),
        .write_data(ex_mem_write_data),
        .read_data(mem_read_data)
    );

    // MEM/WB Pipeline Register Update
    always @(posedge clk) begin
        if (reset) begin
            mem_wb_reg_write <= 1'b0;
        end else begin
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_read_data  <= mem_read_data;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_dest_reg   <= ex_mem_dest_reg;
        end
    end

    // Write-Back Multiplexer
    assign wb_write_data = (mem_wb_mem_to_reg) ? mem_wb_read_data : mem_wb_alu_result;

    // Probes to prevent the synthesis tool from optimizing away the core logic
    assign probe_pc = if_pc_current;
    assign probe_alu_result = ex_alu_result;


endmodule