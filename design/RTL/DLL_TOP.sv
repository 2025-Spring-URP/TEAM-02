module DLL_TOP (

   input   wire                clk,
    input   wire                rst_n,

   // TL의 Credit 정보
   input    wire   [3:0]      tl_cc_np_i,      // Non-Posted(Read) credit consumed
   input    wire   [3:0]      tl_cc_p_i,      // Posted(Write) credit consumed
   input    wire   [3:0]      tl_cc_cpl_i,   // Completion credit consumed

   // TL -> DLL (수신)
   input    wire   [255:0]      tl_data_i,       // TL로부터 받은 TLP 조각들
   
   input   wire               tl2dll_valid_i,
   output   wire               dll2tl_ready_o, 

   // DLL -> TL (송신)
   output  wire   [255:0]      tl_data_o,      // TL에게 보내는 TLP 조각들

   output   wire               dll2tl_valid_o,
   input   wire               tl2dll_ready_i,

   // DLL -> EP (수신)
   input   wire   [255:0]      ep_data_i,       // EP로부터 받은 TLP, DLLP 조각들
   
   output   wire               dll2ep_valid_o, 
   input   wire               ep2dll_ready_i,

   // EP -> DLL (송신)
   output   wire   [255:0]      ep_data_o,       // EP에게 보내는 TLP, DLLP 조각들
   input    wire             ep_link_up_i,    // EP가 연결되면 활성화되는 신호 (DLCMSM이 시작할 수 있도록 trigger)

   input   wire               ep2dll_valid_i,
   output   wire               dll2ep_ready_o
);

   // Credit Limit
   localparam                P_CREDIT_LIMIT  = 4'd8,
                        NP_CREDIT_LIMIT = 4'd4,
                        CPL_CREDIT_LIMIT = 4'd4;

   // DLCMSM
   localparam                  S_IDLE     = 3'd0,
                               S_INIT1     = 3'd1,
                               S_INIT2    = 3'd2,
                               S_ACTIVE     = 3'd3;
   
   reg     [2:0]               dlcmsm_state,      dlcmsm_state_n;
   reg    [2:0]             fc_init1_recv_flags;    // bit0 = P, bit1 = NP, bit2 = Cpl
   wire                     fc_init1_recv_done = (fc_init1_recv_flags == 3'b111);
   reg    [1:0]             fc_init1_send_cnt;      // 0~2까지 (P, NP, Cpl)
   reg                      fc_init1_sent;

   reg                     dll2ep_ready,
                        dll2ep_valid;
   
   always_ff @(posedge clk) begin
        if (!rst_n) begin
         dlcmsm_state               <= S_IDLE;
         end
        else begin
            dlcmsm_state               <= dlcmsm_state_n;
        end
    end

   always_comb begin
        dlcmsm_state_n                 = dlcmsm_state;
      case (dlcmsm_state)
         S_IDLE: begin               // 아무것도 안하다가 EP가 연결되면 init1 상태로 이동
            if (ep_link_up_i) begin
               dlcmsm_state_n = S_INIT1;
            end
         end
         S_INIT1: begin               // TL의 credit 정보를 담은 dllp를 EP에게 보내고 EP로부터도 dllp를 받으면 init2 상태로 이동   
            dll2ep_ready = 1'b1;       // EP의 credit 정보는 레지스터에다가 잘 저장해놔야겠지
            dll2ep_valid = 1'b1;

            // 1. 수신 처리
            if (ep2dll_valid_i) begin
                 case (ep_data_i[7:0]) // DLLP Type 필드 기준
                     8'h01: fc_init1_recv_flags[0] = 1'b1; // P
                     8'h02: fc_init1_recv_flags[1] = 1'b1; // NP
                     8'h03: fc_init1_recv_flags[2] = 1'b1; // Cpl
                 endcase
             end

            // 2. 전송 처리
            if (!fc_init1_sent) begin
                 case (fc_init1_send_cnt)
                     2'd0: begin
                         if (ep2dll_ready_i) begin
                             // ep_data_o = InitFC1-P DLLP
                             fc_init1_send_cnt = 2'd1;
                         end
                     end
                     2'd1: begin
                         if (ep2dll_ready_i) begin
                             // ep_data_o = InitFC1-NP DLLP
                             fc_init1_send_cnt = 2'd2;
                         end
                     end
                     2'd2: begin
                         if (ep2dll_ready_i) begin
                             // ep_data_o = InitFC1-CPL DLLP
                             fc_init1_sent = 1'b1;
                         end
                     end
                 endcase
             end

            // 3. 상태 전이
             if (fc_init1_sent && fc_init1_recv_done) begin
                 dlcmsm_state_n = S_INIT2;
             end

         end

         S_INIT2: begin               // EP에게 너의 credit 정보 잘 수신했어 라는 의미의 dllp를 보내고, EP로부터도 받음
         
         end
         S_ACTIVE: begin               // 이제 TLP를 주고받을 준비 끝
         
         end
      endcase
   end


   assign dll2ep_valid_o = dll2ep_valid;
   assign dll2ep_ready_o = dll2ep_ready;

endmodule
