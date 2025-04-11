// 

module retry_monitor 
#(
    parameter  int SEQ_BITS                 = 12,
    parameter  int RETRY_DEPTH_LG2          = 10,       // Retry Buffer Depth   (User set!)
    parameter  int DATA_WIDTH               = 256
)
(
   input    wire                           sclk,
   input   wire                           srst_n,

// TL
    input   wire    [DATA_WIDTH-1:0]                data_i,
    input   wire                                    wren_i,
    output  wire                                    retry_buffer_full_o,

// ELSE
    input   wire    [SEQ_BITS-1:0]                  acked_seq_i,                   // From ACK/NAK


// PIPE
    output  wire                                    rden_o,
    output  wire                                    retry_buffer_empty_o,                        
    output  reg     [DATA_WIDTH-1:0]                 data_o
   
);

localparam  TABLE_DEPTH           = RETRY_DEPTH_LG2-1;
localparam  PTR_BITS              = RETRY_DEPTH_LG2;
localparam  SIZE_BITS         = 3;


// --------------------------------------
//              Retry Table
// --------------------------------------
// PTR(10b-RETRY_DEPTH_LG2) | SIZE(3b) | 

reg  [PTR_BITS+SIZE_BITS-1:0]       retry_table   [TABLE_DEPTH-1:0];      // 최대 512개의 패킷을 담을 수 있음


always_ff(@posedge clk) begin
    리셋
    if( cnt < TABLE_DEPTH) begin
        cnt <=0;
    end
end

// packet에서 SEQ를 해석해서 table에 기록 


// Retry Buffer is Dual Port SRAM
// Read     = 1 clk delay
// Write    = No Delay

reg [RETRY_DEPTH_LG2-1:0]       wrptr, wrptr_n;
reg [RETRY_DEPTH_LG2-1:0]       rdptr, rdptr_n;

always_ff @(posedge sclk) begin
    if(!srst_n) begin
        wrptr <= 'd0;
        rdptr <= 'd0;
    end
    else begin
        if(rden) begin
        end
    end
end

always_comb begin

end

U_RETRY_BUFFER   SAL_SDP_RAM
#(
    .DEPTH_LG2               (12),
    .DATA_WIDTH              (32),
    .RDATA_FF_OUT            (1),
  // synchronization between read/write ports
  // WR_FIRST: new content is immediately made available for reading
  // RD_FIRST: old content is read before new content is loaded
    //.RW_SYNC                 ("WR_FIRST")
)
(
    .clk                    (sclk),

    .en_a                   (),
    .we_a                   (),
    .addr_a                 (wrptr),
    .di_a                   (),                // FIFO IN  (Write Only)

    .en_b                   (),
    .addr_b                 (rdptr),
    .do_b                   (),                // FIFO OUT (Read Only)
);

assign retry_buffer_empty_o     = ;
assign data_o                   = ;

endmodule