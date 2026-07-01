`timescale 1ns / 1ps
`include "riscv_def.v" // Include definitions file for CSR addresses, exception causes, etc.

// EE 705 - VLSI Design Lab 2025
// Project Name:  	RISC-V CPU
// Description: 	CSR unit RV32I Design
// Group Name - Bitstream Builders (Aditya Tare 24M1169, Gautam Govindraju 24M1166, Sachin Soneria 24M1178)

module riscv_csr (
    // Clock and Reset
    input  wire         clk_i,                    // Clock signal
    input  wire         rst_i,                    // Reset signal (active-high)

    // Interrupt Inputs
    input  wire         intr_i,                   // External interrupt input signal

    // Opcode Inputs
    input  wire         opcode_valid_i,           // Indicates if the current instruction is valid
    input  wire [57:0]  opcode_instr_i,           // 58-bit instruction metadata input
    input  wire [31:0]  opcode_opcode_i,          // 32-bit instruction opcode input
    input  wire [31:0]  opcode_pc_i,              // Program counter value for the current instruction
    input  wire [4:0]   opcode_rd_idx_i,          // Destination register index for writeback
    input  wire [4:0]   opcode_ra_idx_i,          // First source register index (unused in this module)
    input  wire [4:0]   opcode_rb_idx_i,          // Second source register index (unused in this module)
    input  wire [31:0]  opcode_ra_operand_i,      // Value of the first source register
    input  wire [31:0]  opcode_rb_operand_i,      // Value of the second source register (unused in this module)

    // Branch Inputs
    input  wire         branch_exec_request_i,    // Indicates a branch execution request
    input  wire [31:0]  branch_exec_pc_i,         // Target program counter for branch execution

    // System Configuration Inputs
    input  wire [31:0]  cpu_id_i,                 // CPU identification number input
    input  wire [31:0]  reset_vector_i,           // Reset vector address input

    // Fault Inputs
    input  wire         fault_store_i,            // Indicates a store operation fault
    input  wire         fault_load_i,             // Indicates a load operation fault
    input  wire         fault_misaligned_store_i, // Indicates a misaligned store fault
    input  wire         fault_misaligned_load_i,  // Indicates a misaligned load fault
    input  wire         fault_page_store_i,       // Indicates a page fault during a store operation
    input  wire         fault_page_load_i,        // Indicates a page fault during a load operation
    input  wire [31:0]  fault_addr_i,             // Address where a fault occurred

    // Writeback Outputs
    output reg  [4:0]   writeback_idx_o,          // Register index for writeback operation
    output reg          writeback_squash_o,       // Signal to squash the writeback operation
    output reg  [31:0]  writeback_value_o,        // Value to be written back to the register

    // Control Outputs
    output reg          stall_o,                  // Pipeline stall signal (1 = stall)
    output reg          branch_csr_request_o,     // Branch request signal due to CSR operation
    output reg  [31:0]  branch_csr_pc_o,          // Target program counter for CSR-induced branch
    output reg  [31:0]  temp                      // Temporary register to store cause values
);

    // CSR (Machine) Registers Definition
    reg [31:0] mepc;       // Machine Exception Program Counter - Stores PC on exception
    reg [31:0] mcause;     // Machine Cause - Stores the cause of an exception or interrupt
    reg [31:0] mstatus;    // Machine Status - Stores status flags (e.g., interrupt enables)
    reg [31:0] mtvec;      // Machine Trap Vector - Stores the trap handler base address
    reg [31:0] mip;        // Machine Interrupt Pending - Tracks pending interrupts
    reg [31:0] mie;        // Machine Interrupt Enable - Enables specific interrupts
    reg [31:0] mcycle;     // Machine Cycle Counter - Counts CPU cycles
    reg [31:0] mscratch;   // Machine Scratch Register - Temporary storage for machine mode
    reg [31:0] mtime;      // Machine Timer Register (low) - Lower 32 bits of timer
    reg [31:0] mtimeh;     // Machine Timer Register (high) - Upper 32 bits of timer
    reg [31:0] misa;       // Machine ISA - Indicates supported ISA (RV32I here)
    reg [1:0]  mpriv;      // Machine Privilege Level - 00: User, 01: Supervisor, 11: Machine

    // Read-only registers
    reg [31:0] mhartid;    // Machine Hart ID - Stores the CPU ID (read-only)

    // CSR (Supervisor) Registers Definition
    reg [31:0] sepc;       // Supervisor Exception Program Counter - Stores PC for supervisor exceptions
    reg [31:0] scause;     // Supervisor Cause - Stores cause of supervisor exceptions/interrupts
    reg [31:0] sstatus;    // Supervisor Status - Supervisor mode status flags
    reg [31:0] stvec;      // Supervisor Trap Vector - Supervisor trap handler base address
    reg [31:0] sip;        // Supervisor Interrupt Pending - Tracks pending supervisor interrupts
    reg [31:0] sie;        // Supervisor Interrupt Enable - Enables supervisor interrupts
    reg [31:0] sscratch;   // Supervisor Scratch Register - Temporary storage for supervisor mode
    reg [31:0] stval;      // Supervisor Trap Value - Stores fault address or illegal instruction
    reg [31:0] satp;       // Supervisor Address Translation and Protection - Page table base address
    reg [1:0] current_state;

    // Internal Signals
    reg invalid_instr;     // Flag to detect illegal instructions internally
    
    localparam csr_request = 2'b00;
    localparam exception_handling = 2'b01;
    

    // CSR Instruction Decoding
    wire [11:0] csr_addr = opcode_opcode_i[31:20]; // Extracts CSR address from instruction bits [31:20]
    wire [2:0]  funct3   = opcode_opcode_i[14:12]; // Extracts function code from instruction bits [14:12]
    wire [4:0]  rs1      = opcode_opcode_i[19:15]; // Extracts source register index or immediate from bits [19:15]
    wire [31:0] imm      = {27'b0, rs1};           // Zero-extends the 5-bit rs1 field to 32 bits for immediate ops
    wire is_csrrw  = (funct3 == 3'b001);           // CSRRW instruction (CSR read/write)
    wire is_csrrs  = (funct3 == 3'b010);           // CSRRS instruction (CSR read/set)
    wire is_csrrc  = (funct3 == 3'b011);           // CSRRC instruction (CSR read/clear)
    wire is_csrrwi = (funct3 == 3'b101);           // CSRRWI instruction (CSR read/write immediate)
    wire is_csrrsi = (funct3 == 3'b110);           // CSRRSI instruction (CSR read/set immediate)
    wire is_csrrci = (funct3 == 3'b111);           // CSRRCI instruction (CSR read/clear immediate)
    wire is_csr_op = opcode_valid_i && (is_csrrw || is_csrrs || is_csrrc || is_csrrwi || is_csrrsi || is_csrrci); // Flags any CSR operation
    wire is_mret   = (opcode_opcode_i == `INST_MRET); // MRET instruction (machine mode return)

    // Interrupt Logic
    wire [31:0] pending_interrupts = {20'b0, (mip[`IRQ_M_EXT] & mie[`IRQ_M_EXT]), 3'b0, (mip[`IRQ_M_TIMER] & mie[`IRQ_M_TIMER]), 3'b0, (mip[`IRQ_M_SOFT] & mie[`IRQ_M_SOFT]), 3'b0}; // Computes masked pending interrupts
    wire interrupt_valid = ((intr_i == 1) && pending_interrupts != 0) && (((mpriv == `PRIV_MACHINE || mpriv == `PRIV_USER) && mstatus[`SR_MIE_R]) || (mpriv == `PRIV_SUPER && sstatus[`SR_SIE_R])); // Checks if interrupts are valid and enabled
    wire [31:0] interrupt_cause; // Defines the cause of the highest priority interrupt
    assign interrupt_cause = (pending_interrupts[`IRQ_M_EXT])   ? (`MCAUSE_INTERRUPT | `IRQ_M_EXT) :    // External interrupt
                            (pending_interrupts[`IRQ_M_TIMER]) ? (`MCAUSE_INTERRUPT | `IRQ_M_TIMER) :  // Timer interrupt
                            (pending_interrupts[`IRQ_M_SOFT])  ? (`MCAUSE_INTERRUPT | `IRQ_M_SOFT) : 0;// Software interrupt

    // Exception Logic
    wire ecall = opcode_valid_i && (opcode_opcode_i == `INST_ECALL);     // Detects environment call instruction
    wire ebreak = opcode_valid_i && (opcode_opcode_i == `INST_EBREAK);   // Detects environment break instruction
    wire misaligned_fetch = (opcode_pc_i[1:0] != 2'b00);                // Detects misaligned instruction fetch
    wire fault_fetch = opcode_valid_i && (opcode_opcode_i == `INST_FAULT); // Detects instruction fetch fault
    wire exception_occurred = fault_page_store_i || fault_page_load_i || fault_misaligned_store_i || 
                             fault_misaligned_load_i || fault_store_i || fault_load_i || fault_fetch || 
                             invalid_instr || ebreak || ecall || misaligned_fetch; // Flags any exception condition
    wire [31:0] exception_cause; // Defines the cause of the highest priority exception
    assign exception_cause = (fault_page_store_i)      ? `MCAUSE_PAGE_FAULT_STORE :      // Page fault store
                            (fault_page_load_i)       ? `MCAUSE_PAGE_FAULT_LOAD :       // Page fault load
                            (fault_misaligned_store_i)? `MCAUSE_MISALIGNED_STORE :      // Misaligned store
                            (fault_misaligned_load_i) ? `MCAUSE_MISALIGNED_LOAD :       // Misaligned load
                            (fault_store_i)           ? `MCAUSE_FAULT_STORE :           // Store fault
                            (fault_load_i)            ? `MCAUSE_FAULT_LOAD :            // Load fault
                            (fault_fetch)             ? `MCAUSE_FAULT_FETCH :           // Fetch fault
                            (ebreak)                  ? `MCAUSE_BREAKPOINT :            // Breakpoint
                            (misaligned_fetch)        ? `MCAUSE_MISALIGNED_FETCH :      // Misaligned fetch
                            (ecall)                   ? (mpriv == `PRIV_MACHINE ? `MCAUSE_ECALL_M : mpriv == `PRIV_SUPER ? `MCAUSE_ECALL_S : `MCAUSE_ECALL_U) :       // Environment call
                            (invalid_instr)           ? `MCAUSE_ILLEGAL_INSTRUCTION : 0;// Illegal instruction
    
    // CSR Read Logic
    reg [31:0] csr_read_data; // Holds the value read from the addressed CSR
    always @(*) begin
        case (csr_addr) // Selects CSR based on address and assigns its value
            `CSR_MSTATUS:   csr_read_data = mstatus;
            `CSR_MTVEC:     csr_read_data = mtvec;
            `CSR_MEPC:      csr_read_data = mepc;
            `CSR_MCAUSE:    csr_read_data = mcause;
            `CSR_MIP:       csr_read_data = mip;
            `CSR_MIE:       csr_read_data = mie;
            `CSR_MSCRATCH:  csr_read_data = mscratch;
            `CSR_MCYCLE:    csr_read_data = mcycle;
            `CSR_MHARTID:   csr_read_data = mhartid;
            `CSR_MISA:      csr_read_data = misa;
            `CSR_MTIME:     csr_read_data = mtime;
            `CSR_MTIMEH:    csr_read_data = mtimeh;
            `CSR_SSTATUS:   csr_read_data = sstatus;
            `CSR_SIE:       csr_read_data = sie;
            `CSR_STVEC:     csr_read_data = stvec;
            `CSR_SSCRATCH:  csr_read_data = sscratch;
            `CSR_SEPC:      csr_read_data = sepc;
            `CSR_SCAUSE:    csr_read_data = scause;
            `CSR_STVAL:     csr_read_data = stval;
            `CSR_SIP:       csr_read_data = sip;
            `CSR_SATP:      csr_read_data = satp;
            default:        csr_read_data = 32'h0;     // Returns 0 for unimplemented CSR addresses
        endcase
    end

    // CSR Write Data Computation
    reg [31:0] csr_write_data; // Holds the value to be written to the CSR
    always @(*) begin
        if (is_csrrw || is_csrrwi) // Handles CSRRW and CSRRWI instructions
            csr_write_data = (is_csrrw) ? opcode_ra_operand_i : imm; // Writes register value or immediate
        else if (is_csrrs || is_csrrsi) // Handles CSRRS and CSRRSI instructions
            csr_write_data = csr_read_data | ((is_csrrs) ? opcode_ra_operand_i : imm); // Sets bits using OR
        else if (is_csrrc || is_csrrci) // Handles CSRRC and CSRRCI instructions
            csr_write_data = csr_read_data & ~((is_csrrc) ? opcode_ra_operand_i : imm); // Clears bits using AND with negated value
        else
            csr_write_data = csr_read_data; // No change if none of the above operations apply
    end

    // Main Sequential Logic
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            // Reset all registers to initial values
            mstatus    <= 32'h00001800;        // Initializes with MIE=0, MPP=Machine mode
            mtvec      <= reset_vector_i;      // Sets trap vector to reset vector
            mepc       <= 32'h0;               // Clears exception PC
            mcause     <= 32'h0;               // Clears cause register
            mip        <= 32'h0;               // Clears interrupt pending
            mie        <= 32'h0;               // Clears interrupt enable
            mscratch   <= 32'h0;               // Clears scratch register
            mcycle     <= 32'h0;               // Clears cycle counter
            mpriv      <= `PRIV_USER;          // Sets initial privilege to User mode
            mhartid    <= cpu_id_i;            // Sets hart ID to CPU ID
            misa       <= `MISA_RV32 | `MISA_RVI; // Initializes ISA for RV32I
            mtime      <= 32'h0;               // Clears timer (low)
            mtimeh     <= 32'h0;               // Clears timer (high)
            sstatus    <= 32'h0;               // Initializes supervisor status
            stvec      <= 32'h0;               // Clears supervisor trap vector
            sepc       <= 32'h0;               // Clears supervisor exception PC
            scause     <= 32'h0;               // Clears supervisor cause
            sip        <= 32'h0;               // Clears supervisor interrupt pending
            sie        <= 32'h0;               // Clears supervisor interrupt enable
            sscratch   <= 32'h0;               // Clears supervisor scratch
            stval      <= 32'h0;               // Clears supervisor trap value
            satp       <= 32'h0;               // Clears address translation
            writeback_idx_o    <= 5'h0;        // Clears writeback index
            writeback_squash_o <= 1'b0;        // Disables writeback squash
            writeback_value_o  <= 32'h0;       // Clears writeback value
            stall_o            <= 1'b0;        // Disables pipeline stall
            branch_csr_request_o <= 1'b0;      // Disables CSR branch request
            branch_csr_pc_o    <= 32'h0;       // Clears branch target PC
            invalid_instr      <= 1'b0;        // Clears invalid instruction flag
        end else begin
            // Default output values
            case (current_state)
            csr_request: begin
            writeback_idx_o    <= 5'h0;        // Resets writeback index
            writeback_squash_o <= 1'b0;        // Disables writeback squash
            writeback_value_o  <= 32'h0;       // Resets writeback value
            stall_o            <= 1'b0;        // Disables pipeline stall
            branch_csr_request_o <= 1'b0;      // Disables CSR branch request
            branch_csr_pc_o    <= 32'h0;       // Resets branch target PC
            mcycle             <= mcycle + 1;  // Increments cycle counter
            invalid_instr      <= 1'b0;        // Resets invalid instruction flag
            current_state <= exception_handling;
            end
            
            exception_handling: begin
            // Interrupt and Exception Handling (Both conditions true)
            if (interrupt_valid && exception_occurred) begin
                if (mpriv == `PRIV_SUPER) begin
                    // Supervisor mode trap handling
                    sepc               <= opcode_pc_i;         // Save current PC
                    scause             <= interrupt_cause;     // Set interrupt cause
                    stval              <= 32'h0;               // Clear trap value
                    sstatus[`SR_SPIE_R]<= sstatus[`SR_SIE_R];  // Save SIE to SPIE
                    sstatus[`SR_SIE_R] <= 1'b0;                // Disable interrupts
                    sstatus[`SR_SPP_R] <= mpriv;               // Save privilege mode
                    mpriv              <= `PRIV_MACHINE;       // Elevate to Machine mode
                    branch_csr_request_o <= 1'b1;              // Request trap branch
                    branch_csr_pc_o    <= mtvec;               // Set trap vector
                    stall_o           <= 1'b1; 
                    temp               <= interrupt_cause;     // Store cause
                end else begin
                    // Machine mode trap handling
                    mepc               <= opcode_pc_i;         // Save current PC
                    mcause             <= interrupt_cause;     // Set interrupt cause
                    stval              <= 32'h0;               // Clear trap value
                    mstatus[`SR_MPIE_R]<= mstatus[`SR_MIE_R];  // Save MIE to MPIE
                    mstatus[`SR_MIE_R] <= 1'b0;                // Disable interrupts
                    mstatus[`SR_MPP_R] <= mpriv;               // Save privilege mode
                    mpriv              <= `PRIV_MACHINE;       // Set to Machine mode
                    branch_csr_request_o <= 1'b1;              // Request trap branch
                    branch_csr_pc_o    <= mtvec;               // Set trap vector
                    stall_o           <= 1'b1; 
                    temp               <= interrupt_cause;     // Store cause
                end
            end 

            // Interrupt Handling (Only interrupt valid no exception)
            else if (interrupt_valid && !exception_occurred) begin
                if (mpriv == `PRIV_SUPER) begin
                    // Supervisor mode interrupt handling
                    sepc               <= opcode_pc_i;         // Save current PC
                    scause             <= interrupt_cause;     // Set interrupt cause
                    stval              <= 32'h0;               // Clear trap value
                    sstatus[`SR_SPIE_R]<= sstatus[`SR_SIE_R];  // Save SIE to SPIE
                    sstatus[`SR_SIE_R] <= 1'b0;                // Disable interrupts
                    sstatus[`SR_SPP_R] <= mpriv;               // Save privilege mode
                    mpriv              <= `PRIV_MACHINE;       // Elevate to Machine mode
                    branch_csr_request_o <= 1'b1;              // Request trap branch
                    branch_csr_pc_o    <= mtvec;               // Set trap vector
                    stall_o           <= 1'b1; 
                    temp               <= interrupt_cause;     // Store cause
                end else begin
                    // Machine mode interrupt handling
                    mepc               <= opcode_pc_i;         // Save current PC
                    mcause             <= interrupt_cause;     // Set interrupt cause
                    stval              <= 32'h0;               // Clear trap value
                    mstatus[`SR_MPIE_R]<= mstatus[`SR_MIE_R];  // Save MIE to MPIE
                    mstatus[`SR_MIE_R] <= 1'b0;                // Disable interrupts
                    mstatus[`SR_MPP_R] <= mpriv;               // Save privilege mode
                    mpriv              <= `PRIV_MACHINE;       // Set to Machine mode
                    branch_csr_request_o <= 1'b1;              // Request trap branch
                    branch_csr_pc_o    <= mtvec;               // Set trap vector
                    stall_o           <= 1'b1; 
                    temp               <= interrupt_cause;     // Store cause
                end
            end 

            // Exception Handling (Only exception occurred no interrupt)
            else if (exception_occurred && !interrupt_valid) begin
                if (mpriv == `PRIV_SUPER) begin
                    // Supervisor mode exception handling
                    sepc               <= opcode_pc_i;         // Save current PC
                    scause             <= exception_cause;     // Set exception cause
                    stval              <= fault_addr_i;        // Store fault address
                    sstatus[`SR_SPIE_R]<= sstatus[`SR_SIE_R];  // Save SIE to SPIE
                    sstatus[`SR_SPP_R] <= mpriv;               // Save privilege mode
                    mpriv              <= `PRIV_MACHINE;       // Elevate to Machine mode
                    branch_csr_request_o <= 1'b1;              // Request trap branch
                    branch_csr_pc_o    <= mtvec;               // Set trap vector
                    stall_o           <= 1'b1; 
                    temp               <= exception_cause;     // Store cause
                end else begin
                    // Machine mode exception handling
                    mepc               <= opcode_pc_i;         // Save current PC
                    mcause             <= exception_cause;     // Set exception cause
                    stval              <= fault_addr_i;        // Store fault address
                    mstatus[`SR_MPIE_R]<= mstatus[`SR_MIE_R];  // Save MIE to MPIE
                    mstatus[`SR_MPP_R] <= mpriv;               // Save privilege mode
                    mpriv              <= `PRIV_MACHINE;       // Set to Machine mode
                    branch_csr_request_o <= 1'b1;              // Request trap branch
                    branch_csr_pc_o    <= mtvec;               // Set trap vector
                    stall_o           <= 1'b1; 
                    temp               <= exception_cause;     // Store cause
                end
            end 

            // CSR Instruction Execution
            else if (is_csr_op) begin
                stall_o           <= 1'b1;             // Stall pipeline for CSR operation
                writeback_idx_o   <= opcode_rd_idx_i;  // Set writeback register index
                writeback_value_o <= csr_read_data;    // Set writeback value
                case (csr_addr) // Write to specified CSR
                    `CSR_MSTATUS:   mstatus   <= csr_write_data & `CSR_MSTATUS_MASK;
                    `CSR_MTVEC:     mtvec     <= csr_write_data & `CSR_MTVEC_MASK;
                    `CSR_MEPC:      mepc      <= csr_write_data & `CSR_MEPC_MASK;
                    `CSR_MCAUSE:    mcause    <= csr_write_data & `CSR_MCAUSE_MASK;
                    `CSR_MIP:       mip       <= csr_write_data & `CSR_MIP_MASK;
                    `CSR_MIE:       mie       <= csr_write_data & `CSR_MIE_MASK;
                    `CSR_MSCRATCH:  mscratch  <= csr_write_data & `CSR_MSCRATCH_MASK;
                    `CSR_MCYCLE:    mcycle    <= csr_write_data & `CSR_MCYCLE_MASK;
                    `CSR_MTIME:     mtime     <= csr_write_data & `CSR_MTIME_MASK;
                    `CSR_MTIMEH:    mtimeh    <= csr_write_data & `CSR_MTIMEH_MASK;
                    `CSR_SSTATUS:   sstatus   <= csr_write_data & `CSR_SSTATUS_MASK;
                    `CSR_SIE:       sie       <= csr_write_data & `CSR_SIE_MASK;
                    `CSR_STVEC:     stvec     <= csr_write_data & `CSR_STVEC_MASK;
                    `CSR_SSCRATCH:  sscratch  <= csr_write_data & `CSR_SSCRATCH_MASK;
                    `CSR_SEPC:      sepc      <= csr_write_data & `CSR_SEPC_MASK;
                    `CSR_SCAUSE:    scause    <= csr_write_data & `CSR_SCAUSE_MASK;
                    `CSR_STVAL:     stval     <= csr_write_data & `CSR_STVAL_MASK;
                    `CSR_SIP:       sip       <= csr_write_data & `CSR_SIP_MASK;
                    `CSR_SATP:      satp      <= csr_write_data & `CSR_SATP_MASK;
                    default:        ; // No action for unimplemented CSRs
                endcase
            end 

            // MRET Instruction Handling
            else if (is_mret) begin
                if (mpriv == `PRIV_MACHINE) begin
                    // Return from Machine mode
                    mpriv              <= mstatus[`SR_MPP_R];   // Restore privilege mode
                    mstatus[`SR_MIE_R] <= mstatus[`SR_MPIE_R];  // Restore interrupt enable
                    mstatus[`SR_MPIE_R]<= 1'b1;                 // Reset MPIE
                    mstatus[`SR_MPP_R] <= `PRIV_USER;           // Set MPP to User mode
                    branch_csr_request_o <= 1'b1;               // Request return branch
                    branch_csr_pc_o    <= mepc;                 // Set return address
                    stall_o           <= 1'b1;
                end
            end 

            // Invalid Instruction Detection
            if (opcode_valid_i && ((opcode_opcode_i[14:12] != 3'b001) && 
                (opcode_opcode_i[14:12] != 3'b010) && 
                (opcode_opcode_i[14:12] != 3'b011) &&
                (opcode_opcode_i[14:12] != 3'b101) &&
                (opcode_opcode_i[14:12] != 3'b110) &&
                (opcode_opcode_i[14:12] != 3'b111)) && 
                ((csr_read_data === 32'h0) && (csr_addr != 0) &&
                (csr_addr != `CSR_MEPC) && (csr_addr != `CSR_MCAUSE) && 
                (csr_addr != `CSR_MSTATUS) && (csr_addr != `CSR_MTVEC) && 
                (csr_addr != `CSR_MIP) && (csr_addr != `CSR_MIE) && 
                (csr_addr != `CSR_MCYCLE) && (csr_addr != `CSR_MSCRATCH) &&
                (csr_addr != `CSR_MTIME) && (csr_addr != `CSR_MTIMEH) &&
                (csr_addr != `CSR_MISA)) &&
                ((opcode_opcode_i != `INST_EBREAK) &&
                (opcode_opcode_i != `INST_MRET) &&
                (opcode_opcode_i != `INST_ECALL) &&
                (opcode_opcode_i != `INST_FAULT)))
                invalid_instr <= 1'b1; // Set flag for invalid instruction
            else 
                invalid_instr <= 1'b0; // Clear flag if instruction is valid
                current_state <= csr_request;
        end
        default: begin
        current_state <= csr_request;
        end
        endcase
        end
    end

endmodule