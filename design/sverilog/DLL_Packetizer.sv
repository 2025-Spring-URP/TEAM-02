module DLL_Packetizer
#(
    parameter  integer  PIPE_DATA_WIDTH          = 256
)
(
    input   wire                                sclk,
    input   wire                                srst_n,

    // TL
    input   wire  [PIPE_DATA_WIDTH-1:0]         data_i,
    input   wire  [1:0]                         tl_d_en_i,          // 00 : IDLE, 01 : HDR, 10 : DATA

    // Retry Montior
    output  wire  [11:0]                        next_tlp_seq_o,

    output  wire  [PIPE_DATA_WIDTH/8-1:0]       data_o[8],
    output  wire                                wren_o,
    output  wire  [7:0]                         stp_strb_o,

    // Others
    input   wire                                link_up_i

);

// -------------------------------------------------------------------------------------------------
//                                     Define
// -------------------------------------------------------------------------------------------------

// Rules
// 1) MEMWR, MEMRD 모두 MSB에 정렬되어 온다

localparam      S_IDLE = 2'b00,
                S_HDR  = 2'b01,
                S_DATA = 2'b10;

localparam      FMT_WO_DATA_3DW    = 3'b000,     // CPL
                FMT_W_DATA_3DW     = 3'b010,     // CPLD
                FMT_WO_DATA_4DW    = 3'b001,     // MEMrd
                FMT_W_DATA_4DW     = 3'b011;     // MEMwr

localparam      EDS_F       = 32'b0,    //{8'b0000_0000, 8'b1001_0000, 8'b1000_0000, 8'b0001_1111};   // NO USE
                IDL_F       = 32'b0;


typedef struct packed {
    reg [7:0]   tlp_seq_num_l;  //  [31:24]
    reg [3:0]   fcrc;           //  [23:20]
    reg [3:0]   tlp_seq_num_h;  //  [19:16]
    reg         fp;             //  [15]
    reg [6:0]   tlp_len_h;      //  [14:8]
    reg [3:0]   tlp_len_l;      //  [7:4]
    reg [3:0]   ones;           //  [3:0]
} stp_t;

// -------------------------------------------------------------------------------------------------
//                                      STP Generator
// -------------------------------------------------------------------------------------------------

reg  [2:0]                  fmt, fmt_d;
reg  [1:0]                  tl_d_en_d;

reg [9:0]                  dw_size, dw_size_n, dw_size_d;

wire    [31:0]              data_w[8];

genvar i;
generate
    for(i=0; i<8; i++) begin : data_unpack
        assign data_w[i]        = data_i[i*32 +: 32];
    end
endgenerate



assign fmt                  = data_i[7:5];                            // 3 bit
assign dw_size_n            = {data_i[17:16], data_i[31:24]};         // 10bit          // update only at HDR


reg [11:0]          next_tlp_seq, next_tlp_seq_n;             // next_tlp_seq

stp_t           stp_d, stp_d_n;

always_ff @(posedge sclk) begin
    if(!srst_n) begin
        stp_d           <= 'd0;
        fmt_d           <= 'd0;
        tl_d_en_d       <= 'd0;
        dw_size_d       <= 'd0;
        dw_size         <= 'd0;
    end
    else begin
        stp_d           <= stp_d_n;
        fmt_d           <= fmt;
        tl_d_en_d       <= tl_d_en_i;
        if(tl_d_en_i == S_HDR) begin
            dw_size     <= dw_size_n;
        end
        else begin
            dw_size     <= 'd0;
        end
        dw_size_d       <= dw_size;
    end
end

