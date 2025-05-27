module DLL_Packetizer_v1
#(
    parameter  integer  PIPE_DATA_WIDTH          = 256,
    parameter  integer  OUTSTANDING_BITS         = 10
)
(
    input   wire                                sclk,
    input   wire                                srst_n,

    // TL
    input   wire  [PIPE_DATA_WIDTH-1:0]         data_i,
    input   wire  [1:0]                         tl_d_en_i,          // 00 : IDLE, 01 : HDR, 10 : DATA

    // DLLP_GENERATOR
    output  wire  [15:0]                        next_tlp_seq_o,
    // Retry Montior
    output  wire  [PIPE_DATA_WIDTH/8-1:0]       data_o[8],
    output  wire                                wren_o,
    output  wire                                lcrc_o,
    output  wire  [2:0]                         stp_idx_o,
    output  wire  [1:0]                         stp_num_o
);


// Wire
PCIE_PKG::stp_t                     stp_reg;
PCIE_PKG::tlp_memory_req_hdr_t      mem_hdr;            // 4DW
PCIE_PKG::tlp_cpl_hdr_t             cpl_hdr;            // 3DW

reg     [15:0]              next_tlp_seq, next_tlp_seq_n;
reg     [9:0]               outstanding_cnt, outstanding_cnt_n;
reg     [31:0]              data_d[8], data_d_n[8];
reg                         wren_d, wren_d_n;
reg     [2:0]               stp1_idx, stp1_idx_n;
reg     [1:0]               stp_num, stp_num_n;
reg     [1:0]               tl_d_en_d;
reg                         LCRC_done, LCRC_done_n;
reg                         lcrc_reserved, lcrc_reserved_n;

localparam      S_IDLE = 2'b00,
                S_HDR  = 2'b01,
                S_DATA = 2'b10,
                S_DONE = 2'b11;

localparam      IDL_F  = 32'h0000_0000;
localparam      LCRC_F = 32'hFFFF_FFFF;

always_ff @(posedge sclk) begin
    if(!srst_n) begin
        next_tlp_seq        <= 'd0;
        outstanding_cnt     <= 'd0;
        tl_d_en_d           <= 'd0;
        for(int i=0; i<8; i++) begin
            data_d[i]       <= 'd0;
        end
        wren_d              <= 'd0;
        stp1_idx            <= 'd0;
        stp_num             <= 'd0;
        LCRC_done           <= 'd0;
        lcrc_reserved       <= 'd0;
    end
    else begin
        next_tlp_seq        <= next_tlp_seq_n;
        outstanding_cnt     <= outstanding_cnt_n;
        tl_d_en_d           <= tl_d_en_i;
        for(int i=0; i<8; i++) begin
            data_d[i]       <= data_d_n[i];
        end
        wren_d              <= wren_d_n;
        stp1_idx            <= stp1_idx_n;
        stp_num             <= stp_num_n;
        LCRC_done           <= LCRC_done_n;
        lcrc_reserved       <= lcrc_reserved_n;
    end
end


wire [11:0]     tlp_seq_num_w;      // 8+4
wire [10:0]     tlp_len_w;          // 7+4
assign tlp_seq_num_w            = next_tlp_seq;
assign tlp_len_w                = ({data_i[17:16], data_i[31:24]} + ((data_i[5] == 1'b0)? 10'd5 : 10'd6));  // PAYLOAD + (STP + HDR + LCRC)(5 or 6)

always_comb begin
    next_tlp_seq_n      = next_tlp_seq;
    outstanding_cnt_n   = outstanding_cnt;
    wren_d_n            = 'd0;
    stp1_idx_n          = 'd0;
    stp_num_n           = 'd0;
    LCRC_done_n         = 'd0;
    lcrc_reserved_n     = 'd0;

    case(tl_d_en_i)
    S_IDLE : begin
        for(int i=0; i<8; i++) begin
            data_d_n[i]         = 'd0;
        end
        outstanding_cnt_n   = 'd0;
    end
    S_HDR : begin
        next_tlp_seq_n        = next_tlp_seq + 'd1;
        if(data_i[6]) begin
            outstanding_cnt_n     = {data_i[17:16], data_i[31:24]};
        end
        wren_d_n              = 'd1;
        data_d_n[0]           = IDL_F;
        data_d_n[1]           = IDL_F;
        data_d_n[2]           = IDL_F;

        if(data_i[5] /* 4DW */) begin
            data_d_n[3]           = {4'hF, (tlp_seq_num_w), 1'b0, (tlp_len_w), 4'hF};   // STP
            data_d_n[4]           = data_i[0 +: 32];
            data_d_n[5]           = data_i[32 +: 32];
            data_d_n[6]           = data_i[64 +: 32];
            data_d_n[7]           = data_i[96 +: 32];
            stp1_idx_n            = 'd3;
            stp_num_n             = 'd1;
        end
        else begin
            data_d_n[3]           = IDL_F;
            data_d_n[4]           = {4'hF, (tlp_seq_num_w), 1'b0, (tlp_len_w), 4'hF};   // STP
            data_d_n[5]           = data_i[0 +: 32];
            data_d_n[6]           = data_i[32 +: 32];
            data_d_n[7]           = data_i[64 +: 32];
            stp1_idx_n            = 'd4;
            stp_num_n             = 'd1;
        end
    end
    S_DATA : begin
        wren_d_n        = 'd1;
        if(outstanding_cnt == 'd4) begin
            data_d_n[0]           = data_i[0 +: 32];
            data_d_n[1]           = data_i[32 +: 32];
            data_d_n[2]           = data_i[64 +: 32];
            data_d_n[3]           = data_i[96 +: 32];
            data_d_n[4]           = LCRC_F;
            data_d_n[5]           = IDL_F;
            data_d_n[6]           = IDL_F;
            data_d_n[7]           = IDL_F;
            
            LCRC_done_n           = 'd1;
            lcrc_reserved_n       = 'd1;
            outstanding_cnt_n     = outstanding_cnt - 'd4;
        end
        else begin
            for(int i=0; i<8; i++) begin
                data_d_n[i]          = data_i[i*32 +: 32];
            end
            outstanding_cnt_n       = outstanding_cnt - 'd8;
        end
    end
    S_DONE : begin
        if(outstanding_cnt != 'd0) begin
            // synopsys translate_off
            $display("ERROR : Packetizer Outstanding CNT : %d", outstanding_cnt);
            // synopsys translate_on
        end
        if(!LCRC_done) begin
            data_d_n[0]             = LCRC_F;
            LCRC_done_n             = 'd1;
            wren_d_n                = 'd1;
            lcrc_reserved_n         = 'd1;
        end
        else begin
            data_d_n[0]             = IDL_F;
        end

        for(int i=1; i<8; i++) begin
            data_d_n[i]             = IDL_F;
        end
    end
    endcase
end

generate
    for(genvar k=0; k<8; k++) begin : gen_assign_data
        assign data_o[k]         = data_d[k];
    end
endgenerate


assign wren_o               = wren_d;
assign next_tlp_seq_o       = next_tlp_seq;
assign lcrc_o               = lcrc_reserved;
assign stp_idx_o            = stp1_idx;
assign stp_num_o            = stp_num;

endmodule