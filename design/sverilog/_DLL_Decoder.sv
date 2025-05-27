module _DLL_Decoder
#( 
    parameter       PIPE_DATA_WIDTH     = 256,
    parameter       CREDIT_DEPTH        = 12
)
(   
    input   wire                                    sclk,
    input   wire                                    srst_n,
    // -------------------------------------------------------
    //                    DLCMSM
    // -------------------------------------------------------
    output  wire                                    init1_received_o,
    output  wire                                    init2_received_o,

    // -------------------------------------------------------
    //                PIPE Interface
    // -------------------------------------------------------
    input   wire                                    pipe2dll_valid_i,
    input   wire     [PIPE_DATA_WIDTH-1:0]          pipe2dll_data_i,

    // -------------------------------------------------------
    //                    DLLP generator
    // -------------------------------------------------------
    output  wire                                    NAK_scheduled_o, // tlp 뜯어봤는데 지금 들어온 tlp의 seq가 next_rcv_seq랑 달라서 nak 떴다고 알림
    output  wire      [15:0]                        next_rcv_seq_o,  // 지금까지 잘 받은거 + 1

    // -------------------------------------------------------
    //                    retry monitor
    // -------------------------------------------------------
    output  wire      [15:0]                        acknak_seq_num_o, // dllp 뜯어봤는데 상대가 여기까지 받았다고 알림
    output  wire      [1:0]                         acknak_seq_en_o,  // dllp 뜯어봤는데 ack이면 01, nak이면 10으로 출력

    // -------------------------------------------------------
    //              Transaction Layer
    // -------------------------------------------------------
    output   wire     [PIPE_DATA_WIDTH-1:0]          dll2tl_data_o,
    output   wire     [2:0]                          dll2tl_data_en_o,
    
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_p_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_p_d_o,
    output   wire                                    ep_cc_p_en_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_np_h_o,
    output   wire                                    ep_cc_np_en_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_cpl_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_cpl_d_o,
    output   wire                                    ep_cc_cpl_en_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_p_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_p_d_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_np_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_cpl_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_cpl_d_o
);

reg [PIPE_DATA_WIDTH-1:0] dllp_32B, dllp_32B_n;

reg [CREDIT_DEPTH-1:0]  ep_cl_p_h, ep_cl_p_h_n,
                        ep_cl_p_d, ep_cl_p_d_n,
                        ep_cl_np_h, ep_cl_np_h_n,
                        ep_cl_cpl_h, ep_cl_cpl_h_n,
                        ep_cl_cpl_d, ep_cl_cpl_d_n;               

reg                     init2_p_received, init2_p_received_n,
                        init2_np_received, init2_np_received_n,
                        init2_cpl_received, init2_cpl_received_n;

reg [CREDIT_DEPTH-1:0]  ep_cc_p_h, ep_cc_p_h_n,
                        ep_cc_p_d, ep_cc_p_d_n,
                        ep_cc_np_h, ep_cc_np_h_n,
                        ep_cc_cpl_h, ep_cc_cpl_h_n,
                        ep_cc_cpl_d, ep_cc_cpl_d_n;

reg                     ep_cc_p_en, ep_cc_p_en_n,
                        ep_cc_np_en, ep_cc_np_en_n,
                        ep_cc_cpl_en, ep_cc_cpl_en_n;

reg [CREDIT_DEPTH-1:0]  acknak_seq_num, acknak_seq_num_n;

reg [1:0]               acknak_seq_en;          


localparam          S_DLLP_IDLE         = 2'd0,
                    S_DLLP_CRC_CHECK    = 2'd1,
                    S_DLLP_GET_DATA     = 2'd2;

reg [1:0]  dllp_state, dllp_state_n;
reg [31:0] dllp_crc_input;
reg [15:0] dllp_crc_result;

