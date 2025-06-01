// Trial
// Wongi Choi (cwg43352@g.skku.edu)

module TL_AXI_MASTER #(
    parameter ID_WIDTH     = 4,
    parameter ADDR_WIDTH   = 64,
    parameter MAX_READ_REQ_SIZE = 512,
    parameter MAX_PAYLOAD_SIZE = 128,
    parameter READ_COMPLETION_BOUNDARY = 128,
    parameter RX_DEPTH_LG2 = 4,
    parameter TX_DEPTH_LG2 = 3
)
(
    input   wire            clk,
    input   wire            rst_n,

    input   wire [15:0]     config_bdf_i,

    // AXI Master (AW, AR, W, R, B)

    // AXI Write Address Channel
    AXI4_A_IF aw_if,
    // AXI Read Address Channel
    AXI4_A_IF ar_if,
    // AXI Write Channel
    AXI4_W_IF w_if,
    // AXI Read Channel
    AXI4_R_IF r_if,
    // AXI Write Response Channel
    AXI4_B_IF b_if,
    
    // FIFOs (NPhdr, Phdr, Pdata, Cplhdr, Cpldata)
    
    // Rx P Header FIFO
    output  wire            p_hdr_full_o,
    input   wire    [127:0] p_hdr_wdata_i,
    input   wire            p_hdr_wren_i,
    output  wire            p_hdr_rden_o,

    // Rx P Data FIFO
    output  wire            p_data_full_o,
    input   wire    [255:0] p_data_wdata_i,
    input   wire            p_data_wren_i,
    output  wire            p_data_rden_o,

    // Rx NP Header FIFO
    output  wire            np_hdr_full_o,
    input   wire    [127:0] np_hdr_wdata_i,
    input   wire            np_hdr_wren_i,
    output  wire            np_hdr_rden_o,

    // Tx Cpl Header FIFO
    output  wire            cpl_hdr_empty_o,
    output  wire    [95:0]  cpl_hdr_rdata_o,
    input   wire            cpl_hdr_rden_i,

    // Tx Cpl Header FIFO
    output  wire            cpl_data_empty_o,
    output  wire    [255:0] cpl_data_rdata_o,
    input   wire            cpl_data_rden_i,

    // Tx Cpl Payload Counter
    output  wire    [TX_DEPTH_LG2-1:0]  cpl_payload_cnt_o,
    input   wire            cpl_sent_i
);

