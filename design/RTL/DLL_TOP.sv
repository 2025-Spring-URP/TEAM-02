// Receive_TLP_FIFO!

module DLL_TOP
#(
    parameter int               PIPE_DATA_WIDTH   =   256
)
(
	input   wire                sclk,
    input   wire                srst_n,

	// TL의 Credit 정보
    input 	wire	[3:0]		cc_p_h_i,		    // Posted(Write) header credit consumed
    input 	wire	[3:0]		cc_p_d_i,		    // Posted(Write) data credit consumed

	input 	wire	[3:0]		cc_np_h_i,		    // Non-Posted(Read) header credit consumed
    input 	wire	[3:0]		cc_np_d_i,		    // Non-Posted(Read) data credit consumed
	

	input 	wire	[3:0]		cc_cpl_h_i,	        // Completion credit header consumed
    input 	wire	[3:0]		cc_cpl_d_i,	        // Completion credit data consumed

	// TL -> DLL
	input 	wire	[PIPE_DATA_WIDTH-1:0]		tl2dll_data_i, 		// TL로부터 받은 TLP 조각들
    output  wire                                dll2tl_ready_o,     // TL에게 "retry buffer에 자리 있으니까 TLP 보내도 돼"라는 신호

	// DLL -> TL
	output  wire	[PIPE_DATA_WIDTH-1:0]		dll2tl_data_o,		// TL에게 보내는 TLP 조각들
    output  wire                                dll2tl_en_o,        // TL에게 "나 지금 TLP 보낼게"라는 신호

	// PIPE -> DLL
	input	wire	[PIPE_DATA_WIDTH-1:0]		pipe2dll_data_i, 	// EP로부터 받은 TLP, DLLP 조각들

	// DLL -> PIPE
	output	wire	[PIPE_DATA_WIDTH-1:0]		dll2pipe_data_o 	// EP에게 보내는 TLP, DLLP 조각들

    // Many Modules
    output  wire                                link_up_o,
);

wire crc_run_w;
wire    [PIPE_DATA_WIDTH-1:0]       bypass_data_w;
reg     [PIPE_DATA_WIDTH-1:0]       tlp_32B_buffer;

always@ (posedge sclk) begin
    if (!srst_n) begin
        tlp_32B_buffer          <= 'd0;
    end
    else begin
        tlp_32B_buffer          <= bypass_data_w;
    end
end

_DLL_Packtizer packetizer
#(
    .PIPE_DATA_WIDTH            (PIPE_DATA_WIDTH)
)
(
    .sclk                       (sclk),
    .srst_n                     (srst_n),

    .data_i                     (tl2dll_data_i)

    .data_o                     (bypass_data_w),
    .crc_run_o                  (crc_run_w)
);

wire [1:0] DLCM_state;

_DLL_DLCMSM   dlcmsm
(
    .sclk                       (sclk),
    .srst_n                     (srst_n),

    .init1_end_i                (),
    .init2_end_i                (),

    .link_up_o					(link_up_o),
    .DLCM_state_o               (dlcm_state),
);



//                
assign init1_end    = 디코더에서 들어오는 initFC1 확인 & 타이머
assign init2_end    = 디코더에서 들어오는 initFC1 확인 & 타이머

	
//assign dll2tl_ready_o = crc_run & 버퍼 자리 있음;

assign 


endmodule
