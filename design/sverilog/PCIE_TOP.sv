module PCIE_TOP #(
    parameter integer AXI_ID_WIDTH              = 4,
    parameter integer AXI_ADDR_WIDTH            = 64,
    parameter integer MAX_READ_REQ_SIZE         = 512,
    parameter integer MAX_PAYLOAD_SIZE          = 128,
    parameter integer READ_COMPLETION_BOUNDARY  = 128,
    parameter integer RX_DEPTH_LG2              = 4,
    parameter integer TX_DEPTH_LG2              = 3,
    parameter integer RETRY_DEPTH_LG2           = 8,

    parameter integer PIPE_DATA_WIDTH           = 256,  // Data width for PIPE interface
    parameter integer CREDIT_DEPTH              = 12   // Depth for credit management
)
(

    // ---- System Signals ----
    input   wire                                clk,
    input   wire                                rst_n,

    // ---- PCIE Configuration ----
    input   wire [15:0]                         config_bdf_i,

    // ---- PIPE Interface ----
    inout  wire [PIPE_DATA_WIDTH-1:0]           pipe_txdata,
    inout  wire                                 pipe_txvalid,
    inout  wire [PIPE_DATA_WIDTH-1:0]           pipe_rxdata,
    inout  wire                                 pipe_rxvalid,

    // *** AXI Ports ***

    // AXI Master
    ref  AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) aw_if_master,
    ref  AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) ar_if_master,
    ref  AXI4_W_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) w_if_master,
    ref  AXI4_R_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) r_if_master,
    ref  AXI4_B_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) b_if_master,

    // AXI Slave
    ref  AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) aw_if_slave,
    ref  AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) ar_if_slave,
    ref  AXI4_W_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) w_if_slave,
    ref  AXI4_R_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) r_if_slave,
    ref  AXI4_B_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) b_if_slave
);

typedef enum logic [2:0] {
    IDLE,
    P_HDR,
    P_DATA,
    NP_HDR,
    RESERVED,
    CPL_HDR,
    CPL_DATA,
    DONE
} req_t;


wire [RETRY_DEPTH_LG2-1:0]         retry_buffer_leftover_cnt_w;
wire [PIPE_DATA_WIDTH-1:0]         tl2dll_data_w;
req_t                              tl2dll_data_en_w;
wire [PIPE_DATA_WIDTH-1:0]         dll2tl_data_w;
req_t                              dll2tl_data_en_w;



// TL --> DLL Interface
wire [CREDIT_DEPTH-1:0]            cc_p_h_o;                // Posted header credit consumed
wire [CREDIT_DEPTH-1:0]            cc_p_d_o;                // Posted data credit consumed
wire [CREDIT_DEPTH-1:0]            cc_np_h_o;               // Non-posted header credit consumed
wire [CREDIT_DEPTH-1:0]            cc_cpl_h_o;              // Completion header credit consumed
wire [CREDIT_DEPTH-1:0]            cc_cpl_d_o;              // Completion data credit consumed

// DLL --> TL Interface
wire [CREDIT_DEPTH-1:0]            ep_cc_p_h_o;             // Endpoint Posted header credit consumed
wire [CREDIT_DEPTH-1:0]            ep_cc_p_d_o;             // Endpoint Posted data credit consumed
wire [CREDIT_DEPTH-1:0]            ep_cc_np_h_o;            // Endpoint Non-posted header credit consumed
wire [CREDIT_DEPTH-1:0]            ep_cc_cpl_h_o;           // Endpoint Completion header credit consumed
wire [CREDIT_DEPTH-1:0]            ep_cc_cpl_d_o;           // Endpoint Completion data credit consumed
wire                               ep_cc_p_en_o;            // Endpoint Posted credit enable
wire                               ep_cc_np_en_o;           // Endpoint Non-posted credit enable
wire                               ep_cc_cpl_en_o;          // Endpoint Completion credit enable