always_comb begin
    stp_d_n.tlp_seq_num_h       = 'd0;
    stp_d_n.tlp_seq_num_l       = 'd0;
    stp_d_n.fcrc                = 'd0;
    stp_d_n.fp                  = 'd0;
    stp_d_n.tlp_len_h           = 'd0;
    stp_d_n.tlp_len_l           = 'd0;
    stp_d_n.ones                = 4'b1111;
    next_tlp_seq_n              = next_tlp_seq;
    if(tl_d_en_i == S_HDR) begin
        next_tlp_seq_n                      = next_tlp_seq + 'd1;
        stp_d_n.tlp_seq_num_h               = next_tlp_seq[11:8];
        stp_d_n.tlp_seq_num_l               = next_tlp_seq[7:0];

        case(fmt)
            FMT_W_DATA_3DW : begin            //ex) CPLD 3DW(HDR)
                {stp_d_n.tlp_len_h, stp_d_n.tlp_len_l}          = 'd6 + {1'b0, dw_size_n}; // STP(1DW), HDR(3DW), PAYLOAD, LRCR(1DW), END(1DW)]
            end
            FMT_WO_DATA_3DW : begin           //ex) CPL  3DW(HDR)
                {stp_d_n.tlp_len_h, stp_d_n.tlp_len_l}          = 'd6;
            end
            FMT_W_DATA_4DW : begin            //ex) MEMWR 4DW(HDR)
                {stp_d_n.tlp_len_h, stp_d_n.tlp_len_l}          = 'd7 + {1'b0, dw_size_n};     // STP(1DW), HDR(4DW), PAYLOAD, LRCR(1DW), END(1DW)
            end
            FMT_WO_DATA_4DW : begin           //ex) MEMRD 4DW(HDR)
                {stp_d_n.tlp_len_h, stp_d_n.tlp_len_l}          = 'd7;
            end
            // synopsys translate_off
            default : begin
                $display("No Support Prefix FMT Bits");
            end
            // synopsys translate_on
        endcase
    end
end

// -------------------------------------------------------------------------------------------------
//                                           CRC32 & CRC Manage
// -------------------------------------------------------------------------------------------------

/*
reg     [31:0]          lcrc_buffer;
reg                     lcrc_buffer_en;

CUSTOM_LCRC_GEN #(                                  // Combinational Logic, Used 1 CLK
    .CRC_DATA_WIDTH     (PIPE_DATA_WIDTH)          // 32B
)
U_LCRC32
(
    .crc2B_d_i         ({4'b0000, next_tlp_seq}),          // SEQ Input


    .crc32B_d_i        (data_i),    //
    .crc_ena_i         (),
    .crc_strb_i        (),          
    .crc_last_i        (crc_last),

    .crc4B_2d_o        (w_lcrc),         // 4B(32b)          // 1clk delay
    .crc_enb_o         (lcrc_wen)       // 1clk pulse
);
*/

// -------------------------------------------------------------------------------------------------
//                                      Shift Register
// -------------------------------------------------------------------------------------------------

reg  [PIPE_DATA_WIDTH/8-1:0]        data_d[8];
                                                                                

//-------------------------------------------------------------------------------------------
reg  [PIPE_DATA_WIDTH/8-1:0]        sort_d[8], sort_d_n[8];
reg  [PIPE_DATA_WIDTH/8-1:0]        sort_2d[8], sort_2d_n[8];
reg  [2:0]                          s2d_ptr, s2d_ptr_n;

reg                                 reserved_d,   reserved_2d,   wren_d,   wren_2d;
reg                                 reserved_d_n, reserved_2d_n, wren_d_n, wren_2d_n;
reg                                 reserved_3d;

reg [9:0]                           outstanding_payload_cnt,   outstanding_payload_cnt_n;

reg [7:0]                           stp_strb_2d, stp_strb_2d_n;

always_ff @(posedge sclk) begin
    if (!srst_n) begin
        for(int i=0; i<8; i++) begin
            data_d[i]          <= 'd0;
        end
    end
    else begin
        if(tl_d_en_i != S_IDLE) begin
            for(int i=0; i<8; i++) begin
                data_d[i]          <= data_w[i];
            end
        end
    end
end


