module fifo #(
    parameter WIDTH = 8
)(
    input  wire             clk,
    input  wire [WIDTH-1:0] din,
    output wire [WIDTH-1:0] dout
);
    assign dout = din;
endmodule
