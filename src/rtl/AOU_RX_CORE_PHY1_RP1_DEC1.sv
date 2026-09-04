// *****************************************************************************
// SPDX-License-Identifier: Apache-2.0
// *****************************************************************************
//  Copyright (c) 2026 BOS Semiconductors
//  Copyright (c) 2026 Tenstorrent USA Inc
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
// *****************************************************************************
//
//  Module     : AOU_RX_CORE (Simplified)
//  Original   : AOU_RX_CORE.sv  Version 1.00  Date 26-02-26
//  Derived    : 2026-08-04
//
//  Description:
//    This is a parameter-fixed simplification of AOU_RX_CORE.
//    Hard-coded configuration: PHY_TYPE=1 (64B), RP_COUNT=1, DEC_MULTI=1.
//    All generate branches for other PHY_TYPE / RP_COUNT / DEC_MULTI values
//    have been removed.  The module is functionally equivalent to the original
//    when the original is instantiated with those parameter values.
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_RX_CORE_PHY1_RP1_DEC1
import packet_def_pkg::*;
#(
    // ---- Fixed configuration ----
    localparam  PHY_TYPE                    = 1,     // 64B single-PHY
    localparam  FDI_IF_WD                   = 512,
    localparam  PHASE_CNT                   = 256*8 / FDI_IF_WD,       // = 4
    localparam  PHASE_CNT_WD                = (PHASE_CNT == 1) ? 1 : $clog2(PHASE_CNT), // = 2
    localparam  DEC_MULTI                   = 1,

    // ---- Remaining parameters (same as original) ----
    parameter   AXI_PEER_DIE_MAX_DATA_WD    = 1024,
    parameter   AXI_ADDR_WD                 = 64,
    parameter   AXI_ID_WD                   = 10,
    parameter   AXI_LEN_WD                  = 8,
    localparam  AXI_STRB_WD                 = AXI_PEER_DIE_MAX_DATA_WD / 8,

    parameter   MAX_MISC_COUNT_CHUNK        = 2,
    parameter   MAX_REQ_COUNT_CHUNK         = 4,
    parameter   MAX_DATA_COUNT_CHUNK        = 2,
    parameter   MAX_WR_RESP_COUNT_CHUNK     = 12,

    localparam  MAX_MISC_COUNT_WD           = $clog2(MAX_MISC_COUNT_CHUNK + 1),
    localparam  MAX_REQ_COUNT_WD            = $clog2(MAX_REQ_COUNT_CHUNK + 1),
    localparam  MAX_DATA_COUNT_WD           = $clog2(MAX_DATA_COUNT_CHUNK + 1),
    localparam  MAX_WR_RESP_COUNT_WD        = $clog2(MAX_WR_RESP_COUNT_CHUNK + 1),

    localparam  MAX_MISC_WD                 = $clog2(MAX_MISC_COUNT_CHUNK),
    localparam  MAX_REQ_WD                  = $clog2(MAX_REQ_COUNT_CHUNK),
    localparam  MAX_DATA_WD                 = $clog2(MAX_DATA_COUNT_CHUNK),
    localparam  MAX_WR_RESP_WD              = $clog2(MAX_WR_RESP_COUNT_CHUNK),

    parameter   DATA_DEC_CNT                = 4,
    localparam  RP_COUNT                    = 1,     // single RP
    parameter   AW_AR_FIFO_DATA_WIDTH       = 97,
    parameter   R_FIFO_EXT_DATA_WIDTH       = 15,
    parameter   B_FIFO_DATA_WIDTH           = 12
)
(
    input                                                                                       I_CLK,
    input                                                                                       I_RESETN,

    input                                                                                       I_FDI_PL_VALID,
    input   [FDI_IF_WD-1: 0]                                                                    I_FDI_PL_DATA,
    input                                                                                       I_FDI_PL_FLIT_CANCEL,

    // ---- Flattened outputs (RP_COUNT=1, DEC_MULTI=1) ----
    output  [MAX_REQ_COUNT_CHUNK-1:0][AW_AR_FIFO_DATA_WIDTH-1:0]                                O_RD_REQ_FIFO_SDATA,
    output  [MAX_REQ_COUNT_CHUNK-1:0]                                                           O_RD_REQ_FIFO_SVALID,

    output  [MAX_REQ_COUNT_CHUNK-1:0][AW_AR_FIFO_DATA_WIDTH-1:0]                                O_WR_REQ_FIFO_SDATA,
    output  [MAX_REQ_COUNT_CHUNK-1:0]                                                           O_WR_REQ_FIFO_SVALID,

    output  [DATA_DEC_CNT-1:0][AXI_PEER_DIE_MAX_DATA_WD-1:0]                                   O_WR_DATA_FIFO_SDATA,
    output  [DATA_DEC_CNT-1:0][AXI_STRB_WD-1:0]                                                O_WR_DATA_FIFO_SDATA_STRB,
    output  [DATA_DEC_CNT-1:0]                                                                  O_WR_DATA_FIFO_SDATA_WDATAF,
    output  [DATA_DEC_CNT-1:0]                                                                  O_WR_DATA_FIFO_SVALID,

    output  [MAX_WR_RESP_COUNT_CHUNK-1:0][B_FIFO_DATA_WIDTH-1:0]                                O_WR_RESP_FIFO_SDATA,
    output  [MAX_WR_RESP_COUNT_CHUNK-1:0]                                                       O_WR_RESP_FIFO_SVALID,

    output  [DATA_DEC_CNT-1:0][AXI_PEER_DIE_MAX_DATA_WD-1:0]                                   O_RD_DATA_FIFO_SDATA,
    output  [DATA_DEC_CNT-1:0][R_FIFO_EXT_DATA_WIDTH-1:0]                                      O_RD_DATA_FIFO_EXT_SDATA,
    output  [DATA_DEC_CNT-1:0]                                                                  O_RD_DATA_FIFO_SVALID,

    // ---- Credit grant outputs (DEC_MULTI=1, single-element) ----
    output  [MAX_MISC_COUNT_CHUNK-1:0][1:0]                                                     O_CRDTGRANT_WRESPCRED3,
    output  [MAX_MISC_COUNT_CHUNK-1:0][1:0]                                                     O_CRDTGRANT_WRESPCRED2,
    output  [MAX_MISC_COUNT_CHUNK-1:0][1:0]                                                     O_CRDTGRANT_WRESPCRED1,
    output  [MAX_MISC_COUNT_CHUNK-1:0][1:0]                                                     O_CRDTGRANT_WRESPCRED0,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_RDATACRED3,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_RDATACRED2,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_RDATACRED1,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_RDATACRED0,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_WDATACRED3,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_WDATACRED2,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_WDATACRED1,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_WDATACRED0,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_RREQCRED3,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_RREQCRED2,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_RREQCRED1,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_RREQCRED0,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_WREQCRED3,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_WREQCRED2,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_WREQCRED1,
    output  [MAX_MISC_COUNT_CHUNK-1:0][2:0]                                                     O_CRDTGRANT_WREQCRED0,
    output  [MAX_MISC_COUNT_CHUNK-1:0]                                                          O_CRDTGRANT_VALID,

    output  [1:0]                                                                               O_MSGCRDT_WRESPCRED,
    output  [2:0]                                                                               O_MSGCRDT_RDATACRED,
    output  [2:0]                                                                               O_MSGCRDT_WDATACRED,
    output  [2:0]                                                                               O_MSGCRDT_RREQCRED,
    output  [2:0]                                                                               O_MSGCRDT_WREQCRED,
    output  [1:0]                                                                               O_MSGCRDT_RP,
    output                                                                                      O_MSGCRDT_VALID,

    output  [3:0]                                                                               O_ACTIVATION_OP,
    output                                                                                      O_ACTIVATION_PROP_REQ,
    output                                                                                      O_ACTIVATION_VALID
);
//-----------------------------------------------------------------------
    // Granule storage  (DEC_MULTI=1 → single set of 12 granules per chunk)
    st_g_packet [11:0]                  i_g;
    st_g_packet [11:0]                  zero_g;
    st_g_packet [2:0][11:0]             r_g;
    st_g_packet [(1+3)*12-1:0]          w_g;       // 48 granules = {i_g, r_g[0], r_g[1], r_g[2]}

    logic [FDI_IF_WD-1:0]       w_rx_chunk_data;
    logic                       w_rx_chunk_data_valid;
    logic [11:0]                i_msg_start;        // protocol header (single chunk)

    logic [2:0]                 r_fdi_pl_data_valid;
    logic [PHASE_CNT_WD-1:0]    r_aou_rx_phase;

    st_msg_credit_packet        i_msg_credit;