always_ff @ (posedge sclk) begin
    if(!srst_n) begin
        outstanding_payload_cnt     <= 'd0;
        next_tlp_seq                <= 'd0;

        reserved_d                  <= 'd0;
        reserved_2d                 <= 'd0;
        reserved_3d                 <= 'd0;
        wren_d                      <= 'd0;
        wren_2d                     <= 'd0;
        s2d_ptr                     <= 'd0;

        stp_strb_2d                 <= 'd0;

        for(int i=0; i<8; i++) begin
            sort_d[i]           <= 'd0;
            sort_2d[i]          <= 'd0;
        end
        
    end
    else begin
        stp_strb_2d                 <= stp_strb_2d_n;
        outstanding_payload_cnt     <= outstanding_payload_cnt_n;
        next_tlp_seq                <= next_tlp_seq_n;
        reserved_d                  <= reserved_d_n;
        reserved_3d                 <= reserved_2d;

        if(reserved_d) begin
            reserved_2d             <= reserved_d;
        end
        else begin
            reserved_2d             <= reserved_2d_n;
        end
        wren_d                      <= wren_d_n;
        wren_2d                     <= wren_2d_n;
        s2d_ptr                     <= s2d_ptr_n;

        for(int i=0; i<8; i++) begin
            sort_d[i]       <= sort_d_n[i];
            if(wren_d) begin
                if(i < s2d_ptr) begin
                    sort_2d[i]                 <= sort_d[i];
                end
                else begin
                    sort_2d[i]                 <= sort_2d_n[i];
                end
            end
            else begin
                sort_2d[i]                     <= sort_2d_n[i];
            end
        end
    end
end