always_ff @(posedge sclk) begin
    if (!srst_n) begin
        dllp_state          <= S_DLLP_IDLE;

        dllp_32B            <= 'd0;

        ep_cl_p_h           <= 'd0;
        ep_cl_p_d           <= 'd0;
        ep_cl_np_h          <= 'd0;
        ep_cl_cpl_h         <= 'd0;
        ep_cl_cpl_d         <= 'd0;

        init2_p_received    <= 'd0;
        init2_np_received   <= 'd0;
        init2_cpl_received  <= 'd0;

        ep_cc_p_h           <= 'd0;
        ep_cc_p_d           <= 'd0;
        ep_cc_np_h          <= 'd0;
        ep_cc_cpl_h         <= 'd0;
        ep_cc_cpl_d         <= 'd0;

        ep_cc_p_en          <= 'd0;
        ep_cc_np_en         <= 'd0;
        ep_cc_cpl_en        <= 'd0;

        acknak_seq_num      <= 'd0;
    end
    else begin
        dllp_state          <= dllp_state_n;

        dllp_32B            <= dllp_32B_n;

        ep_cl_p_h           <= ep_cl_p_h_n;
        ep_cl_p_d           <= ep_cl_p_d_n;
        ep_cl_np_h          <= ep_cl_np_h_n;
        ep_cl_cpl_h         <= ep_cl_cpl_h_n;
        ep_cl_cpl_d         <= ep_cl_cpl_d_n;

        init2_p_received    <= init2_p_received_n;
        init2_np_received   <= init2_np_received_n;
        init2_cpl_received  <= init2_cpl_received_n;

        ep_cc_p_h           <= ep_cc_p_h_n;
        ep_cc_p_d           <= ep_cc_p_d_n;
        ep_cc_np_h          <= ep_cc_np_h_n;
        ep_cc_cpl_h         <= ep_cc_cpl_h_n;
        ep_cc_cpl_d         <= ep_cc_cpl_d_n;

        ep_cc_p_en          <= ep_cc_p_en_n;
        ep_cc_np_en         <= ep_cc_np_en_n;
        ep_cc_cpl_en        <= ep_cc_cpl_en_n;

        acknak_seq_num      <= acknak_seq_num_n;
    end
end

