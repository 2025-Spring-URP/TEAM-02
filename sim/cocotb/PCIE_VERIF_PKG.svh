// Copyright Sungkyunkwan University
// Author: YongSeong Lim <xidid430rr@gmail.com>
// Description:

// Follows PCIe gen5 specification 1.1

`ifndef __PCIE_VERIF_PKG_SVH__
`define __PCIE_VERIF_PKG_SVH__

package PCIE_VERIF_PKG;

    import PCIE_PKG::*;

    /*
    class Dummy_Adder_EX;                                       // Constraint Random Verification(CRV) 방법론
    // Define the inputs and output
    rand bit [3:0] A, B;
    rand bit [4:0] C;

    // Define the constraints
    constraint c_adder { 	A inside {[0:15]};                  // A의 랜덤 값이 0~15 의 값을 갖도록 제한
                            B inside {[0:15]};
                            C == A + B;                         // C == A+B로 제한한
                        }

    function void display();
        $display("A=0x%0h B=0x%0h C=0x%0h", A, B, C);
    endfunction
    endclass
    */

    // Make Random Generate
    class Random_Generate_Packet;



        /*
        function dllp_ACKNAK_packet_t rand_gen_dllp_ACK(
        );
        endfunction

        function dllp_ACKNAK_packet_t rand_gen_dllp_NAK(
        );
        endfunction

        function dllp_NOP_packet_t rand_gen_dllp_NOP(
        );
        endfunction
        */

    endclass

    // Make Random 1 bit Error
    class Error_Generate;


    endclass

    task send_tlp_memwr(
        input   tlp_memory_req_hdr_t    pkt
    ,   input   
    );
        $display("Send TLP: Seq=%0d", pkt.seq_num);
    endtask

    task send_tlp_memrr(
        input   tlp_memory_req_hdr_t    pkt
    ,   
    );
        $display("Send TLP: Seq=%0d", pkt.seq_num);
    endtask

    task send_tlp_cpld(
        input   tlp_completion_hdr_t    pkt
    ,   
    );
        $display("Send TLP: Seq=%0d", pkt.seq_num);
    endtask

    task send_tlp_cpl(
        input   tlp_completion_hdr_t    pkt
    ,   
    );
        $display("Send TLP: Seq=%0d", pkt.seq_num);
    endtask

    task recv_dllp(input dllp_packet_t dllp);
        case (dllp.dllp_type)
        'h00: begin // ACK
            ack_count++;
            $display("Receive ACK: Seq=%0d", dllp.seq_num);
            head = dllp.seq_num + 1; // ACK된 것까지 제거
        end
        'h10: begin // NAK
            nak_count++;
            $display("Receive NAK: Resending from Seq=%0d", dllp.seq_num);
            for (int i = dllp.seq_num; i < tail; i++) begin
            send_tlp(replay_buffer[i]); // Replay!
            end
        end
        endcase
    endtask

endpackage

`endif