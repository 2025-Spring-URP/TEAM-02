module retry_monitor 
#(
	parameter int     DEPTH_LG2       = 4,
	parameter int     DATA_WIDTH      = 32
)
(
	input wire [DATA_WIDTH-1:0]		data_i,

	output reg [DATA_WIDTH-1:0]		data_o


);
localparam  DATA_DEPTH 		= (2**DEPTH_LG2);
localparam  IDX_BITS		= DEPTH_LG2-1;
localparam  SEQ_BITS 		= 12;
localparam  PTR_BITS 		= DEPTH_LG2;

reg  [DATA_WIDTH-1:0] 						replay_buffer  [DATA_DEPTH-1:0];	// 최대 16개의 패킷 조각을 담을 수 있음음
reg  [IDX_BITS+SEQ_BITS+PTR_BITS-1:0] 		replay_table   [DEPTH_LG2-2:0];		// 최대 8개의 패킷을 담을 수 있음

// packet에서 SEQ를 해석해서 table에 기록 


endmodule