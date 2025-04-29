// Receive_TLP_FIFO!

module DLL_TOP
#(
    parameter int   PIPE_DATA_WIDTH   =   256
)
(
   input   wire                                sclk,
    input   wire                                srst_n,

   // TL의 Credit 정보
    input    wire   [3:0]                      cc_p_h_i,          // Posted(Write) header credit consumed
    input    wire   [3:0]                      cc_p_d_i,          // Posted(Write) data credit consumed

   input    wire   [3:0]                      cc_np_h_i,          // Non-Posted(Read) header credit consumed
    input    wire   [3:0]                      cc_np_d_i,          // Non-Posted(Read) data credit consumed
   

   input    wire   [3:0]                      cc_cpl_h_i,           // Completion credit header consumed
    input    wire   [3:0]                      cc_cpl_d_i,           // Completion credit data consumed

   // TL -> DLL
   input    wire   [PIPE_DATA_WIDTH-1:0]      tl2dll_data_i,       // TL로부터 받은 TLP 조각들
    output  wire                                dll2tl_ready_o,     // TL에게 "retry buffer에 자리 있고 Packetizer도 동작 안하고 있으니깐 TLP 보내도 돼"라는 신호

   // DLL -> TL
   output  wire   [PIPE_DATA_WIDTH-1:0]      dll2tl_data_o,      // TL에게 보내는 TLP 조각들
    output  wire                                dll2tl_en_o,        // TL에게 "나 지금 TLP 보낼게"라는 신호

   // PIPE -> DLL
   input   wire   [PIPE_DATA_WIDTH-1:0]      pipe2dll_data_i,    // EP로부터 받은 TLP, DLLP 조각들

<<<<<<< HEAD
	// DLL -> PIPE
	output	wire	[PIPE_DATA_WIDTH-1:0]		dll2pipe_data_o, 	// EP에게 보내는 TLP, DLLP 조각들
=======
   // DLL -> PIPE
   output   wire   [PIPE_DATA_WIDTH-1:0]      dll2pipe_data_o    // EP에게 보내는 TLP, DLLP 조각들
>>>>>>> a77054d222a5cba47b49aed02c785601fc33b160

    // Many Modules
    output  wire                                link_up_o
);

wire                            crc_run_w;       // Packetizer의 동작 여부를 나타내는 신호
wire    [PIPE_DATA_WIDTH-1:0]   bypass_data_w;   // Packetizer에서 만들어진 TLP 조각들 

_DLL_Packtizer packetizer
#(
    .PIPE_DATA_WIDTH            (PIPE_DATA_WIDTH)
)
(
    .sclk                       (sclk),
    .srst_n                     (srst_n),
    .data_i                     (tl2dll_data_i),
    .data_o                     (bypass_data_w),
    .crc_run_o                  (crc_run_w)
);

reg     [PIPE_DATA_WIDTH-1:0]   tlp_32B_buffer;  // EP로 보내지기 전에 TLP 조각들이 머무르는 버퍼

always@ (posedge sclk) begin
    if (!srst_n) begin
        tlp_32B_buffer          <= 'd0;
    end
    else begin
        tlp_32B_buffer          <= bypass_data_w;
    end
end

reg  [1:0]      dlcm_state;  // dlcmsm의 state. 이게 init1(1), init2(2)면 dllp 주고받아야하고, active(3)가 되어야 tlp 주고받을수있음 
wire            init1_end_w; // dllp generator에서 내 init1 dllp 다 보내고 decoder에서 상대의 init1 dllp 다 받으면 활성화하는 신호
wire            init2_end_w; // 위와 같은데 init2 dllp에 대한 신호

_DLL_DLCMSM   dlcmsm
(
    .sclk                       (sclk),
    .srst_n                     (srst_n),
    .init1_end_i                (init1_end_w),
    .init2_end_i                (init2_end_w),
    .state_o               (dlcm_state)
);


//assign dll2tl_ready_o = crc_run_w & 버퍼 자리 있음;
assign init1_end    = 디코더에서 들어오는 initFC1 확인 & 타이머
assign init2_end    = 디코더에서 들어오는 initFC1 확인 & 타이머

assign 


endmodule
