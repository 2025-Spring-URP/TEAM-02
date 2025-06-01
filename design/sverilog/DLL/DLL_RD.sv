module DLL_RD(
	input wire sclk,
	input wire srst_n,

	// tl
	input wire [11:0] cc_p_h_i,		        // Posted(Write) header credit consumed
    input wire [11:0] cc_p_d_i,		        // Posted(Write) data credit consumed
	input wire [11:0] cc_np_h_i,		    // Non-Posted(Read) header credit consumed
	input wire [11:0] cc_cpl_h_i,	        // Completion credit header consumed
    input wire [11:0] cc_cpl_d_i,           // Completion credit data consumed

	output wire [255:0] dll2tl_data_o,
    output wire [2:0] dll2tl_data_en_o,
    
    output wire [11:0] ep_cc_p_h_o,
    output wire [11:0] ep_cc_p_d_o,
	output wire ep_cc_p_en_o,

    output wire [11:0] ep_cc_np_h_o,
    output wire ep_cc_np_en_o,

    output wire [11:0] ep_cc_cpl_h_o,
    output wire [11:0] ep_cc_cpl_d_o,
    output wire ep_cc_cpl_en_o,
	
    output wire [11:0] ep_cl_p_h_o,
    output wire [11:0] ep_cl_p_d_o,
    output wire [11:0] ep_cl_np_h_o,
    output wire [11:0] ep_cl_cpl_h_o,
    output wire [11:0] ep_cl_cpl_d_o,
	output wire ep_cl_en_o,

	output wire updatefc_p_o,
	output wire updatefc_np_o,
	output wire updatefc_cpl_o,

	// arbiter (dll to pipe)
	input wire arb_ready_i,

	output wire dllp_valid_o,
	output wire [255:0] dllp_data_o,

	// pipe (pipe to dll)
	input pipe2dll_valid_i,
	input wire [255:0] pipe2dll_data_i,

	// retry monitor
	output wire [15:0] acknak_seq_num_o,
    output wire [1:0] acknak_seq_en_o,

	// 
	output wire [1:0] dlcm_state
);

assign ep_cl_en_o = (dlcm_state == 2'd3);

wire init1_send;
wire init2_send;
wire init1_received;
wire init2_received;

wire NAK_scheduled;
wire [11:0] next_rcv_seq;

DLL_DLCMSM dlcmsm 
(
	.sclk(sclk),
	.srst_n(srst_n),

	// dllp generator & decoder
	.init1_end_i(init1_send & init1_received),
	.init2_end_i(init2_send & init2_received),

	.DLCM_state_o(dlcm_state)
);

DLL_DLLP_Generator dllp_generator
(
	.sclk(sclk),
	.srst_n(srst_n),

	// dlcmsm
	.DLCM_state_i(dlcm_state),

	.init1_send_o(init1_send),
	.init2_send_o(init2_send),

	// tl
	.cc_p_h_i(cc_p_h_i),
	.cc_p_d_i(cc_p_d_i),
	.cc_np_h_i(cc_np_h_i),
	.cc_cpl_h_i(cc_cpl_h_i),
	.cc_cpl_d_i(cc_cpl_d_i),

	.updatefc_p_o(updatefc_p_o),
	.updatefc_np_o(updatefc_np_o),
	.updatefc_cpl_o(updatefc_cpl_o),

	// decoder
	.NAK_scheduled_i(NAK_scheduled),
	.next_rcv_seq_i(next_rcv_seq),

	// arbiter
	.arb_ready_i(arb_ready_i),

	.dllp_data_o(dllp_data_o),
	.dllp_valid_o(dllp_valid_o)
);

DLL_Decoder decoder
(
	.sclk(sclk),
	.srst_n(srst_n),

	// dlcmsm
	.init1_received_o(init1_received),
	.init2_received_o(init2_received),

	// pipe
	.pipe2dll_valid_i(pipe2dll_valid_i),
	.pipe2dll_data_i(pipe2dll_data_i),

	// dllp generator
	.NAK_scheduled_o(NAK_scheduled),
	.next_rcv_seq_o(next_rcv_seq),

	// retry monitor
	.acknak_seq_num_o(acknak_seq_num_o),
	.acknak_seq_en_o(acknak_seq_en_o),

	.dll2tl_data_o(dll2tl_data_o),
	.dll2tl_data_en_o(dll2tl_data_en_o),

	.ep_cc_p_h_o(ep_cc_p_h_o),
	.ep_cc_p_d_o(ep_cc_p_d_o),	
	.ep_cc_p_en_o(ep_cc_p_en_o),

	.ep_cc_np_h_o(ep_cc_np_h_o),
	.ep_cc_np_en_o(ep_cc_np_en_o),

	.ep_cc_cpl_h_o(ep_cc_cpl_h_o),
	.ep_cc_cpl_d_o(ep_cc_cpl_d_o),
	.ep_cc_cpl_en_o(ep_cc_cpl_en_o),

	.ep_cl_p_h_o(ep_cl_p_h_o),
	.ep_cl_p_d_o(ep_cl_p_d_o),
	.ep_cl_np_h_o(ep_cl_np_h_o),
	.ep_cl_cpl_h_o(ep_cl_cpl_h_o),
	.ep_cl_cpl_d_o(ep_cl_cpl_d_o)
);

endmodule
