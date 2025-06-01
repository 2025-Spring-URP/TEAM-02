// Trial
// Wongi Choi (cwg43352@g.skku.edu)

module TL_TOP #(
    parameter AXI_ID_WIDTH     = 4,
    parameter AXI_ADDR_WIDTH   = 64,
    parameter MAX_READ_REQ_SIZE         = 512,
    parameter MAX_PAYLOAD_SIZE          = 128,
    parameter READ_COMPLETION_BOUNDARY  = 128,
    parameter RX_DEPTH_LG2      = 4,
    parameter TX_DEPTH_LG2      = 3,
    parameter RETRY_DEPTH_LG2   = 8
)
(
    input   wire            clk,
    input   wire            rst_n,

    input   wire [15:0]     config_bdf_i,

    // *** AXI Ports

    // AXI Master
    AXI4_A_IF aw_if_master,
    AXI4_A_IF ar_if_master,
    AXI4_W_IF w_if_master,
    AXI4_R_IF r_if_master,
    AXI4_B_IF b_if_master,

    // AXI Slave
    AXI4_A_IF aw_if_slave,
    AXI4_A_IF ar_if_slave,
    AXI4_W_IF w_if_slave,
    AXI4_R_IF r_if_slave,
    AXI4_B_IF b_if_slave,

    // *** TL-DLL Transaction

    // TLP Input/Output
    output  wire    [255:0]     tlp_o,
    output  wire    [2:0]       req_o,

    input   wire    [255:0]     tlp_i,
    input   wire    [2:0]       req_i,

    // UpdateFC from DLL, Rx Credit Consumed
    output  wire    [11:0]  cc_ph_o,
    output  wire    [11:0]  cc_pd_o,
    input   wire            updatefc_p_i,
    output  wire    [11:0]  cc_nh_o,
    input   wire            updatefc_np_i,
    output  wire    [11:0]  cc_ch_o,
    output  wire    [11:0]  cc_cd_o,
    input   wire            updatefc_cpl_i,
    
    // Credit Limit from DLL - InitFC
    input   wire    [11:0]  cl_ph_i,
    input   wire    [11:0]  cl_pd_i,
    input   wire    [11:0]  cl_nh_i,
    input   wire    [11:0]  cl_ch_i,
    input   wire    [11:0]  cl_cd_i,
    input   wire            cl_en_i,

    // Credit Consumed from DLL - UpdateFC
    input   wire    [11:0]  cc_ph_i,
    input   wire    [11:0]  cc_pd_i,
    input   wire            cc_p_en_i,
    input   wire    [11:0]  cc_nh_i,
    input   wire            cc_np_en_i,
    input   wire    [11:0]  cc_ch_i,
    input   wire    [11:0]  cc_cd_i,
    input   wire            cc_cpl_en_i,

    // Retry Buffer Leftover Count, Unit: DW
    input  wire  [RETRY_DEPTH_LG2+2:0] retry_buffer_leftover_cnt_i,

    // Link Status
    input  wire             link_active_i

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

    // Internal Wires
    
    // P Header FIFO related
    wire                p_hdr_full;
    wire [127:0]        p_hdr_rdata;
    wire                p_hdr_rden; 
    wire                p_hdr_empty;

    // P Data FIFO related
    wire                p_data_full;
    wire [255:0]        p_data_rdata;
    wire                p_data_rden;
    wire                p_data_empty;

    // NP Header FIFO related
    wire                np_hdr_full;
    wire [127:0]        np_hdr_rdata;
    wire                np_hdr_rden;   
    wire                np_hdr_empty;

    // Completion Header FIFO related
    wire                cpl_hdr_empty;
    wire [95:0]         cpl_hdr_rdata;
    wire                cpl_hdr_rden;
    wire                cpl_hdr_full;

    // Completion Data FIFO related
    wire                cpl_data_empty;
    wire [255:0]        cpl_data_rdata;
    wire                cpl_data_rden;
    wire                cpl_data_full;

    // Payload counters
    wire [TX_DEPTH_LG2-1:0]  p_payload_cnt;  // TL_AXI_SLAVE.tx → TL_FLOW_CONTROL.rx
    wire                     p_sent;         // TL_FLOW_CONTROL.tx → TL_AXI_SLAVE.rx

    wire [TX_DEPTH_LG2-1:0]  cpl_payload_cnt; // TL_FLOW_CONTROL.tx → TL_AXI_SLAVE.rx
    wire                     cpl_sent;        // TL_FLOW_CONTROL.tx → TL_AXI_SLAVE.rx



    TL_AXI_MASTER #(
        .AXI_ID_WIDTH                (AXI_ID_WIDTH),
        .AXI_ADDR_WIDTH              (AXI_ADDR_WIDTH),
        .MAX_READ_REQ_SIZE           (MAX_READ_REQ_SIZE),
        .MAX_PAYLOAD_SIZE            (MAX_PAYLOAD_SIZE),
        .READ_COMPLETION_BOUNDARY    (READ_COMPLETION_BOUNDARY),
        .RX_DEPTH_LG2                (RX_DEPTH_LG2),
        .TX_DEPTH_LG2                (TX_DEPTH_LG2)
    ) u_tl_axi_master (
        .clk                         (clk),
        .rst_n                       (rst_n),
        .config_bdf_i                (config_bdf_i),
        // AXI Master (AW, AR, W, R, B)

        // AXI Write Address Channel
        .aw_if                       (aw_if_master),
        // AXI Read Address Channel
        .ar_if                       (ar_if_master),
        // AXI Write Channel
        .w_if                        (w_if_master),
        // AXI Read Channel
        .r_if                        (r_if_master),
        // AXI Write Response Channel
        .b_if                        (b_if_master),
        // FIFOs (NPhdr, Phdr, Pdata, Cplhdr, Cpldata)
        // Rx P Header FIFO
        .p_hdr_full_o                (p_hdr_full),
        .p_hdr_wdata_i               (tlp_i[127:0]),
        .p_hdr_wren_i                (req_i == P_HDR),
        .p_hdr_rden_o                (p_hdr_rden),
        // Rx P Data FIFO
        .p_data_full_o               (p_data_full),
        .p_data_wdata_i              (tlp_i),
        .p_data_wren_i               (req_i == P_DATA),
        .p_data_rden_o               (p_data_rden),
        // Rx NP Header FIFO
        .np_hdr_full_o               (np_hdr_full),
        .np_hdr_wdata_i              (tlp_i[127:0]),
        .np_hdr_wren_i               (req_i == NP_HDR),
        .np_hdr_rden_o               (np_hdr_rden),
        // Tx Cpl Header FIFO
        .cpl_hdr_empty_o             (cpl_hdr_empty),
        .cpl_hdr_rdata_o             (cpl_hdr_rdata),
        .cpl_hdr_rden_i              (cpl_hdr_rden),
        // Tx Cpl Header FIFO
        .cpl_data_empty_o            (cpl_data_empty),
        .cpl_data_rdata_o            (cpl_data_rdata),
        .cpl_data_rden_i             (cpl_data_rden),
        // Tx Cpl Payload Counter
        .cpl_payload_cnt_o           (cpl_payload_cnt),
        .cpl_sent_i                  (cpl_sent)
    );

    TL_AXI_SLAVE #(
        .AXI_ID_WIDTH                (AXI_ID_WIDTH),
        .AXI_ADDR_WIDTH              (AXI_ADDR_WIDTH),
        .MAX_READ_REQ_SIZE           (MAX_READ_REQ_SIZE),
        .MAX_PAYLOAD_SIZE            (MAX_PAYLOAD_SIZE),
        .READ_COMPLETION_BOUNDARY    (READ_COMPLETION_BOUNDARY),
        .RX_DEPTH_LG2                (RX_DEPTH_LG2),
        .TX_DEPTH_LG2                (TX_DEPTH_LG2)
    ) u_tl_axi_slave (
        .clk                         (clk),
        .rst_n                       (rst_n),
        .config_bdf_i                (config_bdf_i),
        // AXI Slave (AW, AR, W, R, B)

        // AXI Write Address Channel
        .aw_if                       (aw_if_slave),
        // AXI Read Address Channel
        .ar_if                       (ar_if_slave),
        // AXI Write Channel
        .w_if                        (w_if_slave),
        // AXI Read Channel
        .r_if                        (r_if_slave),
        // AXI Write Response Channel
        .b_if                        (b_if_slave),
        // FIFOs (NPhdr, Phdr, Pdata, Cplhdr, Cpldata)
        // Tx NP Header FIFO
        .np_hdr_empty_o              (np_hdr_empty),
        .np_hdr_rdata_o              (np_hdr_rdata),
        .np_hdr_rden_i               (np_hdr_rden),
        // Tx P Header FIFO
        .p_hdr_empty_o               (p_hdr_empty),
        .p_hdr_rdata_o               (p_hdr_rdata),
        .p_hdr_rden_i                (p_hdr_rden),
        // Tx P Data FIFO
        .p_data_empty_o              (p_data_empty),
        .p_data_rdata_o              (p_data_rdata),
        .p_data_rden_i               (p_data_rden),
        // Tx P Payload Counter
        .p_payload_cnt_o             (p_payload_cnt),
        .p_sent_i                    (p_sent),
        // Rx Cpl Header FIFO
        .cpl_hdr_full_o              (cpl_hdr_full),
        .cpl_hdr_wdata_i             (tlp_i[95:0]),
        .cpl_hdr_wren_i              (req_i == CPL_HDR),
        .cpl_hdr_rden_o              (cpl_hdr_rden),
        // Rx Cpl Data FIFO
        .cpl_data_full_o             (cpl_data_full),
        .cpl_data_wdata_i            (tlp_i),
        .cpl_data_wren_i             (req_i == CPL_DATA),
        .cpl_data_rden_o             (cpl_data_rden)
    );

    TL_FLOW_CONTROL #(
        .TX_DEPTH_LG2                   (3),
        .RETRY_DEPTH_LG2                (8)
    ) u_TL_FLOW_CONTROL (
        .clk                            (clk),
        .rst_n                          (rst_n),
        // ** Tx FIFOs

        // Posted Header
        .p_hdr_empty_i                  (p_hdr_empty),
        .p_hdr_rdata_i                  (p_hdr_rdata),
        .p_hdr_rden_o                   (p_hdr_rden),
        // Posted Data
        .p_data_empty_i                 (p_data_empty),
        .p_data_rdata_i                 (p_data_rdata),
        .p_data_rden_o                  (p_data_rden),
        // Non-Posted Header
        .np_hdr_empty_i                 (np_hdr_empty),
        .np_hdr_rdata_i                 (np_hdr_rdata),
        .np_hdr_rden_o                  (np_hdr_rden),
        // Posted TLP Payload Count
        .p_payload_cnt_i                (p_payload_cnt),
        .p_sent_o                       (p_sent),
        // Completion Header
        .cpl_hdr_empty_i                (cpl_hdr_empty),
        .cpl_hdr_rdata_i                (cpl_hdr_rdata),
        .cpl_hdr_rden_o                 (cpl_hdr_rden),
        // Completion Data
        .cpl_data_empty_i               (cpl_data_empty),
        .cpl_data_rdata_i               (cpl_data_rdata),
        .cpl_data_rden_o                (cpl_data_rden),
        // Completion TLP Payload Count
        .cpl_payload_cnt_i              (cpl_payload_cnt),
        .cpl_sent_o                     (cpl_sent),
        // ** Rx FIFOs
        .p_hdr_rden_i                   (p_hdr_rden),
        .p_data_rden_i                  (p_data_rden),
        .np_hdr_rden_i                  (np_hdr_rden),
        .cpl_hdr_rden_i                 (cpl_hdr_rden),
        .cpl_data_rden_i                (cpl_data_rden),
        // UpdateFC from DLL, Credit Consumed
        .cc_ph_o                        (cc_ph_o),
        .cc_pd_o                        (cc_pd_o),
        .updatefc_p_i                   (updatefc_p_i),
        .cc_nh_o                        (cc_nh_o),
        .updatefc_np_i                  (updatefc_np_i),
        .cc_ch_o                        (cc_ch_o),
        .cc_cd_o                        (cc_cd_o),
        .updatefc_cpl_i                 (updatefc_cpl_i),
        // Credit Limit from DLL - InitFC
        .cl_ph_i                        (cl_ph_i),
        .cl_pd_i                        (cl_pd_i),
        .cl_nh_i                        (cl_nh_i),
        .cl_ch_i                        (cl_ch_i),
        .cl_cd_i                        (cl_cd_i),
        .cl_en_i                        (cl_en_i),
        // Credit Consumed Return from DLL - UpdateFC
        .cc_ph_i                        (cc_ph_i),
        .cc_pd_i                        (cc_pd_i),
        .cc_p_en_i                      (cc_p_en_i),
        .cc_nh_i                        (cc_nh_i),
        .cc_np_en_i                     (cc_np_en_i),
        .cc_ch_i                        (cc_ch_i),
        .cc_cd_i                        (cc_cd_i),
        .cc_cpl_en_i                    (cc_cpl_en_i),
        // Retry Buffer Leftover Count, Unit: DW
        .retry_buffer_leftover_cnt_i    (retry_buffer_leftover_cnt_i),
        // DLL Output
        .tlp_o                          (tlp_o),
        // 256-bit TLP DW
        .req_o                          (req_o),
        // 3-bit Req code

        // Link Status
        .link_active_i                  (link_active_i)
    );

endmodule
