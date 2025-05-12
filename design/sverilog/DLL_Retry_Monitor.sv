//s

module DLL_retry_monitor 
#(
    parameter  integer RETRY_DEPTH_LG2          = 8,       // Retry Buffer Depth   (User set!)
    parameter  integer PIPE_DATA_WIDTH          = 256
)
(
   input    wire                           sclk,
   input    wire                           srst_n,

// TL
    output  wire   [RETRY_DEPTH_LG2-1:0]            retry_buffer_leftover_cnt_o,              // DW


// Packetizer
    input   wire    [PIPE_DATA_WIDTH/8-1:0]         data_i[8],
    input   wire                                    data_en_i,
    input   wire    [7:0]                           stp_strb_i,                             // ex) 1000_0000

// ELSE+
    input   wire    [15:0]                          acknak_seq_num_i,                        // From ACK/NAK Decoder
    input   wire    [1:0]                           acknak_seq_en_i,                         // IDLE, ACK, NAK ?

    output  wire    [15:0]                          as_o,

    input   wire                                    rd_en_i,


// To Arbitor
    output  reg     [PIPE_DATA_WIDTH/8-1:0]         data_o[8],
    output  wire                                    data_en_o
   
);



// -----------------------------------------------------------------------------------------
//                                       Retry Management Table
// -----------------------------------------------------------------------------------------
// Type(For Debug) | STP_addr | STP_width_strb | TLP Size(8b) (DW Size) |
//     00000       | 0000_0000| 0000_0000      | 0000_0000


localparam  DEBUG_TYPE            = 5,
            STP_ADDR_BITS         = RETRY_DEPTH_LG2,
            STP_STRB_BITS         = 8,
            MAX_TLP_SIZE_BITS     = 8;

typedef struct packed {
    logic [7:0]   tlp_seq_num_l;   // [7:0]
    logic [3:0]   fcrc;            // [11:8]
    logic [3:0]   tlp_seq_num_h;   // [15:12]
    logic         fp;              // [16]
    logic [6:0]   tlp_len_h;       // [23:17]
    logic [3:0]   tlp_len_l;       // [27:24]
    logic [3:0]   ones;            // [31:28]
} stp_t;

stp_t                                           stp_i[8];


reg [2:0]                                       stp_index;
reg [1:0]                                       acknak_seq_en_d;

reg [DEBUG_TYPE+STP_ADDR_BITS+STP_STRB_BITS+MAX_TLP_SIZE_BITS-1:0]  retry_table_din, retry_table_din_n;
reg [RETRY_DEPTH_LG2-1:0]                                           table_w_idx, table_w_idx_n;

reg [DEBUG_TYPE+STP_ADDR_BITS+STP_STRB_BITS+MAX_TLP_SIZE_BITS-1:0]  retry_table_dout_d;
reg [15:0]                                                          table_r_idx, table_r_idx_n;
reg                                                                 retry_table_rd_en, retry_table_rd_en_n, retry_table_rd_en_d;

localparam          S_IDLE = 2'b00,
                    S_ACK  = 2'b01,
                    S_NAK  = 2'b10;


reg  [RETRY_DEPTH_LG2-1+3:0]                    retry_RAM_leftover_cnt, retry_RAM_leftover_cnt_n;     // PIPE(32B) 단위

reg  [15:0]                                     as_reg, as_reg_n;

reg  [14:0]                                     acknak_timeout_cnt, acknak_timeout_cnt_n;         
reg  [RETRY_DEPTH_LG2-1:0]                      wrptr, wrptr_n;             // Retry Buffer PTR         // MSB에 1비트를 의도적으로 하나 더 넣어서 Wrapping 동작을 관찰해야함.
reg  [RETRY_DEPTH_LG2-1:0]                      rdtpr, rdtpr_n;             // Retry Buffer PTR
//reg  [2:0]                                      rstrb;

reg                                             IsTimeOut, IsTimeOut_d;


generate
    for (genvar k = 0; k < 8; k++) begin
        assign stp_i[k] = stp_t'(data_i[k]);
    end
endgenerate

always_comb begin
    case (stp_strb_i)
        8'b1000_0000: stp_index = 3'd7;
        8'b0100_0000: stp_index = 3'd6;
        8'b0010_0000: stp_index = 3'd5;
        8'b0001_0000: stp_index = 3'd4;
        8'b0000_1000: stp_index = 3'd3;
        8'b0000_0100: stp_index = 3'd2;
        8'b0000_0010: stp_index = 3'd1;
        8'b0000_0001: stp_index = 3'd0;
        default      : begin
            stp_index = 3'd0;
            // synopsys translate_off
            $display("STP_STRB has ERROR! It is not Ont hot");
            // synopsys translate_on
        end
    endcase
end

always_comb begin
    retry_table_din_n   = retry_table_din;
    table_w_idx_n       = table_w_idx;

    if(|stp_strb_i) begin
        table_w_idx_n           = {stp_i[stp_index].tlp_seq_num_h, stp_i[stp_index].tlp_seq_num_l}[RETRY_DEPTH_LG2-1:0];
        retry_table_din_n       = {data_i[6][31:26], wrptr, stp_strb_i, {stp_i[stp_index].tlp_len_h, stp_i[stp_index].tlp_len_l}};
    end
