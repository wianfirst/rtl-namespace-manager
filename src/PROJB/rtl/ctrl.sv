// ============================================================
// PROJB ctrl - original Perforce RTL (never modified by tool)
// ============================================================
module ctrl (
    input logic clk,
    input logic rst_n
);

    // comment: fifo raw name inside comment must not change
    (* marker = "fifo raw string must not change" *)
    logic [63:0] fifo_data;

    fifo #(
        .WIDTH(64)
    ) u_fifo (
        .clk   (clk),
        .rst_n (rst_n),
        .din   ('0),
        .dout  (fifo_data)
    );

endmodule
