//s

module DLL_Retry_Monitor 
#(
    parameter  integer PIPE_DATA_WIDTH          = 256,
    parameter  integer RETRY_DEPTH_LG2          = 8       // Retry Buffer Depth   (User set!)
)
(
   input    wire                           sclk,
   input    wire                           srst_n,

// TL
    output  wire   [RETRY_DEPTH_LG2+2:0]            retry_buffer_leftover_cnt_o,              // DW

// Packetizer
    input   wire    [PIPE_DATA_WIDTH/8-1:0]         data_i[8],
    input   wire                                    data_en_i,
    input   wire                                    lcrc_en_i,
    input   wire    [2:0]                           stp_idx_i,
    input   wire    [1:0]                           stp_num_i,

// ELSE+
    input   wire    [15:0]                          acknak_seq_num_i,                        // From ACK/NAK Decoder
    input   wire    [1:0]                           acknak_seq_en_i,                         // IDLE, ACK, NAK ?
    output  wire    [15:0]                          as_o,

// To Arbitor
    output  wire    [PIPE_DATA_WIDTH/8-1:0]         data_o[8],
    output  wire                                    data_valid_o,
    input   wire                                    data_ready_i,
    output  wire                                    data_last_o
   
);



// -----------------------------------------------------------------------------------------
//                                       Retry Management Table
// -----------------------------------------------------------------------------------------
// Type(For Debug) | STP_addr | STP_idx | TLP Size(8b) (DW Size) |
//     00000       | 0000_0000| 000     | 0000_0000


parameter integer  TIME_OUT_NS    = 2048-1;     // 1023
localparam  MSB                   = RETRY_DEPTH_LG2;

localparam  DEBUG_TYPE            = 8,                          // fmt, type
            STP_ADDR_BITS         = RETRY_DEPTH_LG2,            // Buffer Address
            STP_IDX_BITS          = 3,                          // STP_Index
            MAX_TLP_SIZE_BITS     = 11;                         // TLP Packet Size(STP 포함)

reg [DEBUG_TYPE+STP_ADDR_BITS+STP_IDX_BITS+MAX_TLP_SIZE_BITS-1:0]  retry_table_din, retry_table_din_n;
reg [11:0]                                                         table_w_idx, table_w_idx_n;


wire [DEBUG_TYPE+STP_ADDR_BITS+STP_IDX_BITS+MAX_TLP_SIZE_BITS-1:0]  retry_table_dout_d;
reg [15:0]                                                         table_r_idx, table_r_idx_n;
reg                                                                retry_table_rd_en, retry_table_rd_en_n, retry_table_rd_en_d;

reg  [RETRY_DEPTH_LG2:0]                      wrptr, wrptr_n;             // Retry Buffer PTR         // MSB에 1비트를 의도적으로 하나 더 넣어서 Wrapping 동작을 관찰해야함.

