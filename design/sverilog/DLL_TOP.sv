module DLL_TOP (

	input   wire                clk,
    input   wire                rst_n,

	// TL의 Credit 정보
	input 	wire	[3:0]		tl_cc_np_i,		// Non-Posted(Read) credit consumed
	input 	wire	[3:0]		tl_cc_p_i,		// Posted(Write) credit consumed
	input 	wire	[3:0]		tl_cc_cpl_i,	// Completion credit consumed

	// TL -> DLL (수신)
	input 	wire	[255:0]		tl_data_i, 		// TL로부터 받은 TLP 조각들

	// DLL -> TL (송신)
	output  wire	[255:0]		tl_data_o,		// TL에게 보내는 TLP 조각들

	// DLL -> EP (수신)
	input	wire	[255:0]		ep_data_i, 		// EP로부터 받은 TLP, DLLP 조각들

	// EP -> DLL (송신)
	output	wire	[255:0]		ep_data_o, 		// EP에게 보내는 TLP, DLLP 조각들
	input 	wire 				ep_link_up_i, 	// EP가 연결되면 활성화되는 신호 (DLCMSM이 시작할 수 있도록 trigger)
);

	reg [1:0] dlcmsm_state;

	DLL_DLCMSM   dlcmsm
    (
        .clk                        (clk),
        .rst_n                      (rst_n),
		.link_up_i					(ep_link_up_i),
		.state_o					(dlcmsm_state)
    );

	
	

endmodule
