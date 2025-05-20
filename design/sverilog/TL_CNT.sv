// Author: Wongi Choi <cwg43352@g.skku.edu
// Description: Counter for FIFO

module TL_CNT
#(
    parameter   int     DEPTH           = 4
)
(
    input   wire                        clk
  , input   wire                        rst_n

  , input   wire                        wren_i
  , input   wire                        rden_i

  , output  wire    [DEPTH:0]           cnt_o
);
    // capacity checking
    logic   [DEPTH:0]                   cnt,        cnt_n;

    always_ff @(posedge clk)
        if (~rst_n) begin
            cnt                         <= 'd0;
        end
        else begin
            cnt                         <= cnt_n;
        end

    always_comb begin
        if (wren_i & ~rden_i) begin
            cnt_n                       = cnt + 'd1;
        end
        else if (~wren_i & rden_i) begin
            cnt_n                       = cnt - 'd1;
        end
        else begin
            cnt_n                       = cnt;
        end
    end

    assign  cnt_o                   = cnt;

endmodule
