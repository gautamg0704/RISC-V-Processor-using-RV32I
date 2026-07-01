module gpio_interrupt (
    input wire clk_i,
    input wire rst_i,
    input wire [31:0] gpio_input_i,
    input wire [31:0] gpio_int_mask_i,
    input wire [31:0] gpio_int_level_i,  // Interrupt Level Configuration
    input wire [31:0] gpio_int_set_i,
    input wire [31:0] gpio_int_clr_i,
    input wire [31:0] gpio_int_mode_i,   // Interrupt Mode: 1 = Edge, 0 = Level
    output reg [31:0] gpio_int_status_o,
    output reg intr_o
);
    // Previous state storage for edge detection
    reg [31:0] gpio_input_prev_q;
    reg [31:0] edge_detect;
    reg [31:0] level_detect;
    reg [31:0] interrupt_detect;

    // Edge and Level Detection Logic
    
    
    // MODIFIED FROM HERE ***** by Bitstream Builders//
    
    // MODIFICATION PART 1 START//

    
    wire [31:0] falling_edge = (~gpio_input_i & gpio_input_prev_q);
    wire [31:0] rising_edge = (gpio_input_i & ~gpio_input_prev_q);

    wire [31:0] raw_level = (~gpio_input_i ^ gpio_int_level_i ) & ~(gpio_int_mode_i);
    wire [31:0] raw_mode = (gpio_int_level_i ? rising_edge : falling_edge) & (gpio_int_mode_i);

    wire [31:0] raw_status = raw_mode | raw_level;
    reg [31:0] interrupt_raw_status_reg;
    reg [31:0] interrupt_raw_status_update;
    reg intr_o_update;
    
    
   always @ (posedge clk_i or posedge rst_i ) begin
    if (rst_i)
    gpio_input_prev_q  <= 32'b0;
        else
    gpio_input_prev_q  <= gpio_input_i;
    
    end
    
    always @(*) begin
            interrupt_raw_status_update = raw_status;
        if (|gpio_int_clr_i) 
            interrupt_raw_status_update =  interrupt_raw_status_update & ~ gpio_int_clr_i;

        if (|gpio_int_set_i)
            interrupt_raw_status_update = interrupt_raw_status_update | gpio_int_set_i; 
    
    end
  
  // MODIFICATION PART 1 END//
  
    
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            gpio_int_status_o <= 32'b0;
//            gpio_input_prev_q <= 32'b0;
            edge_detect <= 32'b0;
            level_detect <= 32'b0;
            interrupt_detect <= 32'b0;
//            intr_sub_o <= 1'b0;
        end else begin
//            // Edge detection: XOR to detect state change, masked by interrupt enable
//            edge_detect <= (gpio_input_i ^ gpio_input_prev_q) & gpio_int_mask_i;
            
//            // Level detection: Active-High or Active-Low based on gpio_int_level_i
//            level_detect <= gpio_int_mask_i & 
//                           ((gpio_input_i & gpio_int_level_i) | (~gpio_input_i & ~gpio_int_level_i));
            
//            // Combine detection based on GPIO_INT_MODE (1 = Edge, 0 = Level)
//            interrupt_detect <= (edge_detect & gpio_int_mode_i) | 
//                                (level_detect & ~gpio_int_mode_i);
            
//            // Combined interrupt status with set/clear 
//            gpio_int_status_o <= (gpio_int_status_o | interrupt_detect | gpio_int_set_i) & ~gpio_int_clr_i;
            
//            // Global interrupt
//            intr_o <= |gpio_int_status_o;
            
//            // Store previous input state 
//            gpio_input_prev_q <= gpio_input_i;
       
    //   Above Commented part is the OG part ******   
      // MODIFICATION PART 2 START//    
                
    interrupt_raw_status_reg  <= interrupt_raw_status_update;
    intr_o_update <= |(interrupt_raw_status_reg & gpio_int_mask_i);
    gpio_int_status_o <= interrupt_raw_status_reg;
    
      // MODIFICATION PART 2 END//
    
    
        end
      end  

      // MODIFICATION PART 3 START//  
      
      
       always @(posedge clk_i)
        intr_o <= intr_o_update;

      // MODIFICATION PART 3 END//
endmodule
