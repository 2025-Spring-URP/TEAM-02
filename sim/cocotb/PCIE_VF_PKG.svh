// Copyright Sungkyunkwan University
// Author: YongSeong Lim <xidid430rr@gmail.com>
// Description:

// Follows PCIe gen5 specification 1.1

`ifndef __PCIE_VERIF_PKG_SVH__
`define __PCIE_VERIF_PKG_SVH__

package PCIE_VF_PKG;
    import PCIE_PKG::*; 

    localparam MAX_TLP_DEPTH = 6;

    // ----------------------------------------------------------
    //                  Common Utilities
    // ----------------------------------------------------------
    function automatic [PIPE_DATA_WIDTH-1:0] rand_gen_32B_payload();
        return {
            $urandom(), $urandom(), $urandom(), $urandom(),
            $urandom(), $urandom(), $urandom(), $urandom()
        };
    endfunction

    function automatic [PIPE_DATA_WIDTH-1:0] rand_gen_partial_payload(input int rest_dw);
        logic [PIPE_DATA_WIDTH-1:0] partial = '0;
        for (int i = 0; i < rest_dw; i++) begin
            partial[i*32 +: 32] = $urandom();
        end
        return partial;
    endfunction

    function automatic logic [31:0] gen_crc32(
        input logic [0:(PIPE_DATA_WIDTH*MAX_TLP_DEPTH)-1] data,
        input int len, input int cut_MSB_len
    );
        logic [31:0] crc = 32'hFFFF_FFFF;
        for (int i = cut_MSB_len; i < cut_MSB_len + len; i++) begin
            logic bit_in = data[i] ^ crc[31];
            crc = (crc << 1) ^ (bit_in ? 32'h04C11DB7 : 32'h0);
        end
        return ~crc;
    endfunction

    // Inject Bit Error at a Packet
    function automatic inject_bit_error(
    );
    endfunction

    // ----------------------------------------------------------
    //             Generate Packet Object
    // ----------------------------------------------------------
    class TLP_MEMWR_PKT;
        tlp_memory_req_hdr_t                    hdr;

        rand bit [9:0]                          length;
        rand bit [15:0]                         address;
        rand bit [9:0]                          tag;

        logic [PIPE_DATA_WIDTH-1:0]             tlp[MAX_TLP_DEPTH];

        constraint rules {
            length inside {[2:32]};
            length % 2 == 0;
            address % 4 == 0;
            tag < 1024;
        }

        function new();
            foreach (tlp[i]) tlp[i] = '0;       // Reset '0'
        endfunction

        function set_hdr(
            input   [9:0]           set_length,
            input   [15:0]          set_address,
            input   [9:0]           set_tag,
        );
            //
        endfunction


        //make packet (tlp will have own correct data)
        function make_packet(
            input   [11:0]                      seq_num

        );

            // Step 1) Make HDR

            // Step 2) Make Payload

            // Step 3) Make ECRC, LCRC

            // Step 4) Put all in tlp[]

        endfunction

        // Send Packet
        task automatic send_packet(
            output  [PIPE_DATA_WIDTH-1:0]       pipe_data_o
        );
            for (int i = 0; i < total_depth; i++) begin
                pipe_data_o = tlp[i];
                #1;
            end
        endtask

        task automatic make_error_seq(
            input   [11:0]      new_seq
        );
            // tlp[] <-- 보수 취하기
        endtask

        task automatic make_error_hdr();
            // tlp[] <-- 보수 취하기
        endtask

        task automatic make_error_payload();
            // tlp[] <-- 보수 취하기
        endtask

        task automatic make_error_ecrc();
            // tlp[] <-- 보수 취하기
        endtask

        task automatic make_error_lcrc();
            // tlp[] <-- 보수 취하기
        endtask
    endclass

    class TLP_MEMRD_PKT;
        tlp_memory_req_hdr_t    hdr;
        // Send Packet
        task automatic send_packet(
            input   [11:0]                      seq_num
          , output  [PIPE_DATA_WIDTH-1:0]       pipe_data_o
        );
        endtask
    endclass

    class TLP_CPL_PKT;
        tlp_cpl_hdr_t           hdr;
        // Send Packet
        task automatic send_packet(
            input   [11:0]                      seq_num
          , output  [PIPE_DATA_WIDTH-1:0]       pipe_data_o
        );
        endtask
    endclass

    class TLP_CPLD_PKT;
        tlp_cpl_hdr_t           hdr;
        // Send Packet
        task automatic send_packet(
            input   [11:0]                      seq_num
          , output  [PIPE_DATA_WIDTH-1:0]       pipe_data_o
        );
        endtask
    endclass

    class DLLP_ACK_PKT;
        dllp_ACKNAK_packet_t    hdr;
        // Send Packet
        task automatic send_packet(
            input   [11:0]                      seq_num
          , output  [PIPE_DATA_WIDTH-1:0]       pipe_data_o
        );
        endtask
    endclass

    class DLLP_NAK_PKT;
        dllp_ACKNAK_packet_t    hdr;

        // Send Packet
        task automatic send_packet(
            input   [11:0]                      seq_num
          , output  [PIPE_DATA_WIDTH-1:0]       pipe_data_o
        );
        endtask
    endclass

    class DLLP_NOP_PKT;
        dllp_NOP_packet_t       hdr;

        // Send Packet
        task automatic send_packet(
            input   [11:0]                      seq_num
          , output  [PIPE_DATA_WIDTH-1:0]       pipe_data_o
        );
        endtask
    endclass

    class DLLP_FC_PKT;
        dllp_FC_packet_t        hdr;

        // Send Packet
        task automatic send_packet(
            input   [11:0]                      seq_num
          , output  [PIPE_DATA_WIDTH-1:0]       pipe_data_o
        );
        endtask
    endclass

endpackage

`endif