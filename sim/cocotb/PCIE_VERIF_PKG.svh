// Copyright Sungkyunkwan University
// Author: YongSeong Lim <xidid430rr@gmail.com>
// Description:

// Follows PCIe gen5 specification 1.1

`ifndef __PCIE_VERIF_PKG_SVH__
`define __PCIE_VERIF_PKG_SVH__

package PCIE_VERIF_PKG;

    import PCIE_PKG::*; 

    //                                                 HDR |      MAX_PAYLOAD      | CRC
    localparam  MAX_TLP_DEPTH       = 6;            // 32B | 32B | 32B | 32B | 32B | 32B

    // Make Random 1 bit Error
    class Error_Generate;


    endclass


    // ----------------------------------------------------------
    //                  Send Random Generate Packet
    // ----------------------------------------------------------
    typedef enum {MEMWR, MEMRD, CPL, CPLD} tlp_type_e;

    class Random_Generate_Packet;

        // Random
        rand bit [9:0]                          length;
        rand bit [15:0]                         address;
        rand bit [9:0]                          tag;

        // Saved
        logic   [PIPE_DATA_WIDTH-1:0]           tlp[MAX_TLP_DEPTH];                   // SEQ + HDR | PAYLAOD | ECRC, LCRC
        
        constraint rules {
            length  inside {[2:32]};            // 2, 4, 6 ... 32
            length  % 2 == 0;
            address % 4 == 0;                   // address Natural Aligned
            tag     < 1024;
        }

        function new();
            for (int i = 0; i < 6; i++) begin
                tlp[i] = '0;                        // 전체 256비트 zero로 초기화
            end
        endfunction
        
        task automatic send_rand_gen_tlp(
            input   tlp_type_e              tlp_type
          , input   [11:0]                  seq_num
          , output  [PIPE_DATA_WIDTH-1:0]   pipe_data_o;
        )
            case (tlp_type)
            MEMWR: begin
                send_rand_gen_tlp_memwr(seq_num);
                display();
            end
            MEMRD: begin
                send_tlp_memrd(...);
                display();
            end
            CPL: begin
                send_tlp_cpl(...);
                display();
            end
            CPLD: begin
                send_tlp_cpld(...);
                display();
            end
            endcase
        endtask

        task automatic send_rand_gen_tlp_memwr(
            input   [11:0]                      seq_num
          , output  [PIPE_DATA_WIDTH-1:0]       pipe_data_o
        );
            tlp_memory_req_hdr_t                memwr_hdr;                  // 16B

            // 1. Generate Random Size Payload
            if (!this.randomize()) begin
                $fatal("Randomization failed");
            end

            // 2. TLP Header 생성
            memwr_hdr = gen_tlp_memwr_hdr(                                  // 16B
                                .fmt            (3'b010),
                                .tlp_type       (5'b00000),
                                .tc             (3'b000),
                                .attr           (3'b000),
                                .ln             (1'b0),
                                .th             (1'b0),
                                .td             (1'b0),
                                .ep             (1'b0),
                                .at             (2'b00),
                                .length         (length),               // length는 dw(4B) 기준
                                .requester_id   (16'h0001),
                                .tag            (tag),
                                .Last_DW_BE     (4'hF),
                                .First_DW_BE    (4'hF),
                                .address        (address),
                                .reserved       (2'b00)
            );

            // 3. Payload 채우기 (MSB부터 채우는 구조)
            int i;                                                                          // ex) length = 118B
            int payload_depth           = ((length % 8) == 0)? (length/8) : (length/8)+1;   // ex) 8(4B) | 8(4B) | 8(4B) | 6(4B)
            int payload_rest            = length % 8;                                       // ex) 6(4B)

            tlp[0] = {116'd0, seq_num, memwr_hdr};                                          // 32B = {116b, 12b,| 128b(HDR)}
            for (i = 0; i < payload_depth; i++) begin
                tlp[i+1] = {$urandom(), $urandom(), $urandom(), $urandom(),                 // 32B = 8 x urandom(32b)
                            $urandom(), $urandom(), $urandom(), $urandom()};
            end
            
            case (payload_rest) 
            'd0 : begin                                                                     
                tlp[payload_depth+1]    = {'d0};
            end
            'd1 : begin
                tlp[payload_depth+1]    = {$urandom(), 32'd0,      32'd0,      32'd0, 
                                           32'd0,      32'd0,      32'd0,      32'd0};
            end
            'd2 : begin
                tlp[payload_depth+1]    = {$urandom(), $urandom(), 32'd0,      32'd0,
                                           32'd0,      32'd0,      32'd0,      32'd0};
            end
            'd3 : begin
                tlp[payload_depth+1]    = {$urandom(), $urandom(), $urandom(), 32'd0,
                                           32'd0,      32'd0,      32'd0,      32'd0};
            end
            'd4 : begin
                tlp[payload_depth+1]    = {$urandom(), $urandom(), $urandom(), $urandom(),
                                           32'd0,      32'd0,      32'd0,      32'd0};
            end
            'd5 : begin
                tlp[payload_depth+1]    = {$urandom(), $urandom(), $urandom(), $urandom(),
                                           $urandom(), 32'd0,      32'd0,      32'd0};
            end
            'd6 : begin
                tlp[payload_depth+1]    = {$urandom(), $urandom(), $urandom(), $urandom(),
                                           $urandom(), $urandom(), 32'd0,      32'd0};
            end
            'd7 : begin
                tlp[payload_depth+1]    = {$urandom(), $urandom(), $urandom(), $urandom(),
                                           $urandom(), $urandom(), $urandom(), 32'd0};
            end
            'default : begin
                $display("ERROR | Task_name : send_rand_gen_tlp_memwr at PCIE_VERIF_PKG");
            end
            endcase

            // 4. Payload 나머지와 ECRC, LCRC 채우기
            logic   [31:0]      ecrc;       // 4B
            logic   [31:0]      lcrc;       // 4B

            ecrc = gen_crc32(
                {tlp[0], tlp[1], tlp[2], tlp[3], tlp[4], tlp[5]}
              , ((64 + (length * 4)) * 8)               // HDR(64B) + length(4B단위)
              , (64 * 8)                                // zeros 스킵
            );

            lcrc = gen_crc32(
                {tlp[0], tlp[1], tlp[2], tlp[3], tlp[4], tlp[5]}
              , (12 + ((64 + (length * 4) + 4) * 8))    // SEQ(12b) + HDR(64B) + length(4B) + ECRC(4B)
              , (64 * 8) - 12                           // zeros 스킵
            );


            // 5. 전송
            $display("[TLP SEND] Seq=%0d Length=%0d DW", seq_num, length);
            for (i = 0; i < 1+payload_depth+((payload_rest==0)? 0:1) ; i++) begin
                pipe_data_o             = tlp[i];                             // 실질적 전송이 이뤄지는 부분
                #1
            end
        endtask

        task send_tlp_memrd(
            input   tlp_memory_req_hdr_t            hdr
        );
            $display("Send TLP: Seq=%0d", pkt.seq_num);
        endtask

        task send_tlp_cpld(
            input   tlp_completion_hdr_t            hdr
        ,   
        );
            $display("Send TLP: Seq=%0d", pkt.seq_num);
        endtask

        task send_tlp_cpl(
            input   tlp_completion_hdr_t            hdr
        ,   
        );
            $display("Send TLP: Seq=%0d", pkt.seq_num);
        endtask

        task send_dllp_initFC1(

        );
        
        endtask

    endclass

    function automatic logic [31:0] gen_crc32(
        input logic [0:(PIPE_DATA_WIDTH*MAX_TLP_DEPTH)-1]       data         // MSB first
      , input int                                               len          // 실제 길이
      , input int                                               cut_MSB_len  // MSB를 짜를 비트 길이
    );
        logic [31:0] crc = 32'hFFFF_FFFF;

        for (int i = cut_MSB_len; i < cut_MSB_len+len; i++) begin
            logic bit_in            = data[i] ^ crc[31];
            crc                     = (crc << 1) ^ (bit_in ? 32'h04C11DB7 : 32'h0);
        end

        return ~crc;  // 1's complement
    endfunction



    // ----------------------------------------------------------
    //                  Make BER(Bit Error Rate)
    // ----------------------------------------------------------
    task

    endtask

endpackage

`endif