// This project-specific implementation must remain byte-for-byte unchanged.
module PROJA_fifo(input wire clk, output wire q);
  assign q = ~clk;
endmodule