end

always_ff @(posedge sclk) begin
    if(!srst_n) begin
        retry_table_din         <= 'd0;
        table_w_idx             <= 'd0;
        table_r_idx             <= 'd0;
        retry_table_rd_en_d     <= 'd0;
        acknak_seq_en_d         <= 'd0;
    end
    else begin
        retry_table_din         <= retry_table_din_n;
        table_w_idx             <= table_w_idx_n;
        table_r_idx             <= table_r_idx_n;
        retry_table_rd_en_d     <= retry_table_rd_en;
        retry_table_rd_en       <= retry_table_rd_en_n;
        acknak_seq_en_d         <= acknak_seq_en_i;
    end
end

SAL_SDP_RAM 
#(
    .DEPTH_LG2               (RETRY_DEPTH_LG2),
    .DATA_WIDTH              (DEBUG_TYPE+STP_ADDR_BITS+STP_STRB_BITS+MAX_TLP_SIZE_BITS),
    .RDATA_FF_OUT            (1),
  // synchronization between read/write ports
  // WR_FIRST: new content is immediately made available for reading
  // RD_FIRST: old content is read before new content is loaded
    .RW_SYNC                 ("RD_FIRST"),
    .VIVADO                  (1),
    .BRAM_VERSION            (0)
)
U_RETRY_TABLE
(
    .clk                    (sclk),

    .en_a                   (|stp_strb_i),
    .we_a                   (1'd1),
    .addr_a                 (table_w_idx),
    .di_a                   (retry_table_din),                // FIFO IN  (Write Only)

    .en_b                   (retry_table_rd_en),
    .addr_b                 (table_r_idx[RETRY_DEPTH_LG2-1:0]),
    .do_b                   (retry_table_dout_d)              // FIFO OUT (Read Only)
);


// -----------------------------------------------------------------------------------------
//                                       Retry Buffer
// -----------------------------------------------------------------------------------------
wire [PIPE_DATA_WIDTH-1:0]                           data_d;

assign      IsTimeOut           = (acknak_timeout_cnt == 'd17000-'d1)? 1'b1 : 1'b0;

always_ff @(posedge sclk) begin
    if (!srst_n) begin
        acknak_timeout_cnt          <= 'd0;
        retry_RAM_leftover_cnt      <= '1;
        wrptr                       <= 'd0;
        rdtpr                       <= 'd0;
        as_reg                      <= 'd0;
        IsTimeOut_d                 <= 'd0;
    end
    else begin
        acknak_timeout_cnt          <= acknak_timeout_cnt_n;
        retry_RAM_leftover_cnt      <= retry_RAM_leftover_cnt_n;
        wrptr                       <= wrptr_n;
        IsTimeOut_d                 <= IsTimeOut;
        if(retry_table_rd_en_d) begin
            rdtpr                   <= retry_table_dout_d[STP_STRB_BITS+MAX_TLP_SIZE_BITS +: STP_ADDR_BITS];
        end
        else begin
            rdtpr                   <= rdtpr_n;
        end
        as_reg                      <= as_reg_n;
    end
end

always_comb begin
    wrptr_n                     = wrptr;
    rdtpr_n                     = rdtpr;
    retry_RAM_leftover_cnt_n    = retry_RAM_leftover_cnt;
    acknak_timeout_cnt_n        = acknak_timeout_cnt;
    as_reg_n                    = as_reg;
    retry_table_rd_en_n         = retry_table_rd_en;
    table_r_idx_n               = table_r_idx;


    if(data_en_i & rd_en_i) begin           // When Write & Read are Same Time      (RACE Condition 방지)
        rdtpr_n                     = rdtpr + 'd1;
        wrptr_n                     = wrptr + 'd1;
        retry_RAM_leftover_cnt_n    = retry_RAM_leftover_cnt;
    end
    else if(rd_en_i) begin
        rdtpr_n                     = rdtpr + 'd1;
        retry_RAM_leftover_cnt_n    = retry_RAM_leftover_cnt + 'd8;
    end
    else if(data_en_i) begin
        wrptr_n                     = wrptr + 'd1;
        retry_RAM_leftover_cnt_n    = retry_RAM_leftover_cnt - 'd8;
    end

    case (acknak_seq_en_i)
    S_IDLE : begin
        if(IsTimeOut) begin        // Timeout!
            acknak_timeout_cnt_n      = 'd0;
            // synopsys translate_off
            $display("ACK/NAK Time Out!!! Replay at SEQ : %d", as_reg);
            // synopsys translate_on
            retry_table_rd_en_n       = 'd1;
            table_r_idx_n             = {8'd0, as_reg[7:0]};
        end
        else begin
            acknak_timeout_cnt_n      = acknak_timeout_cnt + 'd1;
        end
    end
    S_ACK : begin
        acknak_timeout_cnt_n      = 'd0; 
        as_reg_n                  = acknak_seq_num_i;
        // synopsys translate_off
        $display("ACK Occur! AS is updated to : %d", acknak_seq_num_i);
        // synopsys translate_on
    end
    S_NAK : begin
        acknak_timeout_cnt_n      = 'd0;

        retry_table_rd_en_n       = 'd1;
        table_r_idx_n             = acknak_seq_num_i - 'd1;
        as_reg_n                  = acknak_seq_num_i - 'd1;
        // synopsys translate_off
        $display("NAK Occur! AS is updated to SEQ : %d and Replay at SEQ : %d", acknak_seq_num_i-'d1, acknak_seq_num_i);
        // synopsys translate_on
    end
    endcase

    case (acknak_seq_en_d)
    S_IDLE : begin
        if(IsTimeOut_d) begin
            rdtpr_n     = retry_table_dout_d[STP_STRB_BITS+MAX_TLP_SIZE_BITS +: STP_ADDR_BITS];
            // synopsys translate_off
            $display("rdptr will be updated , TYPE: %d, ADDR :%h, STRB : %d, SIZE : %d", //[DEBUG_TYPE+STP_ADDR_BITS+STP_STRB_BITS+MAX_TLP_SIZE_BITS-1:0]
                retry_table_dout_d[STP_ADDR_BITS+STP_STRB_BITS+MAX_TLP_SIZE_BITS +: DEBUG_TYPE],
                retry_table_dout_d[              STP_STRB_BITS+MAX_TLP_SIZE_BITS +: STP_ADDR_BITS],
                retry_table_dout_d[                            MAX_TLP_SIZE_BITS +: STP_STRB_BITS],
                retry_table_dout_d[0                                             +: MAX_TLP_SIZE_BITS]);
            // synopsys translate_on
        end
    end
    S_NAK : begin
        rdtpr_n     = retry_table_dout_d[STP_STRB_BITS+MAX_TLP_SIZE_BITS +: STP_ADDR_BITS];     // Replay From NAK position
        // synopsys translate_off
        $display("rdptr will be updated , ADDR :%h", retry_table_dout_d[STP_STRB_BITS+MAX_TLP_SIZE_BITS +: STP_ADDR_BITS]);
        // synopsys translate_on
    end
    endcase
end

SAL_SDP_RAM #(
    .DEPTH_LG2               (RETRY_DEPTH_LG2),
    .DATA_WIDTH              (PIPE_DATA_WIDTH),
    .RDATA_FF_OUT            (1),
  // synchronization between read/write ports
  // WR_FIRST: new content is immediately made available for reading
  // RD_FIRST: old content is read before new content is loaded
    .RW_SYNC                 ("RD_FIRST"),
    .VIVADO                  (1),
    .BRAM_VERSION            (1)
)
U_RETRY_BUFFER
(
    .clk                    (sclk),

    .en_a                   (data_en_i),
    .we_a                   (1'd1),
    .addr_a                 (wrptr),
    .di_a                   ({data_i[7], data_i[6], data_i[5], data_i[4],
                              data_i[3], data_i[2], data_i[1], data_i[0]}),                // FIFO IN  (Write Only)

    .en_b                   (rd_en_i),
    .addr_b                 (rdtpr),
    .do_b                   (data_d)                // FIFO OUT (Read Only)
);

// Read Need 1 Delay
reg                                                 rd_en_d;
always_ff @(posedge sclk) begin
    if(!srst_n) begin
        rd_en_d     <= 0;
    end
    else begin
        rd_en_d     <= rd_en_i;
    end
end


assign as_o                         = as_reg;
assign retry_buffer_leftover_cnt_o  = retry_RAM_leftover_cnt;

generate
    for (genvar k = 0; k < 8; k++) begin
        assign data_o[k] = data_d[k*32 +: 32];
    end
endgenerate
assign data_en_o                    = rd_en_d;



// -----------------------------------------------------------------------------------------
//                                 For Verification            
// -----------------------------------------------------------------------------------------

// synopsys translate_off
always_ff @(posedge sclk) begin
    if (data_en_i && (retry_RAM_leftover_cnt == 0)) begin
        $display("[%0t ns] [RETRY_MON] ERROR: Retry Buffer FULL!", $time);
    end
end
// synopsys translate_on

// TLP Type Field
localparam        TYPE_MEM              = 5'b00000,
                  TYPE_MEM_RDLK         = 5'b00001,
                  TYPE_IO               = 5'b00010,
                  TYPE_CFG_0            = 5'b00100,
                  TYPE_CFG_1            = 5'b00101,
                  TYPE_COMPLETION       = 5'b01010,
                  TYPE_COMPLETION_LK    = 5'b01011,
                  TYPE_MSG              = 5'b10000,
                  TYPE_TCFG             = 5'b11011,
                  TYPE_ATOMIC_ADD       = 5'b11100,
                  TYPE_ATOMIC_SWAP      = 5'b11101,
                  TYPE_ATOMIC_CAS       = 5'b11110,
                  TYPE_LPRFX            = 5'b00000,
                  TYPE_EPRFX            = 5'b10000,
                  TLP_TYPE_UNKNOWN      = 5'b11111;





endmodule