always_comb begin
    table_w_idx_n           = 'd0;
    retry_table_din_n       = 'd0;
    if(stp_num_i == 'd1) begin
        table_w_idx_n           = {data_i[stp_idx_i][27:16]};
        retry_table_din_n       = {data_i[stp_idx_i+'d1][7:0], wrptr[MSB-1:0], stp_idx_i, data_i[stp_idx_i][14:4]};
    end
end

reg    retry_table_wr_en;

always_ff @(posedge sclk) begin
    if(!srst_n) begin
        retry_table_din         <= 'd0;
        table_w_idx             <= 'd0;         // write
        retry_table_wr_en       <= 'd0;
    end
    else begin
        retry_table_wr_en       <= (stp_num_i == 'd1)? 1'b1 : 1'b0;
        retry_table_din         <= retry_table_din_n;
        table_w_idx             <= table_w_idx_n;
    end
end


// Read Prioirty
SAL_SDP_RAM  #(
    .DEPTH_LG2               (RETRY_DEPTH_LG2),
    .DATA_WIDTH              (DEBUG_TYPE + STP_ADDR_BITS + STP_IDX_BITS + MAX_TLP_SIZE_BITS),
    .RDATA_FF_OUT            (1),
  // synchronization between read/write ports
  // WR_FIRST: new content is immediately made available for reading
  // RD_FIRST: old content is read before new content is loaded
    .RW_SYNC                 ("RD_FIRST")
)
U_RETRY_TABLE
(
    .clk                    (sclk),

    .en_a                   (retry_table_wr_en),
    .we_a                   (1'd1),
    .addr_a                 (table_w_idx[RETRY_DEPTH_LG2-1:0]),
    .di_a                   (retry_table_din),                // FIFO IN  (Write Only)

    .en_b                   (retry_table_rd_en),              // Read Maybe Take One Delay...?
    .addr_b                 (table_r_idx[RETRY_DEPTH_LG2-1:0]),
    .do_b                   (retry_table_dout_d)              // FIFO OUT (Read Only)
);


// -------------------------------------------------------------------------------------------------------------------------
//                                                                  Retry Buffer
// ----------------------------------------------------------------------------------------------------------------------

localparam          S_IDLE = 2'b00,
                    S_ACK  = 2'b01,
                    S_NAK  = 2'b10;

reg  [1:0]                                      acknak_seq_en_d, acknak_seq_en_2d;

reg  [RETRY_DEPTH_LG2-1+3:0]                    retry_RAM_leftover_cnt, retry_RAM_leftover_cnt_n;     // PIPE(32B) 단위

reg  [15:0]                                     as_confirmed_reg, as_confirmed_reg_n;

reg  [14:0]                                     acknak_timeout_cnt, acknak_timeout_cnt_n;         
reg  [RETRY_DEPTH_LG2:0]                        rdptr, rdptr_n;             // Retry Buffer PTR

reg                                             IsTimeOut, IsTimeOut_d;

wire                                            lcrc_en_d;
wire [PIPE_DATA_WIDTH/8-1:0]                    data_d[8];

assign      IsTimeOut               = (acknak_timeout_cnt == TIME_OUT_NS)?  1'b1 : 1'b0;

reg      ptr_wr_en, ptr_rd_en;
always_comb begin
    if(wrptr[MSB] == rdptr[MSB]) begin
        if(wrptr[MSB-1:0] > rdptr[MSB-1:0]) begin       // Can Read
            ptr_wr_en       = 'd1;
            ptr_rd_en       = 'd1;
        end
        else begin                                      // Cant Read
            ptr_wr_en       = 'd1;
            ptr_rd_en       = 'd0;
        end
    end
    else begin      // OverFlow
        if(wrptr[MSB-1:0] < rdptr[MSB-1:0] )begin                            
            ptr_rd_en       = 'd1;
            ptr_wr_en       = 'd1;
        end
        else begin
            ptr_wr_en       = 'd0;
            ptr_rd_en       = 'd1;
        end
    end
end

always_ff @(posedge sclk) begin
    if (!srst_n) begin
        acknak_timeout_cnt          <= 'd0;
        retry_RAM_leftover_cnt      <= 'd8 << (RETRY_DEPTH_LG2);         // 2^(RETRY_DEPTH_LG2) * 8DW
        wrptr                       <= 'd0;
        rdptr                       <= 'd0;
        as_confirmed_reg            <= 'd0;
        IsTimeOut_d                 <= 'd0;

        table_r_idx                 <= 'd0;         // read
        retry_table_rd_en_d         <= 'd0;
        acknak_seq_en_d             <= 'd0;
        acknak_seq_en_2d            <= 'd0;
    end
    else begin
        acknak_timeout_cnt          <= acknak_timeout_cnt_n;
        retry_RAM_leftover_cnt      <= retry_RAM_leftover_cnt_n;
        wrptr                       <= wrptr_n;
        rdptr                       <= rdptr_n;
        IsTimeOut_d                 <= IsTimeOut;
        as_confirmed_reg            <= as_confirmed_reg_n;
        table_r_idx                 <= table_r_idx_n;
        retry_table_rd_en_d         <= retry_table_rd_en;
        retry_table_rd_en           <= retry_table_rd_en_n;
        acknak_seq_en_d             <= acknak_seq_en_i;
        acknak_seq_en_2d            <= acknak_seq_en_d;
    end
end

wire wr_ed, rd_en;

assign  wr_ed   =  ptr_wr_en & data_en_i;
assign  rd_en   =  ptr_rd_en & data_ready_i;

always_comb begin
    wrptr_n                     = wrptr;
    rdptr_n                     = rdptr;
    retry_RAM_leftover_cnt_n    = retry_RAM_leftover_cnt;
    acknak_timeout_cnt_n        = acknak_timeout_cnt;
    as_confirmed_reg_n          = as_confirmed_reg;
    retry_table_rd_en_n         = retry_table_rd_en;
    table_r_idx_n               = table_r_idx;


    if(wr_ed & rd_en) begin                          // When Write & Read are Same Time      (RACE Condition 방지)
        wrptr_n                     = wrptr + 'd1;
        retry_RAM_leftover_cnt_n    = retry_RAM_leftover_cnt;
    end
    else if(rd_en) begin
        retry_RAM_leftover_cnt_n    = retry_RAM_leftover_cnt + 'd8;
    end
    else if(wr_ed) begin
        wrptr_n                     = wrptr + 'd1;
        retry_RAM_leftover_cnt_n    = retry_RAM_leftover_cnt - 'd8;
    end

    case (acknak_seq_en_i)
    S_IDLE : begin
        if(IsTimeOut) begin        // Timeout!
            acknak_timeout_cnt_n            = 'd0;
            // synopsys translate_off
            $display("ACK/NAK Time Out!!! Replay at SEQ : %d", as_confirmed_reg);
            // synopsys translate_on
            retry_table_rd_en_n             = 'd1;
            table_r_idx_n                   = {8'd0, as_confirmed_reg[7:0]};
        end
        else begin
            acknak_timeout_cnt_n            = acknak_timeout_cnt + 'd1;
        end
    end
    S_ACK : begin
        acknak_timeout_cnt_n                = 'd0;
        retry_table_rd_en_n                 = 'd0;
        table_r_idx_n                       = 'd0;
        as_confirmed_reg_n                  = acknak_seq_num_i;
        // synopsys translate_off
        $display("ACK Occur! AS is updated to : %d", acknak_seq_num_i);
        // synopsys translate_on
    end
    S_NAK : begin
        acknak_timeout_cnt_n                = 'd0;
        retry_table_rd_en_n                 = 'd1;
        table_r_idx_n                       = acknak_seq_num_i;
        as_confirmed_reg_n                  = acknak_seq_num_i - 'd1;
        // synopsys translate_off
        $display("NAK Occur! AS is updated to SEQ : %d and Replay at SEQ : %d", as_confirmed_reg_n, acknak_seq_num_i);
        // synopsys translate_on
    end
    endcase

    case (acknak_seq_en_2d)
    S_IDLE : begin
        if(IsTimeOut_d) begin
            rdptr_n     = retry_table_dout_d[STP_IDX_BITS+MAX_TLP_SIZE_BITS +: STP_ADDR_BITS];
            // synopsys translate_off
            $display("rdptr will be updated , TYPE: %d, ADDR :%h, STP_IDX : %d, SIZE : %d", //[DEBUG_TYPE+STP_ADDR_BITS+STP_IDX_BITS+MAX_TLP_SIZE_BITS-1:0]
                retry_table_dout_d[STP_ADDR_BITS+STP_IDX_BITS+MAX_TLP_SIZE_BITS +: DEBUG_TYPE],
                retry_table_dout_d[              STP_IDX_BITS+MAX_TLP_SIZE_BITS +: STP_ADDR_BITS],
                retry_table_dout_d[                           MAX_TLP_SIZE_BITS +: STP_IDX_BITS],
                retry_table_dout_d[                                           0 +: MAX_TLP_SIZE_BITS]);
            // synopsys translate_on
        end
        else if(rd_en) begin
            rdptr_n     = rdptr + 'd1;
        end
    end
    S_NAK : begin
        rdptr_n     = retry_table_dout_d[STP_IDX_BITS+MAX_TLP_SIZE_BITS +: STP_ADDR_BITS];     // Replay From NAK position
        // synopsys translate_off
        $display("rdptr will be updated , ADDR :%h", retry_table_dout_d[STP_IDX_BITS+MAX_TLP_SIZE_BITS +: STP_ADDR_BITS]);
        // synopsys translate_on

    end
    default : begin
        if(rd_en) begin
            rdptr_n     = rdptr + 'd1;
        end
    end
    endcase


end

SAL_SDP_RAM #(
    .DEPTH_LG2               (RETRY_DEPTH_LG2),
    .DATA_WIDTH              (PIPE_DATA_WIDTH+1),
    .RDATA_FF_OUT            (1),
  // synchronization between read/write ports
  // WR_FIRST: new content is immediately made available for reading
  // RD_FIRST: old content is read before new content is loaded
    .RW_SYNC                 ("RD_FIRST")
)
U_RETRY_BUFFER
(
    .clk                    (sclk),

    .en_a                   (data_en_i),
    .we_a                   (1'd1),
    .addr_a                 (wrptr[MSB-1:0]),
    .di_a                   ({lcrc_en_i, data_i[7], data_i[6], data_i[5], data_i[4],
                              data_i[3], data_i[2], data_i[1], data_i[0]}),                // FIFO IN  (Write Only)

    .en_b                   (rd_en),
    .addr_b                 (rdptr[MSB-1:0]),
    .do_b                   ({lcrc_en_d, data_d[7], data_d[6], data_d[5], data_d[4],
                              data_d[3], data_d[2], data_d[1], data_d[0]})                // FIFO OUT (Read Only)
);

// Read Need 1 Delay
reg  rd_en_d;
always_ff @(posedge sclk) begin
    if(!srst_n) begin
        rd_en_d     <= 0;
    end
    else begin
        rd_en_d     <= rd_en;
    end
end


assign as_o                         = as_confirmed_reg;
assign retry_buffer_leftover_cnt_o  = retry_RAM_leftover_cnt;

generate
    for (genvar k = 0; k < 8; k++) begin : gen_assign_data
        assign data_o[k] = data_d[k];
    end
endgenerate
assign data_valid_o                    = rd_en_d;
assign data_last_o                     = lcrc_en_d; // LCRC 위치확인을 한칸 둬야할듯




endmodule
