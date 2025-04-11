module _DLL_DLCMSM (
	input	wire 	clk,
	input 	wire 	rst_n,

	// DLLP Generator
	input 	wire	init1_end_i,
	input	wire	init2_end_i,

	// Many Modules
	output 	wire 	state_o 
);

localparam              S_INACTIVE = 3'd0,
                        S_INIT1    = 3'd1,
                        S_INIT2    = 3'd2,
                        S_ACTIVE   = 3'd3;

reg 	[1:0]			state, state_n;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state               <= S_INACTIVE;
    end
    else begin
        state               <= state_n;
    end
end

always_comb begin
	state_n					= state;

	case (state)
		S_INACTIVE: begin
			if (rst_n) begin
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
			begin
				state_n = S_INIT2;
			end
		end

		S_ACTIVE: begin
			state_n = S_ACTIVE;
		end
	endcase
end

assign state_o = state;

endmodule