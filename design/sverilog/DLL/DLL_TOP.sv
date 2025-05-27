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
    input   wire  [PIPE_DATA_WIDTH-1:0]     tl2dll_data_i,
    input   wire  [2:0]                     tl2dll_en_i,
    output  wire  [RETRY_DEPTH_LG2+2:0]     retry_buffer_leftover_cnt_o,        // DW

    // DLL_RD --> TL
	input wire      [CREDIT_DEPTH-1:0]      cc_p_h_i,		        // Posted(Write) header credit consumed
    input wire      [CREDIT_DEPTH-1:0]      cc_p_d_i,		        // Posted(Write) data credit consumed
	input wire      [CREDIT_DEPTH-1:0]      cc_np_h_i,		    // Non-Posted(Read) header credit consumed
    input wire      [CREDIT_DEPTH-1:0]      cc_np_d_i,		    // Non-Posted(Read) data credit consumed
	input wire      [CREDIT_DEPTH-1:0]      cc_cpl_h_i,	        // Completion credit header consumed
    input wire      [CREDIT_DEPTH-1:0]      cc_cpl_d_i,           // Completion credit data consumed

	output wire     [PIPE_DATA_WIDTH-1:0]   dll2tl_data_o,
    output wire     [2:0]                   dll2tl_data_en_o,
    
    output wire     [CREDIT_DEPTH-1:0]      ep_cc_p_h_o,
    output wire     [CREDIT_DEPTH-1:0]      ep_cc_p_d_o,
	output wire                             ep_cc_p_en_o,

    output wire     [CREDIT_DEPTH-1:0]      ep_cc_np_h_o,
    output wire                             ep_cc_np_en_o,

    output wire     [CREDIT_DEPTH-1:0]      ep_cc_cpl_h_o,
    output wire     [CREDIT_DEPTH-1:0]      ep_cc_cpl_d_o,
    output wire                             ep_cc_cpl_en_o,
	
    output wire     [CREDIT_DEPTH-1:0]      ep_cl_p_h_o,
    output wire     [CREDIT_DEPTH-1:0]      ep_cl_p_d_o,
    output wire     [CREDIT_DEPTH-1:0]      ep_cl_np_h_o,
    output wire     [CREDIT_DEPTH-1:0]      ep_cl_cpl_h_o,
    output wire     [CREDIT_DEPTH-1:0]      ep_cl_cpl_d_o,
	output wire                             ep_cl_en_o,

    // PIPE Interface
    output  wire  [PIPE_DATA_WIDTH-1:0]     pipe_txdata_o,
    output  wire                            pipe_txvalid_o,
    input   wire  [PIPE_DATA_WIDTH-1:0]     pipe_rxdata_i,
    input   wire                            pipe_rxvalid_i
);


localparam [2:0]                        IDLE        = 3'b000,
                                        P_HDR       = 3'b001,
                                        P_DATA      = 3'b010,
                                        NP_HDR      = 3'b011,
                                        RESERVED    = 3'b100,
                                        CPL_HDR     = 3'b101,
                                        CPL_DATA    = 3'b110,
                                        DONE        = 3'b111;



wire [1:0]                              DLCMSM_w; 
wire                                    dllp_valid_w;
wire [PIPE_DATA_WIDTH-1:0]              dllp_data_w;
wire                                    dllp_ready_w;
wire [1:0]                              acknak_seq_num_w; // 2 bits for ACK/NAK sequence number
wire [1:0]                              acknak_seq_en_w;  // 2 bits for ACK/NAK sequence enable

wire [1:0]                              tl2dll_en_w;

always_comb begin
    case(tl2dll_en_i)
    IDLE: begin
        tl2dll_en_w = 2'b00; // IDLE state
    end
    P_HDR: begin
        tl2dll_en_w = 2'b01; // Posted Header
    end
    P_DATA: begin
        tl2dll_en_w = 2'b10; // Posted Data
    end
    NP_HDR: begin
        tl2dll_en_w = 2'b01; // Non-Posted Header
    end
    RESERVED: begin
        tl2dll_en_w = 2'b10; // Reserved state, no operation
    end
    CPL_HDR: begin
        tl2dll_en_w = 2'b01; // Completion Headere
    end
    CPL_DATA: begin
        tl2dll_en_w = 2'b10; // Completion Data
    end
    DONE: begin
        tl2dll_en_w = 2'b11; // Done state, no operation
    end
    endcase