/*
    modport master (
        output      avalid, aid, aaddr, alen, asize,
                    aburst, acache, aprot, aqos, aregion,
        input       aready
    );

    modport master (
        output      wvalid, wdata, wstrb, wlast,
        input       wready
    );
    
    modport slave (
        output      bvalid, bid, bresp,
        input       bready
    );

    modport slave (
        output      rvalid, rid, rdata, rresp, rlast,
        input       rready
    );
*/

    wire            p_hdr_empty;
    wire [31:0]     p_hdr_debug;
    wire            p_data_empty;
    wire [31:0]     p_data_debug;
    wire            np_hdr_empty;
    wire [31:0]     np_hdr_debug;
    wire            cpl_hdr_full;
    wire [31:0]     cpl_hdr_debug;
    wire            cpl_data_full;
    wire            cpl_data_wren;
    wire [31:0]     cpl_data_debug;

    wire            ar_full;
    wire [ADDR_WIDTH + ID_WIDTH + 8 - 1: 0] ar_wdata;
    wire            ar_empty;
    wire [ADDR_WIDTH + ID_WIDTH + 8 - 1: 0] ar_rdata;
    wire            ar_rden;
    wire [31:0]     ar_debug;

    // **********************************
    // * P Header / P Data -> AXI Write *
    // **********************************
    PCIE_PKG::tlp_memory_req_hdr_t p_hdr;

    wire [7:0]                  p_hdr_awlen;
    assign p_hdr_awlen = ({p_hdr.length_h, p_hdr.length_l} >> 3) - 1;
    wire [9:0]     p_hdr_tag;
    assign p_hdr_tag = {p_hdr.tg_h, p_hdr.tg_m, p_hdr.tag};
    wire [ID_WIDTH-1:0]     p_hdr_awid;
    assign p_hdr_awid = p_hdr_tag[9:6];
    wire [ADDR_WIDTH-1:0]       p_hdr_awaddr;
    assign p_hdr_awaddr = {p_hdr.addr_h, p_hdr.addr_m, p_hdr.addr_l, 2'b00};
    
    typedef enum logic {
        HEADER,
        PAYLOAD
    } pstate_t;
    pstate_t pstate, pstate_n;

    // AXI Burst Transfer Control
    logic [7:0] wcnt, wcnt_n;
    logic [ID_WIDTH-1:0] wid, wid_n;
    logic p_hdr_rden, p_data_rden;
    logic awvalid, wvalid, wlast, bready;

    always_ff @(posedge clk)
        if (!rst_n) begin
            pstate <= HEADER;
            wcnt <= 8'd0;
            wid <= 'd0;
        end
        else begin
            pstate <= pstate_n;
            wcnt <= wcnt_n;
        end
    
    always_comb begin : memwr_req_to_axi_wr
        pstate_n = pstate;
        wcnt_n = wcnt;

        awvalid = 1'b0;
        wvalid = 1'b0;
        wlast = 1'b0;
        p_hdr_rden = 1'b0;
        p_data_rden = 1'b0;

        case (pstate)
        HEADER: begin
            if (!p_hdr_empty) begin
                awvalid = 1'b1;
            end

            if (aw_if.aready & ~p_hdr_empty) begin
                pstate_n = PAYLOAD;
                p_hdr_rden = 1'b1;

                wcnt_n = p_hdr_awlen;
            end
        end
        PAYLOAD: begin
            if (!p_data_empty) begin
                wvalid = 1'b1;
            end

            if (w_if.wready & ~p_data_empty) begin
                p_data_rden = 1'b1;
                wcnt_n = wcnt - 1;
            end

            if (wcnt == 8'd0) begin
                wlast = 1'b1;
            end

            if (w_if.wready & ~p_data_empty & wlast) begin
                // Transition
                pstate_n = HEADER;
            end
        end
        endcase
        
        bready = 1'b1;
    end

    assign aw_if.avalid = awvalid;
    assign aw_if.aid = p_hdr_awid;
    assign aw_if.aaddr = p_hdr_awaddr;
    assign aw_if.alen = p_hdr_awlen;
    assign aw_if.asize = 3'd5; // 32B
    assign aw_if.aburst = 2'b01; // Incremental
    assign aw_if.acache = 4'b0000;
    assign aw_if.aprot = 3'b000;
    assign aw_if.aqos = 4'b0000;
    assign aw_if.aregion = 4'b0000;

    assign w_if.wvalid = wvalid;
    assign w_if.wstrb = 32'hFFFF_FFFF;
    assign w_if.wlast = wlast;

    assign b_if.bready = bready;

    assign p_hdr_rden_o = p_hdr_rden;
    assign p_data_rden_o = p_hdr_data;

    // **************************************************
    // * NP Header -> AXI Read -> Cpl Header / Cpl FIFO *
    // **************************************************
    PCIE_PKG::tlp_memory_req_hdr_t np_hdr;
    
    wire [9:0]          np_hdr_length;
    assign np_hdr_length = {np_hdr.length_h, np_hdr.length_l};
    wire [63:0]         np_hdr_addr;
    assign np_hdr_addr = {np_hdr.addr_h, np_hdr.addr_m, np_hdr.addr_l, 2'b00};
    wire [9:0]          np_hdr_tag;
    assign np_hdr_tag = {np_hdr.tg_h, np_hdr.tg_m, np_hdr.tag};
    wire [15:0]         np_hdr_requester_id;
    assign np_hdr_requester_id = np_hdr.requester_id;

    typedef enum logic {
        NP_READ,
        CPL_GEN
    } npstate_t;
    npstate_t npstate, npstate_n;

    logic np_hdr_rden;

    // wire [9:0]          np_hdr_length;
    // wire [63:0]         np_hdr_addr;
    // wire [9:0]          np_hdr_tag;

    wire    [6:0]   lower_addr;
    assign lower_addr = araddr[6:0];
    logic   [11:0]  byte_count, byte_count_n;
    logic   [15:0]  np_req_id, np_req_id_n;
    logic   [9:0]   np_req_tag, np_req_tag_n;
    logic   [ADDR_WIDTH-1:0]    araddr, araddr_n;
    logic   [7:0]               arlen, arlen_n;

    logic   ar_wren;

    logic   cpl_hdr_wren;
    
    always_ff @(posedge clk)
        if (!rst_n) begin
            npstate <= NP_READ;
            byte_count <= 12'd0;
            np_req_id <= 16'd0;
            np_req_tag <= 10'd0;
            araddr <= 'd0;
            arlen <= 8'd0;
        end
        else begin
            npstate <= npstate_n;
            byte_count <= byte_count_n;
            np_req_id <= np_req_id_n;
            np_req_tag <= np_req_tag_n;
            araddr <= araddr_n;
            arlen <= arlen_n;
        end
    
    always_comb begin : ar_to_memrd_req
        npstate_n = npstate;
        byte_count_n = byte_count;
        np_req_id_n = np_req_id;
        np_req_tag_n = np_req_tag;
        araddr_n = araddr;
        arlen_n = arlen;

        np_hdr_rden = 1'b0;
        ar_wren = 1'b0;
        cpl_hdr_wren = 1'b0;

        case (npstate)
        NP_READ: begin
            if (!np_hdr_empty) begin
                npstate_n = CPL_GEN;

                np_hdr_rden = 1'b1;

                araddr_n = np_hdr_addr;
                byte_count_n = np_hdr_length << 2;
                np_req_id_n = np_hdr_requester_id;
                np_req_tag_n = np_hdr_tag;

                if (|np_hdr_addr[6:5]) begin // if not RCB start (max beat < 4)
                    arlen_n = (np_hdr_length[7:3] < 'd4 - np_hdr_addr[6:5]) ? // length less than 128-addr[6:0]?
                              {6'd0, (np_hdr_length[4:3] - 'd1)} : // ARLEN set by (length << 3) - 1
                              {6'd0, ('d3 - np_hdr_addr[6:5])}; // ARLEN set by (128-addr[6:0])
                end
                else begin // if RCB start (max beat 4)
                    arlen_n = (np_hdr_length[7:5] < 'd1) ? // length less than 128B?
                              {6'd0, (np_hdr_length[4:3] - 'd1)} : // ARLEN set by (length << 3) - 1
                              8'd3; // ARLEN set by 4-beat
                end
            end
        end
        CPL_GEN: begin
            if (~ar_full & ~cpl_hdr_full) begin
                ar_wren = 1'b1;
                cpl_hdr_wren = 1'b1;

                byte_count_n = byte_count - ((arlen + 'd1) << 5);

                araddr_n = araddr + ((arlen + 8'd1) << 5);
                
                if (|araddr[6:5]) begin // if not RCB start (max beat < 4)
                    arlen_n = (byte_count[9:5] < 'd4 - araddr[6:5]) ? // length less than 128-addr[6:0]?
                              {6'd0, (byte_count[6:5] - 'd1)} : // ARLEN set by (length << 3) - 1
                              {6'd0, ('d3 - araddr[6:5])}; // ARLEN set by (128-addr[6:0])
                end
                else begin // if RCB start (max beat 4)
                    arlen_n = (byte_count[7:5] < 'd1) ? // length less than 128B?
                              {6'd0, (byte_count[6:5] - 'd1)} : // ARLEN set by (length << 3) - 1
                              8'd3; // ARLEN set by 4-beat
                end

                if (byte_count == ((arlen + 1) << 5)) begin
                    npstate_n = NP_READ;
                end
            end
        end
        endcase
    end

    TL_FIFO #(
        .DEPTH_LG2     (RX_DEPTH_LG2),  // FIFO depth
        .DATA_WIDTH    (ADDR_WIDTH + ID_WIDTH + 8), // Data Width: 64 + 4 + 8
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/o Counter
    ) u_ar_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (ar_full),
        .wren_i        (ar_wren),
        .wdata_i       (ar_wdata),

        .empty_o       (ar_empty),
        .rden_i        (ar_rden),
        .rdata_o       (ar_rdata),

        .cnt_o         (),
        .debug_o       (ar_debug)
    );

    assign ar_wdata = {araddr, np_req_tag[9:6], arlen};

    assign ar_if.avalid = !ar_empty;
    assign ar_if.aid = ar_rdata[ID_WIDTH+8-1:8];
    assign ar_if.aaddr = ar_rdata[ADDR_WIDTH+ID_WIDTH+8-1:ID_WIDTH+8];
    assign ar_if.alen = ar_rdata[8-1:0];
    assign ar_if.asize = 3'd5; // 32B
    assign ar_if.aburst = 2'b01; // Incremental
    assign ar_if.acache = 4'b0000;
    assign ar_if.aprot = 3'b000;
    assign ar_if.aqos = 4'b0000;
    assign ar_if.aregion = 4'b0000;

    assign ar_rden = ar_if.aready & ~ar_empty;

    assign np_hdr_rden_o = np_hdr_rden;
    
    TL_CNT #(.DEPTH(TX_DEPTH_LG2)) cpl_payload_cnt (
        .clk        (clk),
        .rst_n      (rst_n),
        .wren_i     (r_if.rvalid & r_if.rlast & ~cpl_data_full),
        .rden_i     (cpl_sent_i),
        .cnt_o      (cpl_payload_cnt_o)
    );
    
    PCIE_PKG::tlp_cpl_hdr_t cpl_hdr;

    logic   [9:0]   cpl_length;
    
    always_comb begin : gen_cpl_hdr
        cpl_length = (arlen + 'd1) << 3;

        // CplD Fmt :010 Type: 0 1010 Completion with Data
        // DW 2
        cpl_hdr.reserved        = 1'b0;
        cpl_hdr.lower_addr      = lower_addr;
        cpl_hdr.tag             = np_req_tag[7:0];
        cpl_hdr.requester_id    = np_req_id;
        // DW 1
        cpl_hdr.byte_count_l    = byte_count[7:0];
        cpl_hdr.cpl_status      = 3'b000; // Successful Completion (SC)
        cpl_hdr.bcm             = 1'b0; // only be set by PCI-X completers
        cpl_hdr.byte_count_h    = byte_count[11:8];
        cpl_hdr.completer_id    = config_bdf_i;
        // DW 0
        cpl_hdr.length_l        = cpl_length[7:0];
        cpl_hdr.td              = 1'b0; // No TLP Digest
        cpl_hdr.ep              = 1'b0; // Not Error Poisoned
        cpl_hdr.attr_l          = 2'b00; // No Attributes
        cpl_hdr.at              = 2'b00; // Untranslated Address
        cpl_hdr.length_h        = cpl_length[9:8];
        cpl_hdr.tg_h            = np_req_tag[9];
        cpl_hdr.tc              = 3'b000; // Normal Traffic Class
        cpl_hdr.tg_m            = np_req_tag[8];
        cpl_hdr.attr_h          = 1'b0; // No Attributes
        cpl_hdr.ln              = 1'b0; // Reserved
        cpl_hdr.th              = 1'b0; // No TLP Hint
        cpl_hdr.fmt             = 3'b010; // 4 DW Header, with data
        cpl_hdr.tlp_type        = 5'b01010; // Completion with data
    end

    // Cpl Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (TX_DEPTH_LG2),  // FIFO depth
        .DATA_WIDTH    (96),            // Data Width: 12B / 96bit / 3DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/ Counter
    ) u_tx_cpl_hdr_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (cpl_hdr_full),
        .wren_i        (cpl_hdr_wren),
        .wdata_i       (cpl_hdr),

        .empty_o       (cpl_hdr_empty_o),
        .rden_i        (cpl_hdr_rden_i),
        .rdata_o       (cpl_hdr_rdata_o),

        .cnt_o         (),
        .debug_o       (cpl_hdr_debug)
    );

    // Cpl Data FIFO
    TL_FIFO #(
        .DEPTH_LG2     (TX_DEPTH_LG2),  // FIFO depth
        .DATA_WIDTH    (256),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/ Counter
    ) u_tx_cpl_data_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (cpl_data_full),
        .wren_i        (cpl_data_wren),
        .wdata_i       (r_if.rdata),

        .empty_o       (cpl_data_empty_o),
        .rden_i        (cpl_data_rden_i),
        .rdata_o       (cpl_data_rdata_o),

        .cnt_o         (),
        .debug_o       (cpl_data_debug)
    );

    assign cpl_data_wren = r_if.rvalid & ~cpl_data_full;
    assign r_if.rready = !cpl_data_full;

    // P Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (RX_DEPTH_LG2),  // FIFO depth: 16
        .DATA_WIDTH    (128),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/o Counter
    ) u_rx_p_hdr_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (p_hdr_full_o),
        .wren_i        (p_hdr_wren_i),
        .wdata_i       (p_hdr_wdata_i),

        .empty_o       (p_hdr_empty),
        .rden_i        (p_hdr_rden),
        .rdata_o       (p_hdr),

        .cnt_o         (),
        .debug_o       (p_hdr_debug)
    );
    
    // P Data FIFO
    TL_FIFO #(
        .DEPTH_LG2     (RX_DEPTH_LG2),  // FIFO depth
        .DATA_WIDTH    (256),           // Data Width: 32B / 256bit / 8DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/o Counter
    ) u_rx_p_data_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (p_data_full_o),
        .wren_i        (p_data_wren_i),
        .wdata_i       (p_data_wdata_i),

        .empty_o       (p_data_empty),
        .rden_i        (p_data_rden),
        .rdata_o       (w_if.wdata),

        .cnt_o         (),
        .debug_o       (p_data_debug)
    );

    // NP Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (RX_DEPTH_LG2),  // FIFO depth
        .DATA_WIDTH    (128),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/o Counter
    ) u_rx_np_hdr_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (np_hdr_full_o),
        .wren_i        (np_hdr_wren_i),
        .wdata_i       (np_hdr_wdata_i),

        .empty_o       (np_hdr_empty),
        .rden_i        (np_hdr_rden),
        .rdata_o       (np_hdr),

        .cnt_o         (),
        .debug_o       (np_hdr_debug)
    );


endmodule
