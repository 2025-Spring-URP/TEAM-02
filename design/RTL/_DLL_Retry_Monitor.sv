// 

module retry_monitor 
#(
    parameter  int RETRY_DEPTH_LG2          = 10;       // Retry Buffer Depth
    parameter  int DATA_WIDTH               = 256;
)
(


// TL
    input   wire    [DATA_WIDTH-1:0]		        data_i,
    output  wire                                    retry_buffer_full_o,

// PIPE
    output  wire                                    retry_buffer_empty_o,
    output  wire                                    
    output  reg     [DATA_WIDTH-1:0]		        data_o
	
);

localparam  SEQ_BITS            = RETRY_DEPTH_LG2 - 1;
localparam  DATA_DEPTH 		    = (2**RETRY_DEPTH_LG2);
localparam  TABLE_DEPTH         = 2**(SEQ_BITS);
localparam  PTR_BITS 		    = RETRY_DEPTH_LG2;


// -----------------------------------------------------
//                       Retry Table
// -----------------------------------------------------
// SEQ_NUM(12b) | PTR(10b-RETRY_DEPTH_LG2) | SIZE(3b) | 

reg  [SEQ_BITS+PTR_BITS-1:0] 		retry_table   [TABLE_DEPTH-1:0];		// 최대 8개의 패킷을 담을 수 있음



always_ff(@posedge clk) begin
    리셋
    if( cnt < TABLE_DEPTH) begin
        cnt <=0;
    end
end

// packet에서 SEQ를 해석해서 table에 기록 


// Retry Buffer is Dual Port DRAM
// Read     = 1 clk delay
// Write    = No Delay 
U_RETRY_BUFFER   SAL_SDP_RAM
#(

)
(

);

endmodule