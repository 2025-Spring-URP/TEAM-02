`include "PCIE_PKG.svh"

module PCIE_TOP_WRAPPER #
(
    parameter DATA_WIDTH = 256
)
(
    input  wire                                 clk,
    input  wire                                 rst,

    inout  wire [DATA_WIDTH-1:0]                pipe_txdata,
    inout  wire                                 pipe_txvalid,
    inout  wire [DATA_WIDTH-1:0]                pipe_rxdata,
    inout  wire                                 pipe_rxvalid,

    // -------- AXI Slave side (외부 AXI 마스터가 쓰는 신호) --------
    // → PCIE_TOP 내부의 “Slave 인터페이스”(aw_if_slave, w_if_slave, …) 와 연결
    input   wire                                s_axi_awvalid,
    output  wire                                s_axi_awready,
    input   wire    [5:0]                       s_axi_awid,
    input   wire    [63:0]                      s_axi_awaddr,
    input   wire    [7:0]                       s_axi_awlen,
    input   wire    [2:0]                       s_axi_awsize,
    input   wire    [1:0]                       s_axi_awburst,
    input   wire    [3:0]                       s_axi_awcache,
    input   wire    [2:0]                       s_axi_awprot,
    input   wire    [3:0]                       s_axi_awqos,
    input   wire    [3:0]                       s_axi_awregion,

    input   wire                                s_axi_wvalid,
    output  wire                                s_axi_wready,
    input   wire    [255:0]                     s_axi_wdata,
    input   wire    [31:0]                      s_axi_wstrb,
    input   wire                                s_axi_wlast,

    output  wire     [5:0]                      s_axi_bid,
    output  wire     [1:0]                      s_axi_bresp,
    output  wire                                s_axi_bvalid,
    input   wire                                s_axi_bready,

    input   wire                                s_axi_arvalid,
    output  wire                                s_axi_arready,
    input   wire    [5:0]                       s_axi_arid,
    input   wire    [63:0]                      s_axi_araddr,
    input   wire    [7:0]                       s_axi_arlen,
    input   wire    [2:0]                       s_axi_arsize,
    input   wire    [1:0]                       s_axi_arburst,
    input   wire    [3:0]                       s_axi_arcache,
    input   wire    [2:0]                       s_axi_arprot,
    input   wire    [3:0]                       s_axi_arqos,
    input   wire    [3:0]                       s_axi_arregion,

    output  wire                                s_axi_rvalid,
    input   wire                                s_axi_rready,
    output  wire    [5:0]                       s_axi_rid,
    output  wire    [255:0]                     s_axi_rdata,
    output  wire    [1:0]                       s_axi_rresp,
    output  wire                                s_axi_rlast,


    // -------- AXI Master side (외부 메모리/디바이스가 쓰는 신호) --------
    // → PCIE_TOP 내부의 “Master 인터페이스”(aw_if_master, w_if_master, …) 와 연결
    output  wire                                m_axi_awvalid,
    input   wire                                m_axi_awready,
    output  wire    [5:0]                       m_axi_awid,
    output  wire    [63:0]                      m_axi_awaddr,
    output  wire    [7:0]                       m_axi_awlen,
    output  wire    [2:0]                       m_axi_awsize,
    output  wire    [1:0]                       m_axi_awburst,
    output  wire    [3:0]                       m_axi_awcache,
    output  wire    [2:0]                       m_axi_awprot,
    output  wire    [3:0]                       m_axi_awqos,
    output  wire    [3:0]                       m_axi_awregion,

    output  wire                                m_axi_wvalid,
    input   wire                                m_axi_wready,
    output  wire    [255:0]                     m_axi_wdata,
    output  wire    [31:0]                      m_axi_wstrb,
    output  wire                                m_axi_wlast,

    input   wire    [5:0]                       m_axi_bid,
    input   wire    [1:0]                       m_axi_bresp,
    input   wire                                m_axi_bvalid,
    output  wire                                m_axi_bready,

    output  wire                                m_axi_arvalid,
    input   wire                                m_axi_arready,
    output  wire    [5:0]                       m_axi_arid,
    output  wire    [63:0]                      m_axi_araddr,
    output  wire    [7:0]                       m_axi_arlen,
    output  wire    [2:0]                       m_axi_arsize,
    output  wire    [1:0]                       m_axi_arburst,
    output  wire    [3:0]                       m_axi_arcache,
    output  wire    [2:0]                       m_axi_arprot,
    output  wire    [3:0]                       m_axi_arqos,
    output  wire    [3:0]                       m_axi_arregion,

    input   wire                                m_axi_rvalid,
    output  wire                                m_axi_rready,
    input   wire    [5:0]                       m_axi_rid,
    input   wire    [255:0]                     m_axi_rdata,
    input   wire    [1:0]                       m_axi_rresp,
    input   wire                                m_axi_rlast
);

    import PCIE_PKG::*;

    // ----------------------------------------------------------
    // ① 인터페이스 인스턴스화: 반드시 aclk/areset_n 연결
    // ----------------------------------------------------------
    AXI4_A_IF #(
        .ID_WIDTH   (6),
        .ADDR_WIDTH (64)
    ) aw_if_master (
        .aclk      (clk),
        .areset_n  (!rst)
    );

    AXI4_A_IF #(
        .ID_WIDTH   (6),
        .ADDR_WIDTH (64)
    ) ar_if_master (
        .aclk      (clk),
        .areset_n  (!rst)
    );

    AXI4_W_IF #(
        .ID_WIDTH   (6),
        .DATA_WIDTH (256),
        .STRB_WIDTH (32)
    ) w_if_master (
        .aclk      (clk),
        .areset_n  (!rst)
    );

    AXI4_R_IF #(
        .ID_WIDTH   (6),
        .DATA_WIDTH (256)
    ) r_if_master (
        .aclk      (clk),
        .areset_n  (!rst)
    );

    AXI4_B_IF #(
        .ID_WIDTH(6)
    ) b_if_master (
        .aclk      (clk),
        .areset_n  (!rst)
    );


    AXI4_A_IF #(
        .ID_WIDTH   (6),
        .ADDR_WIDTH (64)
    ) aw_if_slave (
        .aclk      (clk),
        .areset_n  (!rst)
    );

    AXI4_A_IF #(
        .ID_WIDTH   (6),
        .ADDR_WIDTH (64)
    ) ar_if_slave (
        .aclk      (clk),
        .areset_n  (!rst)
    );

    AXI4_W_IF #(
        .ID_WIDTH   (6),
        .DATA_WIDTH (256),
        .STRB_WIDTH (32)
    ) w_if_slave (
        .aclk      (clk),
        .areset_n  (!rst)
    );

    AXI4_R_IF #(
        .ID_WIDTH   (6),
        .DATA_WIDTH (256)
    ) r_if_slave (
        .aclk      (clk),
        .areset_n  (!rst)
    );

    AXI4_B_IF #(
        .ID_WIDTH(6)
    ) b_if_slave (
        .aclk      (clk),
        .areset_n  (!rst)
    );


    // ----------------------------------------------------------
    // ② PCIE_TOP 인스턴스화
    //    (TL_AXI_MASTER, TL_AXI_SLAVE 등이 내부에서
    //     aw_if_master/aw_if_slave를 드라이브)
    // ----------------------------------------------------------
    PCIE_TOP #(
        .AXI_ID_WIDTH               (6),
        .AXI_ADDR_WIDTH             (64),
        .MAX_READ_REQ_SIZE          (512),
        .MAX_PAYLOAD_SIZE           (128),
        .READ_COMPLETION_BOUNDARY   (128),
        .RX_DEPTH_LG2               (4),
        .TX_DEPTH_LG2               (3),
        .RETRY_DEPTH_LG2            (8),
        .PIPE_DATA_WIDTH            (DATA_WIDTH),
        .CREDIT_DEPTH               (12)
    ) u_pcie_top (
        .clk                        (clk),
        .rst_n                      (!rst),
        .config_bdf_i               (16'h0000),

        .pipe_txdata                (pipe_txdata),
        .pipe_txvalid               (pipe_txvalid),
        .pipe_rxdata                (pipe_rxdata),
        .pipe_rxvalid               (pipe_rxvalid),

        // “Slave 역할” 인터페이스
        .aw_if_slave                (aw_if_slave),
        .ar_if_slave                (ar_if_slave),
        .w_if_slave                 (w_if_slave),
        .r_if_slave                 (r_if_slave),
        .b_if_slave                 (b_if_slave),

        // “Master 역할” 인터페이스
        .aw_if_master               (aw_if_master),
        .ar_if_master               (ar_if_master),
        .w_if_master                (w_if_master),
        .r_if_master                (r_if_master),
        .b_if_master                (b_if_master)
    );


    // ----------------------------------------------------------
    // ③ “Wrapper → PCIE_TOP( Slave 인터페이스 )” 매핑: s_axi_* → aw_if_slave, …
    // ----------------------------------------------------------

    // AW 채널 (Slave)
    assign aw_if_slave.avalid   = s_axi_awvalid;       // Wrapper 입력 → Slave avalid
    assign s_axi_awready        = aw_if_slave.aready;  // Slave aready → Wrapper 출력
    assign aw_if_slave.aid      = s_axi_awid;
    assign aw_if_slave.aaddr    = s_axi_awaddr;
    assign aw_if_slave.alen     = s_axi_awlen;
    assign aw_if_slave.asize    = s_axi_awsize;
    assign aw_if_slave.aburst   = s_axi_awburst;
    assign aw_if_slave.acache   = s_axi_awcache;
    assign aw_if_slave.aprot    = s_axi_awprot;
    assign aw_if_slave.aqos     = s_axi_awqos;
    assign aw_if_slave.aregion  = s_axi_awregion;

    // W 채널 (Slave)
    assign w_if_slave.wvalid    = s_axi_wvalid;        // Wrapper 입력 → Slave wvalid
    assign s_axi_wready         = w_if_slave.wready;    // Slave wready → Wrapper 출력
    assign w_if_slave.wdata     = s_axi_wdata;
    assign w_if_slave.wstrb     = s_axi_wstrb;
    assign w_if_slave.wlast     = s_axi_wlast;

    // B 채널 (Slave)
    assign b_if_slave.bready    = s_axi_bready;        // Wrapper 입력 → Slave bready
    assign s_axi_bid            = b_if_slave.bid;      // Slave bid → Wrapper 출력
    assign s_axi_bresp          = b_if_slave.bresp;    // Slave bresp → Wrapper 출력
    assign s_axi_bvalid         = b_if_slave.bvalid;   // Slave bvalid → Wrapper 출력

    // AR 채널 (Slave)
    assign ar_if_slave.avalid   = s_axi_arvalid;       // Wrapper 입력 → Slave avalid
    assign s_axi_arready        = ar_if_slave.aready;  // Slave aready → Wrapper 출력
    assign ar_if_slave.aid      = s_axi_arid;
    assign ar_if_slave.aaddr    = s_axi_araddr;
    assign ar_if_slave.alen     = s_axi_arlen;
    assign ar_if_slave.asize    = s_axi_arsize;
    assign ar_if_slave.aburst   = s_axi_arburst;
    assign ar_if_slave.acache   = s_axi_arcache;
    assign ar_if_slave.aprot    = s_axi_arprot;
    assign ar_if_slave.aqos     = s_axi_arqos;
    assign ar_if_slave.aregion  = s_axi_arregion;

    // R 채널 (Slave)
    assign r_if_slave.rready    = s_axi_rready;        // Wrapper 입력 → Slave rready
    assign s_axi_rvalid         = r_if_slave.rvalid;   // Slave rvalid → Wrapper 출력
    assign s_axi_rid            = r_if_slave.rid;      // Slave rid → Wrapper 출력
    assign s_axi_rdata          = r_if_slave.rdata;    // Slave rdata → Wrapper 출력
    assign s_axi_rresp          = r_if_slave.rresp;    // Slave rresp → Wrapper 출력
    assign s_axi_rlast          = r_if_slave.rlast;    // Slave rlast → Wrapper 출력


    // ----------------------------------------------------------
    // ④ “Wrapper → PCIE_TOP( Master 인터페이스 )” 매핑: aw_if_master → m_axi_*, …
    // ----------------------------------------------------------

    // AW 채널 (Master)
    assign m_axi_awvalid        = aw_if_master.avalid;   // Master의 avalid → 외부 m_axi_awvalid
    assign aw_if_master.aready  = m_axi_awready;         // 외부 m_axi_awready → Master의 aready
    assign m_axi_awid           = aw_if_master.aid;      // Master의 aid → 외부 m_axi_awid
    assign m_axi_awaddr         = aw_if_master.aaddr;    // Master의 aaddr → 외부 m_axi_awaddr
    assign m_axi_awlen          = aw_if_master.alen;     // Master의 alen → 외부 m_axi_awlen
    assign m_axi_awsize         = aw_if_master.asize;    // Master의 asize → 외부 m_axi_awsize
    assign m_axi_awburst        = aw_if_master.aburst;   // Master의 aburst → 외부 m_axi_awburst
    assign m_axi_awcache        = aw_if_master.acache;   // Master의 acache → 외부 m_axi_awcache
    assign m_axi_awprot         = aw_if_master.aprot;    // Master의 aprot → 외부 m_axi_awprot
    assign m_axi_awqos          = aw_if_master.aqos;     // Master의 aqos → 외부 m_axi_awqos
    assign m_axi_awregion       = aw_if_master.aregion;  // Master의 aregion → 외부 m_axi_awregion

    // W 채널 (Master)
    assign m_axi_wvalid         = w_if_master.wvalid;    // Master의 wvalid → 외부 m_axi_wvalid
    assign w_if_master.wready   = m_axi_wready;          // 외부 m_axi_wready → Master의 wready
    assign m_axi_wdata          = w_if_master.wdata;     // Master의 wdata → 외부 m_axi_wdata
    assign m_axi_wstrb          = w_if_master.wstrb;     // Master의 wstrb → 외부 m_axi_wstrb
    assign m_axi_wlast          = w_if_master.wlast;     // Master의 wlast → 외부 m_axi_wlast

    // B 채널 (Master)
    // ★ 바뀐 부분: m_axi_bready는 내부 b_if_master.bready 값을 외부로 내보냄
    assign m_axi_bready         = b_if_master.bready;     // Master 내부 bready → 외부 m_axi_bready
    assign m_axi_bid            = b_if_master.bid;       // Master의 bid → 외부 m_axi_bid
    assign m_axi_bresp          = b_if_master.bresp;     // Master의 bresp → 외부 m_axi_bresp
    assign m_axi_bvalid         = b_if_master.bvalid;    // Master의 bvalid → 외부 m_axi_bvalid

    // AR 채널 (Master)
    assign m_axi_arvalid        = ar_if_master.avalid;   // Master의 avalid → 외부 m_axi_arvalid
    assign ar_if_master.aready  = m_axi_arready;         // 외부 m_axi_arready → Master의 aready
    assign m_axi_arid           = ar_if_master.aid;      // Master의 aid → 외부 m_axi_arid
    assign m_axi_araddr         = ar_if_master.aaddr;    // Master의 aaddr → 외부 m_axi_araddr
    assign m_axi_arlen          = ar_if_master.alen;     // Master의 alen → 외부 m_axi_arlen
    assign m_axi_arsize         = ar_if_master.asize;    // Master의 asize → 외부 m_axi_arsize
    assign m_axi_arburst        = ar_if_master.aburst;   // Master의 aburst → 외부 m_axi_arburst
    assign m_axi_arcache        = ar_if_master.acache;   // Master의 acache → 외부 m_axi_arcache
    assign m_axi_arprot         = ar_if_master.aprot;    // Master의 aprot → 외부 m_axi_arprot
    assign m_axi_arqos          = ar_if_master.aqos;     // Master의 aqos → 외부 m_axi_arqos
    assign m_axi_arregion       = ar_if_master.aregion;  // Master의 aregion → 외부 m_axi_arregion

    // R 채널 (Master)
    // ★ 바뀐 부분: m_axi_rready는 내부 r_if_master.rready 값을 외부로 내보냄
    assign m_axi_rready         = r_if_master.rready;     // Master 내부 rready → 외부 m_axi_rready
    assign m_axi_rvalid         = r_if_master.rvalid;    // Master의 rvalid → 외부 m_axi_rvalid
    assign m_axi_rid            = r_if_master.rid;       // Master의 rid → 외부 m_axi_rid
    assign m_axi_rdata          = r_if_master.rdata;     // Master의 rdata → 외부 m_axi_rdata
    assign m_axi_rresp          = r_if_master.rresp;     // Master의 rresp → 외부 m_axi_rresp
    assign m_axi_rlast          = r_if_master.rlast;     // Master의 rlast → 외부 m_axi_rlast

endmodule
