// 라우팅만 하기 !

module _DLL_Arbitor
#(
    parameter  int  PIPE_DATA_WIDTH          = 256,
)
(
    // -------------------------------------------------------
    //                    DLCMSM
    // -------------------------------------------------------
    input   wire                                    DL_up,

    input   wire  [PIPE_DATA_WIDTH-1:0]             tlp_32B_buffer_i;
    input   wire  [PIPE_DATA_WIDTH-1:0]             dllp_32B_buffer_i;

    output  wire  [PIPE_DATA_WIDTH-1:0]             pipe_data_o;




);

endmodule