//-------------------------------------------------------------
    // Per-message-type start indicators (DEC_MULTI=1 → single [11:0])
    logic [11:0]                i_misc_start;
    logic [11:0]                i_write_req_start;
    logic [11:0]                i_read_req_start;
    logic [11:0]                i_write_data_start;
    logic [11:0]                i_read_data_start;
    logic [11:0]                i_write_resp_start;

    // MISC
    logic [MAX_MISC_COUNT_CHUNK-1:0][3:0]    i_misc_idx;
    logic [MAX_MISC_COUNT_CHUNK-1:0]         i_misc_valid;
    logic [MAX_MISC_COUNT_WD-1:0]            i_misc_cnt;
    logic [MAX_MISC_COUNT_WD-1:0]            w_misc_cnt_for_wait;

    logic [MAX_MISC_COUNT_CHUNK-1:0][3:0]    r_misc_idx;
    logic [MAX_MISC_COUNT_CHUNK-1:0]         r_misc_valid;
    logic [MAX_MISC_COUNT_WD-1:0]            r_misc_cnt;
    logic [1:0][MAX_MISC_COUNT_CHUNK-1:0][3:0] w_misc_idx;
    logic [1:0][MAX_MISC_COUNT_CHUNK-1:0]    w_misc_valid;
    logic [1:0][MAX_MISC_COUNT_WD-1:0]       w_misc_cnt;

    // Write request
    logic [MAX_REQ_COUNT_CHUNK-1:0][3:0]     i_write_req_idx;
    logic [MAX_REQ_COUNT_CHUNK-1:0]          i_write_req_valid;
    logic [MAX_REQ_COUNT_WD-1:0]             i_write_req_cnt;
    logic [MAX_REQ_COUNT_WD-1:0]             w_write_req_cnt_for_wait;

    logic [MAX_REQ_COUNT_CHUNK-1:0][3:0]     r_write_req_idx;
    logic [MAX_REQ_COUNT_CHUNK-1:0]          r_write_req_valid;
    logic [MAX_REQ_COUNT_WD-1:0]             r_write_req_cnt;
    logic [1:0][MAX_REQ_COUNT_CHUNK-1:0][3:0] w_write_req_idx;
    logic [1:0][MAX_REQ_COUNT_CHUNK-1:0]     w_write_req_valid;
    logic [1:0][MAX_REQ_COUNT_WD-1:0]        w_write_req_cnt;

    // Read request
    logic [MAX_REQ_COUNT_CHUNK-1:0][3:0]     i_read_req_idx;
    logic [MAX_REQ_COUNT_CHUNK-1:0]          i_read_req_valid;
    logic [MAX_REQ_COUNT_WD-1:0]             i_read_req_cnt;
    logic [MAX_REQ_COUNT_WD-1:0]             w_read_req_cnt_for_wait;

    logic [MAX_REQ_COUNT_CHUNK-1:0][3:0]     r_read_req_idx;
    logic [MAX_REQ_COUNT_CHUNK-1:0]          r_read_req_valid;
    logic [MAX_REQ_COUNT_WD-1:0]             r_read_req_cnt;
    logic [1:0][MAX_REQ_COUNT_CHUNK-1:0][3:0] w_read_req_idx;
    logic [1:0][MAX_REQ_COUNT_CHUNK-1:0]     w_read_req_valid;
    logic [1:0][MAX_REQ_COUNT_WD-1:0]        w_read_req_cnt;

    // Write data
    logic [MAX_DATA_COUNT_CHUNK-1:0][3:0]    i_write_data_idx;
    logic [MAX_DATA_COUNT_CHUNK-1:0]         i_write_data_valid;
    logic [MAX_DATA_COUNT_WD-1:0]            i_write_data_cnt;
    logic [MAX_DATA_COUNT_WD-1:0]            w_write0_data_cnt_m1;
    logic [MAX_DATA_COUNT_WD-1:0]            w_write1_data_cnt_m1;

    logic [2:0][MAX_DATA_COUNT_CHUNK-1:0][3:0]  r_write_data_idx;
    logic [2:0][MAX_DATA_COUNT_CHUNK-1:0]       r_write_data_valid;
    logic [2:0][MAX_DATA_COUNT_WD-1:0]          r_write_data_cnt;

    // w_write_data_* = {i_write_data_*, r_write_data_*[0..2]} → 4 slots (DEC_MULTI+3=4 → [3:0])
    logic [3:0][MAX_DATA_COUNT_CHUNK-1:0][3:0]  w_write_data_idx;
    logic [3:0][MAX_DATA_COUNT_CHUNK-1:0]       w_write_data_valid;
    logic [3:0][MAX_DATA_COUNT_WD-1:0]          w_write_data_cnt;
    logic [3:0][MAX_DATA_COUNT_WD-1:0]          w_valid_write_data_cnt;

    // Read data
    logic [MAX_DATA_COUNT_CHUNK-1:0][3:0]    i_read_data_idx;
    logic [MAX_DATA_COUNT_CHUNK-1:0]         i_read_data_valid;
    logic [MAX_DATA_COUNT_WD-1:0]            i_read_data_cnt;
    logic [MAX_DATA_COUNT_WD-1:0]            w_read0_data_cnt_m1;
    logic [MAX_DATA_COUNT_WD-1:0]            w_read1_data_cnt_m1;

    logic [2:0][MAX_DATA_COUNT_CHUNK-1:0][3:0]  r_read_data_idx;
    logic [2:0][MAX_DATA_COUNT_CHUNK-1:0]       r_read_data_valid;
    logic [2:0][MAX_DATA_COUNT_WD-1:0]          r_read_data_cnt;
    logic [3:0][MAX_DATA_COUNT_CHUNK-1:0][3:0]  w_read_data_idx;
    logic [3:0][MAX_DATA_COUNT_CHUNK-1:0]       w_read_data_valid;
    logic [3:0][MAX_DATA_COUNT_WD-1:0]          w_read_data_cnt;
    logic [3:0][MAX_DATA_COUNT_WD-1:0]          w_valid_read_data_cnt;

    // Write response
    logic [MAX_WR_RESP_COUNT_CHUNK-1:0][3:0] i_write_resp_idx;
    logic [MAX_WR_RESP_COUNT_CHUNK-1:0]      i_write_resp_valid;
    logic [MAX_WR_RESP_COUNT_WD-1:0]         i_write_resp_cnt;

    logic                                   w_write512_data_continue;
    logic                                   w_write1024_data_continue;
    logic                                   w_read512_data_continue;
    logic                                   w_read1024_data_continue;

    logic [2:0]                             wait_valid_chunk;

    logic                                   r_write_data_mask;
    logic                                   r_read_data_mask;

//-------------------------------------------------------------
    // AOU_RX_FDI_IF:  FDI flit  →  chunk  accumulation
    AOU_RX_FDI_IF #(
        .FDI_IF_WD                  ( FDI_IF_WD             )
    ) u_aou_rx_fdi_if
    (
        .I_CLK                      ( I_CLK                 ),
        .I_RESETN                   ( I_RESETN              ),
        .I_FDI_PL_VALID             ( I_FDI_PL_VALID        ),
        .I_FDI_PL_DATA              ( I_FDI_PL_DATA         ),
        .I_FDI_PL_FLIT_CANCEL       ( I_FDI_PL_FLIT_CANCEL  ),
        .O_AOU_RX_CHUNK_DATA        ( w_rx_chunk_data       ),
        .O_AOU_RX_CHUNK_DATA_VALID  ( w_rx_chunk_data_valid )
    );

    // ---- PHY_TYPE=1 (64B): single 12-granule block per chunk ----
    // Granules occupy bytes [2:61] of the 512-bit chunk  (12 × 5 = 60 bytes → 480 bits)
    assign i_g          = w_rx_chunk_data[(0+2)*8 +: 12*5*8];      // 480 bits @ byte offset 2
    assign i_msg_start  = (!r_aou_rx_phase[0])
                        ? w_rx_chunk_data[((0+2+12*5)*8+4) +: 12]  // phase even: msg header in upper part
                        : w_rx_chunk_data[((0)*8+4) +: 12];        // phase odd:  msg header in lower part
    assign i_msg_credit = w_rx_chunk_data[0 +: 16];

//-------------------------------------------------------------
    // r_aou_rx_phase: free-running phase counter (0..PHASE_CNT-1)
    always_ff @(posedge I_CLK or negedge I_RESETN) begin
        if (!I_RESETN) begin
            r_aou_rx_phase <= 'd0;
        end else begin
            if (w_rx_chunk_data_valid)
                r_aou_rx_phase <= r_aou_rx_phase + 1;
        end
    end

    assign zero_g = 'd0;

//-----------------------------------------------------------------------
// Helper functions — same as original, avoid X-injection on [gid] select
//-----------------------------------------------------------------------
    function automatic logic [1:0] f_g_others (input logic [3:0] gid,
                                               input st_g_packet [11:0] chunk_g);
        f_g_others = '0;
        for (int j = 0; j < 12; j++) begin
            if (gid == j[3:0]) f_g_others = chunk_g[j].others;
        end
    endfunction

    function automatic logic [3:0] f_g_msg_type (input logic [3:0] gid,
                                                 input st_g_packet [11:0] chunk_g);
        f_g_msg_type = '0;
        for (int j = 0; j < 12; j++) begin
            if (gid == j[3:0]) f_g_msg_type = chunk_g[j].msg_type;
        end
    endfunction

