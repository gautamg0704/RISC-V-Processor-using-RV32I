`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.04.2025 19:28:57
// Design Name: 
// Module Name: start_state
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
 
 
module start_state(
     output reg          inport_awvalid_i
    ,output reg[ 31:0]  inport_awaddr_i
    ,output reg          inport_wvalid_i
    ,output reg [ 31:0]  inport_wdata_i
    ,output reg [  3:0]  inport_wstrb_i
    ,output reg          inport_bready_i
    ,output reg          inport_arvalid_i
    ,output reg [ 31:0]  inport_araddr_i
    ,output reg          inport_rready_i
    ,output reg [3:0] bid,rid
    ,output reg [31:0] reset_vector
   
    ,input          clk
    ,input          rst
    ,input          inport_awready_o
    ,input          inport_wready_o
    ,input          inport_bvalid_o
    ,input [  1:0]  inport_bresp_o
    ,input          inport_arready_o
    ,input          inport_rvalid_o
    ,input [ 31:0]  inport_rdata_o
    ,input [  1:0]  inport_rresp_o
    );

    always@(posedge clk)
    begin
        if(rst)
        begin
        inport_awvalid_i <= 0;
        inport_awaddr_i <= 0;
        inport_wvalid_i <= 0;
        inport_wdata_i  <= 0;
        inport_wstrb_i  <= 0;
        inport_bready_i <= 0;
        inport_arvalid_i <= 0;
        inport_araddr_i <= 0;
        inport_rready_i <= 0;
        reset_vector <=0;
        bid <= 4'h4;
        rid <= 4'h8;
 
        end

    end
endmodule