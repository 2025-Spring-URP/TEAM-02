
// Description
//      0 ) Link_Down이면, TL이 들어와도 버린다.
//      1 ) Decoder - TLP / DLLP check       --> ACK / NAK Gen 신호를 만들어라!
//      2 ) 들어오는 데이터를 FIFO에 저장해둠
//              2-1) 이미 NAK이라면, FIFO 저장 안하고 다 폐기
//              2-2) ACK이라면, TL로 보냄.
//      3 ) CRC GEN을 하여, 비교한다. (CRC가 32B로 동작하므로, 최대 6CLK이 소모된다. --> 이를 기다려주는?)
// NAK_Scheduled

module _DLL_Decoder
#( 
    parameter       PIPE_DATA_WIDTH     = 256,
    parameter       CREDIT_DEPTH        = 3
)
(
    // -------------------------------------------------------
    //                    DLCMSM
    // -------------------------------------------------------
    input   wire                                    DL_up,

    // -------------------------------------------------------
    //                PIPE Interface
    // -------------------------------------------------------
    input   wire     [PIPE_DATA_WIDTH-1:0]          pipe2dll_data_i,


    // -------------------------------------------------------
    //              Transaction Layer
    // -------------------------------------------------------
    // From Transaciton Layer : Credit Consumed
    input   wire     [CREDIT_DEPTH-1:0]             rc_cc_p_h_i,
    input   wire     [CREDIT_DEPTH-1:0]             rc_cc_p_d_i,

    input   wire     [CREDIT_DEPTH-1:0]             rc_cc_np_h_i,
    input   wire     [CREDIT_DEPTH-1:0]             rc_cc_np_d_i,

    input   wire     [CREDIT_DEPTH-1:0]             rc_cc_cpl_h_i,
    input   wire     [CREDIT_DEPTH-1:0]             rc_cc_cpld_d_i,

    // To Transaction Layer
    output  wire     [PIPE_DATA_WIDTH-1:0]          dll2tl_data_o,
    output  wire                                    dll2tl_data_en_o,
    
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_p_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_p_d_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_np_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_np_d_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_cpl_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_cpld_d_o,

    // 

);


// TLP_Receive FIFO
U_TLP_RECEIVE_FIFO  SAL_FIFO
#(

)(

)

// Decode Packet
always_ff @(posedge clk) begin
    if(!preset_n) begin

    end
    else begin
        if(이번 32B가 헤더 패킷이 있는게 확인되면?) begin
            STP_frameToken      <= {d_ff[5][11:0], d_ff[4][31:12]};
            seq_num             <= d_ff[4][11:0];
            tlp_hdr             <= {d_ff[3], d_ff[2], d_ff[1], d_ff[0]};

            cnt                 <= cnt+1;                                   // Next is ~~~
        end
        
        if(cnt != 0) begin
            payload[]           <= ;
        end

        if(cnt == ? LCRC를 check할 시점일때) begin
            // Check LCRC
            LCRC                <= ;

            cnt <= 0;
        end
    end
end

always_ff @(posedge clk) begin
    
end




endmodule