wire [CREDIT_DEPTH-1:0]            ep_cl_p_h_o;             // Endpoint Posted header credit limit
wire [CREDIT_DEPTH-1:0]            ep_cl_p_d_o;             // Endpoint Posted data credit limit
wire [CREDIT_DEPTH-1:0]            ep_cl_np_h_o;            // Endpoint Non-posted header credit limit
wire [CREDIT_DEPTH-1:0]            ep_cl_cpl_h_o;           // Endpoint Completion header credit limit
wire [CREDIT_DEPTH-1:0]            ep_cl_cpl_d_o;           // Endpoint Completion data credit limit
wire [2:0]                         ep_cl_en_o;              // Endpoint credit limit enable

TL_TOP #(
    .AXI_ID_WIDTH                 (AXI_ID_WIDTH),               // example: 4
    .AXI_ADDR_WIDTH               (AXI_ADDR_WIDTH),             // example: 64
    .MAX_READ_REQ_SIZE            (MAX_READ_REQ_SIZE),          // example: 512
    .MAX_PAYLOAD_SIZE             (MAX_PAYLOAD_SIZE),           // example: 128
    .READ_COMPLETION_BOUNDARY     (READ_COMPLETION_BOUNDARY),   // example: 128
    .RX_DEPTH_LG2                 (RX_DEPTH_LG2),               // example: 4
    .TX_DEPTH_LG2                 (TX_DEPTH_LG2),               // example: 3
    .RETRY_DEPTH_LG2              (RETRY_DEPTH_LG2)             // example: 8
) u_tl_top (
    // SYSTEM
    .clk                          (clk),                        // input
    .rst_n                        (rst_n),                      // input, active-low

    .config_bdf_i                 (config_bdf_i),               // input [15:0]

    // AXI Master Interfaces (ref)
    .aw_if_master                 (aw_if_master),               // AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)
    .ar_if_master                 (ar_if_master),               // AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)
    .w_if_master                  (w_if_master),                // AXI4_W_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)
    .r_if_master                  (r_if_master),                // AXI4_R_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)
    .b_if_master                  (b_if_master),                // AXI4_B_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)

    // AXI Slave Interfaces (ref)
    .aw_if_slave                  (aw_if_slave),                // AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)
    .ar_if_slave                  (ar_if_slave),                // AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)
    .w_if_slave                   (w_if_slave),                 // AXI4_W_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)
    .r_if_slave                   (r_if_slave),                 // AXI4_R_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)
    .b_if_slave                   (b_if_slave),                 // AXI4_B_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH)

    // TLP Interface
    .tlp_o                        (tl2dll_data_w),              // output [255:0]
    .req_o                        (tl2dll_data_en_w),           // output [2:0]
    .tlp_i                        (dll2tl_data_w),              // input [255:0]
    .req_i                        (dll2tl_data_en_w),           // input [2:0]

    // Tx Credit Consumed
    .cc_ph_i                      (ep_cc_p_h_o),                // input [11:0]
    .cc_pd_i                      (ep_cc_p_d_o),                // input [11:0]
    .cc_p_en_i                    (ep_cc_p_en_o),               // input
    .cc_nh_i                      (ep_cc_np_h_o),               // input [11:0]
    .cc_np_en_i                   (ep_cc_np_en_o),              // input
    .cc_ch_i                      (ep_cc_cpl_h_o),              // input [11:0]
    .cc_cd_i                      (ep_cc_cpl_d_o),              // input [11:0]
    .cc_cpl_en_i                  (ep_cc_cpl_en_o),             // input

    // Tx Credit Limit
    .cl_ph_i                      (ep_cl_p_h_o),                // input [11:0]
    .cl_pd_i                      (ep_cl_p_d_o),                // input [11:0]
    .cl_nh_i                      (ep_cl_np_h_o),               // input [11:0]
    .cl_ch_i                      (ep_cl_cpl_h_o),              // input [11:0]
    .cl_cd_i                      (ep_cl_cpl_d_o),              // input [11:0]

    // Rx Credit Consumed
    .cc_ph_o                      (cc_p_h_o),                   // output [11:0]
    .cc_pd_o                      (cc_p_d_o),                   // output [11:0]
    .cc_nh_o                      (cc_np_h_o),                  // output [11:0]
    .cc_ch_o                      (cc_cpl_h_o),                 // output [11:0]
    .cc_cd_o                      (cc_cpl_d_o),                 // output [11:0]

    // Retry Monitor
    .retry_buffer_leftover_cnt_i (retry_buffer_leftover_cnt_w),  // output [RETRY_DEPTH_LG2-1:0]

    // Link Active
    .link_active_i                (ep_cl_en_o)                 // input
);



