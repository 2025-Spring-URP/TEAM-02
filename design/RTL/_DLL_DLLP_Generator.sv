// Timer
// NAK_SCHEDULED


module _DLL_DLLP_Generator
#(
    parameter   PIPE_DATA_WIDTH          = 256,

)
(
    input   wire                                    sclk,
    input   wire                                    srst_n,

    // Credit consumed
    ~~~

    // -------------------------------------------------------
    //                    DLCMSM
    // -------------------------------------------------------
    input   wire     [1:0]                          DLCM_state_i,           // LINK_UP, LINK_DOWN
    

    input   wire                                    NAK_scheduled_i,        // CRC에러 + SEQ 에러 둘다 해당.
    
    input   wire    [SEQ_BITS-1:0]                  next_rcv_seq_i,         // 레지스터가 밖에 있음(SEQ) ACK NAK에 담아서


                                                                            //         _________________
    output  wire                                    init1_send_o,           //1clk(___|
    output  wire                                    init2_send_o,           //같음

    output  wire    [PIPE_DATA_WIDTH-1:0]           data_o,                 // DLLP
    

);

// 타이머 구현 (34us) --> CLK : period = 2ns --> 17000번   --> INITFC Timer

// struct 이용해서 InitFC, UpdateFC, ACK, NAK 구현

// 타이머 ACK/NAK (34us) --> Parmater 느낌적으로
 --> NAK_scheduled_i(CRC 랑 next_rcv_seq_i 로 만들기


endmodule