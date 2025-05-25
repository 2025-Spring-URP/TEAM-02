module DLL_TOP #(
    parameter  integer  PIPE_DATA_WIDTH          = 256,
    parameter  integer  RETRY_DEPTH_LG2          = 8,
    parameter  integer  CREDIT_DEPTH             = 12
)
(
    // SYSTEM
    input    wire                           sclk,
    input    wire                           srst_n,

    // TL --> DLL_WR
    input   wire  [PIPE_DATA_WIDTH-1:0]     TL2DLL_data_i,
    input   wire  [2:0]                     TL2DLL_en_i,
    output  wire  [RETRY_DEPTH_LG2-1:0]     retry_buffer_leftover_cnt_o,        // DW

    // DLL_RD --> TL
    output  wire  [PIPE_DATA_WIDTH-1:0]     DLL2TL_data_o,
    output  wire  [2:0]                     DLL2TL_en_o,

    input   wire  [CREDIT_DEPTH-1:0]        rc_cc_p_h_i,                           // Posted(Write) header credit consumed
    input   wire  [CREDIT_DEPTH-1:0]        rc_cc_p_d_i,                           // Posted(Write) data credit consumed
    input   wire  [CREDIT_DEPTH-1:0]        rc_cc_np_h_i,                          // Non-Posted(Read) header credit consumed
    input   wire  [CREDIT_DEPTH-1:0]        rc_cc_cpl_h_i,                         // Completion credit header consumed
    input   wire  [CREDIT_DEPTH-1:0]        rc_cc_cpl_d_i,                         // Completion credit data consumed
    output   wire [CREDIT_DEPTH-1:0]        ep_cc_p_h_o,
    output   wire                           ep_cc_p_h_en_o,
    output   wire [CREDIT_DEPTH-1:0]        ep_cc_p_d_o,
    output   wire                           ep_cc_p_d_en_o,
    output   wire [CREDIT_DEPTH-1:0]        ep_cc_np_h_o,
    output   wire                           ep_cc_np_h_en_o,
    output   wire [CREDIT_DEPTH-1:0]        ep_cc_cpl_h_o,
    output   wire                           ep_cc_cpl_h_en_o,
    output   wire [CREDIT_DEPTH-1:0]        ep_cc_cpl_d_o,
    output   wire                           ep_cc_cpl_d_en_o,
    output   wire [CREDIT_DEPTH-1:0]        ep_cl_p_h_o,
    output   wire [CREDIT_DEPTH-1:0]        ep_cl_p_d_o,
    output   wire [CREDIT_DEPTH-1:0]        ep_cl_np_h_o,
    output   wire [CREDIT_DEPTH-1:0]        ep_cl_cpl_h_o,
    output   wire [CREDIT_DEPTH-1:0]        ep_cl_cpl_d_o,

    // PIPE Interface
    output  wire  [PIPE_DATA_WIDTH-1:0]     pipe_txdata_o,
    output  wire                            pipe_txvalid_o,
    input   wire  [PIPE_DATA_WIDTH-1:0]     pipe_rxdata_i,
    input   wire                            pipe_rxvalid_i
);


DLL_WR #(
    .PIPE_DATA_WIDTH                    (PIPE_DATA_WIDTH),             // 필요시 다른 값으로 수정
    .RETRY_DEPTH_LG2                    (RETRY_DEPTH_LG2),
    .OUTSTANDING_BITS                   (16)
) u_dll_wr(
    // SYSTEM Signal
    .sclk                               (sclk),
    .srst_n                             (srst_n),
    // TL
    .data_i                             (TL2DLL_data_i),
    .tl_d_en_i                          (TL2DLL_en_i),
    .retry_buffer_leftover_cnt_o        (retry_buffer_leftover_cnt_o),

    // DLL_RD
    .DLCMSM_i                           (),
    .data_DLLP_i                        (),
    .DLLP_valid_i                       (),
    .DLLP_ready_o                       (),
    .acknak_seq_num_i                   (),
    .acknak_seq_en_i                    (),

    // PIPE Interface
    .data_o                             (pipe_txdata_o),
    .data_valid_o                       (pipe_txvalid_o)
);


DLL_RD #(


) u_dll_rd (

);



endmodule


