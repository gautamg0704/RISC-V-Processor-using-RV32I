module riscv_fetch(
    input clk_i,                        // Global Clock signal
    input rst_i,                        // Global Reset signal

    input fetch_branch_i,               // Signal to indicate if a branch needs to be taken
    input [31:0] fetch_branch_pc_i,     // Address of the branch target
    input fetch_accept_i,               // Signal indicating if the decode unit is ready to accept data
     input fetch_invalidate_i,           // Signal from the decode unit to invalidate the current fetched instruction

    input icache_accept_i,              // Signal indicating if the icache unit is ready to accept data
    input icache_valid_i,               // Signal indicating a valid instruction from icache
    input [31:0] icache_inst_i,         // The instruction fetched by the icache
    input icache_error_i,               // Signal indicating an icache error

    output reg fetch_valid_o=0,           // Valid instruction and PC signal for decode unit
    output reg [31:0] fetch_instr_o=0,    // The fetched instruction
    output reg [31:0] fetch_pc_o=0,       // The PC of the fetched instruction

    output reg icache_rd_o=0,             // Read request to icache (used for branches)
    output reg icache_flush_o=0,          // Signal to flush the icache

    output icache_invalidate_o,         // Unused in this module
    output reg [31:0] icache_pc_o=0       // PC for the next instruction fetch
);

    parameter INST_ERR = 32'h53;        // Hardcoded ERROR instruction
    parameter SETUP_Icache = 1'b0;      // FSM state
    parameter WAIT_Icache = 1'b1;       // FSM state

    parameter SETUP_fetchUnit = 2'b00;  // FSM state
    parameter WAIT_fetchUnit = 2'b01;   // FSM state
    parameter FINAL_fetchUnit = 2'b10;  // FSM state

    wire stall;                          // Stall signal (1 = stall, 0 = no stall)
   
    reg state_req_signal;               // FSM control for fetch_valid_o
    reg [1:0] state_valid_signal;       // FSM control for icache_rd_o
    reg [31:0] CurrentInstruction;      // Holds the last instruction sent out
    reg [31:0] CurrentPC;               // Holds the last PC sent out

    assign icache_invalidate_o = 1'b0;  // Not needed in module



    reg [1:0] state;
    parameter FETCH_DATA = 2'b01;
    parameter WAIT_CACHE_RESPONSE = 2'b10;
    /* 
        FETCH MODULE WORKING 

        1)If decoder is ready to accept data ,
                a) If branch is needed , icache_pc_o is changed otherwise PC+4
                b) Issue a Read request 
        2)Wait for response from cache ,
                a) Wait until icache_valid comes 
                b) assign the current icache_pc_o and icache_inst_i to fetch_pc_o and fetch_inst_o
                c) increment NextPC value to icache_pc_o + 4
                d) make fetch_valid_o as high (indicating decode unit , new instruction is ready)
        3)On receiving fetch_valid_o , decoder becomes busy and we use this condition to make 
            fetch_valid_o to zero 
    */
    reg [31:0] nextPC,branchAddress;
    reg branch_acknowledged,branch_action_needed;
    always@(posedge clk_i)begin
        if(rst_i)begin
            icache_rd_o <= 0;
            icache_pc_o <= 32'd0;
            fetch_valid_o <= 0;
            nextPC <= 32'd4;
            fetch_pc_o <= 0;
            fetch_instr_o <= 0;
            branch_acknowledged <=1'b0;
            state <= FETCH_DATA;
        end
        else if(fetch_accept_i == 1'b1 & fetch_valid_o==1'b0)begin
            case(state)
                    FETCH_DATA : begin
                        if(branch_action_needed==1'b1)begin
                            icache_pc_o <= branchAddress;
                            branch_acknowledged <=1'b1;
                        end
                        else begin
                            icache_pc_o <=nextPC;
                            branch_acknowledged <=1'b0;
                        end
                        icache_rd_o <=1'b1;
                        state <= WAIT_CACHE_RESPONSE;
                    end
                    WAIT_CACHE_RESPONSE : begin
                        branch_acknowledged <=1'b0;
                        if(icache_valid_i==1'b1)begin
                            state<=FETCH_DATA;
                            icache_rd_o<=1'b0;
                            if(icache_error_i==1'b1)begin
                                fetch_pc_o <=icache_pc_o;
                                fetch_instr_o<=INST_ERR;
                            end
                            else begin
                                fetch_pc_o <=icache_pc_o;
                                fetch_instr_o<=icache_inst_i;
                            end
                            nextPC<=icache_pc_o+4;
                            fetch_valid_o <=1'b1;
                        end
                    end
            endcase
            end
            else 
                fetch_valid_o = 1'b0;
        end

    
    always@(posedge clk_i)begin
        if(rst_i)begin
            branch_action_needed <=1'b0;
            branchAddress <=0;
        end
        else if(fetch_branch_i==1'b1 & branch_acknowledged ==1'b0)begin
            branch_action_needed <=1'b1;
            branchAddress <=fetch_branch_pc_i;
        end
        else if(branch_acknowledged == 1'b1)
            branch_action_needed <=1'b0;
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            icache_flush_o <= 1'b0;
        end
        else if (fetch_invalidate_i == 1'b1) begin
            icache_flush_o <= 1'b1;
        end
        else begin
            icache_flush_o <= 1'b0;
        end
    end

    // always @(posedge clk_i) begin
    //     if(rst_i)begin
    //         icache_pc_o <= 0;
    //     end
    //     else begin
    //         if(fetch_branch_i==1'b1)
    //             icache_pc_o <= fetch_branch_pc_i;
    //         else if(fetch_accept_i == 1'b1)
    //             icache_pc_o <= icache_pc_o + 4 ;
    //     end        
    // end

    // always @(posedge clk_i ) begin
    //     if(rst_i) begin
    //         fetch_valid_o <= 1'b0;
    //         fetch_pc_o <= 32'b0;
    //         CurrentPC <= 32'b0;
    //         fetch_instr_o <= 32'b0;
    //         CurrentInstruction <= 32'b0;
    //     end
    //     else begin
    //         if(fetch_branch_i==1'b0 & icache_valid_i == 1'b1)begin
    //             fetch_valid_o <= 1'b1;
    //             if(fetch_accept_i==1'b1)

    //             begin
    //                 fetch_pc_o <= icache_pc_o;
    //                 CurrentPC <= icache_pc_o;

    //                 if (icache_error_i == 1'b1) begin
    //                     fetch_instr_o <= INST_ERR;
    //                 end else begin
    //                     fetch_instr_o <= icache_inst_i;
    //                     CurrentInstruction <= icache_inst_i;
    //                 end 
    //             end

    //             else 
    //                 begin
    //                     fetch_instr_o <= CurrentInstruction;
    //                     fetch_pc_o <= CurrentPC;
    //                 end
    //         end
    //         else begin
    //                 fetch_valid_o <= 1'b0;
    //         end
    //     end
    // end

    // // Initialize fetch_pc_o properly on reset
    // always @(posedge clk_i or posedge rst_i) begin
    //     if (rst_i) begin
    //         icache_pc_o <= 32'h00000000;
    //     end
    //     else if (stall == 1'b0) begin
    //             if (fetch_branch_i == 1'b1) begin
    //                 icache_pc_o <= fetch_branch_pc_i;
    //              end
    //             else  begin
    //                  icache_pc_o <= icache_pc_o + 4;
    //             end
    //     end else
    //             icache_rd_o <=1'b0;
    // end

    // always @(posedge clk_i or posedge rst_i) begin
    //     if (rst_i) begin
    //         icache_rd_o <=1'b0;
    //     end
    //     else if (fetch_accept_i == 1'b1 | icache_accept_i ==1'b1) begin
    //             icache_rd_o <=1'b1;
    //     end else
    //             icache_rd_o <=1'b0;
    // end

endmodule