DLL_TOP #(
    .PIPE_DATA_WIDTH                 (PIPE_DATA_WIDTH),         // e.g., 256
    .RETRY_DEPTH_LG2                 (RETRY_DEPTH_LG2),         // e.g., 8
    .CREDIT_DEPTH                    (CREDIT_DEPTH)             // e.g., 12
) u_dll_top (
    // SYSTEM
    .sclk                            (clk),                     // input
    .srst_n                          (rst_n),                   // input (active-low)

    // TL --> DLL_WR
    .tl2dll_data_i                   (tl2dll_data_w),                       // input  [PIPE_DATA_WIDTH-1:0]
    .tl2dll_en_i                     (tl2dll_data_en_w),                    // input  [2:0]
    .retry_buffer_leftover_cnt_o     (retry_buffer_leftover_cnt_w),         // output [RETRY_DEPTH_LG2-1:0]

    // DLL_RD <-- TL (Consumed Credit)
    .cc_p_h_i                        (cc_p_h_o),                // input  [CREDIT_DEPTH-1:0] : Posted header
    .cc_p_d_i                        (cc_p_d_o),                // input  [CREDIT_DEPTH-1:0] : Posted data
    .cc_np_h_i                       (cc_np_h_o),               // input  [CREDIT_DEPTH-1:0] : Non-posted header
    .cc_cpl_h_i                      (cc_cpl_h_o),              // input  [CREDIT_DEPTH-1:0] : Completion header
    .cc_cpl_d_i                      (cc_cpl_d_o),              // input  [CREDIT_DEPTH-1:0] : Completion data

    // DLL_RD --> TL (Output TLP)
    .dll2tl_data_o                   (dll2tl_data_w),           // output [PIPE_DATA_WIDTH-1:0]
    .dll2tl_data_en_o                (dll2tl_data_en_w),        // output [2:0]

    // DLL_RD --> TL (Endpoint Credit Consumed)
    .ep_cc_p_h_o                     (ep_cc_p_h_o),             // output [CREDIT_DEPTH-1:0]
    .ep_cc_p_d_o                     (ep_cc_p_d_o),             // output [CREDIT_DEPTH-1:0]
    .ep_cc_p_en_o                    (ep_cc_p_en_o),            // output
    .ep_cc_np_h_o                    (ep_cc_np_h_o),            // output [CREDIT_DEPTH-1:0]
    .ep_cc_np_en_o                   (ep_cc_np_en_o),           // output
    .ep_cc_cpl_h_o                   (ep_cc_cpl_h_o),           // output [CREDIT_DEPTH-1:0]
    .ep_cc_cpl_d_o                   (ep_cc_cpl_d_o),           // output [CREDIT_DEPTH-1:0]
    .ep_cc_cpl_en_o                  (ep_cc_cpl_en_o),          // output

    // DLL_RD --> TL (Endpoint Credit Limit)
    .ep_cl_p_h_o                    (ep_cl_p_h_o),              // output [CREDIT_DEPTH-1:0]
    .ep_cl_p_d_o                    (ep_cl_p_d_o),              // output [CREDIT_DEPTH-1:0]
    .ep_cl_np_h_o                   (ep_cl_np_h_o),             // output [CREDIT_DEPTH-1:0]
    .ep_cl_cpl_h_o                  (ep_cl_cpl_h_o),            // output [CREDIT_DEPTH-1:0]
    .ep_cl_cpl_d_o                  (ep_cl_cpl_d_o),            // output [CREDIT_DEPTH-1:0]
    .ep_cl_en_o                     (ep_cl_en_o),               // output

    // PIPE Interface
    .pipe_txdata_o                  (pipe_txdata),               // output [PIPE_DATA_WIDTH-1:0]
    .pipe_txvalid_o                 (pipe_txvalid),              // output
    .pipe_rxdata_i                  (pipe_rxdata),               // input  [PIPE_DATA_WIDTH-1:0]
    .pipe_rxvalid_i                 (pipe_rxvalid)               // input
);

endmodule
