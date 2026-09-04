// ============================================================
// PROJA fifo - original Perforce RTL (never modified by tool)
// raw module name 'fifo' must only be renamed in generated copy
// ============================================================
module fifo #(
    parameter WIDTH = 32
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout
);

    assign dout = din;

endmodule
