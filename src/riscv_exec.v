//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
// Company: iitb
// Engineer: lynn conway
// 
// Create Date: 07.02.2025 21:56:12
// Design Name: riscv_exec
// Module Name: riscv_exec
// Project Name: risc_v_processor
// Target Devices: pynq z2
// Tool Versions: na
// Description: does execution
// 
// Dependencies: on everyone
// 
// Revision: a few
// Revision 0.01 - File Created
// Additional Comments: good luck to us
// 
//////////////////////////////////////////////////////////////////////////////////
// ALU Operations
`include "riscv_def.v"
//`include "../../../riscv_alu.v"
//`include "../../../bkadd.v"

//--------------------------------------------------------------------------------------------------
module riscv_exec (
    input  wire         clk_i,
    input  wire         rst_i,
    input  wire         opcode_valid_i,
    input  wire [57:0]  opcode_instr_i,  // One-hot encoded instruction type //DECODE
    input  wire [31:0]  opcode_opcode_i, // Raw instruction //FETCH
    input  wire [31:0]  opcode_pc_i,     // Program counter
    input  wire [4:0]   opcode_rd_idx_i, // Destination register //DECODE
    input  wire [4:0]   opcode_ra_idx_i, // Source register 1 //DECODE
    input  wire [4:0]   opcode_rb_idx_i, // Source register 2 //DECODE
    input  wire [31:0]  opcode_ra_operand_i, // Value of rs1 //RF
    input  wire [31:0]  opcode_rb_operand_i, // Value of rs2 //RF

    output reg         branch_request_o,  // Branch control signal // PC
    output reg [31:0]  branch_pc_o,       // Branch target address // PC
    output wire [4:0]   writeback_idx_o,   // Destination register for writeback // WRITEBACK
    (* keep = "true" *) output wire         writeback_squash_o, // Set to 0 (not used)
    output wire [31:0]  writeback_value_o, // Value to be written back // WRITEBACK TO RF
    (* keep = "true" *) output wire         stall_o            // Set to 0 (not used)
);

    // Immediate value decoder // IMM VAL GEN
