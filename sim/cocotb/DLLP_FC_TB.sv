// Copyright Sungkyunkwan University
// Author: YongSeong Lim <xidid430rr@gmail.com>
// Description:

// Follows PCIe gen5 specification 1.1

`include "PCIE_PKG.svh"
`include "PCIE_VERIF_PKG.svh"

`define TIMEOUT_DELAY       100000000
`define RANDOM_SEED         12123344
`define BIT_ERROR_INTERVAL  

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

    logic    [PIPE_DATA_WIDTH-1:0]  	lane_d_RC2EP;       // Error Generate!
    logic    [PIPE_DATA_WIDTH-1:0]  	lane_d_EP2RC;       // Error Generate!

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

    tlp_memwr_hdr           tlp_hdr;
    
    typedef struct packed {
        reg     [7:0]       tlp_seq_num_l;
        reg                 fcrc;
        reg     [3:0]       tlp_seq_num_h;
        reg                 fp;
        reg     [10:4]      tlp_len_h;
        reg     [3:0]       tlp_len_l;
        reg     [3:0]       nonzeros;

    } STP_frameToken_TLP;

    // 32B = 8 x (4B)
    reg [31:0] d_ff [8];

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_dff_assign
            assign d_ff[i] = pipe_d_RC2EP[(i+1)*32-1 -: 32];
        end
    endgenerate

    // Decode Packet
    always_ff @(posedge clk) begin
        if(!preset_n) begin

        end
        else begin
            if(이번 32B가 헤더 패킷이 있는게 확인되면?) begin
                STP_frameToken      <= {d_ff[5][11:0], d_ff[4][31:12]};
                seq_num             <= d_ff[4][11:0];
                tlp_hdr             <= {d_ff[3], d_ff[2], d_ff[1], d_ff[0]};

                cnt                 <= cnt+1;                                   // Next is ~~~
            end
            
            if(cnt != 0) begin
                payload[]           <= ;
            end

            if(cnt == ? LCRC를 check할 시점일때) begin
                // Check LCRC
                LCRC                <= ;

                cnt <= 0;
            end
        end
    end

    always_ff @(posedge clk) begin
        
    end

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


    endtask 

	// Input TLP (automatically input MEMRd, MEMWR, )
    initial begin

		test_init();

		Random_Generate_Packet packet[0:30];
		packet[0] = new();
		packet[0].send_rand_gen_tlp_memwr(0, lane_d_EP2RC);  		// N clk 소요됨

        TLP_MEMWR_PKT           memwr_pkt[];
        TLP_CPLD_PKT            cpld_pkt[];
        TLP_CPL_PKT             cpl_pkt[];

        DLLP_FC_PKT             fc_pkt[];
        DLLP_ACK_PKT            ack_pkt[];
        DLLP_NAK_PKT            nak_pkt[];

        // -------------------------------------
		// Step 1) Flow Control (DLCMSM)- Test
        fork
            // Thread 1     : Check DLCSMSM - InitFC#
            // Description
            //      1) reset_n is set : IDLE --> InitFC1 --> InitFC2 --> UpdateFC
            //      2) 
            begin

            end

            // Thread 2     : (AXI)[Input TLP- memwr, memrd] --> DLL(RC)
            // Description
            //      1) If Retry Buffer is fulled, than stop
            //      2) Situation : ( ) --> DLL(RC) --> EP
            begin

            end

            // Thread 3     : Check Packet which is sended by Root Complex, and Make ACK, NAK
            // Description
            //      1) Check Packet Error (SEQ, LCRC)
            //      2) Decode Packet Type and count Credit --> (it will be send by UpdateFC)
            begin

            end

            // Thread 3     : (EndPoint)[Send TLP- memwr, cpld, cpl] --> Link(Randomly Error) --> DLL(RC)
            // Description
            //      1) If Credit is full, than can't send
            begin

            end
            
        join   // 끝날때 까지 대기

        
        // -------------------------------------
        // Step 2) Check Error Handling of ACK/NAK
        // Not Yet - 링크에서 Error를 만들고 에러 순서를 모니터?

        $finish;
    end

endmodule