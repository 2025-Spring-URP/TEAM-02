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

    input   wire                                s_axi_awvalid
  , output  wire                                s_axi_awready
  , input   wire    [5:0]                       s_axi_awid
  , input   wire    [63:0]                      s_axi_awaddr
  , input   wire    [7:0]                       s_axi_awlen
  , input   wire    [2:0]                       s_axi_awsize
  , input   wire    [1:0]                       s_axi_awburst
  , input   wire    [3:0]                       s_axi_awcache
  , input   wire    [2:0]                       s_axi_awprot
  , input   wire    [3:0]                       s_axi_awqos
  , input   wire    [3:0]                       s_axi_awregion

  , input   wire                                s_axi_wvalid
  , output  wire                                s_axi_wready
  , input   wire    [255:0]                     s_axi_wdata
  , input   wire    [31:0]                      s_axi_wstrb
  , input   wire                                s_axi_wlast

  , output  wire     [5:0]                      s_axi_bid
  , output  wire     [1:0]                      s_axi_bresp
  , output  wire                                s_axi_bvalid
  , input   wire                                s_axi_bready
    
  , input   wire                                s_axi_arvalid
  , output  wire                                s_axi_arready
  , input   wire    [5:0]                       s_axi_arid
  , input   wire    [63:0]                      s_axi_araddr
  , input   wire    [7:0]                       s_axi_arlen
  , input   wire    [2:0]                       s_axi_arsize
  , input   wire    [1:0]                       s_axi_arburst
  , input   wire    [3:0]                       s_axi_arcache
  , input   wire    [2:0]                       s_axi_arprot
  , input   wire    [3:0]                       s_axi_arqos
  , input   wire    [3:0]                       s_axi_arregion

  , output  wire                                s_axi_rvalid
  , input   wire                                s_axi_rready
  , output  wire    [5:0]                       s_axi_rid
  , output  wire    [255:0]                     s_axi_rdata
  , output  wire    [1:0]                       s_axi_rresp
  , output  wire                                s_axi_rlast

    

  , output  wire                                m_axi_awvalid
  , input   wire                                m_axi_awready
  , output  wire    [5:0]                       m_axi_awid
  , output  wire    [63:0]                      m_axi_awaddr
  , output  wire    [7:0]                       m_axi_awlen
  , output  wire    [2:0]                       m_axi_awsize
  , output  wire    [1:0]                       m_axi_awburst
  , output  wire    [3:0]                       m_axi_awcache
  , output  wire    [2:0]                       m_axi_awprot
  , output  wire    [3:0]                       m_axi_awqos
  , output  wire    [3:0]                       m_axi_awregion

  , output  wire                                m_axi_wvalid
  , input   wire                                m_axi_wready
  , output  wire    [255:0]                     m_axi_wdata
  , output  wire    [31:0]                      m_axi_wstrb
  , output  wire                                m_axi_wlast

  , input   wire    [5:0]                       m_axi_bid
  , input   wire    [1:0]                       m_axi_bresp
  , input   wire                                m_axi_bvalid
  , output  wire                                m_axi_bready

  , output  wire                                m_axi_arvalid
  , input   wire                                m_axi_arready
  , output  wire    [5:0]                       m_axi_arid
  , output  wire    [63:0]                      m_axi_araddr
  , output  wire    [7:0]                       m_axi_arlen
  , output  wire    [2:0]                       m_axi_arsize
  , output  wire    [1:0]                       m_axi_arburst
  , output  wire    [3:0]                       m_axi_arcache
  , output  wire    [2:0]                       m_axi_arprot
  , output  wire    [3:0]                       m_axi_arqos
  , output  wire    [3:0]                       m_axi_arregion

  , input   wire                                m_axi_rvalid
  , output  wire                                m_axi_rready
  , input   wire    [5:0]                       m_axi_rid
  , input   wire    [255:0]                     m_axi_rdata
  , input   wire    [1:0]                       m_axi_rresp
  , input   wire                                m_axi_rlast

);
    import PCIE_PKG::*;

    // AXI Master
    AXI4_A_IF aw_if_master;
    AXI4_A_IF ar_if_master;
    AXI4_W_IF w_if_master;
    AXI4_R_IF r_if_master;
    AXI4_B_IF b_if_master;

    // AXI Slave
    AXI4_A_IF aw_if_slave;
    AXI4_A_IF ar_if_slave;
    AXI4_W_IF w_if_slave;
    AXI4_R_IF r_if_slave;
    AXI4_B_IF b_if_slave;



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
        .rst_n                      (rst_n),
        .config_bdf_i               (config_bdf_i),
        .pipe_txdata                (pipe_txdata),
        .pipe_txvalid               (pipe_txvalid),
        .pipe_rxdata                (pipe_rxdata),
        .pipe_rxvalid               (pipe_rxvalid),
        .aw_if_master               (aw_if_master),
        .ar_if_master               (ar_if_master),
        .w_if_master                (w_if_master),
        .r_if_master                (r_if_master),
        .b_if_master                (b_if_master),
        .aw_if_slave                (aw_if_slave),
        .ar_if_slave                (ar_if_slave),
        .w_if_slave                 (w_if_slave),
        .r_if_slave                 (r_if_slave),
        .b_if_slave                 (b_if_slave)
    );





