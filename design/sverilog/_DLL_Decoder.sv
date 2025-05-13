module _DLL_Decoder
#( 
    parameter       PIPE_DATA_WIDTH     = 256,
    parameter       CREDIT_DEPTH        = 12
)
(   
    input   wire                                    sclk,
    input   wire                                    srst_n,
    // -------------------------------------------------------
    //                    DLCMSM
    // -------------------------------------------------------
    output  wire                                    init1_received_o,
    output  wire                                    init2_received_o,

    // -------------------------------------------------------
    //                PIPE Interface
    // -------------------------------------------------------
    input   wire                                    pipe2dll_valid_i,
    input   wire     [PIPE_DATA_WIDTH-1:0]          pipe2dll_data_i,

    // -------------------------------------------------------
    //              Transaction Layer
    // -------------------------------------------------------
    output   wire     [PIPE_DATA_WIDTH-1:0]          dll2tl_data_o,
    output   wire                                    dll2tl_data_valid_o,
    
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_p_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_p_d_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_np_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_np_d_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_cpl_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cc_cpld_d_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_p_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_p_d_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_np_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_np_d_o,

    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_cpl_h_o,
    output   wire     [CREDIT_DEPTH-1:0]             ep_cl_cpld_d_o
);

reg [PIPE_DATA_WIDTH-1:0] dllp_32B, dllp_32B_n;

reg [CREDIT_DEPTH-1:0]  ep_cl_p_h, ep_cl_p_h_n,
                        ep_cl_p_d, ep_cl_p_d_n,
                        ep_cl_np_h, ep_cl_np_h_n,
                        ep_cl_np_d, ep_cl_np_d_n,
                        ep_cl_cpl_h, ep_cl_cpl_h_n,
                        ep_cl_cpl_d, ep_cl_cpl_d_n;                 

reg                     init2_p_received, init2_p_received_n,
                        init2_np_received, init2_np_received_n,
                        init2_cpl_received, init2_cpl_received_n;

reg [CREDIT_DEPTH-1:0]  ep_cc_p_h, ep_cc_p_h_n,
                        ep_cc_p_d, ep_cc_p_d_n,
                        ep_cc_np_h, ep_cc_np_h_n,
                        ep_cc_np_d, ep_cc_np_d_n,
                        ep_cc_cpl_h, ep_cc_cpl_h_n,
                        ep_cc_cpl_d, ep_cc_cpl_d_n;

reg [CREDIT_DEPTH-1:0]  ack_seq_num, ack_seq_num_n,
                        nak_seq_num, nak_seq_num_n;                


localparam          S_DLLP_IDLE         = 2'd0,
                    S_DLLP_CRC_CHECK   = 2'd1,
                    S_DLLP_GET_DATA     = 2'd2;

reg [1:0] dllp_state, dllp_state_n;
reg [31:0] dllp_crc_input;
reg [15:0] dllp_crc_result;

always_ff @(posedge sclk) begin
    if (!srst_n) begin
        dllp_state          <= S_DLLP_IDLE;

        dllp_32B            <= 'd0;

        ep_cl_p_h           <= 'd0;
        ep_cl_p_d           <= 'd0;
        ep_cl_np_h          <= 'd0;
        ep_cl_np_d          <= 'd0;
        ep_cl_cpl_h         <= 'd0;
        ep_cl_cpl_d         <= 'd0;

        init2_p_received    <= 'd0;
        init2_np_received   <= 'd0;
        init2_cpl_received  <= 'd0;

        ep_cc_p_h           <= 'd0;
        ep_cc_p_d           <= 'd0;
        ep_cc_np_h          <= 'd0;
        ep_cc_np_d          <= 'd0;
        ep_cc_cpl_h         <= 'd0;
        ep_cc_cpl_d         <= 'd0;

        ack_seq_num         <= 'd0;
        nak_seq_num         <= 'd0;
    end
    else begin
        dllp_state          <= dllp_state_n;

        dllp_32B            <= dllp_32B_n;

        ep_cl_p_h           <= ep_cl_p_h_n;
        ep_cl_p_d           <= ep_cl_p_d_n;
        ep_cl_np_h          <= ep_cl_np_h_n;
        ep_cl_np_d          <= ep_cl_np_d_n;
        ep_cl_cpl_h         <= ep_cl_cpl_h_n;
        ep_cl_cpl_d         <= ep_cl_cpl_d_n;

        init2_p_received    <= init2_p_received_n;
        init2_np_received   <= init2_np_received_n;
        init2_cpl_received  <= init2_cpl_received_n;

        ep_cc_p_h           <= ep_cc_p_h_n;
        ep_cc_p_d           <= ep_cc_p_d_n;
        ep_cc_np_h          <= ep_cc_np_h_n;
        ep_cc_np_d          <= ep_cc_np_d_n;
        ep_cc_cpl_h         <= ep_cc_cpl_h_n;
        ep_cc_cpl_d         <= ep_cc_cpl_d_n;

        ack_seq_num         <= ack_seq_num_n;
        nak_seq_num         <= nak_seq_num_n;

    end
