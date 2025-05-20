// Trial
// Wongi Choi (cwg43352@g.skku.edu)

module TL_AXI_MASTER #(
    parameter AXI_ID_WIDTH     = 4,
    parameter AXI_ADDR_WIDTH   = 64,
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
    ref  AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) aw_if,
    // AXI Read Address Channel
    ref  AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) ar_if,
    // AXI Write Channel
    ref  AXI4_W_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) w_if,
    // AXI Read Channel
    ref  AXI4_R_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) r_if,
    // AXI Write Response Channel
    ref  AXI4_B_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) b_if,
    
    // FIFOs (NPhdr, Phdr, Pdata, Cplhdr, Cpldata)
    
    // NP Header FIFO
    output  wire            np_hdr_full_o,
    output  wire    [RX_DEPTH_LG2-1:0]  np_hdr_cnt_o,
    input   wire    [127:0] np_hdr_wdata_i,
    input   wire            np_hdr_wren_i,

    // P Header FIFO
    output  wire            p_hdr_full_o,
    output  wire    [RX_DEPTH_LG2-1:0]  p_hdr_cnt_o,
    input   wire    [127:0] p_hdr_wdata_i,
    input   wire            p_hdr_wren_i,

    // P Data FIFO
    output  wire            p_data_full_o,
    output  wire    [RX_DEPTH_LG2-1:0]  p_data_cnt_o,
    input   wire    [255:0] p_data_wdata_i,
    input   wire            p_data_wren_i,

    // Cpl Header FIFO
    output  wire            cpl_hdr_empty_o,
    output  wire    [95:0]  cpl_hdr_rdata_i,
    output  wire            cpl_hdr_rden_i,

    // Cpl Header FIFO
    output  wire            cpl_data_full_o,
    input   wire    [255:0] cpl_data_wdata_i,
    input   wire            cpl_data_wren_i,

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

    // 1 awlen/arlen: 32B, 4DW, 256bit
    // length = ((alen + 'b1) << 2)

    localparam TAG_WIDTH = 256;
    localparam TAG_BIT = $clog2(TAG_WIDTH);
    localparam MAX_PAYLOAD_DW = MAX_PAYLOAD_SIZE / 4; // 32

    wire            p_hdr_full;
    wire [31:0]     p_hdr_debug;
    wire            p_data_full;
    wire [31:0]     p_data_debug;
    wire            np_hdr_full;
    wire [31:0]     np_hdr_debug;
    wire            cpl_hdr_empty;
    wire [31:0]     cpl_hdr_debug;
    wire            cpl_data_empty;
    wire [31:0]     cpl_data_debug;

    // ************ Memory Writer ************
    typedef enum logic [2:0] {
        IDLE,
        WDATA,
        WRESP
    } wstate_t;
    wstate_t wstate, wstate_n;

    // AXI Burst Transfer Control
    logic [7:0] wcnt, wcnt_n;
    logic [AXI_ID_WIDTH-1:0] wid, wid_n;
    logic p_hdr_rden, p_data_rden;
    logic awvalid, wvalid, wlast, bready;

    always_ff @(posedge clk)
        if (!rst_n) begin
            wstate <= IDLE;
            wcnt <= 8'd0;
            wid <= 'd0;
        end
        else begin
            wstate <= wstate_n;
            wcnt <= wcnt_n;
            wid <= wid_n;
        end
    
    always_comb begin : memwr_req_to_axi_wr
        wstate_n = wstate;
        wcnt_n = wcnt;
        wid_n = wid;

        awvalid = 1'b0;
        wvalid = 1'b0;
        wlast = 1'b0;
        p_hdr_rden = 1'b0;
        p_data_rden = 1'b0;

        case (wstate)
        IDLE: begin
            if (!p_hdr_empty) begin
                awvalid = 1'b1;
            end

            if (aw_if.aready & ~p_hdr_empty) begin
                wstate_n = WDATA;
                p_hdr_rden = 1'b1;

                wcnt_n = p_hdr_awlen;
                wid_n = p_hdr_awid;
            end
        end
        WDATA: begin
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
                wstate_n = IDLE;
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

    // ************* Memory Reader *************

    typedef enum logic [2:0] {
        IDLE,
        RREQ,
        RDATA
    } rstate_t;
    rstate_t rstate, rstate_n;

    // AXI Burst Transfer Control
    logic [AXI_ID_WIDTH-1:0] rid, rid_n;
    logic np_hdr_rden;
    logic arvalid, rready;

    // Request Tracking
    logic [63:0] araddr;
    logic [11:0] cpl_byte_count;
    
    always_ff @(posedge clk)
        if (!rst_n) begin
            rstate <= IDLE;
        end
        else begin
            rstate <= rstate_n;
        end

    always_comb begin : ar_to_memrd_req
        np_hdr_rden = 1'b0;
        
        arvalid = 1'b0;
        rready = 1'b0;
        np_hdr_rden = 1'b0;

        case (rstate)
        IDLE: begin
            if (!np_hdr_empty) begin
                if (np_hdr_length > MAX_PAYLOAD_DW) begin
                    
                end
                else begin
                end
            end
        end
        RREQ: begin
        end
        RDATA: begin
        end
        endcase

        if (~np_hdr_full & ~tag_valid) begin
            arready = 1'b1;
        end

        if (ar_if.avalid & arready) begin
            np_hdr_wren = 1'b1;
            tag_allocate = 1'b1;
        end
    end

    assign ar_if.aready = arready;

    typedef enum logic [1:0] {
        IDLE,
        RDATA
    } cplstate_t;

    cplstate_t cplstate, cplstate_n;
    logic [7:0] rcnt, rcnt_n;
    logic rvalid, rlast;
    wire [9:0] cpl_tag;
    assign cpl_tag = {cpl_hdr.tg_h, cpl_hdr.tg_m, cpl_hdr.tag};
    wire [9:0] cpl_length;
    assign cpl_length = {cpl_hdr.length_h, cpl_hdr.length_l};
    // DW to rcnt: 4B -> 32B, arith.shift 3 and -1
    logic tag_free;
    logic cpl_hdr_rden;
    logic cpl_data_rden;

    always_ff @(posedge clk)
        if (!rst_n) begin
            cplstate <= IDLE;
            rcnt <= 8'd0;
        end
        else begin
            cplstate <= cplstate_n;
            rcnt <= rcnt_n;
        end

    always_comb begin : cplD_to_r
        cplstate_n = cplstate;
        rcnt_n = rcnt;

        tag_free = 1'b0;
        cpl_hdr_rden = 1'b0;
        cpl_data_rden = 1'b0;
        rvalid = 1'b0;
        rlast = 1'b0;

        case (cplstate)
        IDLE: begin
            if (!cpl_hdr_empty) begin
                cplstate_n = RDATA;

                rcnt_n = (cpl_length >>> 3) - 1;

                tag_free = 1'b1;
                cpl_hdr_rden = 1'b1;
            end
        end
        RDATA: begin
            if (!cpl_data_empty) begin
                rvalid = 1'b1;
            end

            if (rcnt == 0) begin
                rlast = 1'b1;
            end

            if (~cpl_data_empty & r_if.rready) begin
                cpl_data_rden = 1'b1;
                rcnt_n = rcnt - 1;
            end
            
            if (~cpl_data_empty & r_if.rready & rlast) begin
                if (!cpl_hdr_empty) begin
                    // cplstate_n = RDATA;

                    rcnt_n = (cpl_length >>> 3) - 1;

                    tag_free = 1'b1;
                    cpl_hdr_rden = 1'b1;
                end
                else begin
                    cplstate_n = IDLE;
                end
            end
        end
        endcase
    end

    assign r_if.rid = 4'd0; // Fix to 0
    assign r_if.rvalid = rvalid;
    assign r_if.rlast = rlast;
    assign r_if.rresp = 2'b00; // Fix to 0 (Okay)

    // ******************** Header Set ********************
    PCIE_PKG::tlp_memory_req_hdr_t p_hdr;

    wire [7:0]                  p_hdr_awlen;
    assign p_hdr_awlen = ({p_hdr.length_h, p_hdr.length_l} >> 3) - 1;
    wire [AXI_ID_WIDTH-1:0]     p_hdr_awid;
    assign p_hdr_awid = {p_hdr.tg_h, p_hdr.tg_m, p_hdr.tag}[9:6];
    wire [ADDR_WIDTH-1:0]       p_hdr_awaddr;
    assign p_hdr_awaddr = {p_hdr.addr_h, p_hdr.addr_m, p_hdr.addr_l, 2'b00};

    PCIE_PKG::tlp_memory_req_hdr_t np_hdr;

    wire [7:0]      np_hdr_arlen;
    wire [AXI_ADDR_WIDTH-1:0]     np_hdr_araddr;
    wire [AXI_ID_WIDTH-1:0]     np_hdr_id;
    assign np_hdr_arlen = {np_hdr.addr_h, np_hdr.addr_m, np_hdr.addr_l, 2'b00};
    assign  = {np_hdr.tg_h, np_hdr.tg_m, np_hdr.tag}[9:6];
    assign arid = {np_hdr.tg_h, np_hdr.tg_m, np_hdr.tag}[9:6];

    
    wire [9:0]          np_hdr_length;
    assign np_hdr_length = {p_hdr.length_h, p_hdr.length_l};
    wire [63:0]         np_hdr_araddr;
    assign np_hdr_addr = {np_hdr.addr_h, np_hdr.addr_m, np_hdr.addr_l, 2'b00};
    wire [9:0]          np_hdr_arid;
    assign np_hdr_arid = {np_hdr.tg_h, np_hdr.tg_m, np_hdr.tag}[9:6];


    wire [AXI_ID_WIDTH-1:0]     np_hdr_id;
    assign ar_if.alen = arlen; //
    assign ar_if.aaddr = {np_hdr.addr_h, np_hdr.addr_m, np_hdr.addr_l, 2'b00};
    assign ar_if.aid = {np_hdr.tg_h, np_hdr.tg_m, np_hdr.tag}[9:6];
    assign arid = {np_hdr.tg_h, np_hdr.tg_m, np_hdr.tag}[9:6];

    PCIE_PKG::tlp_cpl_hdr_t cpl_hdr;
    /*
    typedef struct packed {                                 // pg 154
        logic                reserved;         // [95]          MSB
        logic   [6:0]        lower_addr;       // [94:88]
        logic   [7:0]        tag;              // [87:80]
        logic   [15:0]       requester_id;     // [79:64]

        logic   [7:0]        byte_count_l;     // [63:56]
        logic   [2:0]        cpl_status;       // [55:53]
        logic                bcm;              // [52]
        logic   [3:0]        byte_count_h;     // [51:48]
        logic   [15:0]       completer_id;     // [47:32]

        logic   [7:0]        length_l;         // [31:24]
        logic                td;               // [23]
        logic                ep;               // [22]
        logic   [1:0]        attr_l;           // [21:20]
        logic   [1:0]        at;               // [19:18]
        logic   [1:0]        length_h;         // [17:16]
        logic                tg_h;             // [15]
        logic   [2:0]        tc;               // [14:12]
        logic                tg_m;             // [11]
        logic                attr_h;           // [10]
        logic                ln;               // [9]
        logic                th;               // [8]
        logic   [2:0]        fmt;              // [7:5]
        logic   [4:0]        tlp_type;         // [4:0]         LSB
    } tlp_cpl_hdr_t;
    */
    
    always_comb begin : gen_cpl_hdr
        // aw_if.asize: 5, 2^5 = 32B, 8DW
        memwr_length = (aw_if.alen + 1) << 3;
        cpl_tag = {np_hdr.tg_h, np_hdr.tg_m, np_hdr.tag};
        
        // CplD Fmt :010 Type: 0 1010 Completion with Data
        // DW 2
        cpl_hdr.reserved        = 1'b0;
        cpl_hdr.lower_addr      = cpl_lower_addr;
        cpl_hdr.tag             = np_hdr.tag;
        cpl_hdr.requester_id    = cpl_reqid;
        // DW 1
        cpl_hdr.byte_count_l    = cpl_byte_count[7:0];
        cpl_hdr.cpl_status      = 3'b000; // Successful Completion (SC)
        cpl_hdr.bcm             = 1'b0; // only be set by PCI-X completers
        cpl_hdr.byte_count_h    = cpl_byte_count[11:8];
        cpl_hdr.completer_id    = config_bdf_i;
        // DW 0
        cpl_hdr.length_l        = cpl_length[7:0];
        cpl_hdr.td              = 1'b0; // No TLP Digest
        cpl_hdr.ep              = 1'b0; // Not Error Poisoned
        cpl_hdr.attr_l          = 2'b00; // No Attributes
        cpl_hdr.at              = 2'b00; // Untranslated Address
        cpl_hdr.length_h        = cpl_length[9:8];
        cpl_hdr.tg_h            = np_hdr.tg_h;
        cpl_hdr.tc              = 3'b000; // Normal Traffic Class
        cpl_hdr.tg_m            = np_hdr.tg_m;
        cpl_hdr.attr_h          = 1'b0; // No Attributes
        cpl_hdr.ln              = 1'b0; // Reserved
        cpl_hdr.th              = 1'b0; // No TLP Hint
        cpl_hdr.fmt             = 3'b011; // 4 DW Header, with data
        cpl_hdr.tlp_type        = 5'b00000; // Memory Read/Write Request
    end


    // P Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (4),             // FIFO depth: 16
        .DATA_WIDTH    (128),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (1)              // w/o Counter
    ) u_tx_p_hdr_fifo (
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
        .DEPTH_LG2     (4),             // FIFO depth: 16
        .DATA_WIDTH    (256),           // Data Width: 32B / 256bit / 8DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (1)              // w/o Counter
    ) u_tx_p_data_fifo (
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
        .DEPTH_LG2     (4),             // FIFO depth: 16
        .DATA_WIDTH    (128),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (1)              // w/o Counter
    ) u_tx_np_hdr_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (np_hdr_full),
        .wren_i        (np_hdr_wren),
        .wdata_i       (np_hdr),

        .empty_o       (np_hdr_empty),
        .rden_i        (np_hdr_rden_i),
        .rdata_o       (np_hdr_rdata),

        .cnt_o         (),
        .debug_o       (np_hdr_debug)
    );

    // Cpl Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (RX_DEPTH_LG2),  // FIFO depth: 16
        .DATA_WIDTH    (96),            // Data Width: 12B / 96bit / 3DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/ Counter
    ) u_rx_cpl_hdr_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (cpl_hdr_full_o),
        .wren_i        (cpl_hdr_wren_i),
        .wdata_i       (cpl_hdr_wdata_i),

        .empty_o       (cpl_hdr_empty),
        .rden_i        (cpl_hdr_rden),
        .rdata_o       (cpl_hdr),

        .cnt_o         (cpl_hdr_cnt_o),
        .debug_o       (cpl_hdr_debug)
    );

    // Cpl Data FIFO
    TL_FIFO #(
        .DEPTH_LG2     (RX_DEPTH_LG2),  // FIFO depth: 16
        .DATA_WIDTH    (256),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/ Counter
    ) u_rx_cpl_data_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (cpl_data_full_o),
        .wren_i        (cpl_data_wren_i),
        .wdata_i       (cpl_data_wdata_i),

        .empty_o       (cpl_data_empty),
        .rden_i        (cpl_data_rden),
        .rdata_o       (r_if.rdata),

        .cnt_o         (cpl_data_cnt_o),
        .debug_o       (cpl_data_debug)
    );

endmodule
