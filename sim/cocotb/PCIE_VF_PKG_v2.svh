// Copyright Sungkyunkwan University
// Author: YongSeong Lim <xidid430rr@gmail.com>
// Description: Follows PCIe gen5 specification 1.1
// Improved and completed PCIE_VF_PKG

`ifndef __PCIE_VF_PKG_SVH__
`define __PCIE_VF_PKG_SVH__

package PCIE_VF_PKG;
    import PCIE_PKG::*; 

    //-------------------------------------------------------------------------
    // Parameter Definition
    //-------------------------------------------------------------------------
    localparam MAX_TLP_DEPTH = 6;  // TLP를 구성하는 워드 수

    

    //-------------------------------------------------------------------------
    // Common Utility Functions
    //-------------------------------------------------------------------------

    // 32B(8 x 32-bit) 랜덤 페이로드 생성 함수
    function automatic [PIPE_DATA_WIDTH-1:0] rand_gen_32B_payload();
        return {
            $urandom(), $urandom(), $urandom(), $urandom(),
            $urandom(), $urandom(), $urandom(), $urandom()
        };
    endfunction

    // 지정된 DW 개수만큼 부분 페이로드 생성 함수
    function automatic [PIPE_DATA_WIDTH-1:0] rand_gen_partial_payload(input int rest_dw);
        logic [PIPE_DATA_WIDTH-1:0] partial = '0;
        for (int i = 0; i < rest_dw; i++) begin
            partial[i*32 +: 32] = $urandom();
        end
        return partial;
    endfunction

    // 데이터에 대한 32비트 CRC 생성 함수
    function automatic logic [31:0] gen_crc32(
        input logic [0:(PIPE_DATA_WIDTH*MAX_TLP_DEPTH)-1] data,
        input int len, 
        input int cut_MSB_len
    );
        logic [31:0] crc = 32'hFFFF_FFFF;
        for (int i = cut_MSB_len; i < cut_MSB_len + len; i++) begin
            logic bit_in = data[i] ^ crc[31];
            crc = (crc << 1) ^ (bit_in ? 32'h04C11DB7 : 32'h0);
        end
        return ~crc;  // 1의 보수 반환
    endfunction

    // 비트 에러 주입 (패킷 데이터를 수정하는 예시)
    function automatic inject_bit_error();
        // 실제 환경에서는 패킷 데이터의 특정 위치에 에러를 주입하도록 구현
        // 여기서는 단순히 0을 리턴하는 더미 함수로 처리함.
        return 0;
    endfunction

    //-------------------------------------------------------------------------
    // TLP Packet Classes
    //-------------------------------------------------------------------------

    // TLP Memory Write Packet 클래스
    class TLP_MEMWR_PKT;
        // Header 관련 데이터 (PCIE_PKG에 정의되어 있다고 가정)
        tlp_memory_req_hdr_t hdr;

        // 랜덤 생성 필드
        rand bit [9:0]   length;
        rand bit [15:0]  address;
        rand bit [9:0]   tag;

        // TLP 데이터 저장 배열
        logic [PIPE_DATA_WIDTH-1:0] tlp[MAX_TLP_DEPTH];

        // 제약 조건: 길이, 주소, 태그 값
        constraint rules {
            length inside {[2:32]};
            length % 2 == 0;
            address % 4 == 0;
            tag < 1024;
        }

        // 생성자: TLP 배열 초기화
        function new();
            foreach (tlp[i])
                tlp[i] = '0;
        endfunction

        // 헤더 설정 함수 (헤더 생성 함수는 PCIE_PKG에 정의되어 있다고 가정)
        function void set_hdr(
            input int          set_length,
            input int unsigned set_address,
            input int          set_tag
        );
            hdr = gen_tlp_memwr_hdr(
                .fmt            (3'b010),
                .tlp_type       (5'b00000),
                .tc             (3'b000),
                .attr           (3'b000),
                .ln             (1'b0),
                .th             (1'b0),
                .td             (1'b0),
                .ep             (1'b0),
                .at             (2'b00),
                .length         (set_length),
                .requester_id   (16'h0001),
                .tag            (set_tag),
                .Last_DW_BE     (4'hF),
                .First_DW_BE    (4'hF),
                .address        (set_address),
                .reserved       (2'b00)
            );
        endfunction

        // 패킷 생성 함수: 헤더, 페이로드, CRC 계산
        function void make_packet(input int unsigned seq_num);
            // 1. 랜덤 필드 생성
            if (!this.randomize()) begin
                $fatal("TLP_MEMWR_PKT: Randomization failed");
            end

            // 2. 헤더 설정
            set_hdr(length, address, tag);

            // 3. 페이로드 생성 (길이는 DW 단위)
            int payload_depth = (length % 8 == 0) ? (length / 8) : (length / 8) + 1;
            int payload_rest  = length % 8;
            int used_words    = (payload_rest == 0) ? (1 + payload_depth)
                                                   : (1 + payload_depth + 1);

            if (used_words > MAX_TLP_DEPTH) begin
                $display("Error: Packet size (%0d words) exceeds MAX_TLP_DEPTH (%0d)", used_words, MAX_TLP_DEPTH);
                $fatal;
            end

            // 4. 패킷 워드 구성
            // 헤더 워드: {패딩(116비트), seq_num(12비트), hdr(128비트)}
            tlp[0] = {116'd0, seq_num, hdr};

            // 전체 페이로드 워드 채우기
            for (int i = 0; i < payload_depth; i++) begin
                tlp[i+1] = rand_gen_32B_payload();
            end

            // 부분 페이로드가 필요한 경우
            if (payload_rest != 0) begin
                tlp[payload_depth+1] = rand_gen_partial_payload(payload_rest);
            end

            // 5. CRC 계산 (전체 MAX_TLP_DEPTH 워드 기준)
            // 원래 코드에서는 헤더, 페이로드, ECRC, LCRC의 위치가 정해져 있으므로
            // 여기서는 단순히 예시로 CRC를 계산하여 출력함.
            logic [31:0] ecrc, lcrc;
            ecrc = gen_crc32({tlp[0], tlp[1], tlp[2], tlp[3], tlp[4], tlp[5]},
                              ((64 + (length * 4)) * 8),
                              (64 * 8));
            lcrc = gen_crc32({tlp[0], tlp[1], tlp[2], tlp[3], tlp[4], tlp[5]},
                              (12 + ((64 + (length * 4) + 4) * 8)),
                              ((64 * 8) - 12));
            $display("[TLP_MEMWR_PKT] Packet built with ECRC: %h, LCRC: %h", ecrc, lcrc);
        endfunction

        // PIPE 인터페이스로 패킷 전송
        task automatic send_packet(output [PIPE_DATA_WIDTH-1:0] pipe_data_o);
            int payload_depth = (length % 8 == 0) ? (length / 8) : (length / 8) + 1;
            int payload_rest  = length % 8;
            int used_words    = (payload_rest == 0) ? (1 + payload_depth)
                                                   : (1 + payload_depth + 1);
            for (int i = 0; i < used_words; i++) begin
                pipe_data_o = tlp[i];
                #1;
            end
        endtask

        //-------------------------------------------------------------------------
        // 오류 주입 태스크들
        //-------------------------------------------------------------------------

        // 시퀀스 번호에 오류 주입 (보수 취하기)
        task automatic make_error_seq(input int unsigned new_seq);
            // tlp[0]의 구성: {padding, seq_num, hdr}
            // 여기서는 seq_num 필드 (비트[139:128]로 가정)에 대해 보수를 취함
            tlp[0][139:128] = ~new_seq;
        endtask

        // 헤더에 오류 주입 (헤더 부분만 보수 취하기)
        task automatic make_error_hdr();
            tlp[0][127:0] = ~tlp[0][127:0];
        endtask

        // 첫번째 페이로드 워드에 오류 주입
        task automatic make_error_payload();
            if (MAX_TLP_DEPTH > 1) begin
                tlp[1] = ~tlp[1];
            end
        endtask

        // ECRC 오류 주입 (예시로 메시지 출력)
        task automatic make_error_ecrc();
            $display("[TLP_MEMWR_PKT] Simulating error in ECRC");
        endtask

        // LCRC 오류 주입 (예시로 메시지 출력)
        task automatic make_error_lcrc();
            $display("[TLP_MEMWR_PKT] Simulating error in LCRC");
        endtask

    endclass

    // TLP Memory Read Packet 클래스
    class TLP_MEMRD_PKT;
        tlp_memory_req_hdr_t hdr;
        // MEMRD는 페이로드가 없는 경우가 많으므로, 단일 워드 패킷으로 구성

        task automatic send_packet(
            input  int unsigned seq_num,
            output [PIPE_DATA_WIDTH-1:0] pipe_data_o
        );
            hdr = gen_tlp_memrd_hdr(
                .fmt            (3'b000),   // 예시 값
                .tlp_type       (5'b00001), // MEMRD 타입
                .tc             (3'b000),
                .attr           (3'b000),
                .ln             (1'b0),
                .th             (1'b0),
                .td             (1'b0),
                .ep             (1'b0),
                .at             (2'b00),
                .length         (10'd0),    // 페이로드 없음
                .requester_id   (16'h0001),
                .tag            (10'd0),
                .Last_DW_BE     (4'h0),
                .First_DW_BE    (4'h0),
                .address        (16'd0),
                .reserved       (2'b00)
            );
            pipe_data_o = {116'd0, seq_num, hdr};
            #1;
        endtask
    endclass

    // TLP Completion Packet 클래스
    class TLP_CPL_PKT;
        tlp_cpl_hdr_t hdr;
        task automatic send_packet(
            input  int unsigned seq_num,
            output [PIPE_DATA_WIDTH-1:0] pipe_data_o
        );
            hdr = gen_tlp_cpl_hdr(
                .fmt            (3'b010),
                .tlp_type       (5'b01010),
                .tc             (3'b000),
                .attr           (3'b000),
                .rsvd           (1'b0),
                .status         (3'b000),
                .bcm            (1'b0),
                .byte_count     (16'd0),
                .lower_addr     (7'd0)
            );
            pipe_data_o = {116'd0, seq_num, hdr};
            #1;
        endtask
    endclass

    // TLP Completion Data Packet 클래스
    class TLP_CPLD_PKT;
        tlp_cpl_hdr_t hdr;
        task automatic send_packet(
            input  int unsigned seq_num,
            output [PIPE_DATA_WIDTH-1:0] pipe_data_o
        );
            hdr = gen_tlp_cpld_hdr(
                .fmt            (3'b010),
                .tlp_type       (5'b01011),
                .tc             (3'b000),
                .attr           (3'b000),
                .rsvd           (1'b0),
                .status         (3'b000),
                .bcm            (1'b0),
                .byte_count     (16'd0),
                .lower_addr     (7'd0)
            );
            pipe_data_o = {116'd0, seq_num, hdr};
            #1;
        endtask
    endclass

    //-------------------------------------------------------------------------
    // DLLP Packet Classes
    //-------------------------------------------------------------------------

    // DLLP ACK Packet 클래스
    class DLLP_ACK_PKT;
        dllp_ACKNAK_packet_t hdr;
        task automatic send_packet(
            input  int unsigned seq_num,
            output [PIPE_DATA_WIDTH-1:0] pipe_data_o
        );
            // 단일 워드에 ACK 정보를 패킹 (하위 32비트에 seq와 hdr)
            pipe_data_o = { {(PIPE_DATA_WIDTH-32){1'b0}}, seq_num, hdr };
            #1;
        endtask
    endclass

    // DLLP NAK Packet 클래스
    class DLLP_NAK_PKT;
        dllp_ACKNAK_packet_t hdr;
        task automatic send_packet(
            input  int unsigned seq_num,
            output [PIPE_DATA_WIDTH-1:0] pipe_data_o
        );
            pipe_data_o = { {(PIPE_DATA_WIDTH-32){1'b0}}, seq_num, hdr };
            #1;
        endtask
    endclass

    // DLLP NOP Packet 클래스
    class DLLP_NOP_PKT;
        dllp_NOP_packet_t hdr;
        task automatic send_packet(
            input  int unsigned seq_num,
            output [PIPE_DATA_WIDTH-1:0] pipe_data_o
        );
            pipe_data_o = { {(PIPE_DATA_WIDTH-32){1'b0}}, seq_num, hdr };
            #1;
        endtask
    endclass

    // DLLP Flow Control Packet 클래스
    class DLLP_FC_PKT;
        dllp_FC_packet_t hdr;
        task automatic send_packet(
            input  int unsigned seq_num,
            output [PIPE_DATA_WIDTH-1:0] pipe_data_o
        );
            pipe_data_o = { {(PIPE_DATA_WIDTH-32){1'b0}}, seq_num, hdr };
            #1;
        endtask
    endclass

endpackage

`endif
