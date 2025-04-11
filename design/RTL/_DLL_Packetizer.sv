// TL로부터 TLP 조각들 받으면 그거 앞뒤로 SEQ + LCRC 붙이기.

// delay를 위한 Reg를 둬서 CRC 1clk delay(1clk floating 문제)  해결


module _DLL_Packetizer
#(
    parameter  int  PIPE_DATA_WIDTH          = 256
)
(
    input   wire                                sclk,
    input   wire                                srst_n,

    // TL
    input   wire  [PIPE_DATA_WIDTH-1:0]         data_i,
    input   wire                                tl_en,          // data valid --> en = 1 (max 6 clk set)
    input   wire  []             wstrb,
    output  wire                                crc_run_o, 

    // Retry Montior
    output  wire  [PIPE_DATA_WIDTH-1:0]         data_o,
    output  wire                                wren_o,

    // Others
    input   wire                                link_up_i;

);


// Rules
// 1) MEMWR, MEMRD 모두 LSB에 정렬되어 온다
// 2) 
// TLP Type Field
localparam type_t TYPE_MEM              = 5'b00000,
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
                  TYPE_EPRFX            = 5'b10000;

// ---------------------------------------------------------------------------
//                            SEQ Insert
// ---------------------------------------------------------------------------
reg [11:0]      seq_num;
always_ff @(posedge sclk) begin
    if(!rst_n) begin
        seq_num         <= 0;
    end
    else begin
        seq_num         <= seq_num + 1; //Wrapped Around 방식
    end
end

// 만약 하나에 Packet에 꾸겨 넣을거면, data 레지스터에 넣는 것을 수정해야함.
reg  [PIPE_DATA_WIDTH-1:0]          data, data_d;     // data_i --(+SEQ)--> data(no data out here) ---> data_d(with data out here)
wire [PIPE_DATA_WIDTH-1:0]          crc32_din;

always_ff @(posedge sclk) begin
    if (!rst_n) begin
        data                <= 'd0;
        data_d              <= 'd0;
    end
    else begin
        if(tl_en & (pkt_gen_cnt == 'd0)) begin              // First Start : SEQ insert
            if(data_i[124:120] == TYPE_MEM)                 // Check HDR Format Field

            case(data_i[127:125])                           // FMT Check   Prefix | Data | DW
                'd010 : begin   // Posted (w DATA)
                    data[143:112]      <= 'd0                          // Frame Token Reserved
                    data[111:96]       <= {4'b0000, seq_num};          // SEQ
                    data[95:0]         <= data_i[95:0]                 // HDR
                end
                'd000 : begin   // Non Posted (w/o DATA)
                    data[143:112]       <= 'd0                          // Frame Token Reserved
                    data[111:96]        <= {4'b0000, seq_num};          // SEQ
                    data[395:0]         <= data_i[95:0]                 // HDR
                end
                'd011 : begin   // Posted (w DATA)
                    data[175:144]       <= 'd0                          // Frame Token Reserved
                    data[143:128]       <= {4'b0000, seq_num};          // SEQ
                    data[127:0]         <= data_i[127:0]                // HDR
                end
                'd001 : begin   // Non Posted (w/o DATA)
                    data[255:224]       <= 'd0                          // Frame Token Reserved
                    data[223:208]       <= {4'b0000, seq_num};          // SEQ
                    data[207:80]        <= data_i[127:0]                // HDR
                end

            endcase

            data[]              <= 
            data[]              <= data_i;

        end
        else begin                                  // 

        end
        data_d                  <= data;       // 1 clk delay
    end
end

reg [2:0]                           pkt_gen_cnt;        // (MAX) 1 | 4 | 1 
always_ff @(posedge sclk) begin
    if (!rst_n) begin
        pkt_gen_cnt             <= 'd0;
    end
    else begin
        if () begin
            pkt_gen_cnt         <= 'd0;
        end
        else begin
            pkt_gen_cnt         <=  pkt_gen_cnt + 1;
        end
    end
end

assign  crc32_din               = ()? data:data_d;

// -------------------------------- CRC32 FSM ----------------------------------------------- 
// CRC32 FSM
localparam          S_IDLE      = 2'b00,        // crc_run_o = 0;
                    S_CRC_RUN   = 2'b01,        // crc_run_o = 1;
                    S_DONE      = 2'b11;        // crc_run_o = 1;

reg [1:0]   state_n, state;

always_ff @(posedge sclk) begin
    if (!srst_n) begin
        state           <= 'd0;
    end
    else begin
        state           <= state_n;
    end
end

always_comb begin
    state_n                 = S_IDLE;
    crc_run_o               = 'd0;
    crc_en                  = 'd0;

    case()
    S_IDLE : begin
        state_n             = S_CRC_RUN;

        crc_run_o           = 'd0;
        crc_en              = 'd0;
    end
    S_CRC_RUN : begin
        if (crc_enb) begin
            state_n         = S_DONE;
        end
        else begin
            state_n         = S_CRC_RUN;
        end
        crc_run_o           = 'd1;
        crc_en              = 'd1;
    end
    S_DONE : begin
        state_n             = S_IDLE;

        crc_run_o           = 'd1;
        crc_en              = 'd0;
    end
    endcase
end


// CRC32 GEN    --> 1clk delay
wire    crc_enb;

SAL_CRC32_GEN U_CRC32
#(

)
(
    .crc32_d_i          (crc32_din),         // 32B(256b)
    .crc_ena_i          (crc_run_o),

    .crc32_d_o          (),         // 4B(32b)
    .crc_enb_o          (crc_enb)                   // 1clk pulse
)


assign  data_o              = ;
assign  crc_state_o         = ; 

endmodule
