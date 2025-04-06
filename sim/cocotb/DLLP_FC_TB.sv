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

    // inject random seed
    initial begin
        $srandom(`RANDOM_SEED);
    end


    //----------------------------------------------------------
    // Step 1) clock and reset generation
    //----------------------------------------------------------
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
        #1 pclk                 = ~pclk;  	// 1ns 마다 토글 --> 2ns 주기 (500Hhz)
    end

    // reset generation
    initial begin
        preset_n                = 1'b0;      // active at time 0

        repeat (3) @(posedge pclk);          // after 3 cycles,
        preset_n                = 1'b1;      // release the reset
    end

    // enable waveform dump
    initial begin
        $dumpvars(0, u_DUT);
        $dumpfile("dump.vcd");
    end


    //----------------------------------------------------------
    // Step 2) Connection between DUT and test modules
    //----------------------------------------------------------

	wire 	 [PIPE_DATA_WIDTH-1:0]		tlp_32B_w;

    logic    [PIPE_DATA_WIDTH-1:0]  	pipe_d_RC2EP;       // PIPE Interface 32B Data INOUT
    logic    [PIPE_DATA_WIDTH-1:0]  	pipe_d_EP2RC;       // logic - 4 state variable

    DUT_PCIE_DLLP PCIE_DLLP
	#(
	
	)
	(
		.sclk						(pclk)
	  ,	.sreset_n  					(preset_n)

	//	Data Link Layer Input
	  ,	.tlp_i						(tlp_32B_w)				// Total Size : 32B x N th  

	//	PCIE Fabric Link I/O
	  , .pipe_data_i  				(pipe_d_EP2RC)			// EndPoint    --> RootComplex
	  , .pipe_data_o				(pipe_d_RC2EP)			// RootComplex --> Endpoint
    );


    //----------------------------------------------------------
    // Step 3) Testbench starts
    //----------------------------------------------------------
    task test_init();
		
        @(posedge rst_n);                   			// wait for a release of the reset
        repeat (10) @(posedge clk);         			// wait another 10 cycles


        $display("---------------------------------------------------");
        $display("Flow Control Test");
        $display("---------------------------------------------------");

        $display("---------------------------------------------------");
        $display("Load data to memory");
        $display("---------------------------------------------------");


		// TLP(HDR + [Payload] + ECRC) is sent to DLL Layer (32B)
        for (int i=0; i<`SRC_REGION_SIZE; i=i+4) begin
            // send random data to DLL	(MemRd, MemWr, )
            
			// It should not be error
        end

		// PIPE IF send to RC (32B 500Mhz) - TLP & DLLP(FC, NOP)
		// It can be error! --> Make Error! : BER(Bit Error Rate) : 1600B 당 1bit Error를 만들어보자.
		// SEQ(12b) + HDR(16B) + MAX_PAYLOAD(128B) + ECRC(4B) + LCRC(4B) == 160B
		int unsigned rnd;
		for () begin

    		rnd = $urandom_range(0, 1279);  // 0~1279 중 하나

		end
    endtask 

	

	// Input TLP (automatically input MEMRd, MEMWR, )
    initial begin


		
		test_init();

		Random_Generate_Packet packet[0:30];
		packet[0] = new();
		packet[0].send_rand_gen_tlp_memwr(0, pipe_d_EP2RC);  		// N clk 소요됨


		// Step 1) 

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