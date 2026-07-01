module bkadd(
  input [31:0] a,b,
  input cin,
  output [31:0] s,
  output cout);
  
  wire [31:0] p0,g0; //g0 p0 means only g0 p0
  wire [31:0] c; //carries from each level used to evaluate sum
  wire [15:0] g1,p1; //g1 p1 means g2i+1:2i p2i+1,2i
  wire [7:0] g2,p2; //g2 p2 means g4i+3:4i p4i+3:4i
  wire [3:0] g3,p3; //g3 p3 means g8i+7:8i p8i+7:8i
  wire [1:0] g4,p4; //g4 p4 means g16i+15:16i p16i+15:16i
  wire g5,p5; //simply g31;0 and p31:0
  
  //level 0 p&G
  assign p0 = a ^ b;
  assign g0 = a & b;
  
  genvar i;
  generate //level 1 p&G
    for(i=0; i<=15; i=i+1) begin:l1
      assign g1[i] = g0[2*i+1] | (p0[2*i+1] & g0[2*i]);
      assign p1[i] = p0[2*i+1] & p0[2*i];
    end
  endgenerate
  
  generate //level 2 p&G
    for(i=0; i<=7; i=i+1) begin:l2
     assign g2[i] = g1[2*i+1] | (p1[2*i+1] & g1[2*i]);
     assign p2[i] = p1[2*i+1] & p1[2*i];
    end
  endgenerate
  
  generate //level 3 p&G
    for(i=0; i<=3; i=i+1) begin:l3
     assign g3[i] = g2[2*i+1] | (p2[2*i+1] & g2[2*i]);
     assign p3[i] = p2[2*i+1] & p2[2*i];
    end
  endgenerate
  
  generate //level 4 p&G
    for(i=0; i<=1; i=i+1) begin:l4
     assign g4[i] = g3[2*i+1] | (p3[2*i+1] & g3[2*i]);
     assign p4[i] = p3[2*i+1] & p3[2*i];
    end
  endgenerate
  
  //level 5 p&G
  assign g5 = g4[1] | (p4[1] & g4[0]);
  assign p5 = p4[1] & p4[0];
  
  //carry generation
  
  assign c[0] = g0[0] | (p0[0] & cin);
  assign c[1] = g1[0] | (p1[0] & cin);
  assign c[3] = g2[0] | (p2[0] & cin);
  assign c[7] = g3[0] | (p3[0] & cin);
  assign c[15] = g4[0] | (p4[0] & cin);
  assign c[31] = g5 | (p5 & cin);
  
  assign c[2] = g0[2] | (p0[2] & c[1]);
  
  assign c[4] = g0[4] | (p0[4] & c[3]);
  assign c[5] = g1[2] | (p1[2] & c[3]);
  assign c[6] = g0[6] | (p0[6] & c[5]);
  
  assign c[8] = g0[8] | (p0[8] & c[7]);
  assign c[9] = g1[4] | (p1[4] & c[7]);
  assign c[10] = g0[10] | (p0[10] & c[9]);
  assign c[11] = g2[2] | (p2[2] & c[7]);
  assign c[12] = g0[12] | (p0[12] & c[11]);
  assign c[13] = g1[6] | (p1[6] & c[11]);
  assign c[14] = g0[14] | (p0[14] & c[13]);

  assign c[16] = g0[16] | (p0[16] & c[15]);
  assign c[17] = g1[8] | (p1[8] & c[15]);
  assign c[18] = g0[18] | (p0[18] & c[17]);
  assign c[19] = g2[4] | (p2[4] & c[15]);
  
  assign c[20] = g0[20] | (p0[20] & c[19]);
  assign c[21] = g1[10] | (p1[10] & c[19]);
  assign c[22] = g0[22] | (p0[22] & c[21]);
  assign c[23] = g3[2] | (p3[2] & c[15]);
  assign c[24] = g0[24] | (p0[24] & c[23]);
  assign c[25] = g1[12] | (p1[12] & c[23]);
  assign c[26] = g0[26] | (p0[26] & c[25]);
  assign c[27] = g2[6] | (p2[6] & c[23]);
  assign c[28] = g0[28] | (p0[28] & c[27]);
  assign c[29] = g1[14] | (p1[14] & c[27]);
  assign c[30] = g0[30] | (p0[30] & c[29]);
  
  
  assign s = p0 ^ {c[30:0],cin}; //final sum/sub
  assign cout = c[31]; //carry out

endmodule