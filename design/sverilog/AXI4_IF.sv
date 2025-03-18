// Copyright (c) 2024 Sungkyunkwan University
// All rights reserved
// Description:


// Follows AMBA AXI and ACE protocol specification, 2013
// (ARM IHI0022E)
// - Each channel in the AXI protocol has its own interface

// follows the names and conventions from AMBA 4 AXI standard

// AXI4_A_IF can be used for AR and AW channels
interface AXI4_A_IF
#(
    parameter   ID_WIDTH                = 4,
    parameter   ADDR_WIDTH              = 32
)
(
    input   wire                        aclk,
    input   wire                        areset_n
);

    logic                               avalid;
    logic                               aready;
    logic   [ID_WIDTH-1:0]              aid;
    logic   [ADDR_WIDTH-1:0]            aaddr;
    logic   [7:0]                       alen;
    logic   [2:0]                       asize;
    logic   [1:0]                       aburst;
    logic   [3:0]                       acache;
    logic   [2:0]                       aprot;
    logic   [3:0]                       aqos;
    logic   [3:0]                       aregion;

    modport master (
        output      avalid, aid, aaddr, alen, asize,
                    aburst, acache, aprot, aqos, aregion,
        input       aready
    );

    modport slave (
        input       avalid, aid, aaddr, alen, asize,
                    aburst, acache, aprot, aqos, aregion,
        output      aready
    );

    modport monitor (
        input       avalid, aid, aaddr, alen, asize,
                    aburst, acache, aprot, aqos, aregion,
        input       aready
    );

    // synopsys translate_off
    int                                 count;
    always @(posedge aclk)
        if (~areset_n) begin
            count                           <= 0;
        end
        else if (avalid & aready) begin
            count                           <= count + 1;
        end

    // Properties to ensure all data/meta-data remain stable
    //after VALID is asserted
    // $stable is backward looking -> requires ##1 for one-cycle delay
    astable: assert property (   // AW data must remain stable
        @(posedge aclk) disable iff (~areset_n)
        avalid && !aready     |-> ##1 $stable(aid)
                                      && $stable(aaddr)
                                      && $stable(alen)
                                      && $stable(asize)
                                      && $stable(aburst)
                                      && $stable(acache)
                                      && $stable(aprot)
                                      && $stable(aqos)
                                      && $stable(aregion)
    );

    function automatic reset_master();
        avalid                          = 'd0;
        aid                             = 'dx;
        aaddr                           = 'dx;
        alen                            = 'dx;
        asize                           = 'dx;
        aburst                          = 'dx;
        acache                          = 'dx;
        aprot                           = 'dx;
        aqos                            = 'dx;
        aregion                         = 'dx;
    endfunction

    function automatic reset_slave();
        aready                          = 'd0;
    endfunction
    // synopsys translate_on

endinterface

interface AXI4_W_IF
#(
    parameter   ID_WIDTH                = 4,
    parameter   DATA_WIDTH              = 64,
    parameter   STRB_WIDTH              = (DATA_WIDTH/8)
)
(
    input   wire                        aclk,
    input   wire                        areset_n
);

    logic                               wvalid;
    logic                               wready;
    logic   [DATA_WIDTH-1:0]            wdata;
    logic   [STRB_WIDTH-1:0]            wstrb;
    logic                               wlast;

    modport master (
        output      wvalid, wdata, wstrb, wlast,
        input       wready
    );

    modport slave (
        input       wvalid, wdata, wstrb, wlast,
        output      wready
    );

    modport monitor (
        input       wvalid, wdata, wstrb, wlast,
        output      wready
    );

    // synopsys translate_off
    int                                 count;
    int                                 last_count;
    always @(posedge aclk)
        if (~areset_n) begin
            count                           <= 0;
        end
        else if (wvalid & wready) begin
            count                           <= count + 1;
        end
    always @(posedge aclk)
        if (~areset_n) begin
            last_count                      <= 0;
        end
        else if (wvalid & wready & wlast) begin
            last_count                      <= last_count + 1;
        end

    // Properties to ensure all data/meta-data remain stable
    //after VALID is asserted
    // $stable is backward looking -> requires ##1 for one-cycle delay
    wstable: assert property (   // AW data must remain stable
        @(posedge aclk) disable iff (~areset_n)
        wvalid && !wready     |-> ##1 $stable(wdata)
                                      && $stable(wstrb)
                                      && $stable(wlast)
    );

    function automatic reset_master();
        wvalid                          = 'd0;
        wdata                           = 'dx;
        wstrb                           = 'dx;
        wlast                           = 'dx;
    endfunction

    function automatic reset_slave();
        wready                          = 'd0;
    endfunction
    // synopsys translate_on

