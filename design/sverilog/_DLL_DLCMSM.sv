module _DLL_DLCMSM (
   input   wire    sclk,
   input   wire    srst_n,

   // from DLLP Generator, Decoder
   input   wire   init1_end_i,
   input   wire   init2_end_i,

   // to Many Modules
   output  wire    link_up_o,
   output  wire    DLCM_state_o 
);

localparam              S_INACTIVE = 2'd0,
                        S_INIT1    = 2'd1, // link down
//-------------------------------------------------------//
                        S_INIT2    = 2'd2, // link up
                        S_ACTIVE   = 2'd3;

reg    [1:0]         state, state_n;
reg                  link_up;

always_ff @(posedge sclk) begin
    if (!srst_n) begin
        state               <= S_INACTIVE;
    end
    else begin
        state               <= state_n;
    end
end

always_comb begin
   state_n               = state;

   case (state)
      S_INACTIVE: begin
         link_up = 1'b0;
         if (srst_n) begin
            state_n = S_INIT1;
            end
         else begin
            state_n = S_INACTIVE;
         end
      end

      S_INIT1: begin
         link_up = 1'b0;
         if (init1_end_i) begin
            state_n = S_INIT2;
            end
         else begin
            state_n = S_INIT1;
         end
      end

      S_INIT2: begin
         link_up = 1'b1;
         if (init2_end_i) begin
            state_n = S_ACTIVE;
         end
         begin
            state_n = S_INIT2;
         end
      end

      S_ACTIVE: begin
         link_up = 1'b1;
         state_n = S_ACTIVE;
      end
   endcase
end

assign DLCM_state_o = state;
assign link_up_o    = link_up;

endmodule