// Copyright Sungkyunkwan University
// Author: YongSeong Lim <xidid430rr@gmail.com>
// Description:

// Follows PCIe gen5 specification 1.1

`include "PCIE_PKG.svh"
`include "PCIE_VERIF_PKG.svh"

`define TIMEOUT_DELAY   100000000
`define RANDOM_SEED     12123344

`timescale 1ns / 1ps

module DLLP_FC_TB();

    import PCIE_PKG::*;

    reg                     pclk;
    reg                     preset_n;

    // timeout
    initial begin
        #`TIMEOUT_DELAY $display("Timeout!");
        $finish;
    end

    // PIPE CLOCK Generate
    initial begin
        pclk                    = 1'b0;
    end
    always begin
        #1 pclk                 = ~pclk;  // 1ns 마다 토글 --> 2ns 주기 (500Hhz)
    end

    // reset generation
    initial begin
        preset_n                = 1'b0;      // active at time 0

        repeat (3) @(posedge pclk);          // after 3 cycles,
        preset_n                = 1'b1;      // release the reset
    end

    // inject random seed
    initial begin
        $srandom(`RANDOM_SEED);
    end

    // Instantiate DUT
    U_PCIE_DLLP PCIE_DLLP(

    );
    
    logic    [PIPE_DATA_WIDTH-1:0]  	pipe_d_i;       // PIPE Interface 32B Data INOUT
    logic    [PIPE_DATA_WIDTH-1:0]  	pipe_d_o;       // logic - 4 state variable

    // ------------------------------------------------------ GPT Coding ------------------------------

    initial begin
		tlp_packet_t 		pkt;
        dllp_packet_t 		ack, nak;

        wait (!rst);
        



        
        // TLP 전송
        for (int i = 0; i < 4; i++) begin
          pkt.seq_num = i;
          send_tlp(pkt);
        end

        #50;

        // DLLP 응답 (NAK → Replay 발생 확인)
        nak.dllp_type = 'h10;
        nak.seq_num = 1;
        recv_dllp(nak);

        #30;

        // DLLP 응답 (ACK → 버퍼 클리어 확인)
        ack.dllp_type = 'h00;
        ack.seq_num = 3;
        recv_dllp(ack);

        #50;

        $display("ACK: %0d, NAK: %0d", ack_count, nak_count);
        $finish;
    end

endmodule