always_comb begin
    dllp_crc_input              = 32'd0;
    dllp_crc_result             = 16'hFFFF;

    acknak_seq_en               = 2'd0;

    ep_cc_p_en_n                = 1'b0;
    ep_cc_np_en_n               = 1'b0;
    ep_cc_cpl_en_n              = 1'b0;

    case(dllp_state)
        S_DLLP_IDLE: begin
            if ((pipe2dll_valid_i == 1'b1) && (pipe2dll_data_i[15:0] == 16'hACF0)) begin
                dllp_32B_n      = pipe2dll_data_i;
                dllp_state_n    =   S_DLLP_CRC_CHECK;
            end
        end
        S_DLLP_CRC_CHECK: begin
            dllp_crc_input  = dllp_32B[47:16];
            for (int i = 0; i < 32; i++) begin
                if ((dllp_crc_result[15] ^ dllp_crc_input[31 - i]) == 1'b1)
                    dllp_crc_result       = {dllp_crc_result[14:0], 1'b0} ^ 16'h100B;
                else
                    dllp_crc_result       = {dllp_crc_result[14:0], 1'b0};
            end

            if (dllp_32B[15:0] == ~dllp_crc_result) begin   // CRC Pass
                dllp_state_n              = S_DLLP_GET_DATA;
            end
            else begin                                      // CRC Fail
                dllp_state_n              = S_DLLP_IDLE;
            end
        end
        S_DLLP_GET_DATA: begin
            case (dllp_32B[23:16])
                8'b0100_0000: begin // init1 p
                    ep_cl_p_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // p header credit limit
                    ep_cl_p_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // p data credit limit

                    ep_cc_p_en_n = 1'b1;
                end
                8'b0101_0000: begin // init1 np
                    ep_cl_np_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // np header credit limit
                    
                    ep_cc_np_en_n = 1'b1;
                end
                8'b0110_0000: begin // init1 cpl
                    ep_cl_cpl_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // cpl header credit limit
                    ep_cl_cpl_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // cpl data credit limit

                    ep_cc_cpl_en_n = 1'b1;
                end

                8'b1100_0000: begin // init2 p
                    init2_p_received_n = 1'b1;
                end
                8'b1101_0000: begin // init2 np
                    init2_np_received_n = 1'b1;
                end
                8'b1110_0000: begin // init2 cpl
                    init2_cpl_received_n = 1'b1;
                end

                8'b1000_0000: begin // fc p
                    ep_cc_p_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // p header credit consumed
                    ep_cc_p_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // p data credit consumed
                end
                8'b1001_0000: begin // fc np
                    ep_cc_np_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // np header credit consumed
                end
                8'b1010_0000: begin // fc cpl
                    ep_cc_cpl_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // cpl header credit consumed
                    ep_cc_cpl_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // cpl data credit consumed
                end

                8'b0000_0000: begin // ack
                    acknak_seq_en    = 2'd1;
                    acknak_seq_num_n = {dllp_32B[35:32], dllp_32B[47:40]}; // ack sequence number
                end
                8'b0001_0000: begin // nak
                    acknak_seq_en    = 2'd2;
                    acknak_seq_num_n = {dllp_32B[35:32], dllp_32B[47:40]}; // nak sequence number 
                end

                default: begin
                    // do nothing
                end
            endcase
            dllp_state_n          = S_DLLP_IDLE; 
        end
    endcase
end


///////////////////////////////////////////////////////////////////////////////////////////////////////////////

localparam          S_TLP_IDLE              = 3'd0,
                    S_TLP_NP_SEQ_CHECK      = 3'd1,
                    S_TLP_NP_SEND_DATA      = 3'd2,
                    S_TLP_NP_DONE           = 3'd3,
                    S_TLP_P_CPL_GET_PAYLOAD = 3'd4,
                    S_TLP_P_CPL_SEQ_CHECK   = 3'd5,
                    S_TLP_P_CPL_SEND_DATA   = 3'd6,
                    S_TLP_P_CPL_DONE        = 3'd7;

reg [PIPE_DATA_WIDTH-1:0] tlp_first_32B, tlp_first_32B_n;

reg [PIPE_DATA_WIDTH-1:0] tlp_payload_32B[16], tlp_payload_32B_n[16];
reg [10:0] cnt, cnt_n;
reg [10:0] wcnt, wcnt_n;
reg [2:0]  tlp_state, tlp_state_n;

reg [15:0] next_rcv_seq, next_rcv_seq_n;
reg NAK_scheduled, NAK_scheduled_n;

reg     [PIPE_DATA_WIDTH-1:0]          dll2tl_data, dll2tl_data_n;
reg     [2:0]                          dll2tl_data_en, dll2tl_data_en_n;

always_ff @(posedge sclk) begin
    if (!srst_n) begin
        tlp_state          <= S_TLP_IDLE;
        tlp_first_32B      <= 'd0;
        cnt                <= 'd0;
        wcnt               <= 'd0;
        next_rcv_seq       <= 'd0;
        NAK_scheduled      <= 'd0;
        dll2tl_data        <= 'd0;
        dll2tl_data_en     <= 'd0;

        for (int i=0; i<16; i++) begin
            tlp_payload_32B[i] <= {PIPE_DATA_WIDTH{1'b0}};
        end
    end
    else begin
        tlp_state          <= tlp_state_n;
        tlp_first_32B      <= tlp_first_32B_n;
        cnt                <= cnt_n;
        wcnt               <= wcnt_n;
        next_rcv_seq       <= next_rcv_seq_n;
        NAK_scheduled      <= NAK_scheduled_n;
        dll2tl_data        <= dll2tl_data_n;
        dll2tl_data_en     <= dll2tl_data_en_n;

        for (int i=0; i<16; i++) begin
            tlp_payload_32B[i] <= tlp_payload_32B_n[i];
        end
    end
end

always_comb begin
    tlp_state_n          = tlp_state;
    tlp_first_32B_n      = tlp_first_32B;
    cnt_n                = cnt;
    wcnt_n               = wcnt;
    next_rcv_seq_n       = next_rcv_seq;
    NAK_scheduled_n      = NAK_scheduled;
    dll2tl_data_n        = dll2tl_data;
    dll2tl_data_en_n     = dll2tl_data_en;

    for (int i=0; i<16; i++) begin
        tlp_payload_32B_n[i] = tlp_payload_32B[i];
    end

    case (tlp_state)
        S_TLP_IDLE: begin
            dll2tl_data_en_n = 3'd0;
            if ((pipe2dll_valid_i == 1'b1) && (pipe2dll_data_i[15:0] != 16'hACF0)) begin
                tlp_first_32B_n = pipe2dll_data_i;
                if (pipe2dll_data_i[3:0] == 4'b1111) begin
                    tlp_state_n     =   S_TLP_NP_SEQ_CHECK;
                end
                else begin
                    cnt_n           =   ((pipe2dll_data_i[14:4] - 'd6) / 8) - 1;
                    wcnt_n          =   (pipe2dll_data_i[14:4] - 'd6) / 8;
                    tlp_state_n     =   S_TLP_P_CPL_SEQ_CHECK;
                end
            end
        end
        S_TLP_NP_SEQ_CHECK: begin
            if (next_rcv_seq == {tlp_first_32B[19:16], tlp_first_32B[31:24]}) begin // 올바른 seq가 들어왔을때
                next_rcv_seq_n  = next_rcv_seq + 'd1;
                NAK_scheduled_n = 1'b0;
                tlp_state_n     = S_TLP_NP_SEND_DATA;
            end
            else begin // 올바르지 않은 seq가 들어왔을때
                NAK_scheduled_n = 1'b1;
                tlp_state_n     = S_TLP_IDLE;
            end
        end
        S_TLP_NP_SEND_DATA: begin
            dll2tl_data_n    = {128'd0, tlp_first_32B[159:32]};
            dll2tl_data_en_n = 3'd3; // np header
            tlp_state_n      = S_TLP_NP_DONE;
        end
        S_TLP_NP_DONE: begin
            dll2tl_data_en_n = 3'd7; // done
            tlp_state_n = S_TLP_IDLE;
        end
        S_TLP_P_CPL_GET_PAYLOAD: begin
            if (cnt == 'd0) begin
                tlp_payload_32B_n[cnt] = pipe2dll_data_i;
                cnt_n                  = (tlp_first_32B[14:4] - 'd6) / 8;
                tlp_state_n            = S_TLP_P_CPL_SEQ_CHECK;
            end
            else begin
                tlp_payload_32B_n[cnt] = pipe2dll_data_i;
                cnt_n                  = cnt - 'd1;
                tlp_state_n            = S_TLP_P_CPL_GET_PAYLOAD;
            end
        end
        S_TLP_P_CPL_SEQ_CHECK: begin
            if (next_rcv_seq == {tlp_first_32B[115:112], tlp_first_32B[127:120]}) begin // 올바른 seq가 들어왔을때
                next_rcv_seq_n  = next_rcv_seq + 'd1;
                NAK_scheduled_n = 1'b0;
                tlp_state_n     = S_TLP_P_CPL_SEND_DATA;
            end
            else begin // 올바르지 않은 seq가 들어왔을때
                NAK_scheduled_n = 1'b1;
                tlp_state_n     = S_TLP_IDLE;
            end
        end
        S_TLP_P_CPL_SEND_DATA: begin
            if (wcnt == cnt) begin
                dll2tl_data_n    = {128'd0, tlp_first_32B[255:128]};
                if (tlp_first_32B[135:128] == 8'b0110_0000) begin
                    dll2tl_data_en_n = 3'd1; // p header
                end
                else begin
                    dll2tl_data_en_n = 3'd5; // cpl header
                end
            end
            else begin
                dll2tl_data_n    = tlp_payload_32B[wcnt];
                if (tlp_first_32B[135:128] == 8'b0110_0000) begin
                    dll2tl_data_en_n = 3'd2; // p data
                end
                else begin
                    dll2tl_data_en_n = 3'd6; // cpl data
                end
            end
            tlp_state_n          = S_TLP_P_CPL_DONE;
        end
        S_TLP_P_CPL_DONE: begin
            if (wcnt != 'd0) begin
                wcnt_n           = wcnt - 'd1;
                dll2tl_data_en_n = 3'd7; // done
                tlp_state_n      = S_TLP_P_CPL_SEND_DATA;
            end
            else begin
                dll2tl_data_en_n = 3'd7; // done
                tlp_state_n      = S_TLP_IDLE;
            end
        end
    endcase
end


assign init1_received_o = ep_cl_p_h && ep_cl_p_d && ep_cl_np_h && ep_cl_cpl_h && ep_cl_cpl_d;
assign init2_received_o = init2_p_received && init2_np_received && init2_cpl_received;

assign ep_cl_p_h_o      = ep_cl_p_h;
assign ep_cl_p_d_o      = ep_cl_p_d;
assign ep_cl_np_h_o     = ep_cl_np_h;
assign ep_cl_cpl_h_o    = ep_cl_cpl_h;
assign ep_cl_cpl_d_o    = ep_cl_cpl_d;

assign ep_cc_p_h_o      = ep_cc_p_h;
assign ep_cc_p_d_o      = ep_cc_p_d;
assign ep_cc_np_h_o     = ep_cc_np_h;
assign ep_cc_cpl_h_o    = ep_cc_cpl_h;
assign ep_cc_cpl_d_o    = ep_cc_cpl_d;

assign ep_cc_p_en_o   = ep_cc_p_en;
assign ep_cc_np_en_o  = ep_cc_np_en;
assign ep_cc_cpl_en_o = ep_cc_cpl_en;

assign next_rcv_seq_o = next_rcv_seq;
assign NAK_scheduled_o = NAK_scheduled;

assign acknak_seq_en_o  = acknak_seq_en;
assign acknak_seq_num_o = acknak_seq_num;

assign dll2tl_data_o = dll2tl_data;
assign dll2tl_data_en_o = dll2tl_data_en;

endmodule