//-----------------------------------------------------------------------
//  Main state register  (PHY_TYPE=1 → 32_64B path, single decoder)
//-----------------------------------------------------------------------
    always_ff @(posedge I_CLK or negedge I_RESETN) begin
        if (!I_RESETN) begin
            r_fdi_pl_data_valid     <= 'd0;
            r_g                     <= 'd0;

            r_misc_idx              <= 'd0;
            r_misc_valid            <= 'd0;
            r_misc_cnt              <= 'd0;

            r_write_req_idx         <= 'd0;
            r_write_req_valid       <= 'd0;
            r_write_req_cnt         <= 'd0;

            r_read_req_idx          <= 'd0;
            r_read_req_valid        <= 'd0;
            r_read_req_cnt          <= 'd0;

            r_write_data_idx        <= 'd0;
            r_write_data_valid      <= 'd0;
            r_write_data_cnt        <= 'd0;

            r_read_data_idx         <= 'd0;
            r_read_data_valid       <= 'd0;
            r_read_data_cnt         <= 'd0;

            r_write_data_mask       <= 1'b0;
            r_read_data_mask        <= 1'b0;
        end else begin

            if (w_rx_chunk_data_valid) begin
                // ---- Latch current-decoder outputs ----
                r_misc_idx              <= i_misc_idx;
                r_misc_valid            <= i_misc_valid;
                r_misc_cnt              <= i_misc_cnt;

                r_write_req_idx         <= i_write_req_idx;
                r_write_req_valid       <= i_write_req_valid;
                r_write_req_cnt         <= i_write_req_cnt;

                r_read_req_idx          <= i_read_req_idx;
                r_read_req_valid        <= i_read_req_valid;
                r_read_req_cnt          <= i_read_req_cnt;

                if (|r_read_data_mask)
                    r_read_data_mask        <= 'd0;
                else if (|r_write_data_mask)
                    r_write_data_mask       <= 'd0;

                // ---- Shift pipeline ----
                r_fdi_pl_data_valid     <= {r_fdi_pl_data_valid[1:0], w_rx_chunk_data_valid};
                r_g                     <= {r_g[1:0], i_g};

                r_write_data_idx        <= {r_write_data_idx[1], r_write_data_idx[0], i_write_data_idx};
                r_write_data_valid      <= {r_write_data_valid[1], r_write_data_valid[0], i_write_data_valid};
                r_write_data_cnt        <= {r_write_data_cnt[1], r_write_data_cnt[0], i_write_data_cnt};

                r_read_data_idx         <= {r_read_data_idx[1], r_read_data_idx[0], i_read_data_idx};
                r_read_data_valid       <= {r_read_data_valid[1], r_read_data_valid[0], i_read_data_valid};
                r_read_data_cnt         <= {r_read_data_cnt[1], r_read_data_cnt[0], i_read_data_cnt};

            end else begin
                // ---- Data-continue or idle handling ----
                if (w_write512_data_continue | w_read512_data_continue) begin
                    r_misc_valid            <= 'd0;
                    r_write_req_valid       <= 'd0;
                    r_read_req_valid        <= 'd0;

                    r_write_data_valid[2:1] <= 'd0;
                    r_read_data_valid[2:1]  <= 'd0;

                    if (r_write_data_valid[0][0] && (f_g_others(r_write_data_idx[0][0], r_g[0]) == 2'b00))
                        r_write_data_mask   <= 'd1;
                    else if (r_read_data_valid[0][0] && (f_g_others(r_read_data_idx[0][0], r_g[0]) == 2'b00))
                        r_read_data_mask    <= 'd1;

                end else if (w_write1024_data_continue | w_read1024_data_continue) begin
                    r_misc_valid            <= 'd0;
                    r_write_req_valid       <= 'd0;
                    r_read_req_valid        <= 'd0;
                    r_write_data_valid[2]   <= 'd0;
                    r_read_data_valid[2]    <= 'd0;

                    if (r_write_data_valid[0][0] && (f_g_others(r_write_data_idx[0][0], r_g[0]) == 2'b00))
                        r_write_data_mask       <= 'd1;
                    else if (r_read_data_valid[0][0] && (f_g_others(r_read_data_idx[0][0], r_g[0]) == 2'b00))
                        r_read_data_mask        <= 'd1;

                    if (|r_write_data_valid[0] && (f_g_others(r_write_data_idx[0][w_write0_data_cnt_m1[MAX_DATA_WD-1:0]], r_g[0]) == 2'b10)) begin
                        r_write_data_valid[1]   <= 'd0;
                        r_read_data_valid[1]    <= 'd0;
                    end else if (|r_read_data_valid[0] && (f_g_others(r_read_data_idx[0][w_read0_data_cnt_m1[MAX_DATA_WD-1:0]], r_g[0]) == 2'b10)) begin
                        r_write_data_valid[1]   <= 'd0;
                        r_read_data_valid[1]    <= 'd0;
                    end

                end else if (wait_valid_chunk == 0) begin
                    // ---- Idle: clear pipeline ----
                    r_misc_idx              <= 'd0;
                    r_misc_valid            <= 'd0;
                    r_misc_cnt              <= 'd0;

                    r_write_req_idx         <= 'd0;
                    r_write_req_valid       <= 'd0;
                    r_write_req_cnt         <= 'd0;

                    r_read_req_idx          <= 'd0;
                    r_read_req_valid        <= 'd0;
                    r_read_req_cnt          <= 'd0;

                    r_fdi_pl_data_valid     <= {r_fdi_pl_data_valid[1:0], 1'b0};
                    r_g                     <= {r_g[1:0], zero_g};

                    r_write_data_idx        <= {r_write_data_idx[1], r_write_data_idx[0], {MAX_DATA_COUNT_CHUNK{4'b0}}};
                    r_write_data_valid      <= {r_write_data_valid[1], r_write_data_valid[0], {MAX_DATA_COUNT_CHUNK{1'b0}}};
                    r_write_data_cnt        <= {r_write_data_cnt[1], r_write_data_cnt[0], {MAX_DATA_COUNT_WD{1'b0}}};

                    r_read_data_idx         <= {r_read_data_idx[1], r_read_data_idx[0], {MAX_DATA_COUNT_CHUNK{4'b0}}};
                    r_read_data_valid       <= {r_read_data_valid[1], r_read_data_valid[0], {MAX_DATA_COUNT_CHUNK{1'b0}}};
                    r_read_data_cnt         <= {r_read_data_cnt[1], r_read_data_cnt[0], {MAX_DATA_COUNT_WD{1'b0}}};
                end
            end
        end
    end

//-------------------------------------------------------------
    // Message-type classification (DEC_MULTI=1 → single loop over 12 granules)
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : gen_message_decode
            assign i_misc_start[i]          = i_msg_start[i] & (i_g[i].msg_type == MSG_MISC);
            assign i_write_req_start[i]     = i_msg_start[i] & (i_g[i].msg_type == MSG_WR_REQ);
            assign i_read_req_start[i]      = i_msg_start[i] & (i_g[i].msg_type == MSG_RD_REQ);
            assign i_write_data_start[i]    = i_msg_start[i] & ((i_g[i].msg_type == MSG_WR_DATA) | (i_g[i].msg_type == MSG_WRF_DATA));
            assign i_read_data_start[i]     = i_msg_start[i] & (i_g[i].msg_type == MSG_RD_DATA);
            assign i_write_resp_start[i]    = i_msg_start[i] & (i_g[i].msg_type == MSG_WR_RESP);
        end
    endgenerate

    // ---- Granule window:  {current(12), hist0(12), hist1(12), hist2(12)} = 48 granules ----
    assign w_g = {i_g, r_g[0], r_g[1], r_g[2]};

    // ---- Index / valid / count concatenation windows ----
    // DEC_MULTI=1 → i_* arrays are single-slot, no [0] select needed inside concat
    assign w_misc_idx           = {i_misc_idx, r_misc_idx};
    assign w_misc_valid         = {(i_misc_valid & {MAX_MISC_COUNT_CHUNK{w_rx_chunk_data_valid}}), r_misc_valid};
    assign w_misc_cnt           = {i_misc_cnt, r_misc_cnt};

    assign w_write_req_idx      = {i_write_req_idx, r_write_req_idx};
    assign w_write_req_valid    = {(i_write_req_valid & {MAX_REQ_COUNT_CHUNK{w_rx_chunk_data_valid}}), r_write_req_valid};
    assign w_write_req_cnt      = {i_write_req_cnt, r_write_req_cnt};

    assign w_read_req_idx       = {i_read_req_idx, r_read_req_idx};
    assign w_read_req_valid     = {(i_read_req_valid & {MAX_REQ_COUNT_CHUNK{w_rx_chunk_data_valid}}), r_read_req_valid};
    assign w_read_req_cnt       = {i_read_req_cnt, r_read_req_cnt};

    assign w_write_data_idx     = {i_write_data_idx, r_write_data_idx[0], r_write_data_idx[1], r_write_data_idx[2]};
    assign w_write_data_valid   = {(i_write_data_valid & {MAX_DATA_COUNT_CHUNK{w_rx_chunk_data_valid}}), r_write_data_valid[0], r_write_data_valid[1], r_write_data_valid[2]};
    assign w_write_data_cnt     = {i_write_data_cnt, r_write_data_cnt[0], r_write_data_cnt[1], r_write_data_cnt[2]};

    assign w_read_data_idx      = {i_read_data_idx, r_read_data_idx[0], r_read_data_idx[1], r_read_data_idx[2]};
    assign w_read_data_valid    = {(i_read_data_valid & {MAX_DATA_COUNT_CHUNK{w_rx_chunk_data_valid}}), r_read_data_valid[0], r_read_data_valid[1], r_read_data_valid[2]};
    assign w_read_data_cnt      = {i_read_data_cnt, r_read_data_cnt[0], r_read_data_cnt[1], r_read_data_cnt[2]};

//-------------------------------------------------------------
//  Find start index for MISC messages  (DEC_MULTI=1 → single decoder)
//-------------------------------------------------------------
    integer idx_misc;
    always_comb begin
        i_misc_cnt     = 'd0;
        i_misc_valid   = 'd0;
        i_misc_idx     = 'd0;
        for (idx_misc = 0; idx_misc < 12; idx_misc = idx_misc + 1) begin
            if (i_misc_start[idx_misc] == 1'b1) begin
                if (i_misc_cnt < MAX_MISC_COUNT_CHUNK) begin
                    i_misc_idx[i_misc_cnt[MAX_MISC_WD-1:0]] = idx_misc;
                    i_misc_valid[i_misc_cnt[MAX_MISC_WD-1:0]] = 1'b1;
                    i_misc_cnt = i_misc_cnt + 1;
                end
            end
        end
    end

//-------------------------------------------------------------
//  Find start index for write requests  (DEC_MULTI=1)
//-------------------------------------------------------------
    integer idx_wr_req;
    always_comb begin
        i_write_req_cnt     = 'd0;
        i_write_req_valid   = 'd0;
        i_write_req_idx     = 'd0;
        for (idx_wr_req = 0; idx_wr_req < 12; idx_wr_req = idx_wr_req + 1) begin
            if (i_write_req_start[idx_wr_req] == 1'b1) begin
                if (i_write_req_cnt < MAX_REQ_COUNT_CHUNK) begin
                    i_write_req_idx[i_write_req_cnt[MAX_REQ_WD-1:0]] = idx_wr_req;
                    i_write_req_valid[i_write_req_cnt[MAX_REQ_WD-1:0]] = 1'b1;
                    i_write_req_cnt = i_write_req_cnt + 1;
                end
            end
        end
    end

//-------------------------------------------------------------
//  Find start index for read requests  (DEC_MULTI=1)
//-------------------------------------------------------------
    integer idx_rd_req;
    always_comb begin
        i_read_req_cnt     = 'd0;
        i_read_req_valid   = 'd0;
        i_read_req_idx     = 'd0;
        for (idx_rd_req = 0; idx_rd_req < 12; idx_rd_req = idx_rd_req + 1) begin
            if (i_read_req_start[idx_rd_req] == 1'b1) begin
                if (i_read_req_cnt < MAX_REQ_COUNT_CHUNK) begin
                    i_read_req_idx[i_read_req_cnt[MAX_REQ_WD-1:0]] = idx_rd_req;
                    i_read_req_valid[i_read_req_cnt[MAX_REQ_WD-1:0]] = 1'b1;
                    i_read_req_cnt = i_read_req_cnt + 1;
                end
            end
        end
    end

//-------------------------------------------------------------
//  Find start index for write data  (DEC_MULTI=1)
//-------------------------------------------------------------
    integer idx_wr_data;
    always_comb begin
        i_write_data_cnt     = 'd0;
        i_write_data_valid   = 'd0;
        i_write_data_idx     = 'd0;
        for (idx_wr_data = 0; idx_wr_data < 12; idx_wr_data = idx_wr_data + 1) begin
            if (i_write_data_start[idx_wr_data] == 1'b1) begin
                if (i_write_data_cnt < MAX_DATA_COUNT_CHUNK) begin
                    i_write_data_idx[i_write_data_cnt[MAX_DATA_WD-1:0]] = idx_wr_data;
                    i_write_data_valid[i_write_data_cnt[MAX_DATA_WD-1:0]] = 1'b1;
                    i_write_data_cnt = i_write_data_cnt + 1;
                end
            end
        end
    end

    assign w_write0_data_cnt_m1 = (r_write_data_cnt[0] == 0) ? 0 : (r_write_data_cnt[0] - 1);
    assign w_write1_data_cnt_m1 = (r_write_data_cnt[1] == 0) ? 0 : (r_write_data_cnt[1] - 1);

    // ---- Write data continue: PHY_TYPE=1 (<2) → both 512b and 1024b continue possible ----
    always_comb begin
        w_write512_data_continue  = 1'b0;
        w_write1024_data_continue = 1'b0;
        if (|r_write_data_valid[0]) begin
            if (f_g_others(r_write_data_idx[0][w_write0_data_cnt_m1[MAX_DATA_WD-1:0]], r_g[0]) == 2'b01)
                w_write512_data_continue = 1'b1;
            else if (f_g_others(r_write_data_idx[0][w_write0_data_cnt_m1[MAX_DATA_WD-1:0]], r_g[0]) == 2'b10)
                w_write1024_data_continue = 1'b1;
        end
        if (|r_write_data_valid[1]) begin
            if (f_g_others(r_write_data_idx[1][w_write1_data_cnt_m1[MAX_DATA_WD-1:0]], r_g[1]) == 2'b10)
                w_write1024_data_continue = 1'b1;
        end
    end

//-------------------------------------------------------------
//  Find start index for read data  (DEC_MULTI=1)
//-------------------------------------------------------------
    integer idx_rd_data;
    always_comb begin
        i_read_data_cnt     = 'd0;
        i_read_data_valid   = 'd0;
        i_read_data_idx     = 'd0;
        for (idx_rd_data = 0; idx_rd_data < 12; idx_rd_data = idx_rd_data + 1) begin
            if (i_read_data_start[idx_rd_data] == 1'b1) begin
                if (i_read_data_cnt < MAX_DATA_COUNT_CHUNK) begin
                    i_read_data_idx[i_read_data_cnt[MAX_DATA_WD-1:0]] = idx_rd_data;
                    i_read_data_valid[i_read_data_cnt[MAX_DATA_WD-1:0]] = 1'b1;
                    i_read_data_cnt = i_read_data_cnt + 1;
                end
            end
        end
    end

    assign w_read0_data_cnt_m1 = (r_read_data_cnt[0] == 0) ? 0 : (r_read_data_cnt[0] - 1);
    assign w_read1_data_cnt_m1 = (r_read_data_cnt[1] == 0) ? 0 : (r_read_data_cnt[1] - 1);

    // ---- Read data continue: PHY_TYPE=1 (<2) → both 512b and 1024b continue possible ----
    always_comb begin
        w_read512_data_continue  = 1'b0;
        w_read1024_data_continue = 1'b0;
        if (|r_read_data_valid[0]) begin
            if (f_g_others(r_read_data_idx[0][w_read0_data_cnt_m1[MAX_DATA_WD-1:0]], r_g[0]) == 2'b01)
                w_read512_data_continue = 1'b1;
            else if (f_g_others(r_read_data_idx[0][w_read0_data_cnt_m1[MAX_DATA_WD-1:0]], r_g[0]) == 2'b10)
                w_read1024_data_continue = 1'b1;
        end
        if (|r_read_data_valid[1]) begin
            if (f_g_others(r_read_data_idx[1][w_read1_data_cnt_m1[MAX_DATA_WD-1:0]], r_g[1]) == 2'b10)
                w_read1024_data_continue = 1'b1;
        end
    end

//-------------------------------------------------------------
//  Find start index for write responses  (DEC_MULTI=1)
//-------------------------------------------------------------
    integer idx_wr_resp;
    always_comb begin
        i_write_resp_cnt     = 'd0;
        i_write_resp_valid   = 'd0;
        i_write_resp_idx     = 'd0;
        for (idx_wr_resp = 0; idx_wr_resp < 12; idx_wr_resp = idx_wr_resp + 1) begin
            if (i_write_resp_start[idx_wr_resp] == 1'b1) begin
                if (i_write_resp_cnt < MAX_WR_RESP_COUNT_CHUNK) begin
                    i_write_resp_idx[i_write_resp_cnt] = idx_wr_resp;
                    i_write_resp_valid[i_write_resp_cnt] = 1'b1;
                    i_write_resp_cnt = i_write_resp_cnt + 1;
                end
            end
        end
    end

//-------------------------------------------------------------
    assign w_misc_cnt_for_wait          = (r_misc_cnt == 0) ? 0 : (r_misc_cnt - 1);
    assign w_write_req_cnt_for_wait     = (r_write_req_cnt == 0) ? 0 : (r_write_req_cnt - 1);
    assign w_read_req_cnt_for_wait      = (r_read_req_cnt == 0) ? 0 : (r_read_req_cnt - 1);

    // w_valid_*_data_cnt[*] = w_*_data_cnt[*] - 1  (4 slots: DEC_MULTI+3 = 4 → [3:0])
    integer data_dec_sel;
    always_comb begin
        for (data_dec_sel = 0; data_dec_sel < 4; data_dec_sel = data_dec_sel + 1) begin
            w_valid_write_data_cnt[data_dec_sel] = (w_write_data_cnt[data_dec_sel] == 0) ? 0 : (w_write_data_cnt[data_dec_sel] - 1);
            w_valid_read_data_cnt[data_dec_sel]  = (w_read_data_cnt[data_dec_sel]  == 0) ? 0 : (w_read_data_cnt[data_dec_sel]  - 1);
        end
    end

//-------------------------------------------------------------
//  wait_valid_chunk — stall pipeline while a multi-granule message
//  has not yet been fully received across chunk boundaries.
//  (PHY_TYPE=1 → only the first terms; PHY_TYPE>1 and ==3 terms removed.)
//-------------------------------------------------------------
    logic [3:0] w_wvc_wridx_c2;
    logic [3:0] w_wvc_rdidx_c2;
    logic [3:0] w_wvc_wridx_c1;
    logic [3:0] w_wvc_rdidx_c1;
    logic [3:0] w_wvc_wridx_c0;
    logic [3:0] w_wvc_rdidx_c0;
    logic [3:0] w_wvc_misc_idx;
    logic [1:0] w_wvc_misc_others;

    assign w_wvc_wridx_c2 = r_write_data_idx[2][w_valid_write_data_cnt[0][MAX_DATA_WD-1:0]];
    assign w_wvc_rdidx_c2 = r_read_data_idx [2][w_valid_read_data_cnt [0][MAX_DATA_WD-1:0]];
    assign w_wvc_wridx_c1 = r_write_data_idx[1][w_valid_write_data_cnt[1][MAX_DATA_WD-1:0]];
    assign w_wvc_rdidx_c1 = r_read_data_idx [1][w_valid_read_data_cnt [1][MAX_DATA_WD-1:0]];
    assign w_wvc_wridx_c0 = r_write_data_idx[0][w_valid_write_data_cnt[2][MAX_DATA_WD-1:0]];
    assign w_wvc_rdidx_c0 = r_read_data_idx [0][w_valid_read_data_cnt [2][MAX_DATA_WD-1:0]];
    assign w_wvc_misc_idx = r_misc_idx[w_misc_cnt_for_wait[MAX_MISC_WD-1:0]];
    assign w_wvc_misc_others = f_g_others(w_wvc_misc_idx, r_g[0]);

    // wait_valid_chunk[2]: PHY_TYPE=1 → only first term (no PHY_TYPE>1 or ==3 additions)
    assign wait_valid_chunk[2] = ((r_write_data_valid[2][w_valid_write_data_cnt[0][MAX_DATA_WD-1:0]] && (f_g_others(w_wvc_wridx_c2, r_g[2]) == 2'b10) && (((f_g_msg_type(w_wvc_wridx_c2, r_g[2]) == MSG_WR_DATA) && (w_wvc_wridx_c2 + 30 > 36)) |
                                                                                                                                                           ((f_g_msg_type(w_wvc_wridx_c2, r_g[2]) == MSG_WRF_DATA) && (w_wvc_wridx_c2 + 27 > 36)))) ||
                                  (r_read_data_valid[2][w_valid_read_data_cnt[0][MAX_DATA_WD-1:0]] && (f_g_others(w_wvc_rdidx_c2, r_g[2]) == 2'b10) && (w_wvc_rdidx_c2 + 27 > 36)));

    // wait_valid_chunk[1]: PHY_TYPE=1 → only first term (no PHY_TYPE>1 addition)
    assign wait_valid_chunk[1] = ((r_write_data_valid[1][w_valid_write_data_cnt[1][MAX_DATA_WD-1:0]] && (f_g_others(w_wvc_wridx_c1, r_g[1]) == 2'b01) && (((f_g_msg_type(w_wvc_wridx_c1, r_g[1]) == MSG_WR_DATA) && (w_wvc_wridx_c1 + 15 > 24)) |
                                                                                                                                                           ((f_g_msg_type(w_wvc_wridx_c1, r_g[1]) == MSG_WRF_DATA) && (w_wvc_wridx_c1 + 14 > 24)))) ||
                                  (r_read_data_valid[1][w_valid_read_data_cnt[1][MAX_DATA_WD-1:0]] && (f_g_others(w_wvc_rdidx_c1, r_g[1]) == 2'b01) && (w_wvc_rdidx_c1 + 14 > 24)));

    // wait_valid_chunk[0]: no PHY_TYPE dependence
    assign wait_valid_chunk[0] = ((|r_misc_valid && (w_wvc_misc_others[0] == 1'b1) && (w_wvc_misc_idx + 2 > 12)) |
                                  (|r_write_req_valid && (r_write_req_idx[w_write_req_cnt_for_wait[MAX_REQ_WD-1:0]] + 3 > 12)) |
                                  (|r_read_req_valid && (r_read_req_idx[w_read_req_cnt_for_wait[MAX_REQ_WD-1:0]] + 3 > 12)) |
                                  (|r_write_data_valid[0] && (f_g_others(w_wvc_wridx_c0, r_g[0]) == 2'b00) && (((f_g_msg_type(w_wvc_wridx_c0, r_g[0]) == MSG_WR_DATA) && (w_wvc_wridx_c0 + 8 > 12)) |
                                                                                                               ((f_g_msg_type(w_wvc_wridx_c0, r_g[0]) == MSG_WRF_DATA) && (w_wvc_wridx_c0 + 7 > 12)))) |
                                  (|r_read_data_valid[0] && (f_g_others(w_wvc_rdidx_c0, r_g[0]) == 2'b00) && (w_wvc_rdidx_c0 + 8 > 12)));

//-------------------------------------------------------------
//  Packet reassembly from w_g  (DEC_MULTI=1 → idx_dec_sel = 0, all indices simplify)
//-------------------------------------------------------------
    st_misc_grantcredit_packet      [MAX_MISC_COUNT_CHUNK-1:0]       w_misc_packet;
    st_misc_activation_packet                                        w_misc_activation_packet;
    st_write_req_packet_tmp         [MAX_REQ_COUNT_CHUNK-1:0]        w_write_req_packet_tmp;
    st_read_req_packet_tmp          [MAX_REQ_COUNT_CHUNK-1:0]        w_read_req_packet_tmp;
    st_write_data256_packet_tmp     [MAX_DATA_COUNT_CHUNK-1:0]       w_write_data256_packet_tmp;
    st_write_data512_packet_tmp                                      w_write_data512_packet_tmp;
    st_write_data1024_packet_tmp                                     w_write_data1024_packet_tmp;
    st_read_data256_packet_tmp      [MAX_DATA_COUNT_CHUNK-1:0]       w_read_data256_packet_tmp;
    st_read_data512_packet_tmp                                       w_read_data512_packet_tmp;
    st_read_data1024_packet_tmp                                      w_read_data1024_packet_tmp;
    st_write_resp_packet_tmp        [MAX_WR_RESP_COUNT_CHUNK-1:0]    w_write_resp_packet_tmp;

    integer idx_msg_sel;
    always_comb begin
        // ---- MISC packets ----
        for (idx_msg_sel = 0; idx_msg_sel < MAX_MISC_COUNT_CHUNK; idx_msg_sel = idx_msg_sel + 1) begin
            w_misc_packet[idx_msg_sel] = w_g[(w_misc_idx[idx_msg_sel] + 24) +: 2];
        end

        // ---- Write / Read request packets ----
        for (idx_msg_sel = 0; idx_msg_sel < MAX_REQ_COUNT_CHUNK; idx_msg_sel = idx_msg_sel + 1) begin
            w_write_req_packet_tmp[idx_msg_sel] = w_g[(w_write_req_idx[idx_msg_sel] + 24) +: 3];
            w_read_req_packet_tmp[idx_msg_sel]  = w_g[(w_read_req_idx[idx_msg_sel]  + 24) +: 3];
        end

        // ---- 256-bit write/read data ----
        for (idx_msg_sel = 0; idx_msg_sel < MAX_DATA_COUNT_CHUNK; idx_msg_sel = idx_msg_sel + 1) begin
            if (w_g[24 + w_write_data_idx[2][idx_msg_sel]].msg_type == MSG_WR_DATA)
                w_write_data256_packet_tmp[idx_msg_sel] = w_g[(w_write_data_idx[2][idx_msg_sel] + 24) +: 8];
            else
                w_write_data256_packet_tmp[idx_msg_sel] = w_g[(w_write_data_idx[2][idx_msg_sel] + 24) +: 7];

            w_read_data256_packet_tmp[idx_msg_sel] = w_g[(w_read_data_idx[2][idx_msg_sel] + 24) +: 8];
        end

        // ---- 512-bit write data ----
        if (w_g[12 + w_write_data_idx[1][w_valid_write_data_cnt[1][MAX_DATA_WD-1:0]]].msg_type == MSG_WR_DATA)
            w_write_data512_packet_tmp = w_g[(w_write_data_idx[1][w_valid_write_data_cnt[1][MAX_DATA_WD-1:0]] + 12) +: 15];
        else
            w_write_data512_packet_tmp = w_g[(w_write_data_idx[1][w_valid_write_data_cnt[1][MAX_DATA_WD-1:0]] + 12) +: 14];

        // ---- 1024-bit write data ----
        if (w_g[w_write_data_idx[0][w_valid_write_data_cnt[0][MAX_DATA_WD-1:0]]].msg_type == MSG_WR_DATA)
            w_write_data1024_packet_tmp = w_g[(w_write_data_idx[0][w_valid_write_data_cnt[0][MAX_DATA_WD-1:0]]) +: 30];
        else
            w_write_data1024_packet_tmp = w_g[(w_write_data_idx[0][w_valid_write_data_cnt[0][MAX_DATA_WD-1:0]]) +: 27];

        // ---- 512-bit / 1024-bit read data ----
        w_read_data512_packet_tmp  = w_g[(w_read_data_idx[1][w_valid_read_data_cnt[1][MAX_DATA_WD-1:0]] + 12) +: 14];
        w_read_data1024_packet_tmp = w_g[(w_read_data_idx[0][w_valid_read_data_cnt[0][MAX_DATA_WD-1:0]]) +: 27];

        // ---- Write response packets ----
        for (idx_msg_sel = 0; idx_msg_sel < MAX_WR_RESP_COUNT_CHUNK; idx_msg_sel = idx_msg_sel + 1) begin
            w_write_resp_packet_tmp[idx_msg_sel] = w_g[(i_write_resp_idx[idx_msg_sel] + 36) +: 1];
        end
    end

    assign w_misc_activation_packet = w_g[(i_misc_idx[0] + 36) +: 1];

//-------------------------------------------------------------
//  Byte-level flattening  (DEC_MULTI=1)
//-------------------------------------------------------------
    st_write_req_packet         [MAX_REQ_COUNT_CHUNK-1:0]        w_write_req_packet;
    st_read_req_packet          [MAX_REQ_COUNT_CHUNK-1:0]        w_read_req_packet;
    st_write_data256_packet     [MAX_DATA_COUNT_CHUNK-1:0]       w_write_data256_packet;
    st_write_data512_packet                                      w_write_data512_packet;
    st_write_data1024_packet                                     w_write_data1024_packet;
    st_read_data256_packet      [MAX_DATA_COUNT_CHUNK-1:0]       w_read_data256_packet;
    st_read_data512_packet                                       w_read_data512_packet;
    st_read_data1024_packet                                      w_read_data1024_packet;
    st_write_resp_packet        [MAX_WR_RESP_COUNT_CHUNK-1:0]    w_write_resp_packet;

    // Flat byte arrays for unpacking
    logic [MAX_REQ_COUNT_CHUNK-1:0][63:0]        awaddr_flat;
    logic [MAX_REQ_COUNT_CHUNK-1:0][63:0]        araddr_flat;
    logic [MAX_DATA_COUNT_CHUNK-1:0][255:0]      wdata_256_flat;
    logic [MAX_DATA_COUNT_CHUNK-1:0][31:0]       wstrb_256_flat;
    logic [511:0]                                wdata_512_flat;
    logic [63:0]                                 wstrb_512_flat;
    logic [1023:0]                               wdata_1024_flat;
    logic [127:0]                                wstrb_1024_flat;
    logic [MAX_DATA_COUNT_CHUNK-1:0][255:0]      rdata_256_flat;
    logic [511:0]                                rdata_512_flat;
    logic [1023:0]                               rdata_1024_flat;

    always_comb begin
        // ---- AW / AR address flatten ----
        for (int unsigned j = 0; j < MAX_REQ_COUNT_CHUNK; j = j + 1) begin
            for (int unsigned i = 0; i < 8; i = i + 1) begin
                awaddr_flat[j][(i+1)*8-1 -: 8] = w_write_req_packet_tmp[j].awaddr[i];
                araddr_flat[j][(i+1)*8-1 -: 8] = w_read_req_packet_tmp[j].araddr[i];
            end
        end

        // ---- 256-bit data / strobe flatten ----
        for (int unsigned j = 0; j < MAX_DATA_COUNT_CHUNK; j = j + 1) begin
            for (int unsigned i = 0; i < 4; i = i + 1) begin
                wstrb_256_flat[j][(i+1)*8-1 -: 8] = w_write_data256_packet_tmp[j].wstrb[i];
            end
            for (int unsigned i = 0; i < 32; i = i + 1) begin
                wdata_256_flat[j][(i+1)*8-1 -: 8] = w_write_data256_packet_tmp[j].wdata[i];
                rdata_256_flat[j][(i+1)*8-1 -: 8] = w_read_data256_packet_tmp[j].rdata[i];
            end
        end

        // ---- 512-bit data flatten ----
        for (int unsigned i = 0; i < 64; i = i + 1) begin
            wdata_512_flat[(i+1)*8-1 -: 8] = w_write_data512_packet_tmp.wdata[i];
            rdata_512_flat[(i+1)*8-1 -: 8] = w_read_data512_packet_tmp.rdata[i];
        end

        // ---- 1024-bit data flatten ----
        for (int unsigned i = 0; i < 128; i = i + 1) begin
            wdata_1024_flat[(i+1)*8-1 -: 8] = w_write_data1024_packet_tmp.wdata[i];
            rdata_1024_flat[(i+1)*8-1 -: 8] = w_read_data1024_packet_tmp.rdata[i];
        end

        // ---- 512-bit strobe flatten ----
        for (int unsigned i = 0; i < 8; i = i + 1) begin
            wstrb_512_flat[(i+1)*8-1 -: 8] = w_write_data512_packet_tmp.wstrb[i];
        end

        // ---- 1024-bit strobe flatten ----
        for (int unsigned i = 0; i < 16; i = i + 1) begin
            wstrb_1024_flat[(i+1)*8-1 -: 8] = w_write_data1024_packet_tmp.wstrb[i];
        end
    end

//-------------------------------------------------------------
//  Final structured packet assembly  (DEC_MULTI=1)
//-------------------------------------------------------------
    integer idx_msg_sel_tmp;

    always_comb begin
        // ---- Write / Read request ----
        for (idx_msg_sel_tmp = 0; idx_msg_sel_tmp < MAX_REQ_COUNT_CHUNK; idx_msg_sel_tmp = idx_msg_sel_tmp + 1) begin
            w_write_req_packet[idx_msg_sel_tmp].awid       = {w_write_req_packet_tmp[idx_msg_sel_tmp].awid_1, w_write_req_packet_tmp[idx_msg_sel_tmp].awid_0};
            w_write_req_packet[idx_msg_sel_tmp].awaddr     = awaddr_flat[idx_msg_sel_tmp];
            w_write_req_packet[idx_msg_sel_tmp].awlen      = w_write_req_packet_tmp[idx_msg_sel_tmp].awlen;
            w_write_req_packet[idx_msg_sel_tmp].awsize     = w_write_req_packet_tmp[idx_msg_sel_tmp].awsize;
            w_write_req_packet[idx_msg_sel_tmp].awlock     = w_write_req_packet_tmp[idx_msg_sel_tmp].awlock;
            w_write_req_packet[idx_msg_sel_tmp].awcache    = w_write_req_packet_tmp[idx_msg_sel_tmp].awcache;
            w_write_req_packet[idx_msg_sel_tmp].awprot     = w_write_req_packet_tmp[idx_msg_sel_tmp].awprot;
            w_write_req_packet[idx_msg_sel_tmp].awqos      = w_write_req_packet_tmp[idx_msg_sel_tmp].awqos;
            w_write_req_packet[idx_msg_sel_tmp].prof       = {w_write_req_packet_tmp[idx_msg_sel_tmp].prof_1, w_write_req_packet_tmp[idx_msg_sel_tmp].prof_0};
            w_write_req_packet[idx_msg_sel_tmp].profextlen = w_write_req_packet_tmp[idx_msg_sel_tmp].profextlen;
            w_write_req_packet[idx_msg_sel_tmp].msg_type   = w_write_req_packet_tmp[idx_msg_sel_tmp].msg_type;
            w_write_req_packet[idx_msg_sel_tmp].rp         = w_write_req_packet_tmp[idx_msg_sel_tmp].rp;
            w_write_req_packet[idx_msg_sel_tmp].rsvd       = 'd0;

            w_read_req_packet[idx_msg_sel_tmp].arid        = {w_read_req_packet_tmp[idx_msg_sel_tmp].arid_1, w_read_req_packet_tmp[idx_msg_sel_tmp].arid_0};
            w_read_req_packet[idx_msg_sel_tmp].araddr      = araddr_flat[idx_msg_sel_tmp];
            w_read_req_packet[idx_msg_sel_tmp].arlen       = w_read_req_packet_tmp[idx_msg_sel_tmp].arlen;
            w_read_req_packet[idx_msg_sel_tmp].arsize      = w_read_req_packet_tmp[idx_msg_sel_tmp].arsize;
            w_read_req_packet[idx_msg_sel_tmp].arlock      = w_read_req_packet_tmp[idx_msg_sel_tmp].arlock;
            w_read_req_packet[idx_msg_sel_tmp].arcache     = w_read_req_packet_tmp[idx_msg_sel_tmp].arcache;
            w_read_req_packet[idx_msg_sel_tmp].arprot      = w_read_req_packet_tmp[idx_msg_sel_tmp].arprot;
            w_read_req_packet[idx_msg_sel_tmp].arqos       = w_read_req_packet_tmp[idx_msg_sel_tmp].arqos;
            w_read_req_packet[idx_msg_sel_tmp].prof        = {w_read_req_packet_tmp[idx_msg_sel_tmp].prof_1, w_read_req_packet_tmp[idx_msg_sel_tmp].prof_0};
            w_read_req_packet[idx_msg_sel_tmp].profextlen  = w_read_req_packet_tmp[idx_msg_sel_tmp].profextlen;
            w_read_req_packet[idx_msg_sel_tmp].msg_type    = w_read_req_packet_tmp[idx_msg_sel_tmp].msg_type;
            w_read_req_packet[idx_msg_sel_tmp].rp          = w_read_req_packet_tmp[idx_msg_sel_tmp].rp;
            w_read_req_packet[idx_msg_sel_tmp].rsvd        = 'd0;
        end

        // ---- 256-bit write / read data ----
        for (idx_msg_sel_tmp = 0; idx_msg_sel_tmp < MAX_DATA_COUNT_CHUNK; idx_msg_sel_tmp = idx_msg_sel_tmp + 1) begin
            w_write_data256_packet[idx_msg_sel_tmp].wdata      = wdata_256_flat[idx_msg_sel_tmp];
            w_write_data256_packet[idx_msg_sel_tmp].wstrb      = wstrb_256_flat[idx_msg_sel_tmp];
            w_write_data256_packet[idx_msg_sel_tmp].prof       = {w_write_data256_packet_tmp[idx_msg_sel_tmp].prof_1, w_write_data256_packet_tmp[idx_msg_sel_tmp].prof_0};
            w_write_data256_packet[idx_msg_sel_tmp].profextlen = w_write_data256_packet_tmp[idx_msg_sel_tmp].profextlen;
            w_write_data256_packet[idx_msg_sel_tmp].msg_type   = w_write_data256_packet_tmp[idx_msg_sel_tmp].msg_type;
            w_write_data256_packet[idx_msg_sel_tmp].rp         = w_write_data256_packet_tmp[idx_msg_sel_tmp].rp;
            w_write_data256_packet[idx_msg_sel_tmp].dlength    = w_write_data256_packet_tmp[idx_msg_sel_tmp].dlength;
            w_write_data256_packet[idx_msg_sel_tmp].rsvd       = 'd0;

            w_read_data256_packet[idx_msg_sel_tmp].rdata       = rdata_256_flat[idx_msg_sel_tmp];
            w_read_data256_packet[idx_msg_sel_tmp].rid         = {w_read_data256_packet_tmp[idx_msg_sel_tmp].rid_1, w_read_data256_packet_tmp[idx_msg_sel_tmp].rid_0};
            w_read_data256_packet[idx_msg_sel_tmp].rresp       = w_read_data256_packet_tmp[idx_msg_sel_tmp].rresp;
            w_read_data256_packet[idx_msg_sel_tmp].rlast       = w_read_data256_packet_tmp[idx_msg_sel_tmp].rlast;
            w_read_data256_packet[idx_msg_sel_tmp].prof        = {w_read_data256_packet_tmp[idx_msg_sel_tmp].prof_1, w_read_data256_packet_tmp[idx_msg_sel_tmp].prof_0};
            w_read_data256_packet[idx_msg_sel_tmp].profextlen  = w_read_data256_packet_tmp[idx_msg_sel_tmp].profextlen;
            w_read_data256_packet[idx_msg_sel_tmp].msg_type    = w_read_data256_packet_tmp[idx_msg_sel_tmp].msg_type;
            w_read_data256_packet[idx_msg_sel_tmp].rp          = w_read_data256_packet_tmp[idx_msg_sel_tmp].rp;
            w_read_data256_packet[idx_msg_sel_tmp].dlength     = w_read_data256_packet_tmp[idx_msg_sel_tmp].dlength;
            w_read_data256_packet[idx_msg_sel_tmp].rsvd        = 'd0;
        end

        // ---- 512-bit write data ----
        w_write_data512_packet.wdata                       = wdata_512_flat;
        w_write_data512_packet.wstrb                       = wstrb_512_flat;
        w_write_data512_packet.prof                        = {w_write_data512_packet_tmp.prof_1, w_write_data512_packet_tmp.prof_0};
        w_write_data512_packet.profextlen                  = w_write_data512_packet_tmp.profextlen;
        w_write_data512_packet.msg_type                    = w_write_data512_packet_tmp.msg_type;
        w_write_data512_packet.rp                          = w_write_data512_packet_tmp.rp;
        w_write_data512_packet.dlength                     = w_write_data512_packet_tmp.dlength;

        // ---- 1024-bit write data ----
        w_write_data1024_packet.wdata                      = wdata_1024_flat;
        w_write_data1024_packet.wstrb                      = wstrb_1024_flat;
        w_write_data1024_packet.prof                       = {w_write_data1024_packet_tmp.prof_1, w_write_data1024_packet_tmp.prof_0};
        w_write_data1024_packet.profextlen                 = w_write_data1024_packet_tmp.profextlen;
        w_write_data1024_packet.msg_type                   = w_write_data1024_packet_tmp.msg_type;
        w_write_data1024_packet.rp                         = w_write_data1024_packet_tmp.rp;
        w_write_data1024_packet.dlength                    = w_write_data1024_packet_tmp.dlength;
        w_write_data1024_packet.rsvd                       = 'd0;

        // ---- 512-bit read data ----
        w_read_data512_packet.rdata                        = rdata_512_flat;
        w_read_data512_packet.rid                          = {w_read_data512_packet_tmp.rid_1, w_read_data512_packet_tmp.rid_0};
        w_read_data512_packet.rresp                        = w_read_data512_packet_tmp.rresp;
        w_read_data512_packet.rlast                        = w_read_data512_packet_tmp.rlast;
        w_read_data512_packet.prof                         = {w_read_data512_packet_tmp.prof_1, w_read_data512_packet_tmp.prof_0};
        w_read_data512_packet.profextlen                   = w_read_data512_packet_tmp.profextlen;
        w_read_data512_packet.msg_type                     = w_read_data512_packet_tmp.msg_type;
        w_read_data512_packet.rp                           = w_read_data512_packet_tmp.rp;
        w_read_data512_packet.dlength                      = w_read_data512_packet_tmp.dlength;
        w_read_data512_packet.rsvd                         = 'd0;

        // ---- 1024-bit read data ----
        w_read_data1024_packet.rdata                       = rdata_1024_flat;
        w_read_data1024_packet.rid                         = {w_read_data1024_packet_tmp.rid_1, w_read_data1024_packet_tmp.rid_0};
        w_read_data1024_packet.rresp                       = w_read_data1024_packet_tmp.rresp;
        w_read_data1024_packet.rlast                       = w_read_data1024_packet_tmp.rlast;
        w_read_data1024_packet.prof                        = {w_read_data1024_packet_tmp.prof_1, w_read_data1024_packet_tmp.prof_0};
        w_read_data1024_packet.profextlen                  = w_read_data1024_packet_tmp.profextlen;
        w_read_data1024_packet.msg_type                    = w_read_data1024_packet_tmp.msg_type;
        w_read_data1024_packet.rp                          = w_read_data1024_packet_tmp.rp;
        w_read_data1024_packet.dlength                     = w_read_data1024_packet_tmp.dlength;
        w_read_data1024_packet.rsvd                        = 'd0;

        // ---- Write response ----
        for (idx_msg_sel_tmp = 0; idx_msg_sel_tmp < MAX_WR_RESP_COUNT_CHUNK; idx_msg_sel_tmp = idx_msg_sel_tmp + 1) begin
            w_write_resp_packet[idx_msg_sel_tmp].bid       = {w_write_resp_packet_tmp[idx_msg_sel_tmp].bid_1, w_write_resp_packet_tmp[idx_msg_sel_tmp].bid_0};
            w_write_resp_packet[idx_msg_sel_tmp].bresp     = w_write_resp_packet_tmp[idx_msg_sel_tmp].bresp;
            w_write_resp_packet[idx_msg_sel_tmp].prof      = {w_write_resp_packet_tmp[idx_msg_sel_tmp].prof_1, w_write_resp_packet_tmp[idx_msg_sel_tmp].prof_0};
            w_write_resp_packet[idx_msg_sel_tmp].profextlen = w_write_resp_packet_tmp[idx_msg_sel_tmp].profextlen;
            w_write_resp_packet[idx_msg_sel_tmp].msg_type  = w_write_resp_packet_tmp[idx_msg_sel_tmp].msg_type;
            w_write_resp_packet[idx_msg_sel_tmp].rp        = w_write_resp_packet_tmp[idx_msg_sel_tmp].rp;
            w_write_resp_packet[idx_msg_sel_tmp].rsvd      = 'd0;
        end
    end

//-------------------------------------------------------------
//  Output assignment  (RP_COUNT=1 → z=0, DEC_MULTI=1 → y=0)
//  RP match: z == rp  →  0 == rp  →  rp == 0
//-------------------------------------------------------------
    genvar x;
    generate

        // ---- Write request ----
        for (x = 0; x < MAX_REQ_COUNT_CHUNK; x = x + 1) begin
            assign O_WR_REQ_FIFO_SDATA[x] = (w_write_req_packet[x].rp == 2'd0) ? {
                w_write_req_packet[x].awid,
                w_write_req_packet[x].awaddr,
                w_write_req_packet[x].awlen,
                w_write_req_packet[x].awsize,
                w_write_req_packet[x].awlock,
                w_write_req_packet[x].awcache,
                w_write_req_packet[x].awprot,
                w_write_req_packet[x].awqos
            } : {(AW_AR_FIFO_DATA_WIDTH){1'b0}};

            assign O_WR_REQ_FIFO_SVALID[x] = (w_write_req_packet[x].rp == 2'd0)
                ? ((|wait_valid_chunk) ? (w_write_req_valid[x] && w_rx_chunk_data_valid) : w_write_req_valid[x])
                : 1'b0;
        end

        // ---- Write data (4 slots: 0=1024b, 1=512b, 2=256b#0, 3=256b#1) ----
        // Slot 0: 1024-bit
        assign O_WR_DATA_FIFO_SDATA[0] = (w_write_data1024_packet.rp == 2'd0)
            ? w_write_data1024_packet.wdata : {(AXI_PEER_DIE_MAX_DATA_WD){1'b0}};
        assign O_WR_DATA_FIFO_SDATA_STRB[0] = (w_write_data1024_packet.rp == 2'd0)
            ? ((w_write_data1024_packet.msg_type == MSG_WR_DATA) ? w_write_data1024_packet.wstrb : {128{1'b1}})
            : {AXI_STRB_WD{1'b0}};
        assign O_WR_DATA_FIFO_SDATA_WDATAF[0] = (w_write_data1024_packet.rp == 2'd0)
            ? ((w_write_data1024_packet.msg_type == MSG_WR_DATA) ? 1'b0 : 1'b1) : 1'b0;
        assign O_WR_DATA_FIFO_SVALID[0] = (w_write_data1024_packet.rp == 2'd0)
            ? ((w_write_data1024_packet.dlength == 2'b10)
                ? ((|wait_valid_chunk) ? (w_write_data_valid[0][w_valid_write_data_cnt[0][MAX_DATA_WD-1:0]] && w_rx_chunk_data_valid) : w_write_data_valid[0][w_valid_write_data_cnt[0][MAX_DATA_WD-1:0]])
                : 1'b0)
            : 1'b0;

        // Slot 1: 512-bit
        assign O_WR_DATA_FIFO_SDATA[1] = (w_write_data512_packet.rp == 2'd0)
            ? {{(AXI_PEER_DIE_MAX_DATA_WD-512){1'b0}}, w_write_data512_packet.wdata[511:0]} : {(AXI_PEER_DIE_MAX_DATA_WD){1'b0}};
        assign O_WR_DATA_FIFO_SDATA_STRB[1] = (w_write_data512_packet.rp == 2'd0)
            ? ((w_write_data512_packet.msg_type == MSG_WR_DATA) ? w_write_data512_packet.wstrb : {{(AXI_STRB_WD-64){1'b0}}, {64{1'b1}}})
            : {AXI_STRB_WD{1'b0}};
        assign O_WR_DATA_FIFO_SDATA_WDATAF[1] = (w_write_data512_packet.rp == 2'd0)
            ? ((w_write_data512_packet.msg_type == MSG_WR_DATA) ? 1'b0 : 1'b1) : 1'b0;
        assign O_WR_DATA_FIFO_SVALID[1] = (w_write_data512_packet.rp == 2'd0)
            ? ((w_write_data512_packet.dlength == 2'b01)
                ? ((|wait_valid_chunk) ? (w_write_data_valid[1][w_valid_write_data_cnt[1][MAX_DATA_WD-1:0]] && w_rx_chunk_data_valid) : w_write_data_valid[1][w_valid_write_data_cnt[1][MAX_DATA_WD-1:0]])
                : 1'b0)
            : 1'b0;

        // Slot 2: 256-bit #0
        assign O_WR_DATA_FIFO_SDATA[2] = (w_write_data256_packet[0].rp == 2'd0)
            ? {{(AXI_PEER_DIE_MAX_DATA_WD-256){1'b0}}, w_write_data256_packet[0].wdata[255:0]} : {(AXI_PEER_DIE_MAX_DATA_WD){1'b0}};
        assign O_WR_DATA_FIFO_SDATA_STRB[2] = (w_write_data256_packet[0].rp == 2'd0)
            ? ((w_write_data256_packet[0].msg_type == MSG_WR_DATA) ? w_write_data256_packet[0].wstrb : {{(AXI_STRB_WD-32){1'b0}}, {32{1'b1}}})
            : {AXI_STRB_WD{1'b0}};
        assign O_WR_DATA_FIFO_SDATA_WDATAF[2] = (w_write_data256_packet[0].rp == 2'd0)
            ? ((w_write_data256_packet[0].msg_type == MSG_WR_DATA) ? 1'b0 : 1'b1) : 1'b0;
        assign O_WR_DATA_FIFO_SVALID[2] = (w_write_data256_packet[0].rp == 2'd0)
            ? ((w_write_data256_packet[0].dlength == 2'b00)
                ? ((|wait_valid_chunk) ? (w_write_data_valid[2][0] && w_rx_chunk_data_valid) : (w_write_data_valid[2][0] && !r_write_data_mask))
                : 1'b0)
            : 1'b0;

        // Slot 3: 256-bit #1
        assign O_WR_DATA_FIFO_SDATA[3] = (w_write_data256_packet[1].rp == 2'd0)
            ? {{(AXI_PEER_DIE_MAX_DATA_WD-256){1'b0}}, w_write_data256_packet[1].wdata[255:0]} : {(AXI_PEER_DIE_MAX_DATA_WD){1'b0}};
        assign O_WR_DATA_FIFO_SDATA_STRB[3] = (w_write_data256_packet[1].rp == 2'd0)
            ? ((w_write_data256_packet[1].msg_type == MSG_WR_DATA) ? w_write_data256_packet[1].wstrb : {{(AXI_STRB_WD-32){1'b0}}, {32{1'b1}}})
            : {AXI_STRB_WD{1'b0}};
        assign O_WR_DATA_FIFO_SDATA_WDATAF[3] = (w_write_data256_packet[1].rp == 2'd0)
            ? ((w_write_data256_packet[1].msg_type == MSG_WR_DATA) ? 1'b0 : 1'b1) : 1'b0;
        assign O_WR_DATA_FIFO_SVALID[3] = (w_write_data256_packet[1].rp == 2'd0)
            ? ((w_write_data256_packet[1].dlength == 2'b00)
                ? ((|wait_valid_chunk) ? (w_write_data_valid[2][1] && w_rx_chunk_data_valid) : w_write_data_valid[2][1])
                : 1'b0)
            : 1'b0;

        // ---- Write response ----
        for (x = 0; x < MAX_WR_RESP_COUNT_CHUNK; x = x + 1) begin
            assign O_WR_RESP_FIFO_SDATA[x] = (w_write_resp_packet[x].rp == 2'd0) ? {
                w_write_resp_packet[x].bid,
                w_write_resp_packet[x].bresp
            } : {(B_FIFO_DATA_WIDTH){1'b0}};
            assign O_WR_RESP_FIFO_SVALID[x] = (w_write_resp_packet[x].rp == 2'd0) ? (i_write_resp_valid[x] && w_rx_chunk_data_valid) : 1'b0;
        end

        // ---- Read request ----
        for (x = 0; x < MAX_REQ_COUNT_CHUNK; x = x + 1) begin
            assign O_RD_REQ_FIFO_SDATA[x] = (w_read_req_packet[x].rp == 2'd0) ? {
                w_read_req_packet[x].arid,
                w_read_req_packet[x].araddr,
                w_read_req_packet[x].arlen,
                w_read_req_packet[x].arsize,
                w_read_req_packet[x].arlock,
                w_read_req_packet[x].arcache,
                w_read_req_packet[x].arprot,
                w_read_req_packet[x].arqos
            } : {(AW_AR_FIFO_DATA_WIDTH){1'b0}};
            assign O_RD_REQ_FIFO_SVALID[x] = (w_read_req_packet[x].rp == 2'd0)
                ? ((|wait_valid_chunk) ? (w_read_req_valid[x] && w_rx_chunk_data_valid) : w_read_req_valid[x])
                : 1'b0;
        end

        // ---- Read data (4 slots) ----
        assign O_RD_DATA_FIFO_SDATA[0] = (w_read_data1024_packet.rp == 2'd0)
            ? w_read_data1024_packet.rdata[1023:0] : {(AXI_PEER_DIE_MAX_DATA_WD){1'b0}};
        assign O_RD_DATA_FIFO_SDATA[1] = (w_read_data512_packet.rp == 2'd0)
            ? {{(AXI_PEER_DIE_MAX_DATA_WD-512){1'b0}}, w_read_data512_packet.rdata[511:0]} : {(AXI_PEER_DIE_MAX_DATA_WD){1'b0}};
        assign O_RD_DATA_FIFO_SDATA[2] = (w_read_data256_packet[0].rp == 2'd0)
            ? {{(AXI_PEER_DIE_MAX_DATA_WD-256){1'b0}}, w_read_data256_packet[0].rdata[255:0]} : {(AXI_PEER_DIE_MAX_DATA_WD){1'b0}};
        assign O_RD_DATA_FIFO_SDATA[3] = (w_read_data256_packet[1].rp == 2'd0)
            ? {{(AXI_PEER_DIE_MAX_DATA_WD-256){1'b0}}, w_read_data256_packet[1].rdata[255:0]} : {(AXI_PEER_DIE_MAX_DATA_WD){1'b0}};

        assign O_RD_DATA_FIFO_EXT_SDATA[0] = (w_read_data1024_packet.rp == 2'd0) ? {
            w_read_data1024_packet.rid,
            w_read_data1024_packet.rresp,
            w_read_data1024_packet.rlast
        } : {R_FIFO_EXT_DATA_WIDTH{1'b0}};
        assign O_RD_DATA_FIFO_EXT_SDATA[1] = (w_read_data512_packet.rp == 2'd0) ? {
            w_read_data512_packet.rid,
            w_read_data512_packet.rresp,
            w_read_data512_packet.rlast
        } : {R_FIFO_EXT_DATA_WIDTH{1'b0}};
        assign O_RD_DATA_FIFO_EXT_SDATA[2] = (w_read_data256_packet[0].rp == 2'd0) ? {
            w_read_data256_packet[0].rid,
            w_read_data256_packet[0].rresp,
            w_read_data256_packet[0].rlast
        } : {R_FIFO_EXT_DATA_WIDTH{1'b0}};
        assign O_RD_DATA_FIFO_EXT_SDATA[3] = (w_read_data256_packet[1].rp == 2'd0) ? {
            w_read_data256_packet[1].rid,
            w_read_data256_packet[1].rresp,
            w_read_data256_packet[1].rlast
        } : {R_FIFO_EXT_DATA_WIDTH{1'b0}};

        assign O_RD_DATA_FIFO_SVALID[0] = (w_read_data1024_packet.rp == 2'd0)
            ? ((w_read_data1024_packet.dlength == 2'b10)
                ? ((|wait_valid_chunk) ? (w_read_data_valid[0][w_valid_read_data_cnt[0][MAX_DATA_WD-1:0]] && w_rx_chunk_data_valid) : w_read_data_valid[0][w_valid_read_data_cnt[0][MAX_DATA_WD-1:0]])
                : 1'b0)
            : 1'b0;
        assign O_RD_DATA_FIFO_SVALID[1] = (w_read_data512_packet.rp == 2'd0)
            ? ((w_read_data512_packet.dlength == 2'b01)
                ? ((|wait_valid_chunk) ? (w_read_data_valid[1][w_valid_read_data_cnt[1][MAX_DATA_WD-1:0]] && w_rx_chunk_data_valid) : w_read_data_valid[1][w_valid_read_data_cnt[1][MAX_DATA_WD-1:0]])
                : 1'b0)
            : 1'b0;
        assign O_RD_DATA_FIFO_SVALID[2] = (w_read_data256_packet[0].rp == 2'd0)
            ? ((w_read_data256_packet[0].dlength == 2'b00)
                ? ((|wait_valid_chunk) ? (w_read_data_valid[2][0] && w_rx_chunk_data_valid) : (w_read_data_valid[2][0] && !r_read_data_mask))
                : 1'b0)
            : 1'b0;
        assign O_RD_DATA_FIFO_SVALID[3] = (w_read_data256_packet[1].rp == 2'd0)
            ? ((w_read_data256_packet[1].dlength == 2'b00)
                ? ((|wait_valid_chunk) ? (w_read_data_valid[2][1] && w_rx_chunk_data_valid) : w_read_data_valid[2][1])
                : 1'b0)
            : 1'b0;

    endgenerate

//-------------------------------------------------------------
//  Credit grant outputs  (DEC_MULTI=1)
//-------------------------------------------------------------
    generate
        for (x = 0; x < MAX_MISC_COUNT_CHUNK; x = x + 1) begin
            assign O_CRDTGRANT_WRESPCRED3[x] = w_misc_packet[x].wrespcred3;
            assign O_CRDTGRANT_WRESPCRED2[x] = w_misc_packet[x].wrespcred2;
            assign O_CRDTGRANT_WRESPCRED1[x] = w_misc_packet[x].wrespcred1;
            assign O_CRDTGRANT_WRESPCRED0[x] = {w_misc_packet[x].wrespcred0_1, w_misc_packet[x].wrespcred0_0};
            assign O_CRDTGRANT_RDATACRED3[x] = w_misc_packet[x].rdatacred3;
            assign O_CRDTGRANT_RDATACRED2[x] = w_misc_packet[x].rdatacred2;
            assign O_CRDTGRANT_RDATACRED1[x] = {w_misc_packet[x].rdatacred1_1, w_misc_packet[x].rdatacred1_0};
            assign O_CRDTGRANT_RDATACRED0[x] = w_misc_packet[x].rdatacred0;
            assign O_CRDTGRANT_WDATACRED3[x] = w_misc_packet[x].wdatacred3;
            assign O_CRDTGRANT_WDATACRED2[x] = w_misc_packet[x].wdatacred2;
            assign O_CRDTGRANT_WDATACRED1[x] = w_misc_packet[x].wdatacred1;
            assign O_CRDTGRANT_WDATACRED0[x] = {w_misc_packet[x].wdatacred0_1, w_misc_packet[x].wdatacred0_0};
            assign O_CRDTGRANT_RREQCRED3[x]  = w_misc_packet[x].rreqcred3;
            assign O_CRDTGRANT_RREQCRED2[x]  = w_misc_packet[x].rreqcred2;
            assign O_CRDTGRANT_RREQCRED1[x]  = {w_misc_packet[x].rreqcred1_1, w_misc_packet[x].rreqcred1_0};
            assign O_CRDTGRANT_RREQCRED0[x]  = w_misc_packet[x].rreqcred0;
            assign O_CRDTGRANT_WREQCRED3[x]  = w_misc_packet[x].wreqcred3;
            assign O_CRDTGRANT_WREQCRED2[x]  = w_misc_packet[x].wreqcred2;
            assign O_CRDTGRANT_WREQCRED1[x]  = w_misc_packet[x].wreqcred1;
            assign O_CRDTGRANT_WREQCRED0[x]  = {w_misc_packet[x].wreqcred0_1, w_misc_packet[x].wreqcred0_0};
            assign O_CRDTGRANT_VALID[x]      = (w_misc_packet[x].misc_op == 3'b100)
                ? ((|wait_valid_chunk) ? (w_misc_valid[x] && w_rx_chunk_data_valid) : w_misc_valid[x])
                : 1'b0;
        end
    endgenerate

    // ---- Message credit ----
    assign O_MSGCRDT_WRESPCRED     = i_msg_credit.wrespcred;
    assign O_MSGCRDT_RDATACRED     = i_msg_credit.rdatacred;
    assign O_MSGCRDT_WDATACRED     = i_msg_credit.wdatacred;
    assign O_MSGCRDT_RREQCRED      = i_msg_credit.rreqcred;
    assign O_MSGCRDT_WREQCRED      = i_msg_credit.wreqcred;
    assign O_MSGCRDT_RP            = i_msg_credit.rp;
    assign O_MSGCRDT_VALID         = (r_aou_rx_phase == 2'b10) && w_rx_chunk_data_valid;

    // ---- Activation ----
    assign O_ACTIVATION_OP         = {w_misc_activation_packet.activation_op_1, w_misc_activation_packet.activation_op_0};
    assign O_ACTIVATION_PROP_REQ   = w_misc_activation_packet.property_req;
    assign O_ACTIVATION_VALID      = (w_misc_activation_packet.misc_op == 3'b010) ? (i_misc_valid[0] && w_rx_chunk_data_valid) : 1'b0;

endmodule
