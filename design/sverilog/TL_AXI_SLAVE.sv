// Trial
// Wongi Choi (cwg43352@g.skku.edu)

module TL_AXI_SLAVE #(
    parameter AXI_ID_WIDTH     = 4,
    parameter AXI_ADDR_WIDTH   = 64,
    parameter MAX_READ_REQ_SIZE = 512,
    parameter MAX_PAYLOAD_SIZE = 128,
    parameter RX_DEPTH_LG2 = 4
)
(
    input   wire            clk,
    input   wire            rst_n,

    input   wire [15:0]     config_bdf_i,

    // AXI Slave (AW, AR, W, R, B)

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
    output  wire            np_hdr_empty_o,
    output  wire    [127:0] np_hdr_rdata_o,
    input   wire            np_hdr_rden_i,

    // P Header FIFO
    output  wire            p_hdr_empty_o,
    output  wire    [127:0] p_hdr_rdata_o,
    input   wire            p_hdr_rden_i,

    // P Data FIFO
    output  wire            p_data_empty_o,
    output  wire    [255:0] p_data_rdata_o,
    input   wire            p_data_rden_i,

    // Cpl Header FIFO
    output  wire            cpl_hdr_full_o,
    output  wire    [RX_DEPTH_LG2-1:0]  cpl_hdr_cnt_o,
    input   wire    [95:0]  cpl_hdr_wdata_i,
    input   wire            cpl_hdr_wren_i,

    // Cpl Header FIFO
    output  wire            cpl_data_full_o,
    output  wire    [RX_DEPTH_LG2-1:0]  cpl_data_cnt_o,
    input   wire    [255:0] cpl_data_wdata_i,
    input   wire            cpl_data_wren_i,

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



    localparam TAG_WIDTH = 256;
    localparam TAG_BIT = $clog2(TAG_WIDTH);

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

    // ************ Memory Write Packer ************
    typedef enum logic [2:0] {
        IDLE,
        WDATA,
        WRESP
    } wstate_t;
    wstate_t wstate, wstate_n;

    // AXI Burst Transfer Control
    logic [7:0] wcnt, wcnt_n;
    logic [AXI_ID_WIDTH-1:0] write_id, write_id_n;
    logic p_hdr_wren, p_data_wren;
    logic awready, wready, bvalid;

    // Available TL P count
    logic [4:0] preq_cnt, preq_cnt_n;

    always_ff @(posedge clk)
        if (!rst_n) begin
            wstate <= IDLE;
            wcnt <= 8'd0;
            write_id <= 'd0;
        end
        else begin
            wstate <= wstate_n;
            wcnt <= wcnt_n;
            write_id <= write_id_n;
        end
    
    always_comb begin : aw_to_memwr_req
        wstate_n = wstate;
        wcnt_n = wcnt;
        write_id_n = write_id;

        awready = 1'b0;
        wready = 1'b0;
        bvalid = 1'b0;
        p_hdr_wren = 1'b0;
        p_data_wren = 1'b0;

        case (wstate)
        IDLE: begin
            if (!p_hdr_full) begin
                awready = 1'b1;
            end

            if (aw_if.avalid & ~p_hdr_full) begin
                wstate_n = WDATA;
                p_hdr_wren = 1'b1;

                wcnt_n = aw_if.alen;
                wid_n = aw_if.aid;
            end
        end
        WDATA: begin
            if (!p_data_full) begin
                wready = 1'b1;
            end

            if (w_if.wvalid & ~p_data_full) begin
                p_data_wren = 1'b1;
                wcnt_n = wcnt - 1;

                if (w_if.wlast/* | (w_if.wcnt == 0)*/) begin
                    wstate_n = WRESP;
                end
            end
        end
        WRESP: begin
            bvalid = 1'b1;

            if (b_if.bready) begin
                if (!p_hdr_full) begin
                    awready = 1'b1;
                end

                if (aw_if.avalid & ~p_hdr_full) begin
                    wstate_n = WDATA;
                    p_hdr_wren = 1'b1;

                    wcnt_n = aw_if.alen;
                    wid_n = aw_if.aid;
                end
                else begin
                    wstate_n = IDLE;
                end
            end
        end
        endcase
    end

    assign aw_if.aready = awready;
    assign w_if.wready = wready;
    assign b_if.bid = write_id;
    assign b_if.bvalid = bvalid;
    assign b_if.bresp = 2'b00; // Fix to 0 (Okay)

    // ************ Memory Read Packer ************

    // AXI Burst Transfer Control
    logic [AXI_ID_WIDTH-1:0] read_id, read_id_n;
    logic np_hdr_wren;
    logic arready, rvalid, rlast;

    // Tag Allocator Handshake
    logic tag_allocate; // input set by above

    always_comb begin : ar_to_memrd_req
        arready = 1'b0;
        rvalid = 1'b0;
        np_hdr_wren = 1'b0;
        tag_allocate = 1'b0;

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
        memwr_length = (ar_if.alen + 1) << 3;
        memwr_tag = 10'd0;

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
        memrd_length = (aw_if.alen + 1) << 3;
        memrd_tag = {{(10-TAG_BIT){1'b0}}, tag_counter};

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

    PCIE_PKG::tlp_completion_w_data_hdr_t cpl_hdr;

    // P Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (4),             // FIFO depth: 16
        .DATA_WIDTH    (128),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .RST_MEM       (0)              // Reset: Retain Memory
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
    
    // P Data FIFO
    TL_FIFO #(
        .DEPTH_LG2     (4),             // FIFO depth: 16
        .DATA_WIDTH    (256),           // Data Width: 32B / 256bit / 8DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .RST_MEM       (0)              // Reset: Retain Memory
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

    // NP Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (4),             // FIFO depth: 16
        .DATA_WIDTH    (128),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .RST_MEM       (0)              // Reset: Retain Memory
    ) u_tx_np_hdr_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (np_hdr_full),
        .wren_i        (np_hdr_wren),
        .wdata_i       (np_hdr),

        .empty_o       (np_hdr_empty),
        .rden_i        (np_hdr_rden),
        .rdata_o       (np_hdr_rdata),

        .cnt_o         (),
        .debug_o       (np_hdr_debug)
    );

    // Cpl Header FIFO
    TL_FIFO #(
        .DEPTH_LG2     (RX_DEPTH_LG2),             // FIFO depth: 16
        .DATA_WIDTH    (96),           // Data Width: 12B / 96bit / 3DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .RST_MEM       (0)              // Reset: Retain Memory
    ) u_rx_cpl_hdr_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (cpl_hdr_full),
        .wren_i        (cpl_hdr_wren),
        .wdata_i       (cpl_hdr_wdata),

        .empty_o       (cpl_hdr_empty),
        .rden_i        (cpl_hdr_rden),
        .rdata_o       (cpl_hdr),

        .cnt_o         (cpl_hdr_cnt_o),
        .debug_o       (cpl_hdr_debug)
    );

    // Cpl Data FIFO
    TL_FIFO #(
        .DEPTH_LG2     (RX_DEPTH_LG2),             // FIFO depth: 16
        .DATA_WIDTH    (256),           // Data Width: 16B / 128bit / 4DW
        .RDATA_FF_OUT  (0),             // No Read Data FF
        .RST_MEM       (0)              // Reset: Retain Memory
    ) u_rx_cpl_data_fifo (
        .clk           (clk),
        .rst_n         (rst_n),

        .full_o        (cpl_data_full),
        .wren_i        (cpl_data_wren),
        .wdata_i       (r_if.rdata),

        .empty_o       (cpl_data_empty),
        .rden_i        (cpl_data_rden),
        .rdata_o       (cpl_data_rdata),

        .cnt_o         (cpl_data_cnt_o),
        .debug_o       (cpl_data_debug)
    );

endmodule