end




DLL_WR #(
    .PIPE_DATA_WIDTH                    (PIPE_DATA_WIDTH),             // 필요시 다른 값으로 수정
    .RETRY_DEPTH_LG2                    (RETRY_DEPTH_LG2),
    .OUTSTANDING_BITS                   (16)
) u_dll_wr(
    // SYSTEM Signal
    .sclk                               (sclk),
    .srst_n                             (srst_n),
    // TL
    .data_i                             (tl2dll_data_i),
    .tl_d_en_i                          (tl2dll_en_w),
    .retry_buffer_leftover_cnt_o        (retry_buffer_leftover_cnt_o),

    // DLL_RD
    .DLCMSM_i                           (DLCMSM_w), // input [1:0]
    .data_DLLP_i                        (dllp_data_w),
    .DLLP_valid_i                       (dllp_valid_w),
    .DLLP_ready_o                       (dllp_ready_w),
    .acknak_seq_num_i                   (acknak_seq_num_w),
    .acknak_seq_en_i                    (acknak_seq_en_w),

    // PIPE Interface
    .data_o                             (pipe_txdata_o),
    .data_valid_o                       (pipe_txvalid_o)
);


DLL_RD u_dll_rd (
    .sclk                               (sclk),  // input
    .srst_n                             (srst_n),  // input

    // Transaction Layer - Consumed Credit
    .cc_p_h_i                           (cc_p_h_i),  // input  [11:0]
    .cc_p_d_i                           (cc_p_d_i),  // input  [11:0]
    .cc_np_h_i                          (cc_np_h_i),  // input  [11:0]
    //.cc_np_d_i                          (cc_np_d_i),  // input  [11:0]
    .cc_cpl_h_i                         (cc_cpl_h_i),  // input  [11:0]
    .cc_cpl_d_i                         (cc_cpl_d_i),  // input  [11:0]

    // TL Data Out
    .dll2tl_data_o                      (dll2tl_data_o),  // output [255:0]
    .dll2tl_data_en_o                   (dll2tl_data_en_o),  // output [2:0]

    // Endpoint Credit Consumed
    .ep_cc_p_h_o                        (ep_cc_p_h_o),  // output [11:0]
    .ep_cc_p_d_o                        (ep_cc_p_d_o),  // output [11:0]
    .ep_cc_p_en_o                       (ep_cc_p_en_o),  // output

    .ep_cc_np_h_o                       (ep_cc_np_h_o),  // output [11:0]
    .ep_cc_np_en_o                      (ep_cc_np_en_o),  // output

    .ep_cc_cpl_h_o                      (ep_cc_cpl_h_o),  // output [11:0]
    .ep_cc_cpl_d_o                      (ep_cc_cpl_d_o),  // output [11:0]
    .ep_cc_cpl_en_o                     (ep_cc_cpl_en_o),  // output

    // Endpoint Credit Limit
    .ep_cl_p_h_o                        (ep_cl_p_h_o),  // output [11:0]
    .ep_cl_p_d_o                        (ep_cl_p_d_o),  // output [11:0]
    .ep_cl_np_h_o                       (ep_cl_np_h_o),  // output [11:0]
    .ep_cl_cpl_h_o                      (ep_cl_cpl_h_o),  // output [11:0]
    .ep_cl_cpl_d_o                      (ep_cl_cpl_d_o),  // output [11:0]
    .ep_cl_en_o                         (ep_cl_en_o),  // output

    // Arbiter
    .arb_ready_i                        (dllp_ready_w),  // input

    // DLLP Output
    .dllp_valid_o                       (dllp_valid_w),  // output
    .dllp_data_o                        (dllp_data_w),  // output [255:0]

    // Retry Monitor
    .acknak_seq_num_o                   (acknak_seq_num_w),  // output [15:0]
    .acknak_seq_en_o                    (acknak_seq_en_w),  // output [1:0]

    // State
    .dlcm_state                         (DLCMSM_w),   // output [1:0]

    // PIPE -> DLL
    .pipe2dll_valid_i                   (pipe_rxvalid_i),  // input
    .pipe2dll_data_i                    (pipe_rxdata_i)  // input [255:0]
);


endmodule