endinterface

interface AXI4_B_IF
#(
    parameter   ID_WIDTH                = 4
)
(
    input   wire                        aclk,
    input   wire                        areset_n
);

    logic                               bvalid;
    logic                               bready;
    logic   [ID_WIDTH-1:0]              bid;
    logic   [1:0]                       bresp;

    modport master (
        input       bvalid, bid, bresp,
        output      bready
    );

    modport slave (
        output      bvalid, bid, bresp,
        input       bready
    );

    modport monitor (
        output      bvalid, bid, bresp,
        input       bready
    );

    // synopsys translate_off
    int                                 count;
    always @(posedge aclk)
        if (~areset_n) begin
            count                           <= 0;
        end
        else if (bvalid & bready) begin
            count                           <= count + 1;
        end

    // Properties to ensure all data/meta-data remain stable
    //after VALID is asserted
    // $stable is backward looking -> requires ##1 for one-cycle delay
    bstable: assert property (   // AW data must remain stable
        @(posedge aclk) disable iff (~areset_n)
        bvalid && !bready     |-> ##1 $stable(bid)
                                      && $stable(bresp)
    );

    function automatic reset_master();
        bready                          = 'd0;
    endfunction

    function automatic reset_slave();
        bvalid                          = 'd0;
        bid                             = 'dx;
        bresp                           = 'dx;
    endfunction
    // synopsys translate_on

endinterface

interface AXI4_R_IF
#(
    parameter   ID_WIDTH                = 4,
    parameter   DATA_WIDTH              = 64
)
(
    input   wire                        aclk,
    input   wire                        areset_n
);

    logic                               rvalid;
    logic                               rready;
    logic   [ID_WIDTH-1:0]              rid;
    logic   [DATA_WIDTH-1:0]            rdata;
    logic   [1:0]                       rresp;
    logic                               rlast;

    modport master (
        input       rvalid, rid, rdata, rresp, rlast,
        output      rready
    );

    modport slave (
        output      rvalid, rid, rdata, rresp, rlast,
        input       rready
    );

    modport monitor (
        output      rvalid, rid, rdata, rresp, rlast,
        input       rready
    );

    // synopsys translate_off
    int                                 count;
    int                                 last_count;
    always @(posedge aclk)
        if (~areset_n) begin
            count                           <= 0;
        end
        else if (rvalid & rready) begin
            count                           <= count + 1;
        end
    always @(posedge aclk)
        if (~areset_n) begin
            last_count                      <= 0;
        end
        else if (rvalid & rready & rlast) begin
            last_count                      <= last_count + 1;
        end

    // Properties to ensure all data/meta-data remain stable
    //after VALID is asserted
    // $stable is backward looking -> requires ##1 for one-cycle delay
    rstable: assert property (   // AW data must remain stable
        @(posedge aclk) disable iff (~areset_n)
        rvalid && !rready     |-> ##1 $stable(rid)
                                      && $stable(rdata)
                                      && $stable(rresp)
                                      && $stable(rlast)
    );


    function automatic reset_master();
        rready                          = 'd0;
    endfunction

    function automatic reset_slave();
        rvalid                          = 'd0;
        rid                             = 'dx;
        rdata                           = 'dx;
        rresp                           = 'dx;
        rlast                           = 'dx;
    endfunction
    // synopsys translate_on

endinterface