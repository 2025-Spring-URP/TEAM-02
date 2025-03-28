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
    parameter   ADDR_WIDTH              = 32,
    parameter   MAX_TRANSACTION_BYTES   = 4096                  // 4096B = 2^12 Bytes = 4KB     (4KB Boundary) --> OS가 기본 페이지 크기를 4KB로 설정, 페이지를 넘기면 TLB switch? , 대부분의 메모리가 4KB boundary로 설계됨?
)
(   
    input   wire                        aclk,
    input   wire                        areset_n
);
                                                                // Interface는 4-state(0, 1, x, z) 를 지원하는 logic으로 짜야함.        
    logic                               avalid;                 // Valid (Master -> Slave)
    logic                               aready;                 // Ready (Slave -> Master)
    logic   [ID_WIDTH-1:0]              aid;                    // Transaction identifier
    logic   [ADDR_WIDTH-1:0]            aaddr;                  // 32Bit address (4GB 메모리)
    logic   [7:0]                       alen;                   // Length       (한번의 Burst에서 전송되는 데이터 전송 횟수)
    logic   [2:0]                       asize;                  // Size         (Byte 단위, Data / 8, Burst시 한번의 Beat마다 Size만큼 데이터를 Len번 보냄) EX) 100b --> 16bytes per transfer
    logic   [1:0]                       aburst;                 // Burst Attribute
    logic   [3:0]                       acache;                 // Memory Attrtibute, (Bufferable, Modifiable-분할, 병합, 변경ok, 
    logic   [2:0]                       aprot;                  // Access Attribtues, 접근 권한 (Realm Management Extentension을 통한 메모리 보호, 메모리/캐시 등을 보안 격리된 실행 컨텍스트 끼리 공유/분리)
    logic   [3:0]                       aqos;                   // QoS Identifier
    logic   [3:0]                       aregion;                // Address Decode없이 이 필드를 바탕으로 빠르게 처리 가능

    modport master (                                            // Signal 방향을  정의하는데 사용
        output      avalid, aid, aaddr, alen, asize,
                    aburst, acache, aprot, aqos, aregion,
        input       aready
    );

    modport slave (
        input       avalid, aid, aaddr, alen, asize,
                    aburst, acache, aprot, aqos, aregion,
        output      aready
    );

    modport monitor (                                           // Verification용 관찰용
        input       avalid, aid, aaddr, alen, asize,
                    aburst, acache, aprot, aqos, aregion,
        input       aready
    );

    // synopsys translate_off
    //                                                                      / 위 주석을 사용시, 시뮬레이션에서는 포함되지만 Synthesis에서는 무시됨                    
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
    /* // AXI 프로토콜은 Valid가 1이 된 이후, READY가 될때까지 Stable(유지)해야함. 이를 확인
    *  Label 이름 : Astable  <-- Error시 라벨 이름이 뜸
    *  disable iff <-- 조건이 맞다면 이 assertion은 비활성화, 여기서 iff 는 if and only if
    *  |-> 의미 연산자로, "왼쪽 조건이 만족되면 오른쪽 조건이 항상 따라와야 한다는 뜻".
    */
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
    /*
    * AXI4_A_IF m_if(...);
    * initial m_if.reset_master();
    * 위와 같이 쓸 수 있음음
    * automatic : 함수가 호출될 때 마다 고유한 스택 프레임을 생성 (변수 간섭이 없음)
    *  Reset이후에도 값이 연산이 안되어 계속 'dx 인 상태로 있다면 검증할때 찾기 편해서 'dx로 설정함. (중요) 
    */
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


    //Defined By LIM
    //           ____             
    // CLK  ____|    |___
    //         ____
    // GNT  __|  
    //              __
    // REQ  _______|
    // EX) Clocking Block Example <-- This is for Verification, 쉽게 입력을 인가하고, Race Condition을 해결해주는 목적
    clocking cb @(posedge clk);
        default     input   #1step    output  #2ns;   // 이렇게 Default로 기본 설정 가능.   , 1Step이란 scheduling Time을 다음으로 미루어 Race conditon을 예방목적! (디폴트값)
        inptut 
        input   #1ns    gnt;                          // DUT --> TB  방향의 신호(input , Sampling)     : posedge clk - 1ns 
        output  #5      req;                          // TB  --> DUT 방향의 신호(output, Drive)        : posedge clk + 5 time units    (`timescale을 작성해야 time units이 결정됨)

        output  negedge grant;                        // 얘는 Default 적용 되므로, Negedge의 2ns 뒤에 
    endclocking



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
    logic   [1:0]                       bresp;              // Slave --> Master에게 쓰기 결과가 어땠는지 알려줌 (전체 Burst의 결과를 하나로 요약전달)
                                                            // 여기서, Exclusive(단독) Access란? : 단독으로 읽고,쓰고, 그 사이에 아무도 못건드리게 보장하는 접근방식
                                                            // 멀티 코어 시스템에서 Race Condition을 피하고, Lock-Free 방식의 동기화 구현, atomic 연산에도 쓰임

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
    logic   [1:0]                       rresp;                  // 마찬가지로 Slave가 읽기 결과가 정상인지 오류가 있는지 알려주는 신호,
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