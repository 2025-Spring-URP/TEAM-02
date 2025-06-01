// Trial
// Wongi Choi (cwg43352@g.skku.edu)

module TL_FLOW_CONTROL #(
    parameter TX_DEPTH_LG2      = 3,
    parameter RETRY_DEPTH_LG2   = 8
)(
    input   wire            clk,
    input   wire            rst_n,

    // ** Tx FIFOs

    // Posted Header
    input   wire            p_hdr_empty_i,
    input   wire    [127:0] p_hdr_rdata_i,
    output  wire            p_hdr_rden_o,
    // Posted Data
    input   wire            p_data_empty_i,
    input   wire    [255:0] p_data_rdata_i,
    output  wire            p_data_rden_o,
    // Non-Posted Header
    input   wire            np_hdr_empty_i,
    input   wire    [127:0] np_hdr_rdata_i,
    output  wire            np_hdr_rden_o,
    // Posted TLP Payload Count
    input   wire    [TX_DEPTH_LG2-1:0]  p_payload_cnt_i,
    output  wire            p_sent_o,
    // Completion Header
    input   wire            cpl_hdr_empty_i,
    input   wire     [95:0] cpl_hdr_rdata_i,
    output  wire            cpl_hdr_rden_o,
    // Completion Data
    input   wire            cpl_data_empty_i,
    input   wire    [255:0] cpl_data_rdata_i,
    output  wire            cpl_data_rden_o,
    // Completion TLP Payload Count
    input   wire    [TX_DEPTH_LG2-1:0]  cpl_payload_cnt_i,
    output  wire            cpl_sent_o,

    // ** Rx FIFOs
    input   wire            p_hdr_rden_i,
    input   wire            p_data_rden_i,
    input   wire            np_hdr_rden_i,
    input   wire            cpl_hdr_rden_i,
    input   wire            cpl_data_rden_i,

    // Credit Consumed Output
    output  wire    [11:0]  cc_ph_o,
    output  wire    [11:0]  cc_pd_o,
    output  wire    [11:0]  cc_nh_o,
    output  wire    [11:0]  cc_ch_o,
    output  wire    [11:0]  cc_cd_o,
    
    // Credit Limit from DLL - InitFC
    input   wire    [11:0]  cl_ph_i,
    input   wire    [11:0]  cl_pd_i,
    input   wire    [11:0]  cl_nh_i,
    input   wire    [11:0]  cl_ch_i,
    input   wire    [11:0]  cl_cd_i,
    input   wire            cl_en_i,

    // Credit Consumed Return from DLL - UpdateFC
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

    // DLL Output
    output  wire    [255:0] tlp_o,     // 256-bit TLP DW
    output  wire      [2:0] req_o,     // 3-bit Req code

    // Link Status
    input  wire             link_active_i
);

    localparam      HEADER_MARGIN = 1 + 1; // 1 header unit, 1 for calc.
    localparam      DATA_MARGIN = 4; // 32B unit

    logic np_hdr_rden, p_hdr_rden, cpl_hdr_rden;
    logic p_data_rden, cpl_data_rden;
    assign np_hdr_rden_o = np_hdr_rden;
    assign p_hdr_rden_o = p_hdr_rden;
    assign cpl_hdr_rden_o = cpl_hdr_rden;
    assign p_data_rden_o = p_data_rden;
    assign cpl_data_rden_o = cpl_data_rden;

    logic   [255:0]     tlp;
    assign tlp_o = tlp;

    logic cpl_sent, p_sent;
    assign cpl_sent_o = cpl_sent;
    assign p_sent_o = p_sent;
    
    req_t fstate, fstate_n;
    assign req_o = fstate;
    logic   [2:0]   pcnt, pcnt_n; // payload count

    PCIE_PKG::tlp_cpl_hdr_t cpl_hdr;
    PCIE_PKG::tlp_memory_req_hdr_t p_hdr;
    assign cpl_hdr = PCIE_PKG::tlp_cpl_hdr_t'(cpl_hdr_rdata_i);
    assign p_hdr = PCIE_PKG::tlp_memory_req_hdr_t'(p_hdr_rdata_i);

    wire [9:0] cpl_hdr_length, p_hdr_length;
    assign p_hdr_length = {p_hdr.length_h, p_hdr.length_l};
    assign cpl_hdr_length = {cpl_hdr.length_h, cpl_hdr.length_l};

    typedef enum logic [2:0] {
        IDLE,
        P_HDR,      P_DATA,
        NP_HDR,     RESERVED,
        CPL_HDR,    CPL_DATA,
        DONE
    } req_t;

    logic [11:0]    ph_limit, pd_limit, nh_limit, ch_limit, cd_limit;
    logic [11:0]    ph_consumed, nh_consumed, ch_consumed;
    logic [11:0]    ph_consumed_n, nh_consumed_n, ch_consumed_n;
    logic [11:0]    pd_consumed, cd_consumed;
    logic [11:0]    pd_consumed_n, cd_consumed_n;

    // ph_cnt, nh_cnt, ch_cnt: count for 1 Header
    // pd_cnt, cd_cnt: count for 32B

    wire [11:0]     ph_available, pd_available, nh_available;
    wire [11:0]     ch_available, cd_available;
    assign ph_available = ph_limit - ph_consumed;
    assign pd_available = pd_limit - pd_consumed;
    assign nh_available = nh_limit - nh_consumed;
    assign ch_available = ch_limit - ch_consumed;
    assign cd_available = cd_limit - cd_consumed;

    always_ff @(posedge clk)
        if (!rst_n) begin
            ph_limit <= 'd0;
            pd_limit <= 'd0;
            nh_limit <= 'd0;
            ch_limit <= 'd0;
            cd_limit <= 'd0;
        end
        else if (cl_en_i) begin
            ph_limit <= cl_ph_i;
            pd_limit <= cl_pd_i;
            nh_limit <= cl_nh_i;
            ch_limit <= cl_ch_i;
            cd_limit <= cl_cd_i;
        end
        else begin
            if (cc_p_en_i) begin
                ph_limit <= ph_limit + cc_ph_i;
                pd_limit <= pd_limit + cc_pd_i;
            end
            if (cc_np_en_i) begin
                nh_limit <= nh_limit + cc_nh_i;
            end
            if (cc_cpl_en_i) begin
                ch_limit <= ch_limit + cc_ch_i;
                cd_limit <= cd_limit + cc_cd_i;
            end
        end
    
    always_ff @(posedge clk)
        if (!rst_n) begin
            fstate <= IDLE;
            pcnt <= 'd0;
            ph_consumed <= 'd0;
            pd_consumed <= 'd0;
            nh_consumed <= 'd0;
            ch_consumed <= 'd0;
            cd_consumed <= 'd0;
        end
        else begin
            fstate <= fstate_n;
            pcnt <= pcnt_n;
            ph_consumed <= ph_consumed_n;
            pd_consumed <= pd_consumed_n;
            nh_consumed <= nh_consumed_n;
            ch_consumed <= ch_consumed_n;
            cd_consumed <= cd_consumed_n;
        end
    
    always_comb begin
        fstate_n = fstate;
        pcnt_n = pcnt;
        ph_consumed_n = ph_consumed;
        pd_consumed_n = pd_consumed;
        nh_consumed_n = nh_consumed;
        ch_consumed_n = ch_consumed;
        cd_consumed_n = cd_consumed;

        p_hdr_rden = 1'b0;
        np_hdr_rden = 1'b0;
        cpl_hdr_rden = 1'b0;
        p_data_rden = 1'b0;
        cpl_data_rden = 1'b0;
        cpl_sent = 1'b0;
        p_sent = 1'b0;
        tlp = 256'd0;

        case (fstate)
        IDLE: begin
            if (~cpl_hdr_empty_i & link_active_i) begin
                if (
                    'd1 < ch_available &
                    (cpl_hdr_length >> 2) < cd_available &
                    cpl_payload_cnt_i != 'd0 &
                    (retry_buffer_leftover_cnt_i >> 3) + (cpl_hdr_length >> 3) + 'd1 < (1 << RETRY_DEPTH_LG2)
                ) begin
                    fstate_n = CPL_HDR;

                    ch_consumed_n = ch_consumed + 'd1;
                    cd_consumed_n = cd_consumed + (cpl_hdr_length >> 2);
                    pcnt_n = (cpl_hdr_length >> 3);
                end
            end
            else if (~p_hdr_empty_i & link_active_i) begin
                if (
                    'd1 < ph_available &
                    (p_hdr_length >> 2) < pd_available &
                    p_payload_cnt_i != 'd0 &
                    (retry_buffer_leftover_cnt_i >> 3) + (p_hdr_length >> 3) + 'd1 < (1 << RETRY_DEPTH_LG2)
                ) begin
                    fstate_n = P_HDR;
                    
                    ph_consumed_n = ph_consumed + 'd1;
                    pd_consumed_n = pd_consumed + (p_hdr_length >> 2);
                    pcnt_n = (p_hdr_length >> 3);
                end
            end
            else if (~np_hdr_empty_i & link_active_i) begin
                if (
                    cc_nh + nh_cnt < cl_nh_i - HEADER_MARGIN &
                    (retry_buffer_leftover_cnt_i >> 3) + 'd1 < (1 << RETRY_DEPTH_LG2)
                ) begin
                    fstate_n = NP_HDR;

                    nh_consumed_n = nh_consumed + 'd1;
                end
            end
        end
        P_HDR: begin
            p_hdr_rden = 1'b1;
            tlp = {128'd0, p_hdr_rdata_i};

            fstate_n = P_DATA;
        end
        P_DATA: begin
            p_data_rden = 1'b1;
            tlp = p_data_rdata_i;

            pcnt_n = pcnt - 'd1;
            
            if (pcnt == 'd1) begin
                fstate_n = DONE;

                p_sent = 1'b1;
            end
        end
        NP_HDR: begin
            np_hdr_rden = 1'b1;
            tlp = {128'd0, np_hdr_rdata_i};

            fstate_n = DONE;
        end
        CPL_HDR: begin
            cpl_hdr_rden = 1'b1;
            tlp = {160'd0, cpl_hdr_rdata_i};

            fstate_n = CPL_DATA;
        end
        CPL_DATA: begin
            cpl_data_rden = 1'b1;
            tlp = cpl_data_rdata_i;

            pcnt_n = pcnt - 'd1;
            
            if (pcnt == 'd1) begin
                fstate_n = DONE;

                cpl_sent = 1'b1;
            end
        end
        DONE: begin
            if (~cpl_hdr_empty_i & link_active_i) begin
                if (
                    'd1 < ch_available &
                    (cpl_hdr_length >> 2) < cd_available &
                    cpl_payload_cnt_i != 'd0 &
                    (retry_buffer_leftover_cnt_i >> 3) + (cpl_hdr_length >> 3) + 'd1 < (1 << RETRY_DEPTH_LG2)
                ) begin
                    fstate_n = CPL_HDR;

                    ch_consumed_n = ch_consumed + 'd1;
                    cd_consumed_n = cd_consumed + (cpl_hdr_length >> 2);
                    pcnt_n = (cpl_hdr_length >> 3);
                end
            end
            else if (~p_hdr_empty_i & link_active_i) begin
                if (
                    'd1 < ph_available &
                    (p_hdr_length >> 2) < pd_available &
                    p_payload_cnt_i != 'd0 &
                    (retry_buffer_leftover_cnt_i >> 3) + (p_hdr_length >> 3) + 'd1 < (1 << RETRY_DEPTH_LG2)
                ) begin
                    fstate_n = P_HDR;
                    
                    ph_consumed_n = ph_consumed + 'd1;
                    pd_consumed_n = pd_consumed + (p_hdr_length >> 2);
                    pcnt_n = (p_hdr_length >> 3);
                end
            end
            else if (~np_hdr_empty_i & link_active_i) begin
                if (
                    cc_nh + nh_cnt < cl_nh_i - HEADER_MARGIN &
                    (retry_buffer_leftover_cnt_i >> 3) + 'd1 < (1 << RETRY_DEPTH_LG2)
                ) begin
                    fstate_n = NP_HDR;

                    nh_consumed_n = nh_consumed + 'd1;
                end
            end
        end
        endcase
    end

    // Credit Returned Counter

endmodule
