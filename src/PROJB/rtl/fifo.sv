// ============================================================
// PROJB fifo - original Perforce RTL (never modified by tool)
// ============================================================
module fifo #(
    parameter WIDTH = 64
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout
);

    assign dout = din;

endmodule
