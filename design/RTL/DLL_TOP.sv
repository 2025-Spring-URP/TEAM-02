module DLL_TOP (

	input   wire                clk,
    input   wire                rst_n,

	// TL의 Credit 정보
    input 	wire	[3:0]		cc_p_h_i,		    // Posted(Write) header credit consumed
    input 	wire	[3:0]		cc_p_d_i,		    // Posted(Write) data credit consumed

	input 	wire	[3:0]		cc_np_h_i,		    // Non-Posted(Read) header credit consumed
    input 	wire	[3:0]		cc_np_d_i,		    // Non-Posted(Read) data credit consumed
	

	input 	wire	[3:0]		cc_cpl_h_i,	        // Completion credit header consumed
    input 	wire	[3:0]		cc_cpl_d_i,	        // Completion credit data consumed

	// TL -> DLL
	input 	wire	[255:0]		tl2dll_data_i, 		// TL로부터 받은 TLP 조각들
    output  wire                dll2tl_ready_o,     // TL에게 "retry buffer에 자리 있으니까 TLP 보내도 돼"라는 신호

	// DLL -> TL
	output  wire	[255:0]		dll2tl_data_o,		// TL에게 보내는 TLP 조각들
    output  wire                dll2tl_en_o,        // TL에게 "나 지금 TLP 보낼게"라는 신호

	// DLL -> EP
	input	wire	[255:0]		pipe2dll_data_i, 	// EP로부터 받은 TLP, DLLP 조각들

	// EP -> DLL
	output	wire	[255:0]		dll2pipe_data_o, 	// EP에게 보내는 TLP, DLLP 조각들
);

	reg [1:0] dlcm_state;

	_DLL_DLCMSM   dlcmsm
    (
        .clk                        (clk),
        .rst_n                      (rst_n),
		.link_up_i					(ep_link_up_i),
		.state_o					(dlcm_state)
    );

	
	

endmodule
