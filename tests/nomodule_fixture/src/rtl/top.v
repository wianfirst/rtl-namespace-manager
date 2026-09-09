module top (
    input  wire       clk,
    input  wire [7:0] din,
    output wire [7:0] dout
);
    fifo #(.WIDTH(8)) u_fifo (
        .clk  (clk),
        .din  (din),
        .dout (dout)
    );
endmodule