// 32B에 하나의 STP만 존재할 수 있도록 구현.
// 만약 Multi Frame을 하고 싶다면, sort_d --> sort_2d로 shift됨을 이용해서
// 미리 sort_d에 데이터를 넣으면됌
// reg  [3:0]   s2d_ptr을 사용해서 8을 넘어갈땐 sort_d에 작성되도록하면됌.
always_comb begin
    for(int i=0; i<8; i++) begin
        sort_2d_n[i]            = 'd0;
        sort_d_n[i]             = 'd0;
    end
    
    outstanding_payload_cnt_n   = 'd0;
    reserved_d_n                = 'd0;
    reserved_2d_n               = 'd0;
    wren_d_n                    = 'd0;
    wren_2d_n                   = 'd0;
    s2d_ptr_n                   = 'd0;
    stp_strb_2d_n               = 8'b0000_0000;
    case(tl_d_en_d)
    S_HDR : begin//------------------------------------------------------------------
        case(tl_d_en_i)
        S_HDR : begin                                   // 이전 : HDR, 현재 : HDR
            case(fmt_d)
            FMT_WO_DATA_3DW: begin
                sort_2d_n[0]      = stp_d;
                sort_2d_n[1]      = data_d[0];
                sort_2d_n[2]      = data_d[1];
                sort_2d_n[3]      = data_d[2];
                sort_2d_n[4]      = '1;            //LCRC Reserved
                sort_2d_n[5]      = IDL_F;         //IDL
                sort_2d_n[6]      = IDL_F;         //IDL
                sort_2d_n[7]      = IDL_F;         //IDL

                stp_strb_2d_n         = 8'b0000_0001;

                outstanding_payload_cnt_n       =   0;
                reserved_d_n      = 'd0;
                reserved_2d_n     = 'd1;
                wren_d_n          = 'd0;
                wren_2d_n         = 'd1;
                s2d_ptr_n         = 'd0;
            end
            FMT_WO_DATA_4DW: begin
                sort_2d_n[0]      = stp_d;
                sort_2d_n[1]      = data_d[0];
                sort_2d_n[2]      = data_d[1];
                sort_2d_n[3]      = data_d[2];
                sort_2d_n[4]      = data_d[3];
                sort_2d_n[5]      = '1;              //LCRC Reserved
                sort_2d_n[6]      = IDL_F;           //IDL
                sort_2d_n[7]      = IDL_F;           //IDL

                stp_strb_2d_n         = 8'b0000_0001;

                outstanding_payload_cnt_n       =   0;
                reserved_d_n      = 'd0;
                reserved_2d_n     = 'd1;
                wren_d_n          = 'd0;
                wren_2d_n         = 'd1;
                s2d_ptr_n         = 'd0;
            end
            // synopsys translate_off
            default : begin
                $display("FMT_d Error : This situation should without DATA");
            end
            // synopsys translate_on
            endcase
        end
        S_DATA: begin                                   // 이전 : HDR, 현재 : S_DATA
            case(fmt_d)                                 // 이 상황에서 payload_cnt가 8보다 작아서 LCRC만? END까지? 를 미리 넣을 수 있을 때 그런 상황 고려해야함
            FMT_W_DATA_3DW: begin
                sort_2d_n[0]          = stp_d;
                sort_2d_n[1]          = data_d[0];       // HDR
                sort_2d_n[2]          = data_d[1];
                sort_2d_n[3]          = data_d[2];

                stp_strb_2d_n         = 8'b0000_0001;

                case(dw_size)
                'd0 : begin
                    // synopsys translate_off
                    $display("ERROR! it should be at least 1 DW payload");
                    // synopsys translate_on
                end
                'd1 : begin
                    sort_2d_n[4]                = data_w[0];
                    sort_2d_n[5]                = '1;          //LCRC Reserved
                    sort_2d_n[6]                = IDL_F;       // IDL
                    sort_2d_n[7]                = IDL_F;       // IDL

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                'd2 : begin
                    sort_2d_n[4]                = data_w[0];
                    sort_2d_n[5]                = data_w[1];
                    sort_2d_n[6]                = '1;           //LCRC Reserved
                    sort_2d_n[7]                = IDL_F;        // IDL

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                'd3 : begin                                         // 여기서부터 END가 넘어가는 상황(END가 넘어가버릴때부터 wren_d 사용), PCIE 5.0은 END사용 X
                    sort_2d_n[4]                = data_w[0];
                    sort_2d_n[5]                = data_w[1];
                    sort_2d_n[6]                = data_w[2];
                    sort_2d_n[7]                = '1;         // LCRC

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                default : begin
                    sort_2d_n[4]                = data_w[0];
                    sort_2d_n[5]                = data_w[1];
                    sort_2d_n[6]                = data_w[2];
                    sort_2d_n[7]                = data_w[3];
                    $display("WHY");
                    outstanding_payload_cnt_n   = dw_size - 'd4;                          //---------------------------------------------
                    reserved_2d_n               = 'd0;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd4;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                endcase
            end
            FMT_W_DATA_4DW: begin
                sort_2d_n[0]                    = stp_d;
                sort_2d_n[1]                    = data_d[0];       // HDR
                sort_2d_n[2]                    = data_d[1];
                sort_2d_n[3]                    = data_d[2];
                sort_2d_n[4]                    = data_d[3];

                stp_strb_2d_n                   = 8'b0000_0001;

                $display("dw_size : %d  | dw_size_d : %d : ", dw_size, dw_size_d);
                case(dw_size)
                'd0 : begin
                    // synopsys translate_off
                    $display("ERROR! it should be at least 1 DW payload");
                    // synopsys translate_on
                end
                'd1 : begin
                    sort_2d_n[5]                = data_w[0];
                    sort_2d_n[6]                = '1;          // LCRC
                    sort_2d_n[7]                = IDL_F;        // IDL

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                'd2 : begin                                         // 여기서부터 END가 넘어가는 상황(END가 넘어가버릴때부터 wren_d 사용)
                    sort_2d_n[5]                = data_w[0];
                    sort_2d_n[6]                = data_w[1];
                    sort_2d_n[7]                = '1;         // LCRC 

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                default : begin
                    sort_2d_n[5]                = data_w[0];
                    sort_2d_n[6]                = data_w[1];
                    sort_2d_n[7]                = data_w[2];

                    outstanding_payload_cnt_n   = dw_size - 'd3;
                    reserved_2d_n               = 'd0;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd3;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                endcase
            end
            // synopsys translate_off
            default : begin
                $display("FMT_d Error : This situation should with DATA");
            end
            // synopsys translate_on
            endcase
        end
        S_IDLE: begin
            case(fmt_d)                                 // 이 상황에서 payload_cnt가 8보다 작아서 LCRC만? END까지? 를 미리 넣을 수 있을 때 그런 상황 고려해야함
            FMT_WO_DATA_3DW: begin
                sort_2d_n[0]      = stp_d;
                sort_2d_n[1]      = data_d[0];
                sort_2d_n[2]      = data_d[1];
                sort_2d_n[3]      = data_d[2];
                sort_2d_n[4]      = '1;            //LCRC Reserved
                sort_2d_n[5]      = IDL_F;         //IDL
                sort_2d_n[6]      = IDL_F;         //IDL
                sort_2d_n[7]      = IDL_F;         //IDL

                stp_strb_2d_n     = 8'b0000_0001;

                outstanding_payload_cnt_n   = 'd0;
                reserved_d_n                = 'd0;
                reserved_2d_n               = 'd1;
                wren_d_n                    = 'd0;
                wren_2d_n                   = 'd1;
                s2d_ptr_n                   = 'd0;
            end
            FMT_WO_DATA_4DW: begin
                sort_2d_n[0]      = stp_d;
                sort_2d_n[1]      = data_d[0];
                sort_2d_n[2]      = data_d[1];
                sort_2d_n[3]      = data_d[2];
                sort_2d_n[4]      = data_d[3];
                sort_2d_n[5]      = '1;              //LCRC Reserved
                sort_2d_n[6]      = IDL_F;           //IDL
                sort_2d_n[7]      = IDL_F;           //IDL

                stp_strb_2d_n     = 8'b0000_0001;

                outstanding_payload_cnt_n       = 'd0;
                reserved_d_n                    = 'd0;
                reserved_2d_n                   = 'd1;
                wren_d_n                        = 'd0;
                wren_2d_n                       = 'd1;
                s2d_ptr_n                       = 'd0;
            end
            FMT_W_DATA_3DW: begin
                sort_2d_n[0]          = stp_d;
                sort_2d_n[1]          = data_d[0];       // HDR
                sort_2d_n[2]          = data_d[1];
                sort_2d_n[3]          = data_d[2];

                stp_strb_2d_n         = 8'b0000_0001;

                case(dw_size)
                'd0 : begin
                    // synopsys translate_off
                    $display("ERROR! it should be at least 1 DW payload");
                    // synopsys translate_on
                end
                'd1 : begin
                    sort_2d_n[4]                = data_w[0];
                    sort_2d_n[5]                = '1;          // LCRC
                    sort_2d_n[6]                = IDL_F;       // IDL
                    sort_2d_n[7]                = IDL_F;       // IDL

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                'd2 : begin
                    sort_2d_n[4]                = data_w[0];
                    sort_2d_n[5]                = data_w[1];
                    sort_2d_n[6]                = '1;           // LCRC
                    sort_2d_n[7]                = IDL_F;        // IDL

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                'd3 : begin                                         // 여기서부터 END가 넘어가는 상황(END가 넘어가버릴때부터 wren_d 사용), PCIE 5.0은 END사용 X
                    sort_2d_n[4]                = data_w[0];
                    sort_2d_n[5]                = data_w[1];
                    sort_2d_n[6]                = data_w[2];
                    sort_2d_n[7]                = '1;         // LCRC

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                'd4 : begin
                    sort_2d_n[4]                = data_w[0];
                    sort_2d_n[5]                = data_w[1];
                    sort_2d_n[6]                = data_w[2];
                    sort_2d_n[7]                = data_w[3];
                    sort_d_n[0]                 = 32'hFFFF_FFFF;               // LCRC

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd0;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd1;
                    reserved_d_n                = 'd1;
                    wren_d_n                    = 'd1;
                end
                default : begin
                    sort_2d_n[4]                = data_w[0];
                    sort_2d_n[5]                = data_w[1];
                    sort_2d_n[6]                = data_w[2];
                    sort_2d_n[7]                = data_w[3];

                    outstanding_payload_cnt_n   = dw_size - 'd4;                          //---------------------------------------------
                    reserved_2d_n               = 'd0;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd4;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                endcase
            end
            FMT_W_DATA_4DW: begin
                sort_2d_n[0]                    = stp_d;
                sort_2d_n[1]                    = data_d[0];       // HDR
                sort_2d_n[2]                    = data_d[1];
                sort_2d_n[3]                    = data_d[2];
                sort_2d_n[4]                    = data_d[3];

                stp_strb_2d_n                   = 8'b0000_0001;

                case(dw_size)
                'd0 : begin
                    // synopsys translate_off
                    $display("ERROR! it should be at least 1 DW payload");
                    // synopsys translate_on
                end
                'd1 : begin
                    sort_2d_n[5]                = data_w[0];
                    sort_2d_n[6]                = '1;          // LCRC
                    sort_2d_n[7]                = IDL_F;        // IDL

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                'd2 : begin
                    sort_2d_n[5]                = data_w[0];
                    sort_2d_n[6]                = data_w[1];
                    sort_2d_n[7]                = '1;         // LCRC 

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd0;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;
                end
                'd3 : begin
                    sort_2d_n[5]                = data_w[0];
                    sort_2d_n[6]                = data_w[1];
                    sort_2d_n[7]                = data_w[2];

                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    s2d_ptr_n                   = 'd1;
                    reserved_d_n                = 'd1;
                    wren_d_n                    = 'd1;
                end
                default : begin
                    // synopsys translate_off
                    $display("ERROR, No Data!");
                    // synopsys translate_on
                end
                endcase
            end
            // synopsys translate_off
            default : begin
                $display("FMT_d Error : No Defined FMT");
            end
            // synopsys translate_on
            endcase
        end
        endcase
    end
    S_DATA : begin//------------------------------------------------------------------------
        if(outstanding_payload_cnt == 0) begin
            for(int i=1; i<8; i++) begin
                sort_2d_n[i]                = IDL_F;         // IDL
            end
            if(reserved_2d) begin
                sort_2d_n[0]                    = IDL_F;
                outstanding_payload_cnt_n       = 'd0;
                reserved_2d_n                   = 'd0;
                wren_2d_n                       = 'd0;
                reserved_d_n                    = 'd0;
                wren_d_n                        = 'd0;

                s2d_ptr_n                       = 'd0;
            end
            else begin
                sort_2d_n[0]                    = '1;   // LCRC
                outstanding_payload_cnt_n       = 'd0;
                reserved_2d_n                   = reserved_d;
                wren_2d_n                       = wren_d;
                reserved_d_n                    = 'd0;
                wren_d_n                        = 'd0;

                s2d_ptr_n                       = 'd0;
            end
            // synopsys translate_off
            $display("tl_d_en_d : S_DATA , Outstanding_payload_cnt == 0 : All data is done");
            // synopsys translate_on
        end
        else begin
            case(tl_d_en_i)
            S_HDR : begin                                   // 이전 : S_DATA, 현재 : S_HDR
                for(reg [10:0] i=0; i<8; i++) begin
                    if( i < outstanding_payload_cnt) begin                
                        sort_2d_n[i]      = data_d[s2d_ptr + i];
                    end
                    else if(i < outstanding_payload_cnt + 'd1) begin
                        sort_2d_n[i]      = '1;                         // LCRC
                    end
                    else begin
                        sort_2d_n[i]      = IDL_F;                      // IDL
                    end
                end
                outstanding_payload_cnt_n       = 'd0;
                reserved_2d_n                   = 'd1;  //reserved_d = 1이라서 어짜피 알아서 업데이트됨.
                wren_2d_n                       = 'd1;
                reserved_d_n                    = 'd0;
                wren_d_n                        = 'd0;

                s2d_ptr_n                       = 'd0;
            end
            S_DATA: begin                                   // 이전 : S_DATA, 현재 : S_DATA 
                if(outstanding_payload_cnt < 'd8) begin                         // LCRC Input
                    for(reg [10:0] i=0; i<8; i++) begin
                        if( i + s2d_ptr < 'd8) begin                
                            sort_2d_n[i]      = data_d[s2d_ptr + i];
                        end
                        else if( i < outstanding_payload_cnt ) begin
                            sort_2d_n[i]      = data_w[i+s2d_ptr-'d8];
                        end
                        else if(i < outstanding_payload_cnt + 'd1) begin
                            sort_2d_n[i]      = '1;                         // LCRC
                        end
                        else begin
                            sort_2d_n[i]      = IDL_F;                      // IDL
                        end
                    end
                    outstanding_payload_cnt_n   = 'd0;
                    reserved_2d_n               = 'd1;
                    wren_2d_n                   = 'd1;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;

                    s2d_ptr_n                   = 'd0;
                end
                else begin                                                      // No LCRC
                    for(reg [3:0] i=0; i<8; i++) begin
                        if( i + s2d_ptr < 'd8) begin                            // EX) s2d_ptr = 3
                            sort_2d_n[i]      = data_d[s2d_ptr + i];                //       3 4 5 6 7
                        end
                        else begin
                            sort_2d_n[i]      = data_w[i+s2d_ptr-'d8];          // 0 1 2
                        end
                    end
                    outstanding_payload_cnt_n   = outstanding_payload_cnt - 'd8;
                    reserved_2d_n               = 'd0;
                    wren_2d_n                   = 'd1;
                    reserved_d_n                = 'd0;
                    wren_d_n                    = 'd0;

                    s2d_ptr_n                   = s2d_ptr;
                end
            end
            S_IDLE: begin                                   // 이전 : S_DATA, 현재 : S_IDLE
                for(reg [10:0] i=0; i<8; i++) begin
                    if( i < outstanding_payload_cnt) begin                
                        sort_2d_n[i]      = data_d[s2d_ptr + i];
                    end
                    else if(i < outstanding_payload_cnt + 'd1) begin
                        sort_2d_n[i]      = '1;                         // LCRC
                    end
                    else begin
                        sort_2d_n[i]      = IDL_F;                      // IDL
                    end
                end
                outstanding_payload_cnt_n       = 'd0;
                reserved_2d_n                   = 'd1;
                wren_2d_n                       = 'd1;
                reserved_d_n                    = 'd0;
                wren_d_n                        = 'd0;

                s2d_ptr_n                       = 'd0;     
            end
            endcase
        end
    end
    S_IDLE : begin//------------------------------------------------------------------------  
        // synopsys translate_off
        $display("tl_d_en_d : S_IDLE");
        // synopsys translate_on
    end
    // synopsys translate_off
    default: begin
        $display("There is no tl_d_en STATE");
    end
    // synopsys translate_on
    endcase
end


// -------------------------------------------------------------------------------------------------
//                                      OUTPUT Buffer   
// -------------------------------------------------------------------------------------------------


generate
    for (genvar k = 0; k < 8; k++) begin
        assign  data_o[k]              = sort_2d[k];
    end
endgenerate

assign  wren_o               = wren_2d;
assign  next_tlp_seq_o       = next_tlp_seq;

assign  stp_strb_o           = stp_strb_2d;

endmodule
