`include "PCIE_PKG.svh"
import PCIE_PKG::*;

module DLL_DLLP_Generator
#(
    parameter   PIPE_DATA_WIDTH             = 256,
    parameter   SEQ_BITS                    = 12,

    parameter   CREDIT_LIMIT_P_HEADER       = 16,
    parameter   CREDIT_LIMIT_P_DATA         = 16,
    parameter   CREDIT_LIMIT_NP_HEADER      = 16,
    parameter   CREDIT_LIMIT_CPL_HEADER     = 16,
    parameter   CREDIT_LIMIT_CPL_DATA       = 16
)
(
    input   wire                                    sclk,
    input   wire                                    srst_n,

    // DLCMSM
    input   wire     [1:0]                          DLCM_state_i,           // inactive(0) init1(1) init2(2) active(2)

    output  wire                                    init1_send_o,           // init1 dllp 3개 다 보내면 1로 활성화
    output  wire                                    init2_send_o,           // init2 dllp 3개 다 보내면 1로 활성화

    // Transaction Layer
    input 	wire	[11:0]		                    cc_p_h_i,		        // Posted(Write) header credit consumed
    input 	wire	[11:0]		                    cc_p_d_i,		        // Posted(Write) data credit consumed
	input 	wire	[11:0]		                    cc_np_h_i,		        // Non-Posted(Read) header credit consumed
	input 	wire	[11:0]		                    cc_cpl_h_i,	            // Completion credit header consumed
    input 	wire	[11:0]		                    cc_cpl_d_i,	            // Completion credit data consumed

    // Decoder
    input   wire                                    NAK_scheduled_i,        // CRC에러/SEQ에러 감지하면 1로 활성화돼서 들어옴
    input   wire    [SEQ_BITS-1:0]                  next_rcv_seq_i,         // 지금까지 잘 받은 패킷의 SEQ. 외부에 있는 레지스터에 저장되어있음

    // Arbiter
    output  wire    [PIPE_DATA_WIDTH-1:0]           dllp_data_o,            // 버퍼에게 보내는 32바이트짜리 DLLP 조각
    output  wire                                    dllp_valid_o,            // 버퍼에게 보낼게 하는 신호
    input   wire                                    arb_ready_i
);

// 여기서 만들어야 할 DLLP는 INIT1, INIT2, UpdateFC, ACK, NAK
// INIT1의 경우 DLCM_state_i로 init1(1)이 들어오면 P, NP, CPL의 credit limit을 담아서 스펙에 적힌 init1 format을 따른 DLLP를 생성
// credit limit은 파라미터로 받고, credit consumed는 tl로부터 계속 최신값을 받을거임
// 근데 dllp 3개 보내면 init1_send를 활성화하지만 dllp는 이후에도 계속해서 P, NP CPL 순서로 반복해서 보냄. 그건 arbiter가 해야할일.


// INIT1 DLLP

reg [2:0]                   init1_state, init1_state_n;
reg [14:0]                  init1_cnt, init1_cnt_n;
reg                         init1_send, init1_send_n;

dllp_FC_packet_t            init1_p_dllp, init1_np_dllp, init1_cpl_dllp;
reg [47:0]                  init1_crc_input;
reg [15:0]                  init1_crc_temp;

reg [PIPE_DATA_WIDTH-1:0]   init1_dllp_data;
reg                         init1_dllp_valid;

localparam                  S_INIT1_IDLE     = 3'd0,
                            S_INIT1_CRC_P    = 3'd1,
                            S_INIT1_SEND_P   = 3'd2,
                            S_INIT1_CRC_NP   = 3'd3,
                            S_INIT1_SEND_NP  = 3'd4,
                            S_INIT1_CRC_CPL  = 3'd5,
                            S_INIT1_SEND_CPL = 3'd6,
                            S_INIT1_WAIT     = 3'd7;

always_ff @(posedge sclk) begin
    if (!srst_n || (DLCM_state_i != 2'd1)) begin
        init1_state     <= S_INIT1_IDLE;
        init1_cnt       <= 15'd0;
        init1_send      <= 1'b0;
    end
    else begin
        init1_state     <= init1_state_n;
        init1_cnt       <= init1_cnt_n;
        init1_send      <= init1_send_n;
    end
end

always_comb begin
    init1_state_n       = init1_state;
    init1_cnt_n         = init1_cnt;
    init1_send_n        = init1_send;

    init1_crc_input     = 32'd0;
    init1_crc_temp      = 16'hFFFF;

    init1_dllp_data     = 'd0;
    init1_dllp_valid    = 1'b0;

    case (init1_state)
        S_INIT1_IDLE: begin
            if (DLCM_state_i == 2'd1) begin
                init1_p_dllp.crc16      = 16'd0;
                init1_p_dllp.dllp_type  = 8'b0100_0000;
                init1_p_dllp.hdrFC_h    = CREDIT_LIMIT_P_HEADER[7:2];
                init1_p_dllp.hdrFC_l    = CREDIT_LIMIT_P_HEADER[1:0];
                init1_p_dllp.dataFC_h   = CREDIT_LIMIT_P_DATA[11:8];
                init1_p_dllp.dataFC_l   = CREDIT_LIMIT_P_DATA[7:0];
                init1_p_dllp.hdrScale   = 2'b00;
                init1_p_dllp.dataScale  = 2'b00;

                init1_np_dllp.crc16      = 16'd0;
                init1_np_dllp.dllp_type  = 8'b0101_0000;
                init1_np_dllp.hdrFC_h    = CREDIT_LIMIT_NP_HEADER[7:2];
                init1_np_dllp.hdrFC_l    = CREDIT_LIMIT_NP_HEADER[1:0];
                init1_np_dllp.dataFC_h   = 4'd0;
                init1_np_dllp.dataFC_l   = 8'd0;
                init1_np_dllp.hdrScale   = 2'b00;
                init1_np_dllp.dataScale  = 2'b00;

                init1_cpl_dllp.crc16     = 16'd0;
                init1_cpl_dllp.dllp_type = 8'b0110_0000;
                init1_cpl_dllp.hdrFC_h   = CREDIT_LIMIT_CPL_HEADER[7:2];
                init1_cpl_dllp.hdrFC_l   = CREDIT_LIMIT_CPL_HEADER[1:0];
                init1_cpl_dllp.dataFC_h  = CREDIT_LIMIT_CPL_DATA[11:8];
                init1_cpl_dllp.dataFC_l  = CREDIT_LIMIT_CPL_DATA[7:0];
                init1_cpl_dllp.hdrScale  = 2'b00;
                init1_cpl_dllp.dataScale = 2'b00;

                init1_state_n            = S_INIT1_CRC_P;
            end
            else begin
                init1_state_n            = S_INIT1_IDLE;
            end
        end
        S_INIT1_CRC_P: begin
            init1_crc_input              = init1_p_dllp[31:0];
            for (int i = 0; i < 32; i++) begin
                if ((init1_crc_temp[15] ^ init1_crc_input[31 - i]) == 1'b1)
                    init1_crc_temp       = {init1_crc_temp[14:0], 1'b0} ^ 16'h100B;
                else
                    init1_crc_temp       = {init1_crc_temp[14:0], 1'b0};
            end
            init1_p_dllp.crc16           = ~init1_crc_temp;
            init1_state_n                = S_INIT1_SEND_P;
        end
        S_INIT1_SEND_P: begin
            init1_dllp_valid             = 1'b1;
            init1_dllp_data              = {192'd0, init1_p_dllp, 16'hACF0};
            if (arb_ready_i) begin
                init1_state_n                = S_INIT1_CRC_NP;
            end
        end
        S_INIT1_CRC_NP: begin
            if (!init1_send) begin
                init1_crc_input              = init1_np_dllp[31:0];
                for (int i = 0; i < 32; i++) begin
                    if ((init1_crc_temp[15] ^ init1_crc_input[31 - i]) == 1'b1)
                        init1_crc_temp       = {init1_crc_temp[14:0], 1'b0} ^ 16'h100B;
                    else
                        init1_crc_temp       = {init1_crc_temp[14:0], 1'b0};
                end
                init1_np_dllp.crc16          = ~init1_crc_temp;
            end
            init1_state_n                = S_INIT1_SEND_NP;
        end
        S_INIT1_SEND_NP: begin
            init1_dllp_valid             = 1'b1;
            init1_dllp_data              = {192'd0, init1_np_dllp, 16'hACF0};
            if (arb_ready_i) begin
                init1_state_n                = S_INIT1_CRC_CPL;
            end
        end
        S_INIT1_CRC_CPL: begin
            if (!init1_send) begin
                init1_crc_input              = init1_cpl_dllp[31:0];
                for (int i = 0; i < 32; i++) begin
                    if ((init1_crc_temp[15] ^ init1_crc_input[31 - i]) == 1'b1)
                        init1_crc_temp       = {init1_crc_temp[14:0], 1'b0} ^ 16'h100B;
                    else
                        init1_crc_temp       = {init1_crc_temp[14:0], 1'b0};
                end
                init1_cpl_dllp.crc16         = ~init1_crc_temp;
            end
            init1_state_n                = S_INIT1_SEND_CPL;
        end
        S_INIT1_SEND_CPL: begin
            init1_dllp_valid             = 1'b1;
            init1_dllp_data              = {128'd0, init1_cpl_dllp, 16'hACF0};
            if (arb_ready_i) begin
                init1_state_n                = S_INIT1_WAIT;
            end
        end
        S_INIT1_WAIT: begin
            init1_send_n                 = 1'b1;
            if (init1_cnt == 'd1023) begin
                init1_state_n            = S_INIT1_SEND_P;
                init1_cnt_n              = 15'd0;
            end
            else begin
                init1_state_n            = S_INIT1_WAIT;
                init1_cnt_n              = init1_cnt + 15'd1;
            end
        end
    endcase
end

// INIT2의 경우 DLCM_state_i로 init2(2)가 들어오면 P, NP, CPL의 credit limit을 담아서 스펙에 적힌 init2 format을 따른 DLLP를 생성
// 얘도 dllp 3개 보내면 init2_send를 활성화하지만 dllp는 이후에도 계속해서 P, NP CPL 순서로 반복해서 보냄

// INIT2 DLLP

reg [2:0]                   init2_state, init2_state_n;
reg [14:0]                  init2_cnt, init2_cnt_n;
reg                         init2_send, init2_send_n;

dllp_FC_packet_t            init2_p_dllp, init2_np_dllp, init2_cpl_dllp;
reg [47:0]                  init2_crc_input;
reg [15:0]                  init2_crc_temp;

reg [PIPE_DATA_WIDTH-1:0]   init2_dllp_data;
reg                         init2_dllp_valid;


localparam                  S_INIT2_IDLE     = 3'd0,
                            S_INIT2_CRC_P    = 3'd1,
                            S_INIT2_SEND_P   = 3'd2,
                            S_INIT2_CRC_NP   = 3'd3,
                            S_INIT2_SEND_NP  = 3'd4,
                            S_INIT2_CRC_CPL  = 3'd5,
                            S_INIT2_SEND_CPL = 3'd6,
                            S_INIT2_WAIT     = 3'd7;

always_ff @(posedge sclk) begin
    if (!srst_n || (DLCM_state_i != 2'd2)) begin
        init2_state     <= S_INIT2_IDLE;
        init2_cnt       <= 15'd0;
        init2_send      <= 1'b0;
    end
    else begin
        init2_state     <= init2_state_n;
        init2_cnt       <= init2_cnt_n;
        init2_send      <= init2_send_n;
    end
end

always_comb begin
    init2_state_n       = init2_state;
    init2_cnt_n         = init2_cnt;
    init2_send_n        = init2_send;

    init2_crc_input     = 32'd0;
    init2_crc_temp      = 16'hFFFF;

    init2_dllp_data     = 'd0;
    init2_dllp_valid    = 1'b0;

    case (init2_state)
        S_INIT2_IDLE: begin
            if (DLCM_state_i == 2'd2) begin
                init2_p_dllp.crc16      = 16'd0;
                init2_p_dllp.dllp_type  = 8'b1100_0000;
                init2_p_dllp.hdrFC_h    = CREDIT_LIMIT_P_HEADER[7:2];
                init2_p_dllp.hdrFC_l    = CREDIT_LIMIT_P_HEADER[1:0];
                init2_p_dllp.dataFC_h   = CREDIT_LIMIT_P_DATA[11:8];
                init2_p_dllp.dataFC_l   = CREDIT_LIMIT_P_DATA[7:0];
                init2_p_dllp.hdrScale   = 2'b00;
                init2_p_dllp.dataScale  = 2'b00;

                init2_np_dllp.crc16      = 16'd0;
                init2_np_dllp.dllp_type  = 8'b1101_0000;
                init2_np_dllp.hdrFC_h    = CREDIT_LIMIT_NP_HEADER[7:2];
                init2_np_dllp.hdrFC_l    = CREDIT_LIMIT_NP_HEADER[1:0];
                init2_np_dllp.dataFC_h   = 4'd0;
                init2_np_dllp.dataFC_l   = 8'd0;
                init2_np_dllp.hdrScale   = 2'b00;
                init2_np_dllp.dataScale  = 2'b00;

                init2_cpl_dllp.crc16     = 16'd0;
                init2_cpl_dllp.dllp_type = 8'b1110_0000;
                init2_cpl_dllp.hdrFC_h   = CREDIT_LIMIT_CPL_HEADER[7:2];
                init2_cpl_dllp.hdrFC_l   = CREDIT_LIMIT_CPL_HEADER[1:0];
                init2_cpl_dllp.dataFC_h  = CREDIT_LIMIT_CPL_DATA[11:8];
                init2_cpl_dllp.dataFC_l  = CREDIT_LIMIT_CPL_DATA[7:0];
                init2_cpl_dllp.hdrScale  = 2'b00;
                init2_cpl_dllp.dataScale = 2'b00;

                init2_state_n            = S_INIT2_CRC_P;
            end
            else begin
                init2_state_n            = S_INIT2_IDLE;
            end
        end
        S_INIT2_CRC_P: begin
            init2_crc_input              = init2_p_dllp[31:0];
            for (int i = 0; i < 32; i++) begin
                if ((init2_crc_temp[15] ^ init2_crc_input[31 - i]) == 1'b1)
                    init2_crc_temp       = {init2_crc_temp[14:0], 1'b0} ^ 16'h100B;
                else
                    init2_crc_temp       = {init2_crc_temp[14:0], 1'b0};
            end
            init2_p_dllp.crc16           = ~init2_crc_temp;
            init2_state_n                = S_INIT2_SEND_P;
        end
        S_INIT2_SEND_P: begin
            init2_dllp_valid             = 1'b1;
            init2_dllp_data              = {192'd0, init2_p_dllp, 16'hACF0};
            if (arb_ready_i) begin
                init2_state_n                = S_INIT2_CRC_NP;
            end
        end
        S_INIT2_CRC_NP: begin
            if (!init2_send) begin
                init2_crc_input              = init2_np_dllp[31:0];
                for (int i = 0; i < 32; i++) begin
                    if ((init2_crc_temp[15] ^ init2_crc_input[31 - i]) == 1'b1)
                        init2_crc_temp       = {init2_crc_temp[14:0], 1'b0} ^ 16'h100B;
                    else
                        init2_crc_temp       = {init2_crc_temp[14:0], 1'b0};
                end
                init2_np_dllp.crc16          = ~init2_crc_temp;
            end
            init2_state_n                = S_INIT2_SEND_NP;
        end
        S_INIT2_SEND_NP: begin
            init2_dllp_valid             = 1'b1;
            init2_dllp_data              = {192'd0, init2_np_dllp, 16'hACF0};
            if (arb_ready_i) begin
                init2_state_n                = S_INIT2_CRC_CPL;
            end
        end
        S_INIT2_CRC_CPL: begin
            if (!init2_send) begin
                init2_crc_input              = init2_cpl_dllp[31:0];
                for (int i = 0; i < 32; i++) begin
                    if ((init2_crc_temp[15] ^ init2_crc_input[31 - i]) == 1'b1)
                        init2_crc_temp       = {init2_crc_temp[14:0], 1'b0} ^ 16'h100B;
                    else
                        init2_crc_temp       = {init2_crc_temp[14:0], 1'b0};
                end
                init2_cpl_dllp.crc16         = ~init2_crc_temp;
            end
            init2_state_n                = S_INIT2_SEND_CPL;
        end
        S_INIT2_SEND_CPL: begin
            init2_dllp_valid             = 1'b1;
            init2_dllp_data              = {128'd0, init2_cpl_dllp, 16'hACF0};
            if (arb_ready_i) begin
                init2_state_n                = S_INIT2_WAIT;
            end
        end
        S_INIT2_WAIT: begin
            init2_send_n                 = 1'b1;
            if (init2_cnt == 'd1023) begin
                init2_state_n            = S_INIT2_SEND_P;
                init2_cnt_n              = 15'd0;
            end
            else begin
                init2_state_n            = S_INIT2_WAIT;
                init2_cnt_n              = init2_cnt + 15'd1;
            end
        end
    endcase
end


// UpdateFC의 경우 DLCM_state_i가 active(3)인 상황에서 주기적으로 P, NP, CPL의 credit consumed를 담아서 update fc format을 따른 dllp를 생성
// 이 주기는 내부 타이머를 통해 구현. 스펙에 적인 타이머는 34us. 근데 sclk의 주파수는 500MHz라서 타이머가 17000번 세고 보내고 하는 식으로 해야할듯
// ACK NAK의 경우 DLCM_state_i가 active(3)인 상황에서 주기적으로 NAK_scheduled_i, next_rcv_seq_i를 바탕으로 ack/nak format을 따른 dllp를 생성
// 마찬가지로 이 주기도 내부 타이머를 통해 구현. 이것도 34us로 해서 updatefc dllp랑 동시에 보내는 일이 없게 조정하는게 좋을듯

// updateFC, ACK/NAK DLLP

reg [3:0]                   active_state, active_state_n;
reg [14:0]                  active_cnt, active_cnt_n;

dllp_FC_packet_t            active_updatefc_p_dllp, active_updatefc_np_dllp, active_updatefc_cpl_dllp;
dllp_ACKNAK_packet_t        active_acknak_dllp;
reg [47:0]                  active_crc_input;
reg [15:0]                  active_crc_temp;

reg [PIPE_DATA_WIDTH-1:0]   active_dllp_data;
reg                         active_dllp_valid;

localparam                  S_ACTIVE_IDLE        = 4'd0,
                            S_ACTIVE_CRC_FC_P    = 4'd1,
                            S_ACTIVE_SEND_FC_P   = 4'd2,
                            S_ACTIVE_CRC_FC_NP   = 4'd3,
                            S_ACTIVE_SEND_FC_NP  = 4'd4,
                            S_ACTIVE_CRC_FC_CPL  = 4'd5,
                            S_ACTIVE_SEND_FC_CPL = 4'd6,
                            S_ACTIVE_CRC_AN      = 4'd7,
                            S_ACTIVE_SEND_AN     = 4'd8,
                            S_ACTIVE_WAIT        = 4'd9;

always_ff @(posedge sclk) begin
    if (!srst_n || (DLCM_state_i != 2'd3)) begin
        active_state    <= S_ACTIVE_IDLE;
        active_cnt      <= 15'd0;
    end
    else begin
        active_state    <= active_state_n;
        active_cnt      <= active_cnt_n;
    end
end

always_comb begin
    active_state_n      = active_state;
    active_cnt_n        = active_cnt;

    active_crc_input    = 32'd0;
    active_crc_temp     = 16'hFFFF;

    active_dllp_data    = 'd0;
    active_dllp_valid   = 1'b0;

    case (active_state)
        S_ACTIVE_IDLE: begin
            if (DLCM_state_i == 2'd3) begin
                active_acknak_dllp.crc16            = 16'd0;
                active_acknak_dllp.dllp_type        = (NAK_scheduled_i)?'h00:'h10;
                active_acknak_dllp.acknak_seq_num_h = next_rcv_seq_i[11:8];
                active_acknak_dllp.acknak_seq_num_l = next_rcv_seq_i[7:0];
                active_acknak_dllp.reserved_h       = 'd0;
                active_acknak_dllp.reserved_l       = 'd0;
                
                active_updatefc_p_dllp.crc16      = 16'd0;
                active_updatefc_p_dllp.dllp_type  = 8'b1000_0000;
                active_updatefc_p_dllp.hdrFC_h    = cc_p_h_i[7:2];
                active_updatefc_p_dllp.hdrFC_l    = cc_p_h_i[1:0];
                active_updatefc_p_dllp.dataFC_h   = cc_p_d_i[11:8];
                active_updatefc_p_dllp.dataFC_l   = cc_p_d_i[7:0];
                active_updatefc_p_dllp.hdrScale   = 2'b00;
                active_updatefc_p_dllp.dataScale  = 2'b00;

                active_updatefc_np_dllp.crc16      = 16'd0;
                active_updatefc_np_dllp.dllp_type  = 8'b1001_0000;
                active_updatefc_np_dllp.hdrFC_h    = cc_np_h_i[7:2];
                active_updatefc_np_dllp.hdrFC_l    = cc_np_h_i[1:0];
                active_updatefc_np_dllp.dataFC_h   = 4'd0;
                active_updatefc_np_dllp.dataFC_l   = 8'd0;
                active_updatefc_np_dllp.hdrScale   = 2'b00;
                active_updatefc_np_dllp.dataScale  = 2'b00;

                active_updatefc_cpl_dllp.crc16      = 16'd0;
                active_updatefc_cpl_dllp.dllp_type  = 8'b1010_0000;
                active_updatefc_cpl_dllp.hdrFC_h    = cc_cpl_h_i[7:2];
                active_updatefc_cpl_dllp.hdrFC_l    = cc_cpl_h_i[1:0];
                active_updatefc_cpl_dllp.dataFC_h   = cc_cpl_d_i[11:8];
                active_updatefc_cpl_dllp.dataFC_l   = cc_cpl_d_i[7:0];
                active_updatefc_cpl_dllp.hdrScale   = 2'b00;
                active_updatefc_cpl_dllp.dataScale  = 2'b00;

                active_state_n            = S_ACTIVE_CRC_FC_P;
            end
            else begin
                active_state_n            = S_ACTIVE_IDLE;
            end
        end
        S_ACTIVE_CRC_FC_P: begin
            active_crc_input              = active_updatefc_p_dllp[31:0];
            for (int i = 0; i < 32; i++) begin
                if ((active_crc_temp[15] ^ active_crc_input[31 - i]) == 1'b1)
                    active_crc_temp       = {active_crc_temp[14:0], 1'b0} ^ 16'h100B;
                else
                    active_crc_temp       = {active_crc_temp[14:0], 1'b0};
            end
            active_updatefc_p_dllp.crc16  = ~active_crc_temp;
            active_state_n                = S_ACTIVE_SEND_FC_P;
        end
        S_ACTIVE_SEND_FC_P: begin
            active_dllp_valid             = 1'b1;
            active_dllp_data              = {192'd0, active_updatefc_p_dllp, 16'hACF0};
            if (arb_ready_i) begin
                active_state_n                = S_ACTIVE_CRC_FC_NP;
            end
        end
        S_ACTIVE_CRC_FC_NP: begin
            active_crc_input              = active_updatefc_np_dllp[31:0];
            for (int i = 0; i < 32; i++) begin
                if ((active_crc_temp[15] ^ active_crc_input[31 - i]) == 1'b1)
                    active_crc_temp       = {active_crc_temp[14:0], 1'b0} ^ 16'h100B;
                else
                    active_crc_temp       = {active_crc_temp[14:0], 1'b0};
            end
            active_updatefc_np_dllp.crc16  = ~active_crc_temp;
            active_state_n                 = S_ACTIVE_SEND_FC_NP;
        end
        S_ACTIVE_SEND_FC_NP: begin
            active_dllp_valid             = 1'b1;
            active_dllp_data              = {192'd0, active_updatefc_np_dllp, 16'hACF0};
            if (arb_ready_i) begin
                active_state_n                = S_ACTIVE_CRC_FC_CPL;
            end
        end
        S_ACTIVE_CRC_FC_CPL: begin
            active_crc_input              = active_updatefc_cpl_dllp[31:0];
            for (int i = 0; i < 32; i++) begin
                if ((active_crc_temp[15] ^ active_crc_input[31 - i]) == 1'b1)
                    active_crc_temp       = {active_crc_temp[14:0], 1'b0} ^ 16'h100B;
                else
                    active_crc_temp       = {active_crc_temp[14:0], 1'b0};
            end
            active_updatefc_cpl_dllp.crc16 = ~active_crc_temp;
            active_state_n                 = S_ACTIVE_SEND_FC_CPL;
        end
        S_ACTIVE_SEND_FC_CPL: begin
            active_dllp_valid             = 1'b1;
            active_dllp_data              = {192'd0, active_updatefc_cpl_dllp, 16'hACF0};
            if (arb_ready_i) begin
                active_state_n                = S_ACTIVE_CRC_AN;
            end
        end
        S_ACTIVE_CRC_AN: begin
            active_crc_input              = active_acknak_dllp[31:0];
            for (int i = 0; i < 32; i++) begin
                if ((active_crc_temp[15] ^ active_crc_input[31 - i]) == 1'b1)
                    active_crc_temp       = {active_crc_temp[14:0], 1'b0} ^ 16'h100B;
                else
                    active_crc_temp       = {active_crc_temp[14:0], 1'b0};
            end
            active_acknak_dllp.crc16      = ~active_crc_temp;
            active_state_n                = S_ACTIVE_SEND_AN;
        end
        S_ACTIVE_SEND_AN: begin
            active_dllp_valid             = 1'b1;
            active_dllp_data              = {192'd0, active_acknak_dllp, 16'hACF0};
            if (arb_ready_i) begin
                active_state_n                = S_ACTIVE_WAIT;
            end
        end
        S_ACTIVE_WAIT: begin
            if (active_cnt == 'd1023) begin
                active_state_n            = S_ACTIVE_IDLE;
                active_cnt_n              = 15'd0;
            end
            else begin
                active_state_n            = S_ACTIVE_WAIT;
                active_cnt_n              = active_cnt + 15'd1;
            end
        end
    endcase
end

//assign dllp_data_o = DLCM_state_i가 0이면 0, DLCM_state_i가 1이면 init1_dllp_data, DLCM_state_i가 2이면 init2_dllp_data, DLCM_state_i가 3이면 updatefc_dllp_data 또는 acknak_dllp_data
assign dllp_data_o  =   (DLCM_state_i == 2'd1) ? init1_dllp_data : 
                        (DLCM_state_i == 2'd2) ? init2_dllp_data : 
                        (DLCM_state_i == 2'd3) ? active_dllp_data : 256'd0;

assign dllp_valid_o =   (DLCM_state_i == 2'd1) ? init1_dllp_valid : 
                        (DLCM_state_i == 2'd2) ? init2_dllp_valid : 
                        (DLCM_state_i == 2'd3) ? active_dllp_valid : 1'b0;

assign init1_send_o = init1_send;
assign init2_send_o = init2_send;

endmodule
