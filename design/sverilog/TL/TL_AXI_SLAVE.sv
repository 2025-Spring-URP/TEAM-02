// Trial
// Wongi Choi (cwg43352@g.skku.edu)

module TL_AXI_SLAVE #(
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

    // AXI Slave (AW, AR, W, R, B)

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
    
    // Tx NP Header FIFO
    output  wire            np_hdr_empty_o,
    output  wire    [127:0] np_hdr_rdata_o,
    input   wire            np_hdr_rden_i,

    // Tx P Header FIFO
    output  wire            p_hdr_empty_o,
    output  wire    [127:0] p_hdr_rdata_o,
    input   wire            p_hdr_rden_i,

    // Tx P Data FIFO
    output  wire            p_data_empty_o,
    output  wire    [255:0] p_data_rdata_o,
    input   wire            p_data_rden_i,

    // Tx P Payload Counter
    output  wire    [TX_DEPTH_LG2-1:0]  p_payload_cnt_o,
    input   wire            p_sent_i,

    // Rx Cpl Header FIFO
    output  wire            cpl_hdr_full_o,
    input   wire    [95:0]  cpl_hdr_wdata_i,
    input   wire            cpl_hdr_wren_i,
    output  wire            cpl_hdr_rden_o,

    // Rx Cpl Data FIFO
    output  wire            cpl_data_full_o,
    input   wire    [255:0] cpl_data_wdata_i,
    input   wire            cpl_data_wren_i,
    output  wire            cpl_data_rden_o
);