end

always_comb begin
    dllp_crc_input              = 32'd0;
    dllp_crc_result             = 16'hFFFF;

    case(dllp_state)
        S_DLLP_IDLE: begin
            if ((pipe2dll_valid_i == 1'b1) && (pipe2dll_data_i[15:0] == 16'hACF0)) begin
                dllp_32B_n      = pipe2dll_data_i;
                dllp_state_n    =   S_DLLP_CRC_CHECK;
            end
        end
        S_DLLP_CRC_CHECK: begin
            dllp_crc_input  = dllp_32B[47:16];
            for (int i = 0; i < 32; i++) begin
                if ((dllp_crc_result[15] ^ dllp_crc_input[31 - i]) == 1'b1)
                    dllp_crc_result       = {dllp_crc_result[14:0], 1'b0} ^ 16'h100B;
                else
                    dllp_crc_result       = {dllp_crc_result[14:0], 1'b0};
            end

            if (dllp_32B[15:0] == ~dllp_crc_result) begin   // CRC Pass
                dllp_state_n              = S_DLLP_GET_DATA;
            end
            else begin                                      // CRC Fail
                dllp_state_n              = S_DLLP_IDLE;
            end
        end
        S_DLLP_GET_DATA: begin
            case (dllp_32B[23:16])
                8'b0100_0000: begin // init1 p
                    ep_cl_p_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // p header credit limit
                    ep_cl_p_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // p data credit limit
                end
                8'b0101_0000: begin // init1 np
                    ep_cl_np_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // np header credit limit
                    ep_cl_np_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // np data credit limit
                end
                8'b0110_0000: begin // init1 cpl
                    ep_cl_cpl_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // cpl header credit limit
                    ep_cl_cpl_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // cpl data credit limit
                end

                8'b1100_0000: begin // init2 p
                    init2_p_received_n = 1'b1;
                end
                8'b1101_0000: begin // init2 np
                    init2_np_received_n = 1'b1;
                end
                8'b1110_0000: begin // init2 cpl
                    init2_cpl_received_n = 1'b1;
                end

                8'b1000_0000: begin // fc p
                    ep_cc_p_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // p header credit consumed
                    ep_cc_p_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // p data credit consumed
                end
                8'b1001_0000: begin // fc np
                    ep_cc_np_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // np header credit consumed
                    ep_cc_np_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // np data credit consumed
                end
                8'b1010_0000: begin // fc cpl
                    ep_cc_cpl_h_n = {4'd0, dllp_32B[29:24], dllp_32B[39:38]}; // cpl header credit consumed
                    ep_cc_cpl_d_n = {dllp_32B[35:32], dllp_32B[47:40]};       // cpl data credit consumed
                end

                8'b0000_0000: begin // ack
                    ack_seq_num_n = {dllp_32B[35:32], dllp_32B[47:40]}; // ack sequence number
                end
                8'b0001_0000: begin // nak
                    nak_seq_num_n = {dllp_32B[35:32], dllp_32B[47:40]}; // nak sequence number 
                end

                default: begin
                    $display("[DLLP DECODER] Warning: Unknown DLLP type %h", dllp_32B[23:16]);
                end
            endcase
            dllp_state_n          = S_DLLP_IDLE; 
        end
    endcase
end

assign init1_received_o = ep_cl_p_h && ep_cl_p_d && ep_cl_np_h && ep_cl_np_d && ep_cl_cpl_h && ep_cl_cpl_d;
assign init2_received_o = init2_p_received && init2_np_received && init2_cpl_received;

assign ep_cl_p_h_o      = ep_cl_p_h;
assign ep_cl_p_d_o      = ep_cl_p_d;
assign ep_cl_np_h_o     = ep_cl_np_h;
assign ep_cl_np_d_o     = ep_cl_np_d;
assign ep_cl_cpl_h_o    = ep_cl_cpl_h;
assign ep_cl_cpl_d_o    = ep_cl_cpl_d;

assign ep_cc_p_h_o      = ep_cc_p_h;
assign ep_cc_p_d_o      = ep_cc_p_d;
assign ep_cc_np_h_o     = ep_cc_np_h;
assign ep_cc_np_d_o     = ep_cc_np_d;
assign ep_cc_cpl_h_o    = ep_cc_cpl_h;
assign ep_cc_cpl_d_o    = ep_cc_cpl_d;

endmodule