//----------------------------------------------------------------------------//
//  AXI Master Interface (m_axi_*) -> aw_if_master, w_if_master, b_if_master, //
//                               -> ar_if_master, r_if_master               //
//----------------------------------------------------------------------------//

// AW channel
assign aw_if_master.avalid    = m_axi_awvalid;
assign m_axi_awready          = aw_if_master.aready;
assign aw_if_master.aid       = m_axi_awid;
assign aw_if_master.aaddr     = m_axi_awaddr;
assign aw_if_master.alen      = m_axi_awlen;
assign aw_if_master.asize     = m_axi_awsize;
assign aw_if_master.aburst    = m_axi_awburst;
assign aw_if_master.acache    = m_axi_awcache;
assign aw_if_master.aprot     = m_axi_awprot;
assign aw_if_master.aqos      = m_axi_awqos;
assign aw_if_master.aregion   = m_axi_awregion;

// W channel
assign w_if_master.wvalid     = m_axi_wvalid;
assign m_axi_wready           = w_if_master.wready;
assign w_if_master.wdata      = m_axi_wdata;
assign w_if_master.wstrb      = m_axi_wstrb;
assign w_if_master.wlast      = m_axi_wlast;

// B channel
assign m_axi_bid              = b_if_master.bid;
assign m_axi_bresp            = b_if_master.bresp;
assign m_axi_bvalid           = b_if_master.bvalid;
assign b_if_master.bready     = m_axi_bready;

// AR channel
assign ar_if_master.avalid    = m_axi_arvalid;
assign m_axi_arready          = ar_if_master.aready;
assign ar_if_master.aid       = m_axi_arid;
assign ar_if_master.aaddr     = m_axi_araddr;
assign ar_if_master.alen      = m_axi_arlen;
assign ar_if_master.asize     = m_axi_arsize;
assign ar_if_master.aburst    = m_axi_arburst;
assign ar_if_master.acache    = m_axi_arcache;
assign ar_if_master.aprot     = m_axi_arprot;
assign ar_if_master.aqos      = m_axi_arqos;
assign ar_if_master.aregion   = m_axi_arregion;

// R channel
assign m_axi_rvalid           = r_if_master.rvalid;
assign r_if_master.rready     = m_axi_rready;
assign m_axi_rid              = r_if_master.rid;
assign m_axi_rdata            = r_if_master.rdata;
assign m_axi_rresp            = r_if_master.rresp;
assign m_axi_rlast            = r_if_master.rlast;


//----------------------------------------------------------------------------//
//  AXI Slave Interface (s_axi_*) -> aw_if_slave, w_if_slave, b_if_slave,     //
//                         -> ar_if_slave, r_if_slave                       //
//----------------------------------------------------------------------------//

// AW channel (slave receives, so direction reversed)
assign aw_if_slave.avalid     = s_axi_awvalid;
assign s_axi_awready          = aw_if_slave.aready;
assign aw_if_slave.aid        = s_axi_awid;
assign aw_if_slave.aaddr      = s_axi_awaddr;
assign aw_if_slave.alen       = s_axi_awlen;
assign aw_if_slave.asize      = s_axi_awsize;
assign aw_if_slave.aburst     = s_axi_awburst;
assign aw_if_slave.acache     = s_axi_awcache;
assign aw_if_slave.aprot      = s_axi_awprot;
assign aw_if_slave.aqos       = s_axi_awqos;
assign aw_if_slave.aregion    = s_axi_awregion;

// W channel
assign w_if_slave.wvalid      = s_axi_wvalid;
assign s_axi_wready           = w_if_slave.wready;
assign w_if_slave.wdata       = s_axi_wdata;
assign w_if_slave.wstrb       = s_axi_wstrb;
assign w_if_slave.wlast       = s_axi_wlast;

// B channel
assign s_axi_bid              = b_if_slave.bid;
assign s_axi_bresp            = b_if_slave.bresp;
assign s_axi_bvalid           = b_if_slave.bvalid;
assign b_if_slave.bready      = s_axi_bready;

// AR channel
assign ar_if_slave.avalid     = s_axi_arvalid;
assign s_axi_arready          = ar_if_slave.aready;
assign ar_if_slave.aid        = s_axi_arid;
assign ar_if_slave.aaddr      = s_axi_araddr;
assign ar_if_slave.alen       = s_axi_arlen;
assign ar_if_slave.asize      = s_axi_arsize;
assign ar_if_slave.aburst     = s_axi_arburst;
assign ar_if_slave.acache     = s_axi_arcache;
assign ar_if_slave.aprot      = s_axi_arprot;
assign ar_if_slave.aqos       = s_axi_arqos;
assign ar_if_slave.aregion    = s_axi_arregion;

// R channel
assign s_axi_rvalid           = r_if_slave.rvalid;
assign r_if_slave.rready      = s_axi_rready;
assign s_axi_rid              = r_if_slave.rid;
assign s_axi_rdata            = r_if_slave.rdata;
assign s_axi_rresp            = r_if_slave.rresp;
assign s_axi_rlast            = r_if_slave.rlast;



    assign  pipe_txdata             = txdata;
    assign  pipe_txvalid            = txvalid;
endmodule