/*
    modport slave (
        input       avalid, aid, aaddr, alen, asize,
                    aburst, acache, aprot, aqos, aregion,
        output      aready
    );

    modport slave (
        input       wvalid, wdata, wstrb, wlast,
        output      wready
    );
    
    modport master (
        input       bvalid, bid, bresp,
        output      bready
    );

    modport master (
        input       rvalid, rid, rdata, rresp, rlast,
        output      rready
    );
*/

    // 1 awlen/arlen: 32B, 4DW, 256bit
    // length = ((alen + 'b1) << 2)



    localparam TAG_WIDTH = 64;
    localparam TAG_BIT = $clog2(TAG_WIDTH);

    wire            p_hdr_full;
    wire            p_hdr_wren;
    wire [31:0]     p_hdr_debug;

    wire            p_data_full;
    wire            p_data_wren;
    wire [31:0]     p_data_debug;

    wire            np_hdr_full;
    wire [31:0]     np_hdr_debug;

    wire            cpl_hdr_empty;
    wire [31:0]     cpl_hdr_debug;

    wire            cpl_data_empty;
    wire [31:0]     cpl_data_debug;

    // ************ Memory Write Packer ************

    assign b_if.bid = 4'd0;
    assign b_if.bvalid = 1'b1; // Always Valid
    assign b_if.bresp = 2'b00; // Fix to 0 (Okay)

    TL_CNT #(.DEPTH(TX_DEPTH_LG2)) p_payload_cnt (
        .clk        (clk),
        .rst_n      (rst_n),
        .wren_i     (w_if.wvalid & w_if.wlast & ~p_data_full),
        .rden_i     (p_sent_i),
        .cnt_o      (p_payload_cnt_o)
    );

    // ************ Memory Read Packer ************

    // AXI Burst Transfer Control
    logic np_hdr_wren;
    logic arready;

    // Tag Allocator Handshake
    logic tag_allocate; // input set by above

    always_comb begin : ar_to_memrd_req
        arready = 1'b0;
        np_hdr_wren = 1'b0;
        tag_allocate = 1'b0;

        if (~np_hdr_full & tag_valid) begin
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

    logic [3:0] rid, rid_n;
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
            rid <= 4'd0;
        end
        else begin
            cplstate <= cplstate_n;
            rcnt <= rcnt_n;
            rid <= rid_n;
        end

    always_comb begin : cplD_to_r
        cplstate_n = cplstate;
        rcnt_n = rcnt;
        rid_n = rid;

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
                rid_n = cpl_tag[9:6];

                tag_free = 1'b1;
                cpl_hdr_rden = 1'b1;
            end
        end
        RDATA: begin
            if (!cpl_data_empty) begin
                rvalid = 1'b1;
            end

            if (rcnt == 8'd0) begin
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
                    rid_n = cpl_tag[9:6];

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

    assign r_if.rid = rid;
    assign r_if.rvalid = rvalid;
    assign r_if.rlast = rlast;
    assign r_if.rresp = 2'b00; // Fix to 0 (Okay)

    assign cpl_hdr_rden_o = cpl_hdr_rden;
    assign cpl_data_rden_o = cpl_data_rden;

    // **************** Tag Allocator ****************

    logic [TAG_WIDTH-1:0] tag_pool;
    logic [TAG_BIT-1:0] tag_counter;
    wire tag_valid;
    assign tag_valid = !tag_pool[tag_counter];
    // tag_pool[i]: 0 (Valid) / 1 (Not Valid)
    // logic tag_allocate; // input set by above
    // logic tag_free;
    // logic [TAG_BIT-1:0] tag_completion;

    always_ff @(posedge clk)
        if (!rst_n) begin
            tag_pool <= 'b0;
            tag_counter <= 'b0;
        end
        else begin
            if (tag_free) begin
                tag_pool[cpl_tag] <= 1'b0;
            end
            if (tag_allocate && tag_valid) begin
                tag_pool[tag_counter] <= 1'b1;
                tag_counter <= tag_counter + 'b1;
            end
        end

    // ******************** Header Set ********************
    PCIE_PKG::tlp_memory_req_hdr_t p_hdr;
    logic [9:0]     memwr_length;
    logic [9:0]     memwr_tag;

    always_comb begin : gen_memwr_hdr
        // aw_if.asize: 5, 2^5 = 32B, 8DW
        memwr_length = (aw_if.alen + 1) << 3;
        memwr_tag = {aw_if.aid, 6'd0};

        // DW 3
        p_hdr.addr_l        = aw_if.aaddr[7:2]; // Address (Low)
        p_hdr.reserved      = 2'b00; // No Processing Hint
        p_hdr.addr_m        = {aw_if.aaddr[15:8], aw_if.aaddr[23:16], aw_if.aaddr[31:24]};
        // DW 2
        p_hdr.addr_h        = {aw_if.aaddr[39:32], aw_if.aaddr[47:40], aw_if.aaddr[55:48], aw_if.aaddr[63:56]}; // Address (High)
        // DW 1
        p_hdr.byte_enable   = 8'hFF; // [7:4]: Last DW Enable, [3:0]: First DW Enable
        p_hdr.tag           = memwr_tag[7:0]; // tag
        p_hdr.requester_id  = config_bdf_i;
        // DW 0
        p_hdr.length_l      = memwr_length[7:0];
        p_hdr.td            = 1'b0; // No TLP Digest
        p_hdr.ep            = 1'b0; // Not Error Poisoned
        p_hdr.attr_l        = 2'b00; // No Attributes
        p_hdr.at            = 2'b00; // Untranslated Address
        p_hdr.length_h      = memwr_length[9:8];
        p_hdr.tg_h          = memwr_tag[9];
        p_hdr.tc            = 3'b000; // Normal Traffic Class
        p_hdr.tg_m          = memwr_tag[8];
        p_hdr.attr_h        = 1'b0; // No Attributes
        p_hdr.ln            = 1'b0; // Reserved
        p_hdr.th            = 1'b0; // No TLP Hint
        p_hdr.fmt           = 3'b011; // 4 DW Header, with data
        p_hdr.tlp_type      = 5'b00000; // Memory Read/Write Request
    end

    PCIE_PKG::tlp_memory_req_hdr_t np_hdr;
    logic [9:0]     memrd_length;
    logic [9:0]     memrd_tag;

    always_comb begin : gen_memrd_hdr
        // aw_if.asize: 5, 2^5 = 32B, 8DW
        memrd_length = (ar_if.alen + 1) << 3;
        memrd_tag = {ar_if.aid, tag_counter};

        // DW 3
        np_hdr.addr_l       = ar_if.aaddr[7:2]; // Address (Low)
        np_hdr.reserved     = 2'b00; // No Processing Hint
        np_hdr.addr_m       = {ar_if.aaddr[15:8], ar_if.aaddr[23:16], ar_if.aaddr[31:24]};
        // DW 2
        np_hdr.addr_h       = {ar_if.aaddr[39:32], ar_if.aaddr[47:40], ar_if.aaddr[55:48], ar_if.aaddr[63:56]}; // Address (High)
        // DW 1
        np_hdr.byte_enable  = 8'hFF; // [7:4]: Last DW Enable, [3:0]: First DW Enable
        np_hdr.tag          = memrd_tag[7:0]; // tag
        np_hdr.requester_id = config_bdf_i;
        // DW 0
        np_hdr.length_l     = memrd_length[7:0];
        np_hdr.td           = 1'b0; // No TLP Digest
        np_hdr.ep           = 1'b0; // Not Error Poisoned
        np_hdr.attr_l       = 2'b00; // No Attributes
        np_hdr.at           = 2'b00; // Untranslated Address
        np_hdr.length_h     = memrd_length[9:8];
        np_hdr.tg_h         = memrd_tag[9];
        np_hdr.tc           = 3'b000; // Normal Traffic Class
        np_hdr.tg_m         = memrd_tag[8];
        np_hdr.attr_h       = 1'b0; // No Attributes
        np_hdr.ln           = 1'b0; // Reserved
        np_hdr.th           = 1'b0; // No TLP Hint
        np_hdr.fmt          = 3'b001; // 4 DW Header, no data
        np_hdr.tlp_type     = 5'b00000; // Memory Read/Write Request
    end

    PCIE_PKG::tlp_cpl_hdr_t cpl_hdr;

    // P Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (TX_DEPTH_LG2),  // FIFO depth
        .DATA_WIDTH    (128),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/o Counter
    ) u_tx_p_hdr_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (p_hdr_full),
        .wren_i        (p_hdr_wren),
        .wdata_i       (p_hdr),

        .empty_o       (p_hdr_empty_o),
        .rden_i        (p_hdr_rden_i),
        .rdata_o       (p_hdr_rdata_o),

        .cnt_o         (),
        .debug_o       (p_hdr_debug)
    );

    assign aw_if.aready = !p_hdr_full;
    assign p_hdr_wren = aw_if.avalid & ~p_hdr_full;

    // P Data FIFO
    TL_FIFO #(
        .DEPTH_LG2     (TX_DEPTH_LG2),  // FIFO depth
        .DATA_WIDTH    (256),           // Data Width: 32B / 256bit / 8DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/o Counter
    ) u_tx_p_data_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (p_data_full),
        .wren_i        (p_data_wren),
        .wdata_i       (w_if.wdata),

        .empty_o       (p_data_empty_o),
        .rden_i        (p_data_rden_i),
        .rdata_o       (p_data_rdata_o),

        .cnt_o         (),
        .debug_o       (p_data_debug)
    );

    assign w_if.wready = !p_data_full;
    assign p_data_wren = w_if.wvalid & ~p_data_full;

    // NP Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (TX_DEPTH_LG2),  // FIFO depth
        .DATA_WIDTH    (128),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .USE_CNT       (0)              // w/o Counter
    ) u_tx_np_hdr_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (np_hdr_full),
        .wren_i        (np_hdr_wren),
        .wdata_i       (np_hdr),

        .empty_o       (np_hdr_empty_o),
        .rden_i        (np_hdr_rden_i),
        .rdata_o       (np_hdr_rdata_o),

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

        .cnt_o         (),
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

        .cnt_o         (),
        .debug_o       (cpl_data_debug)
    );

endmodule
