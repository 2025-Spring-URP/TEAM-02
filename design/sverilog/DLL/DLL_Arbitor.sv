module DLL_Arbitor #(
    parameter  integer  PIPE_DATA_WIDTH          = 256,
    parameter  integer  OUTSTANDING_BITS         = 16
)
(
    input   wire                                sclk,
    input   wire                                srst_n,
    input   wire  [OUTSTANDING_BITS-1:0]        outstanding_TLP_i,

    /*      DLL_Retry_Monitor       */
    input   wire  [PIPE_DATA_WIDTH/8-1:0]       data_TLP_i[8],
    input   wire                                TLP_valid_i,
    output  reg                                 TLP_ready_o,
    input   wire                                TLP_last_i,
    /*      DLCMSM              */
    input   wire  [1:0]                         DLCMSM_i,
    /*      DLL Generator          */
    input   wire  [PIPE_DATA_WIDTH/8-1:0]       data_DLLP_i[8],
    input   wire                                DLLP_valid_i,
    output  reg                                 DLLP_ready_o,
    //input   wire                                DLLP_last_i,

    /*      PIPE Interface       */
    output  wire  [PIPE_DATA_WIDTH/8-1:0]       data_PIPE_o[8],
    output  wire                                data_PIPE_valid_o
);

// DLCMSM
localparam  DL_Inactive = 2'b00,
            DL_Init1    = 2'b01,
            DL_Init2    = 2'b10,
            DL_Active   = 2'b11;

typedef enum reg [1:0] {
    S_IDLE      = 2'b00,
    S_TLP_RUN   = 2'b01,
    S_DLLP_RUN  = 2'b10
} wr_state_t;

wr_state_t         state, state_n;


reg [PIPE_DATA_WIDTH/8-1:0]     data_PIPE[8];
reg                             data_PIPE_valid;


always_ff @(posedge sclk) begin
    if(!srst_n) begin
        state       <= S_IDLE;
    end
    else begin
        state       <= state_n;
    end
end

wire  TLP_handshake, DLLP_handshake;
assign TLP_handshake        = TLP_valid_i  & TLP_ready_o;
assign DLLP_handshake       = DLLP_valid_i & DLLP_ready_o;

always_comb begin
    state_n         = state;
    for(int i=0; i<8; i++) begin
        data_PIPE[i]        = 'd0;
    end
    data_PIPE_valid         = 'd0;
    TLP_ready_o             = 'd0;
    DLLP_ready_o            = 'd0;
    
    case(state)
    S_IDLE : begin
        TLP_ready_o     = 'd0;
        DLLP_ready_o    = 'd0;
        case(DLCMSM_i)
        DL_Inactive : begin
            state_n         = S_IDLE;
        end
        DL_Init1 : begin
            if(DLLP_valid_i) begin
                state_n         = S_DLLP_RUN;
                DLLP_ready_o    = 'd1;
            end
        end
        DL_Init2 : begin
            if(DLLP_valid_i) begin
                state_n         = S_DLLP_RUN;
                DLLP_ready_o    = 'd1;
            end
        end
        DL_Active : begin
            if(DLLP_valid_i) begin                          // Prioirty
                state_n         = S_DLLP_RUN;
                DLLP_ready_o    = 'd1;
            end
            else if(outstanding_TLP_i != 'd0) begin
                state_n         = S_TLP_RUN;
                TLP_ready_o     = 'd1;
            end
        end
        endcase
    end
    S_TLP_RUN : begin
        TLP_ready_o     = 'd1;
        DLLP_ready_o    = 'd0;
        if(TLP_handshake) begin
            for(int i=0; i<8; i++) begin
                data_PIPE[i]        = data_TLP_i[i];
            end
            data_PIPE_valid         = TLP_valid_i;
        end

        if(DLLP_valid_i & TLP_last_i) begin
            state_n         = S_DLLP_RUN;
            DLLP_ready_o    = 'd1;
        end
        else if(outstanding_TLP_i == 'd0) begin
            state_n         = S_IDLE;
            TLP_ready_o     = 'd0;
        end

    end
    S_DLLP_RUN : begin
        TLP_ready_o     = 'd0;
        DLLP_ready_o    = 'd1;
        for(int i=0; i<8; i++) begin
            data_PIPE[i]        = data_DLLP_i[i];
        end
        data_PIPE_valid         = 'd1;
        
        if((DLCMSM_i == DL_Active) & (outstanding_TLP_i != 'd0)) begin
            state_n         = S_TLP_RUN;
        end
        else begin
            state_n         = S_IDLE;
        end
        /*
        if(DLLP_last_i) begin
            state_n         = S_IDLE;
            DLLP_ready_o    = 'd0;
        end
        */
    end
    endcase
end



generate
    for(genvar k=0; k<8; k++) begin : gen_assign_data
        assign  data_PIPE_o[k]       = data_PIPE[k];
    end
endgenerate
assign data_PIPE_valid_o            = data_PIPE_valid;



endmodule