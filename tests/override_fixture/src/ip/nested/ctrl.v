module ctrl(input wire clk, output wire q);
  fifo u_fifo (.clk(clk), .q(q));
endmodule
