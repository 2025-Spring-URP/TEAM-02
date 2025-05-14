module _DLL_DLCMSM (
   input   wire    sclk,
   input   wire    srst_n,

   // from DLLP Generator, Decoder
   input   wire   init1_end_i,
   input   wire   init2_end_i,

   // to Many Modules
   output  wire [1:0]    DLCM_state_o 
);

localparam              S_INACTIVE = 2'd0,
                        S_INIT1    = 2'd1,
                        S_INIT2    = 2'd2,
                        S_ACTIVE   = 2'd3;

reg    [1:0]         state, state_n;

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
         if (srst_n) begin
            state_n = S_INIT1;
            end
         else begin
            state_n = S_INACTIVE;
         end
      end

      S_INIT1: begin
         if (init1_end_i) begin
            state_n = S_INIT2;
            end
         else begin
            state_n = S_INIT1;
         end
      end

      S_INIT2: begin
         if (init2_end_i) begin
            state_n = S_ACTIVE;
         end
         else begin
            state_n = S_INIT2;
         end
      end

      S_ACTIVE: begin
         state_n = S_ACTIVE;
      end
   endcase
end

assign DLCM_state_o = state;

endmodule
