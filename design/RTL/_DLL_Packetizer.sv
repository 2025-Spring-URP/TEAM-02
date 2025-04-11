// TL로부터 TLP 조각들 받으면 그거 앞뒤로 SEQ + LCRC 붙이기.

// delay를 위한 Reg를 둬서 CRC 1clk delay(1clk floating 문제)  해결


module _DLL_Packetizer
#(
    parameter  int  PIPE_DATA_WIDTH          = 256,
)
(
    input   wire                                sclk,
    input   wire                                srst_n,

    // TL
    input   wire  [PIPE_DATA_WIDTH-1:0]         data_i,
    output  wire                                crc_run_o, 

    // Retry Montior
    output  wire  [PIPE_DATA_WIDTH-1:0]         data_o,
    output  wire                                wren_o,

);

reg [PIPE_DATA_WIDTH-1:0]           data_d;
reg [PIPE_DATA_WIDTH-1:0]           data_2d;

// CRC32 FSM (Gray Code Style)
localparam          S_IDLE      = 2'b00,        // crc_run_o = 0;
                    S_CRC_RUN   = 2'b01,        // crc_run_o = 1;
                    S_DONE      = 2'b11;        // crc_run_o = 1;

always_ff @(posedge clk) begin
    if (!srst_n) begin

    end
    else begin

    end
end

always_comb begin
    
    case()
    endcase
end


assign  data_o              = ;
assign  crc_state_o         = ; 

endmodule
