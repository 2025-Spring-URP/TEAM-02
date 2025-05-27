module DLL_WR #(
    parameter  integer  PIPE_DATA_WIDTH          = 256,
    parameter  integer  RETRY_DEPTH_LG2          = 8,
    parameter  integer  OUTSTANDING_BITS         = 16
)
(
    // SYSTEM
    input    wire                           sclk,
    input    wire                           srst_n,

    // TL
    input   wire  [PIPE_DATA_WIDTH-1:0]     data_i,
    input   wire  [1:0]                     tl_d_en_i,                          // 00 : IDLE, 01 : HDR, 10 : DATA, 11 : DONE
    output  wire  [RETRY_DEPTH_LG2+2:0]     retry_buffer_leftover_cnt_o,        // DW

    // DLL_RD
    input   wire  [1:0]                     DLCMSM_i,
    input   wire  [PIPE_DATA_WIDTH/8-1:0]   data_DLLP_i[8],         // 2DW
    input   wire                            DLLP_valid_i,
    output  wire                            DLLP_ready_o,

    //output  wire  [15:0]                  next_tlp_seq_o,

    input   wire  [15:0]                    acknak_seq_num_i,
    input   wire  [1:0]                     acknak_seq_en_i,        // IDLE ACK NAK
    //output  wire  [15:0]                  as_o,

    // PIPE Interface
    output  wire  [PIPE_DATA_WIDTH-1:0]     data_o,
    output  wire                            data_valid_o
);

/* ================DLL_Packetizer================ */
wire  [PIPE_DATA_WIDTH/8-1:0]   sorted_data_w[8];
wire                            sorted_wren_w;
wire                            sorted_lcrc_w;

wire  [2:0]                     stp_idx_w;
wire  [1:0]                     stp_num_w;

wire  [15:0]                    next_tlp_seq_o;

/* ================DLL_Retry_Monitor================ */
wire  [PIPE_DATA_WIDTH/8-1:0]   data_TLP_w[8];
wire                            TLP_valid_w;
wire                            TLP_ready_w;
wire                            TLP_last_w;
wire  [15:0]                    as_w;       

/* ================DLL_Arbitor================ */
wire  [PIPE_DATA_WIDTH/8-1:0]   data_PIPE_w[8];
wire                            data_PIPE_valid_w;


//----------------------------------------------------------
//
//----------------------------------------------------------
DLL_Packetizer_v1 #(
	.PIPE_DATA_WIDTH			        (PIPE_DATA_WIDTH)
) u_packetizer(
	/* System Signals */
	.sclk           			        (sclk),
	.srst_n         			        (srst_n),
	/* Transcaction Layer */
	.data_i         			        (data_i),
	.tl_d_en_i      			        (tl_d_en_i),
    /* DLLP_GENERATOR */
    .next_tlp_seq_o 			        (next_tlp_seq_o),
	/* Retry Monitor */
	.data_o         			        (sorted_data_w),
	.wren_o         			        (sorted_wren_w),
    .lcrc_o                             (sorted_lcrc_w),
	.stp_idx_o					        (stp_idx_w),
	.stp_num_o					        (stp_num_w)
    /* DLL_Aribitor */
);

DLL_Retry_Monitor #(
	.PIPE_DATA_WIDTH			        (PIPE_DATA_WIDTH),
	.RETRY_DEPTH_LG2			        (RETRY_DEPTH_LG2)
) u_retry_monitor(
	/* System Signals */
	.sclk                               (sclk),
	.srst_n                             (srst_n),
	/* Transaction Layer */
	.retry_buffer_leftover_cnt_o        (retry_buffer_leftover_cnt_o),
	/* Packetizer */
	.data_i                             (sorted_data_w),
	.data_en_i                          (sorted_wren_w),
    .lcrc_en_i                          (sorted_lcrc_w),
	.stp_idx_i					        (stp_idx_w),
	.stp_num_i					        (stp_num_w),
	/* DLL_Others */
	.acknak_seq_num_i                   (acknak_seq_num_i),
	.acknak_seq_en_i                    (acknak_seq_en_i),
	.as_o                               (as_w),
	/* DLL Arbitor */
	.data_o                             (data_TLP_w),
	.data_valid_o                       (TLP_valid_w),
    .data_ready_i                       (TLP_ready_w),
    .data_last_o                        (TLP_last_w)
);


