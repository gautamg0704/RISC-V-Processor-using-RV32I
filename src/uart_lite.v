`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.03.2025 03:44:32
// Design Name: 
// Module Name: uart_lite
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_lite (
    input           clk_i,
    input           rst_i,
     // AXI-Lite Configuration Inputs
    input           cfg_awvalid_i,
    input  [31:0]   cfg_awaddr_i,
    input           cfg_wvalid_i,
    input  [31:0]   cfg_wdata_i,
    input  [3:0]    cfg_wstrb_i,
    input           cfg_bready_i,
    input           cfg_arvalid_i,
    input  [31:0]   cfg_araddr_i,
    input           cfg_rready_i,
    // UART Serial Input
 
    input           rx_i,
    // AXI-Lite Configuration Outputs
 
    output reg        cfg_awready_o,
    output reg        cfg_wready_o,
    output reg        cfg_bvalid_o,
    output      [1:0] cfg_bresp_o,
    output reg        cfg_arready_o,
    output reg        cfg_rvalid_o,
    output reg [31:0] cfg_rdata_o,
    output      [1:0] cfg_rresp_o,
    // UART Serial Output
    output reg        tx_o,
    output reg        intr_o
);
 
  // Internal Registers and Wires
 
  // Data registers for RX and TX
 
  reg [7:0]  ulite_rx_reg;        // Holds received data
  reg [7:0]  ulite_tx_reg;        // Holds data to be transmitted
  reg [4:0]  ulite_status_reg;    // Holds status bits
  reg [4:0]  ulite_control_reg;   // Holds control bits
  // Define Control Bit Fields
 
  `define ULITE_CONTROL_IE       4
  `define ULITE_CONTROL_RST_RX   1
  `define ULITE_CONTROL_RST_TX   0
  // Define Status Bit Fields
 
  `define ULITE_STATUS_IE        4
  `define ULITE_STATUS_TXFULL    3
  `define ULITE_STATUS_TXEMPTY   2
  `define ULITE_STATUS_RXFULL    1
  `define ULITE_STATUS_RXVALID   0
  // Define Address Mapping
 
  `define ULITE_RX       8'h00
  `define ULITE_TX       8'h04
  `define ULITE_STATUS   8'h08
  `define ULITE_CONTROL  8'h0C
  reg [2:0] tindex;
  reg       tcount;  
  reg [2:0] rindex;
  reg       rcount;
  reg txdone;
  reg rxdone;
  reg read_flag;
  assign cfg_bresp_o = 2'b00; // Always OK response
  assign cfg_rresp_o = 2'b00; // Always OK response
   wire baud_clk;
  // UART TX Shifting Process (operates on baud_clk)
 
  always @(posedge baud_clk) begin
   if (rst_i) begin
    tx_o <= 1;
    tindex <= 3'd7;
    tcount <= 1'b0;
    txdone <= 1'b0;
   end
 
   else if (ulite_status_reg[`ULITE_STATUS_TXEMPTY] == 1'b0) begin
 
      // Transmission in progress
      if (tcount == 1'b0) begin
        tx_o   <= 1'b0;    // Send start bit (logic 0)
        tcount <= 1'b1;
      end
      else begin
        tx_o   <= ulite_tx_reg[tindex]; // Transmit data bit (MSB first)
        if (tindex == 3'd0) begin
 
          // When the last bit is transmitted, finish transmission:
          txdone <= 1'b1;
          tindex <= 3'd7;
          tcount <= 1'b0;
        end
        else begin
          tindex <= tindex - 1;
        end
      end
    end
    else begin
      tx_o   <= 1'b1; //stop bit and maintains 1
      txdone <= 1'b0;
      tindex <= 3'd7;
      tcount <= 1'b0;
    end
  //end
  // UART RX Sampling Process (operates on baud_clk)
  //always @(posedge baud_clk) begin
  if (cfg_wdata_i[1])
            ulite_rx_reg <= 8'b0;  // Reset RX FIFO
          else
            ulite_rx_reg <= ulite_rx_reg;
  if (rst_i) begin
        rcount                        <= 1'b0;
        rindex                        <= 3'd7;
        ulite_rx_reg                  <= 8'b0;
        rxdone                        <= 1'b0;
   end
   else begin
      if (rx_i != 1'b1 && rcount == 1'b0) begin
 
        // Detect start bit (rx_i goes low)
        rcount <= 1'b1;
      end
      else if (rcount == 1'b1 && rindex > 0) begin
        ulite_rx_reg[rindex] <= rx_i;
        rindex <= rindex - 1;
      end
      else if (rindex == 3'd0) begin
        ulite_rx_reg[rindex] <= rx_i;
        rcount <= 1'b0;
        rindex <= 3'd7;
        rxdone <= 1'b1;
      end
      else begin
        rcount <= 1'b0;
        rindex <= 3'd7;
        rxdone <= 1'b0;
      end
    end
  end
  // AXI-Lite Write TX Buffer
 
  always @(posedge clk_i) begin
    if (rst_i) begin
      //ulite_rx_reg             <= 8'b0;
      ulite_tx_reg             <= 8'b0;
      ulite_status_reg         <= 5'b00100;
      ulite_control_reg        <= 5'b00000;
      cfg_awready_o            <= 1'b0;
      cfg_wready_o             <= 1'b0;
      cfg_bvalid_o             <= 1'b0;
      //tx_o                          <= 1;      // Idle state is high
      //tindex                        <= 3'd7;
      //tcount                        <= 1'b0;
     // ulite_status_reg[`ULITE_STATUS_TXEMPTY] <= 1; // Mark transmitter as idle
      //ulite_status_reg[`ULITE_STATUS_TXFULL]  <= 0;
      //rcount                        <= 1'b0;
      //rindex                        <= 3'd7;
      //ulite_rx_reg                  <= 8'b0;
      //ulite_status_reg[`ULITE_STATUS_RXFULL]  <= 0;
      //ulite_status_reg[`ULITE_STATUS_RXVALID] <= 0;
    end
    else if (cfg_awvalid_i && cfg_wvalid_i) begin
      case (cfg_awaddr_i[7:0])
 
        `ULITE_TX: begin
 
          // Accept new TX data only if transmitter is idle.
 
          if (ulite_status_reg[`ULITE_STATUS_TXEMPTY] == 1'b1) begin 
            cfg_awready_o <= 1'b1;
            cfg_wready_o  <= 1'b1;
            ulite_tx_reg  <= cfg_wdata_i[7:0];    // Latch TX data
            ulite_status_reg[`ULITE_STATUS_TXEMPTY] <= 1'b0; // Mark TX as busy
            ulite_status_reg[`ULITE_STATUS_TXFULL]  <= 1'b1;
          end
          else begin
            cfg_awready_o <= 1'b0;
            cfg_wready_o  <= 1'b0;
          end
        end
 
        `ULITE_CONTROL: begin
          cfg_awready_o <= 1'b1;
          cfg_wready_o  <= 1'b1;
          ulite_control_reg[`ULITE_CONTROL_IE]     <= cfg_wdata_i[4];
          ulite_control_reg[`ULITE_CONTROL_RST_RX] <= cfg_wdata_i[1];
          ulite_control_reg[`ULITE_CONTROL_RST_TX] <= cfg_wdata_i[0];
          if (cfg_wdata_i[4])
            ulite_status_reg[`ULITE_STATUS_IE] <= 1;
          else
            ulite_status_reg[`ULITE_STATUS_IE] <= 0;
          // Reset logic:
//          if (cfg_wdata_i[1])
//            ulite_rx_reg <= 8'b0;  // Reset RX FIFO
//          else
//            ulite_rx_reg <= ulite_rx_reg;
          if (cfg_wdata_i[0]) begin
            ulite_tx_reg <= 8'b0;  // Reset TX FIFO
            ulite_status_reg[`ULITE_STATUS_TXEMPTY] <= 1;
            ulite_status_reg[`ULITE_STATUS_TXFULL]  <= 0;
            //tindex <= 3'd7;
            //tcount <= 1'b0;
          end
          else begin
            ulite_tx_reg <= ulite_tx_reg;  // Reset TX FIFO
          end
        end
        default: begin
          cfg_awready_o <= 1'b0;
          cfg_wready_o  <= 1'b0;
          cfg_bvalid_o  <= 1'b0;
        end
      endcase
      if (cfg_bready_i == 1'b1)
        cfg_bvalid_o <= 1'b1;
      else
         cfg_bvalid_o <= 1'b0;
    end
    else if (txdone) begin   //tx is done transmitting updating the status flags
        ulite_status_reg[`ULITE_STATUS_TXEMPTY] <= 1; // Mark as idle
        ulite_status_reg[`ULITE_STATUS_TXFULL]  <= 0;
    end
    else begin
      cfg_awready_o <= 1'b0;
      cfg_wready_o  <= 1'b0;
      cfg_bvalid_o  <= 1'b0;
    end
// end
 
  // AXI-Lite Read RX Buffer
  //always @(posedge clk_i) begin
    if (rst_i) begin
      cfg_rvalid_o   <= 1'b0;
      cfg_rdata_o    <= 32'b0;
      cfg_arready_o  <= 1'b0;
      intr_o <= 1'b0;
      read_flag <= 1'b0;
    end
    else if (cfg_arvalid_i) begin
      cfg_arready_o <= 1'b1; // Always ready for a read address
      case (cfg_araddr_i[7:0])
 
        `ULITE_RX: begin
          if (cfg_rready_i == 1'b1 && ulite_status_reg[`ULITE_STATUS_RXFULL] == 1'b1) begin
            cfg_rvalid_o <= 1'b1;
            cfg_rdata_o  <= {24'b0, ulite_rx_reg}; // Read RX data
            ulite_status_reg[`ULITE_STATUS_RXFULL]  <= 1'b0;
            ulite_status_reg[`ULITE_STATUS_RXVALID] <= 1'b0;
            intr_o <= 1'b0;
            read_flag <= 1'b1;
          end
          else begin
            cfg_rvalid_o <= 1'b0;
          end
        end
 
        `ULITE_STATUS: begin
          if (cfg_rready_i == 1'b1) begin
            cfg_rvalid_o <= 1'b1;
            cfg_rdata_o  <= {24'b0, ulite_status_reg}; // Read Status register
          end
          else begin
            cfg_rvalid_o <= 1'b0;
          end
        end
 
        `ULITE_CONTROL: begin
          if (cfg_rready_i == 1'b1) begin
            cfg_rvalid_o <= 1'b1;
            cfg_rdata_o  <= {27'b0, ulite_control_reg}; // Read Control register
          end
          else begin
            cfg_rvalid_o <= 1'b0;
          end
        end
        default: begin
          cfg_rdata_o  <= 32'b0;
        end
      endcase
    end
    else if (rxdone && !(read_flag)) begin
        ulite_status_reg[`ULITE_STATUS_RXFULL]  <= 1;
        ulite_status_reg[`ULITE_STATUS_RXVALID] <= 1;
        if (ulite_status_reg[`ULITE_STATUS_IE] == 1'b1)
             intr_o <= 1'b1;
        else
           intr_o <= 1'b0;
    end
    else if(!(rxdone)) 
        read_flag <= 1'b0;
    else begin
      cfg_rvalid_o  <= 1'b0;
      cfg_rdata_o   <= 32'b0;
      cfg_arready_o <= 1'b0;
      intr_o <= 1'b0;
    end
  end
  
 baud_rate_gen #(
    .SYSTEM_CLK_FREQ(50_000_000),
    .OUT_CLK_FREQ(115200)
  ) u_baud (
    .clk(clk_i),
    .out_clk(baud_clk)
  );
endmodule