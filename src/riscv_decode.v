`timescale 1ns / 1ps
`include "riscv_def.v"

module riscv_decode (
    // Clock and Reset
    input  wire         clk_i,                    // Clock signal
    input  wire         rst_i,                    // Reset signal (active-high)

    // Instruction Fetch Inputs
    input  wire         fetch_valid_i,            // Indicates if fetched instruction is valid
    input  wire [31:0]  fetch_instr_i,            // 32-bit instruction to be decoded
    input  wire [31:0]  fetch_pc_i,               // Program counter value of fetched instruction

    // Branch Inputs
    input  wire         branch_request_i,         // Signals a branch request
    input  wire [31:0]  branch_pc_i,              // Target PC for a branch
    input  wire         branch_csr_request_i,     // Indicates branch due to CSR operation
    input  wire [31:0]  branch_csr_pc_i,          // PC for CSR-based branch

    // Writeback Inputs
    input  wire [4:0]   writeback_exec_idx_i,     // Destination register index from execution unit
    input  wire         writeback_exec_squash_i,  // Squash signal for execution writeback
    input  wire [31:0]  writeback_exec_value_i,   // Value from execution stage writeback
    input  wire [4:0]   writeback_mem_idx_i,      // Destination register index from memory stage
    input  wire         writeback_mem_squash_i,   // Squash signal for memory writeback
    input  wire [31:0]  writeback_mem_value_i,    // Value from memory stage writeback
    input  wire [4:0]   writeback_csr_idx_i,      // Destination register index from CSR unit
    input  wire         writeback_csr_squash_i,   // Squash signal for CSR writeback
    input  wire [31:0]  writeback_csr_value_i,    // Value from CSR writeback
    input  wire [4:0]   writeback_muldiv_idx_i,   // Destination register index from mul/div unit
    input  wire         writeback_muldiv_squash_i,// Squash signal for mul/div writeback
    input  wire [31:0]  writeback_muldiv_value_i, // Value from mul/div unit writeback

    // Stall Inputs
    input  wire         exec_stall_i,             // Execution unit stall signal
    input  wire         lsu_stall_i,              // Load/store unit stall signal
    input  wire         csr_stall_i,              // CSR unit stall signal

    // Fetch Control Outputs
    output reg          fetch_branch_o,           // Signals a branch to be taken
    output reg [31:0]   fetch_branch_pc_o,        // Target PC for branch
    output reg          fetch_accept_o,           // Indicates readiness to accept new instruction
    output reg          fetch_invalidate_o,       // Invalidates current fetched instruction

    // Opcode Validation Outputs
    output reg          exec_opcode_valid_o,      // Valid instruction for ALU execution
    output reg          lsu_opcode_valid_o,       // Valid instruction for load/store operation
    output reg          csr_opcode_valid_o,       // Valid instruction for CSR operation
    output reg          muldiv_opcode_valid_o,    // Valid instruction for mul/div operation

    // Decoded Instruction Outputs
    output reg [57:0]   opcode_instr_o,           // Encoded representation of decoded instruction
    output reg [31:0]   opcode_opcode_o,          // Original 32-bit fetched instruction
    output reg [31:0]   opcode_pc_o,              // Program counter of decoded instruction

    // Register Operand Outputs
    output reg [4:0]    opcode_rd_idx_o,          // Destination register index (rd)
    output reg [4:0]    opcode_ra_idx_o,          // First source register index (rs1)
    output reg [4:0]    opcode_rb_idx_o,          // Second source register index (rs2)
    output reg [31:0]   opcode_ra_operand_o,      // Value of first source register (rs1)
    output reg [31:0]   opcode_rb_operand_o       // Value of second source register (rs2)
);

    // Internal Signals
    wire [56:0] op_instr;                         // Instruction encoding (bits 0-56)
    wire [6:0]  op_code = fetch_instr_i[6:0];     // Opcode field from instruction (bits 6:0)
    wire [4:0]  t1 = fetch_instr_i[11:7];         // Destination register index (rd)
    wire [4:0]  t2 = fetch_instr_i[19:15];        // First source register index (rs1)
    wire [4:0]  t3 = fetch_instr_i[24:20];        // Second source register index (rs2)

    // Register File Definition
    reg [31:0]  RF [31:0];                        // 32 registers, each 32 bits wide
    integer     i;                                // Loop variable for register initialization

    // Instruction Fetch and Validation Logic
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset state: Clear outputs
            opcode_instr_o      <= 58'b0;         // Clear encoded instruction
            opcode_opcode_o     <= 32'b0;         // Clear original instruction
            opcode_pc_o         <= 32'b0;         // Clear program counter
            fetch_accept_o      <= 1'b0;          // Not accepting new instructions
            fetch_invalidate_o  <= 1'b0;          // No invalidation on reset
        end else begin
            // Determine if pipeline can accept new instruction
            fetch_accept_o <= !(exec_stall_i || lsu_stall_i || csr_stall_i); // Accept if no stalls
            opcode_instr_o <= 58'b0;              // Default: clear encoded instruction

            if (fetch_valid_i) begin
                // Valid instruction received
                opcode_opcode_o    <= fetch_instr_i; // Store original instruction
                opcode_pc_o        <= fetch_pc_i;    // Store instruction PC
                fetch_invalidate_o <= 1'b0;          // Do not invalidate valid instruction

                // Check if instruction is invalid (all bits 0-56 are 0)
                if (op_instr[56:0] == 57'd0)
                    opcode_instr_o[57] <= 1'b1;      // Set invalid bit (57) if no match
                else
                    opcode_instr_o <= {1'b0, op_instr}; // Valid instruction, clear invalid bit
            end else begin
                fetch_invalidate_o <= 1'b1;          // Invalidate if no valid instruction
            end
        end
    end

    // Branch Handling Logic
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset state: Clear branch signals
            fetch_branch_o    <= 1'b0;            // No branch
            fetch_branch_pc_o <= 32'b0;           // Clear branch target PC
        end else begin
            if (branch_request_i) begin
                // Regular branch request
                fetch_branch_o    <= 1'b1;         // Signal branch
                fetch_branch_pc_o <= branch_pc_i;  // Set branch target PC
            end else if (branch_csr_request_i) begin
                // CSR-induced branch request
                fetch_branch_o    <= 1'b1;         // Signal branch
                fetch_branch_pc_o <= branch_csr_pc_i; // Set CSR branch target PC
            end else begin
                fetch_branch_o    <= 1'b0;         // No branch by default
            end
        end
    end

    // Register File Writeback Logic
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset state: Initialize all registers to zero
            for (i = 0; i < 32; i = i + 1) begin
                RF[i] <= 32'b0;
            end
        end else begin
            // Writeback from various pipeline stages if not squashed
            if (!writeback_exec_squash_i)
                RF[writeback_exec_idx_i] <= writeback_exec_value_i;     // Execution stage writeback
            if (!writeback_mem_squash_i)
                RF[writeback_mem_idx_i] <= writeback_mem_value_i;       // Memory stage writeback
            if (!writeback_csr_squash_i)
                RF[writeback_csr_idx_i] <= writeback_csr_value_i;       // CSR stage writeback
            if (!writeback_muldiv_squash_i)
                RF[writeback_muldiv_idx_i] <= writeback_muldiv_value_i; // Mul/Div stage writeback
        end
    end

    // Register Operand Output Logic
    always @(posedge clk_i) begin
        // Update register indices and operand values
        opcode_rd_idx_o    <= t1;                    // Destination register index
        opcode_ra_idx_o    <= t2;                    // First source register index
        opcode_rb_idx_o    <= t3;                    // Second source register index
        opcode_ra_operand_o <= RF[t2];               // First source operand value
        opcode_rb_operand_o <= RF[t3];               // Second source operand value
    end

    // Opcode Validation Logic
    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset state: Clear all validation signals
            exec_opcode_valid_o    <= 1'b0;
            lsu_opcode_valid_o     <= 1'b0;
            csr_opcode_valid_o     <= 1'b0;
            muldiv_opcode_valid_o  <= 1'b0;
        end else begin
            if (fetch_valid_i) begin
                // Validate opcode based on instruction type
                if ((op_code == 7'b1100011) || (op_code == 7'b0010011) || 
                    (op_code == 7'b0110011) || (op_code == 7'b1101111) || 
                    (op_code == 7'b1100111))
                    exec_opcode_valid_o <= 1'b1;    // ALU/Branch/Jump instructions
                else if ((op_code == 7'b0000011) || (op_code == 7'b0100011) || 
                         (op_code == 7'b0110111))
                    lsu_opcode_valid_o <= 1'b1;     // Load/Store/LUI instructions
                else if ((op_code == 7'b1110011) || (op_code == 7'b1010011))
                    csr_opcode_valid_o <= 1'b1;     // CSR or floating-point instructions
                else if (op_instr[`ENUM_INST_MULT] || op_instr[`ENUM_INST_MULH] || 
                         op_instr[`ENUM_INST_MULHSU] || op_instr[`ENUM_INST_MULHU])
                    muldiv_opcode_valid_o <= 1'b1;  // Multiplication instructions
                else begin
                    // No valid instruction type matched
                    exec_opcode_valid_o    <= 1'b0;
                    lsu_opcode_valid_o     <= 1'b0;
                    csr_opcode_valid_o     <= 1'b0;
                    muldiv_opcode_valid_o  <= 1'b0;
                end
                end else begin 
                    exec_opcode_valid_o    <= 1'b0;
                    lsu_opcode_valid_o     <= 1'b0;
                    csr_opcode_valid_o     <= 1'b0;
                    muldiv_opcode_valid_o  <= 1'b0;
                end
            end
        end
    
    

    // Instruction Decoding (Assign specific instruction bits)
    assign op_instr[`ENUM_INST_ANDI]    = ((fetch_instr_i & `INST_ANDI_MASK)  == `INST_ANDI);    // ANDI
    assign op_instr[`ENUM_INST_ADDI]    = ((fetch_instr_i & `INST_ADDI_MASK)  == `INST_ADDI);    // ADDI
    assign op_instr[`ENUM_INST_SLTI]    = ((fetch_instr_i & `INST_SLTI_MASK)  == `INST_SLTI);    // SLTI
    assign op_instr[`ENUM_INST_SLTIU]   = ((fetch_instr_i & `INST_SLTIU_MASK) == `INST_SLTIU);   // SLTIU
    assign op_instr[`ENUM_INST_ORI]     = ((fetch_instr_i & `INST_ORI_MASK)   == `INST_ORI);     // ORI
    assign op_instr[`ENUM_INST_XORI]    = ((fetch_instr_i & `INST_XORI_MASK)  == `INST_XORI);    // XORI
    assign op_instr[`ENUM_INST_SLLI]    = ((fetch_instr_i & `INST_SLLI_MASK)  == `INST_SLLI);    // SLLI
    assign op_instr[`ENUM_INST_SRLI]    = ((fetch_instr_i & `INST_SRLI_MASK)  == `INST_SRLI);    // SRLI
    assign op_instr[`ENUM_INST_SRAI]    = ((fetch_instr_i & `INST_SRAI_MASK)  == `INST_SRAI);    // SRAI
    assign op_instr[`ENUM_INST_LUI]     = ((fetch_instr_i & `INST_LUI_MASK)   == `INST_LUI);     // LUI
    assign op_instr[`ENUM_INST_AUIPC]   = ((fetch_instr_i & `INST_AUIPC_MASK) == `INST_AUIPC);   // AUIPC
    assign op_instr[`ENUM_INST_ADD]     = ((fetch_instr_i & `INST_ADD_MASK)   == `INST_ADD);     // ADD
    assign op_instr[`ENUM_INST_SUB]     = ((fetch_instr_i & `INST_SUB_MASK)   == `INST_SUB);     // SUB
    assign op_instr[`ENUM_INST_SLT]     = ((fetch_instr_i & `INST_SLT_MASK)   == `INST_SLT);     // SLT
    assign op_instr[`ENUM_INST_SLTU]    = ((fetch_instr_i & `INST_SLTU_MASK)  == `INST_SLTU);    // SLTU
    assign op_instr[`ENUM_INST_XOR]     = ((fetch_instr_i & `INST_XOR_MASK)   == `INST_XOR);     // XOR
    assign op_instr[`ENUM_INST_OR]      = ((fetch_instr_i & `INST_OR_MASK)    == `INST_OR);      // OR
    assign op_instr[`ENUM_INST_AND]     = ((fetch_instr_i & `INST_AND_MASK)   == `INST_AND);     // AND
    assign op_instr[`ENUM_INST_SLL]     = ((fetch_instr_i & `INST_SLL_MASK)   == `INST_SLL);     // SLL
    assign op_instr[`ENUM_INST_SRL]     = ((fetch_instr_i & `INST_SRL_MASK)   == `INST_SRL);     // SRL
    assign op_instr[`ENUM_INST_SRA]     = ((fetch_instr_i & `INST_SRA_MASK)   == `INST_SRA);     // SRA
    assign op_instr[`ENUM_INST_JAL]     = ((fetch_instr_i & `INST_JAL_MASK)   == `INST_JAL);     // JAL
    assign op_instr[`ENUM_INST_JALR]    = ((fetch_instr_i & `INST_JALR_MASK)  == `INST_JALR);    // JALR
    assign op_instr[`ENUM_INST_BEQ]     = ((fetch_instr_i & `INST_BEQ_MASK)   == `INST_BEQ);     // BEQ
    assign op_instr[`ENUM_INST_BNE]     = ((fetch_instr_i & `INST_BNE_MASK)   == `INST_BNE);     // BNE
    assign op_instr[`ENUM_INST_BLT]     = ((fetch_instr_i & `INST_BLT_MASK)   == `INST_BLT);     // BLT
    assign op_instr[`ENUM_INST_BGE]     = ((fetch_instr_i & `INST_BGE_MASK)   == `INST_BGE);     // BGE
    assign op_instr[`ENUM_INST_BLTU]    = ((fetch_instr_i & `INST_BLTU_MASK)  == `INST_BLTU);    // BLTU
    assign op_instr[`ENUM_INST_BGEU]    = ((fetch_instr_i & `INST_BGEU_MASK)  == `INST_BGEU);    // BGEU
    assign op_instr[`ENUM_INST_LB]      = ((fetch_instr_i & `INST_LB_MASK)    == `INST_LB);      // LB
    assign op_instr[`ENUM_INST_LH]      = ((fetch_instr_i & `INST_LH_MASK)    == `INST_LH);      // LH
    assign op_instr[`ENUM_INST_LW]      = ((fetch_instr_i & `INST_LW_MASK)    == `INST_LW);      // LW
    assign op_instr[`ENUM_INST_LBU]     = ((fetch_instr_i & `INST_LBU_MASK)   == `INST_LBU);     // LBU
    assign op_instr[`ENUM_INST_LHU]     = ((fetch_instr_i & `INST_LHU_MASK)   == `INST_LHU);     // LHU
    assign op_instr[`ENUM_INST_LWU]     = ((fetch_instr_i & `INST_LWU_MASK)   == `INST_LWU);     // LWU
    assign op_instr[`ENUM_INST_SB]      = ((fetch_instr_i & `INST_SB_MASK)    == `INST_SB);      // SB
    assign op_instr[`ENUM_INST_SH]      = ((fetch_instr_i & `INST_SH_MASK)    == `INST_SH);      // SH
    assign op_instr[`ENUM_INST_SW]      = ((fetch_instr_i & `INST_SW_MASK)    == `INST_SW);      // SW
    assign op_instr[`ENUM_INST_ECALL]   = ((fetch_instr_i & `INST_ECALL_MASK) == `INST_ECALL);   // ECALL
    assign op_instr[`ENUM_INST_EBREAK]  = ((fetch_instr_i & `INST_EBREAK_MASK) == `INST_EBREAK); // EBREAK
    assign op_instr[`ENUM_INST_ERET]    = ((fetch_instr_i & `INST_MRET_MASK)  == `INST_MRET);    // ERET (MRET)
    assign op_instr[`ENUM_INST_CSRRW]   = ((fetch_instr_i & `INST_CSRRW_MASK) == `INST_CSRRW);   // CSRRW
    assign op_instr[`ENUM_INST_CSRRS]   = ((fetch_instr_i & `INST_CSRRS_MASK) == `INST_CSRRS);   // CSRRS
    assign op_instr[`ENUM_INST_CSRRC]   = ((fetch_instr_i & `INST_CSRRC_MASK) == `INST_CSRRC);   // CSRRC
    assign op_instr[`ENUM_INST_CSRRWI]  = ((fetch_instr_i & `INST_CSRRWI_MASK) == `INST_CSRRWI); // CSRRWI
    assign op_instr[`ENUM_INST_CSRRSI]  = ((fetch_instr_i & `INST_CSRRSI_MASK) == `INST_CSRRSI); // CSRRSI
    assign op_instr[`ENUM_INST_CSRRCI]  = ((fetch_instr_i & `INST_CSRRCI_MASK) == `INST_CSRRCI); // CSRRCI
    assign op_instr[`ENUM_INST_MULT]     = ((fetch_instr_i & `INST_MUL_MASK)   == `INST_MUL);     // MUL
    assign op_instr[`ENUM_INST_MULH]    = ((fetch_instr_i & `INST_MULH_MASK)  == `INST_MULH);    // MULH
    assign op_instr[`ENUM_INST_MULHSU]  = ((fetch_instr_i & `INST_MULHSU_MASK) == `INST_MULHSU); // MULHSU
    assign op_instr[`ENUM_INST_MULHU]   = ((fetch_instr_i & `INST_MULHU_MASK) == `INST_MULHU);   // MULHU
    assign op_instr[`ENUM_INST_DIV]     = ((fetch_instr_i & `INST_DIV_MASK)   == `INST_DIV);     // DIV
    assign op_instr[`ENUM_INST_DIVU]    = ((fetch_instr_i & `INST_DIVU_MASK)  == `INST_DIVU);    // DIVU
    assign op_instr[`ENUM_INST_REM]     = ((fetch_instr_i & `INST_REM_MASK)   == `INST_REM);     // REM
    assign op_instr[`ENUM_INST_REMU]    = ((fetch_instr_i & `INST_REMU_MASK)  == `INST_REMU);    // REMU
    assign op_instr[`ENUM_INST_FAULT]   = ((fetch_instr_i & `INST_FAULT_MASK) == `INST_FAULT);   // FAULT
    assign op_instr[`ENUM_INST_PAGE_FAULT] = ((fetch_instr_i & `INST_PAGE_FAULT_MASK) == `INST_PAGE_FAULT); // PAGE_FAULT

endmodule
