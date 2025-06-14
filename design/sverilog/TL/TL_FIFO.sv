// Copyright (c) 2024 Sungkyunkwan University
// All rights reserved
// Author: Jungrae Kim <dale40@gmail.com>
// Description:

module TL_FIFO
#(
    parameter   int     DEPTH_LG2       = 4
  , parameter   int     DATA_WIDTH      = 256
  , parameter   bit     RDATA_FF_OUT    = 0
  , parameter   bit     USE_CNT         = 0
)
(
    input   wire                        clk
  , input   wire                        rst_n

  , output  wire                        full_o
  , input   wire                        wren_i
  , input   wire    [DATA_WIDTH-1:0]    wdata_i

  , output  wire                        empty_o
  , input   wire                        rden_i
  , output  wire    [DATA_WIDTH-1:0]    rdata_o

  , output  wire    [DEPTH_LG2:0]       cnt_o
  , output  logic   [31:0]              debug_o
);
    // read/write pointers have one extra bit for full/empty checking
    logic   [DEPTH_LG2:0]               wrptr,      wrptr_n;
    logic   [DEPTH_LG2:0]               rdptr,      rdptr_n;

    logic                               full,       full_n;
    logic                               empty,      empty_n;
    logic                               overflown,  overflown_n;
    logic                               undrflown,  undrflown_n;

    always_ff @(posedge clk)
        if (~rst_n) begin
            wrptr                       <= {(DEPTH_LG2+1){1'b0}};
            rdptr                       <= {(DEPTH_LG2+1){1'b0}};

            full                        <= 1'b1; // not to receive new data while this IP is under a reset.
            empty                       <= 1'b1;
            overflown                   <= 1'b0;
            undrflown                   <= 1'b0;
        end
        else begin
            wrptr                       <= wrptr_n;
            rdptr                       <= rdptr_n;

            full                        <= full_n;
            empty                       <= empty_n;
            overflown                   <= overflown_n;
            undrflown                   <= undrflown_n;
        end

    always_comb begin
        if (wren_i) begin
            wrptr_n                     = wrptr + 'd1;
        end
        else begin
            wrptr_n                     = wrptr;
        end

        if (rden_i) begin
            rdptr_n                     = rdptr + 'd1;
        end
        else begin
            rdptr_n                     = rdptr;
        end

        full_n                      =  (wrptr_n[DEPTH_LG2] != rdptr_n[DEPTH_LG2])
                                     & (wrptr_n[DEPTH_LG2-1:0] == rdptr_n[DEPTH_LG2-1:0]);
        empty_n                     = (wrptr_n == rdptr_n);
        overflown_n                 = overflown | (full_o & wren_i);    // sticky
        undrflown_n                 = undrflown | (empty_o & rden_i);   // sticky
    end

    assign  full_o                  = full;
    assign  empty_o                 = empty;
    assign  debug_o[31]             = overflown;
    assign  debug_o[30]             = full;
    assign  debug_o[15]             = undrflown;
    assign  debug_o[14]             = empty;

    generate
        if ($bits(wrptr) > 14) begin: dbg_ptr1
            assign  debug_o[29:16]          = wrptr[13:0];
            assign  debug_o[13:0]           = rdptr[13:0];
        end
        else begin: dbg_ptr2
            assign  debug_o[29:16]          = 14'd0 | wrptr;
            assign  debug_o[13:0]           = 14'd0 | rdptr;
        end
    endgenerate

    // synopsys translate_off
    /* svlint off operator_case_equality */
    overflow_check: assert property (
        @(posedge clk) disable iff (~rst_n)
        (overflown !== 1'b1)
    );
    undrflow_check: assert property (
        @(posedge clk) disable iff (~rst_n)
        (undrflown !== 1'b1)
    );
    /* svlint on operator_case_equality */
    // synopsys translate_on

    generate
        if (RDATA_FF_OUT) begin: rdata_timing_optimize
            SAL_SDP_RAM
            #(
                .DEPTH_LG2                      (DEPTH_LG2)
              , .DATA_WIDTH                     (DATA_WIDTH)
              , .RDATA_FF_OUT                   (1)
            )
            u_mem
            (
                .clk                            (clk)

              , .en_a                           (wren_i)
              , .we_a                           (wren_i)
              , .addr_a                         (wrptr[DEPTH_LG2-1:0])
              , .di_a                           (wdata_i)

              , .en_b                           (1'b1)
              // _n if you're using RDATA_FF_OUT = 1
              , .addr_b                         (rdptr_n[DEPTH_LG2-1:0])
              , .do_b                           (rdata_o)
            );
        end
        else begin: rdata_no_timing_optimize
            SAL_SDP_RAM
            #(
                .DEPTH_LG2                      (DEPTH_LG2)
              , .DATA_WIDTH                     (DATA_WIDTH)
              , .RDATA_FF_OUT                   (0)
            )
            u_mem
            (
                .clk                            (clk)

              , .en_a                           (wren_i)
              , .we_a                           (wren_i)
              , .addr_a                         (wrptr[DEPTH_LG2-1:0])
              , .di_a                           (wdata_i)

              , .en_b                           (1'b1)
              // NO _n if you're using RDATA_FF_OUT = 0
              , .addr_b                         (rdptr[DEPTH_LG2-1:0])
              , .do_b                           (rdata_o)
            );
        end

        if (USE_CNT) begin : with_counter
            TL_CNT #(.DEPTH(DEPTH_LG2)) fifo_cnt (
                .clk        (clk),
                .rst_n      (rst_n),
                .wren_i     (wren_i),
                .rden_i     (rden_i),
                .cnt_o      (cnt_o)
            );
        end
        else begin : without_counter
            assign cnt_o = {(DEPTH_LG2){1'b0}};
        end
    endgenerate

endmodule
