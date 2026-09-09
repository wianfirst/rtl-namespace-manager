// RTL helper header stored with a .v extension: only `define text,
// no module declarations (content is like a .vh file).
`ifndef RTL_DEFS_V
`define RTL_DEFS_V
`define RTL_WORD_WIDTH     32
`define RTL_FIFO_DEPTH_DFLT 8
`define RTL_BUS(A,B)  A [B-1:0]
`endif