localparam          S_IDLE = 2'b00,
                    S_ACK  = 2'b01,
                    S_NAK  = 2'b10;

reg     [OUTSTANDING_BITS-1:0]      outstanding_TLP, outstanding_TLP_n;
reg     [1:0]                       acknak_seq_en_d, acknak_seq_en_2d;
reg     [1:0]                       stp_num_d;
always_ff @(posedge sclk) begin
    if(!srst_n) begin
        outstanding_TLP     <= 'd0;
        stp_num_d           <= 'd0;
        acknak_seq_en_d     <= 'd0;
        acknak_seq_en_2d    <= 'd0;
    end
    else begin
        outstanding_TLP     <= outstanding_TLP_n;
        stp_num_d           <= stp_num_w;
        acknak_seq_en_d     <= acknak_seq_en_i;
        acknak_seq_en_2d    <= acknak_seq_en_d;
    end
end


always_comb begin
    outstanding_TLP_n    = outstanding_TLP;

    if((stp_num_d != 'd0) & !(TLP_valid_w & TLP_last_w)) begin
        outstanding_TLP_n   = outstanding_TLP + 'd1;
    end
    else if((stp_num_d != 'd0) & (TLP_valid_w & TLP_last_w)) begin
        outstanding_TLP_n   = outstanding_TLP;
    end
    else if((stp_num_d == 'd0) & (TLP_valid_w & TLP_last_w)) begin
        if(outstanding_TLP == 'd0) begin
            outstanding_TLP_n       = outstanding_TLP;
            // synopsys translate_off
            $fatal("ERROR at outstanding_TLP == 0");
            // synopsys translate_on
        end
        else begin
            outstanding_TLP_n       = outstanding_TLP - 'd1;
        end
    end
    
    if(acknak_seq_en_2d == S_NAK) begin
        if((next_tlp_seq_o-'d1) <= as_w) begin
            outstanding_TLP_n       = (16'hFFFF - as_w - 'd1) + (next_tlp_seq_o);
        end
        else begin
            outstanding_TLP_n       = (next_tlp_seq_o-'d1) - as_w;
        end
    end
end



DLL_Arbitor	#(
    .PIPE_DATA_WIDTH			        (PIPE_DATA_WIDTH),
    .OUTSTANDING_BITS                   (OUTSTANDING_BITS)
) u_Arbitor (
	/* System Signals */
	.sclk                               (sclk),
	.srst_n                             (srst_n),
    .outstanding_TLP_i                  (outstanding_TLP),
    /*      DLL_Retry_Monitor       */
    .data_TLP_i                         (data_TLP_w),
    .TLP_valid_i                        (TLP_valid_w),
    .TLP_ready_o                        (TLP_ready_w),
    .TLP_last_i                         (TLP_last_w),
    /*      DLCMSM              */
    .DLCMSM_i                           (DLCMSM_i),
    /*      DLL Generator          */
    .data_DLLP_i                        (data_DLLP_i),
    .DLLP_valid_i                       (DLLP_valid_i),
    .DLLP_ready_o                       (DLLP_ready_o),
    /*      PIPE Interface       */
    .data_PIPE_o                        (data_PIPE_w),
    .data_PIPE_valid_o                  (data_PIPE_valid_w)
);



/* ================PIPE Interface================ */
generate
    for(genvar k=0; k<8; k++) begin : gen_assign_data
        assign data_o[k*32 +: 32]       = data_PIPE_w[k];
    end
endgenerate

assign  data_valid_o            = data_PIPE_valid_w;

endmodule
