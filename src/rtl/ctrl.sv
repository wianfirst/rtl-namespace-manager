// ============================================================
// PROJA ctrl - original Perforce RTL (never modified by tool)
// 'fifo' below is a module instantiation -> PROJA__fifo
// 'fifo_data' is a signal name   -> must NOT change
// 'u_fifo'     is an instance name -> must NOT change
// ============================================================
module ctrl (
    input logic clk,
    input logic rst_n
);

    // comment: fifo raw name inside comment must not change
    /* block comment also mentions fifo and must not change */
    (* marker = "fifo raw string must not change" *)
    logic [31:0] fifo_data;

    fifo #(
        .WIDTH(32)
    ) u_fifo (
        .clk   (clk),
        .rst_n (rst_n),
        .din   ('0),
        .dout  (fifo_data)
    );

endmodule