reg [31:0] imm_val;
    always @(*) begin
        case (opcode_opcode_i[6:0])
            7'b0010011, 7'b0000011, 7'b1100111:  // R-type I-type
                imm_val = {{20{opcode_opcode_i[31]}}, opcode_opcode_i[31:20]}; 
            7'b1100011:  // B-type 
                imm_val = {{19{opcode_opcode_i[31]}}, opcode_opcode_i[31], opcode_opcode_i[7], opcode_opcode_i[30:25], opcode_opcode_i[11:8], 1'b0}; 
            7'b1101111:  // J-type
                imm_val = {{11{opcode_opcode_i[31]}}, opcode_opcode_i[19:12], opcode_opcode_i[20], opcode_opcode_i[30:21], 1'b0}; 
            7'b0110111, 7'b0010111:  // U-type
                imm_val = {opcode_opcode_i[31:12], 12'b0};
            default:
                imm_val = 32'b0;
        endcase
    end
    assign writeback_squash_o = 1'b0;
    assign stall_o = 1'b0;
    

    reg [31:0] bk1_a, bk1_b, bpc_o;
    reg brq_o;
    wire [31:0] j_type_o; 
    //other alu constituted by adder hw
    bkadd b1(.a(bk1_a), .b(bk1_b), .cin(1'b0), .s(j_type_o), .cout()); //UPDATE: reduced ADDER hw USING MUX & using ALU
    
// ALU control signals // ALU SIGNALS
    reg [3:0] alu_func_r;
    reg [31:0] alu_input_a_r, alu_input_b_r;
    wire [31:0] alu_p_w;
    
always @(*) begin
    // Default values
    alu_func_r = 4'b0000;
    alu_input_a_r = 32'b0;
    alu_input_b_r = 32'b0;
    brq_o = 1'b0;
    bpc_o = 32'b0;
              
if (opcode_valid_i) begin
    if (opcode_opcode_i[6:0] == 7'b0110011) begin
        alu_input_a_r = opcode_ra_operand_i;
        alu_input_b_r = opcode_rb_operand_i;

        // r type
        if (opcode_instr_i[`ENUM_INST_ADD]) //1
            alu_func_r = `ALU_ADD;
        else if (opcode_instr_i[`ENUM_INST_SUB]) //2
            alu_func_r = `ALU_SUB;
        else if (opcode_instr_i[`ENUM_INST_AND]) //3
            alu_func_r = `ALU_AND;
        else if (opcode_instr_i[`ENUM_INST_OR]) //4
            alu_func_r = `ALU_OR;
        else if (opcode_instr_i[`ENUM_INST_MULT]) //11
            alu_func_r = `ALU_MULT;
        else if (opcode_instr_i[`ENUM_INST_XOR]) //5
            alu_func_r = `ALU_XOR; //mohith
        else if (opcode_instr_i[`ENUM_INST_SLL]) //6
            alu_func_r = `ALU_SHIFTL;
        else if (opcode_instr_i[`ENUM_INST_SRL]) //7
            alu_func_r = `ALU_SHIFTR;
        else if (opcode_instr_i[`ENUM_INST_SRA]) //8
            alu_func_r = `ALU_SHIFTR_ARITH;
        else if (opcode_instr_i[`ENUM_INST_SLT]) //9
            alu_func_r = `ALU_LESS_THAN_SIGNED;
        else if (opcode_instr_i[`ENUM_INST_SLTU]) //10
            alu_func_r = `ALU_LESS_THAN;
    end
    // i-type
    else if (opcode_opcode_i[6:0] == 7'b0010011) begin
            alu_input_a_r = opcode_ra_operand_i;
            alu_input_b_r = imm_val;

        if (opcode_instr_i[`ENUM_INST_ADDI])  //i1
            alu_func_r = `ALU_ADD;
        else if (opcode_instr_i[`ENUM_INST_ANDI]) //i2
            alu_func_r = `ALU_AND;
        else if (opcode_instr_i[`ENUM_INST_ORI]) //i3
            alu_func_r = `ALU_OR;
        else if (opcode_instr_i[`ENUM_INST_XORI])//i4
            alu_func_r = `ALU_XOR;
        else if (opcode_instr_i[`ENUM_INST_SLLI]) //i5
            alu_func_r = `ALU_SHIFTL;
        else if (opcode_instr_i[`ENUM_INST_SRLI]) //i6
            alu_func_r = `ALU_SHIFTR;
        else if (opcode_instr_i[`ENUM_INST_SRAI]) //i7
            alu_func_r = `ALU_SHIFTR_ARITH; //priyangshu
    end
    // u-type auipc
    else if (opcode_opcode_i[6:0] == 7'b0010111) begin
        if (opcode_instr_i[`ENUM_INST_AUIPC]) begin //u1
            alu_func_r = `ALU_ADD;
            alu_input_a_r = opcode_pc_i;
            alu_input_b_r = imm_val;
        end
    end
    // u-typ lui
    else if (opcode_opcode_i[6:0] == 7'b0110111) begin
        if (opcode_instr_i[`ENUM_INST_LUI]) begin //u2
            alu_func_r = `ALU_ADD;
            alu_input_a_r = 32'b0;
            alu_input_b_r = imm_val;
        end
    end
    // j-type jal //lynnconway
    else if (opcode_opcode_i[6:0] == 7'b1101111) begin
        if (opcode_instr_i[`ENUM_INST_JAL]) begin //j1
            alu_func_r = `ALU_ADD;
            alu_input_b_r = 32'h4;
            alu_input_a_r = opcode_pc_i;
            bk1_a = imm_val;
            bk1_b = opcode_pc_i;
            bpc_o = j_type_o; //UPDATE: reduced redundant registers
            brq_o = 1'b1;
        end // priyangshu
    end
    
    // j-type jalr
    else if (opcode_opcode_i[6:0] == 7'b1100111) begin
        if (opcode_instr_i[`ENUM_INST_JALR]) begin //j2
            alu_func_r = `ALU_ADD;
            alu_input_b_r = 32'h4;
            alu_input_a_r = opcode_pc_i;
            bk1_a = imm_val;
            bk1_b = opcode_ra_operand_i;
            bpc_o = j_type_o;  //UPDATE: reduced redundant registers
            brq_o = 1'b1;
        end
    end
    
    // b-type branches
    else if (opcode_opcode_i[6:0] == 7'b1100011) begin
    bk1_a = imm_val;
    bk1_b = opcode_pc_i;
        if (opcode_instr_i[`ENUM_INST_BEQ])
            brq_o = (opcode_ra_operand_i == opcode_rb_operand_i);
        else if (opcode_instr_i[`ENUM_INST_BNE])
            brq_o = (opcode_ra_operand_i != opcode_rb_operand_i); //riscv_lynn
        else if (opcode_instr_i[`ENUM_INST_BLT])
            brq_o = ($signed(opcode_ra_operand_i) < $signed(opcode_rb_operand_i));
        else if (opcode_instr_i[`ENUM_INST_BGE])
            brq_o = ($signed(opcode_ra_operand_i) >= $signed(opcode_rb_operand_i));
        else if (opcode_instr_i[`ENUM_INST_BLTU])
            brq_o = (opcode_ra_operand_i < opcode_rb_operand_i);
        else if (opcode_instr_i[`ENUM_INST_BGEU])
            brq_o = (opcode_ra_operand_i >= opcode_rb_operand_i);

	 bpc_o = brq_o ?  j_type_o : opcode_pc_i; //UPDATE: got rid of redundant logic if branch is not taken
    end
       
end   //if vepa
end    //always comb

    
    // Flop ALU output
     riscv_alu u_alu(
    .alu_op_i(alu_func_r),
    .alu_a_i(alu_input_a_r),
    .alu_b_i(alu_input_b_r),
    .alu_p_o(alu_p_w));

    reg [31:0] op;
    reg [4:0] op_index;
    
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i || ~opcode_valid_i) begin
        op <= 32'H0;
        op_index <= 5'h0;
        branch_pc_o <= 32'h0;
        end
    else begin
        branch_pc_o <= bpc_o; //branch handles are also now sent sequential
        branch_request_o <= brq_o;
        op <=  alu_p_w; //UPDATE : reduced redundant mux logic
        op_index <= (opcode_opcode_i[6:0] == 7'b1100011)? 5'b0 : opcode_rd_idx_i; // UPDATE : rdx reset when B-types
        end
    end //always seq priyangshu
    assign writeback_value_o = op; //concurrent assign
    assign writeback_idx_o = op_index;
endmodule
