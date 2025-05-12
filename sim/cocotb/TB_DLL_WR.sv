`timescale 1ps/1ps
`define VIVADO

import PCIE_PKG::*;

module TB_DLL_WR;

  // -------------------------------------------------------------------
  // Parameters
  // -------------------------------------------------------------------
  localparam int    PIPE_DATA_WIDTH = 256,
					RETRY_DEPTH_LG2 = 8;

  localparam time   CLK_PERIOD_PS  = 2; // 2ns


  localparam      	S_IDLE = 2'b00,
					S_HDR  = 2'b01,
					S_DATA = 2'b10;

  localparam  		FMT_WODATA_3DW        = 3'b000,
                    FMT_WDATA_3DW         = 3'b010,
                    FMT_WODATA_4DW        = 3'b001,
                    FMT_WDATA_4DW         = 3'b011;

  localparam  	    TYPE_MEM              = 5'b00000,
                    TYPE_MEM_RDLK         = 5'b00001,
                    TYPE_IO               = 5'b00010,
                    TYPE_CFG_0            = 5'b00100,
                    TYPE_CFG_1            = 5'b00101,
                    TYPE_COMPLETION       = 5'b01010,
                    TYPE_COMPLETION_LK    = 5'b01011,
                    TYPE_MSG              = 5'b10000,
                    TYPE_TCFG             = 5'b11011,
                    TYPE_ATOMIC_ADD       = 5'b11100,
                    TYPE_ATOMIC_SWAP      = 5'b11101,
                    TYPE_ATOMIC_CAS       = 5'b11110,
                    TYPE_LPRFX            = 5'b00000,
                    TYPE_EPRFX            = 5'b10000;

  // -------------------------------------------------------------------
  // DUT Signals
  // -------------------------------------------------------------------
  logic                           		sclk;
  logic                           		srst_n;

  logic   [PIPE_DATA_WIDTH-1:0]   		packetizer_data_i;
  logic   [1:0]                   		tl_d_en_i;
  logic	  [11:0]			      		next_tlp_seq;
  logic   [PIPE_DATA_WIDTH/8-1:0] 		packetizer_data_o[8];
  logic                           		packetizer_wren_o;
  logic   [7:0]					  		packetizer_stp_strb_o;
  logic							  		link_up;

  logic [RETRY_DEPTH_LG2-1:0]	  		retry_buffer_leftover_cnt_o;
  logic	[15:0]					  		acknak_seq_num_i;
  logic [1:0]							acknak_seq_en_i;
  logic [15:0]							as_o;							// Acked Seq Num
  logic 								rd_en_i;
  logic [PIPE_DATA_WIDTH/8-1:0]         retry_data_o[8];
  logic 								retry_data_en_o;
  // -------------------------------------------------------------------
  // DUT Instance
  // -------------------------------------------------------------------
    DLL_Packetizer #(
        .PIPE_DATA_WIDTH			(PIPE_DATA_WIDTH)
    ) u_packetizer (
        .sclk           			(sclk),
        .srst_n         			(srst_n),
        .data_i         			(packetizer_data_i),
        .tl_d_en_i      			(tl_d_en_i),
        .next_tlp_seq_o 			(next_tlp_seq),
        .data_o         			(packetizer_data_o),
        .wren_o         			(packetizer_wren_o),
        .stp_strb_o     			(packetizer_stp_strb_o),
        .link_up_i      			(link_up)
    );

    // -------------------------
    // DLL Retry Monitor Instance
    // -------------------------
    DLL_retry_monitor #(
        .PIPE_DATA_WIDTH			(PIPE_DATA_WIDTH),
        .RETRY_DEPTH_LG2			(RETRY_DEPTH_LG2)
    ) u_retry_monitor (
        .sclk                       (sclk),
        .srst_n                     (srst_n),
        .retry_buffer_leftover_cnt_o(retry_buffer_leftover_cnt_o),
        .data_i                     (packetizer_data_o),
        .data_en_i                  (packetizer_wren_o),
        .stp_strb_i                 (packetizer_stp_strb_o),
        .acknak_seq_num_i           (acknak_seq_num_i),
        .acknak_seq_en_i            (acknak_seq_en_i),
        .as_o                       (as_o),
        .rd_en_i                    (rd_en_i),
        .data_o                     (retry_data_o),
        .data_en_o                  (retry_data_en_o)
    );
  // -------------------------------------------------------------------
  // Clock Generation
  // -------------------------------------------------------------------
	initial sclk = 0;
	always #(CLK_PERIOD_PS/2) sclk = ~sclk;

  // -------------------------------------------------------------------
  // Tasks
  // -------------------------------------------------------------------
    logic [15:0]                  		    seq_num;
	integer									tmp;
    tlp_memory_req_hdr_t					tlp_memwr_hdr;
	tlp_memory_req_hdr_t					tlp_memrd_hdr;
	tlp_cpl_hdr_t							tlp_cpl_hdr;
	tlp_cpl_hdr_t							tlp_cpld_hdr;

	task send_memwr(input logic [9:0] payload_len, output logic [31:0] crc_correct_data);

		$display("                                                                                                                       <---- [T=%4t ns]|     Send MEM Write Reqest! | SEQ_NUM : %3d" ,$time, seq_num);
		seq_num 							= seq_num + 1;

		tl_d_en_i           				= S_HDR;
		tlp_memwr_hdr = gen_tlp_memxr_hdr(
							FMT_WDATA_4DW,            	// fmt
							5'b00000,          			// tlp_type
							3'b000,            			// tc
							3'b000,            			// attr
							1'b0,              			// ln
							1'b0,              			// th
							1'b0,              			// td
							1'b0,              			// ep
							2'b00,             			// at
							payload_len,             	// length
							16'h0000,          			// requester_id
							'd0,             			// tag
							4'b0000,           			// Last_DW_BE
							4'b0000,           			// First_DW_BE
							{60'h2222_2222_2222_222, 2'b00},
							2'b00              			// reserved
						);

		tmp	= 'd1;
		packetizer_data_i[0 +: 128]              	    = tlp_memwr_hdr;		// Send HDR
		packetizer_data_i[128 +: 128]					= 'd0;
		#(CLK_PERIOD_PS);
		tl_d_en_i           				= S_DATA;
		for (int i = 0; i < payload_len / 8 + ((payload_len % 8 == 0)? 0 : 1); i++) begin						// Send DATA
			for (int j = 0; j < 8; j++) begin
				if(i == payload_len / 8) begin
					if( j < payload_len % 8) begin
						packetizer_data_i[32*j +: 32] 		= tmp;
						tmp = tmp + 'd1;
					end
					else begin
						packetizer_data_i[32*j +: 32] 		= 'd0;
					end
				end
				else begin
					packetizer_data_i[32*j +: 32] 		= tmp;
					tmp = tmp + 'd1;
				end
			end
			#(CLK_PERIOD_PS);
		end

		// CRC Calculator
	endtask

	task send_memrd(output logic [31:0] crc_correct_data);
		$display("                                                                                                                       <---- [T=%4t ns]|     Send MEM Read Reqest! | SEQ_NUM : %3d" ,$time, seq_num);
		seq_num 							= seq_num + 1;

		tl_d_en_i           				= S_HDR;
		tlp_memrd_hdr = gen_tlp_memxr_hdr(
							FMT_WODATA_4DW,            	// fmt
							5'b00000,          			// tlp_type
							3'b000,            			// tc
							3'b000,            			// attr
							1'b0,              			// ln
							1'b0,              			// th
							1'b0,              			// td
							1'b0,              			// ep
							2'b00,             			// at
							'd0,             			// length
							16'h0000,          			// requester_id
							'd0,             			// tag
							4'b0000,           			// Last_DW_BE
							4'b0000,           			// First_DW_BE
							{60'h1111_1111_1111_111, 2'b00}, 	// address
							2'b00              			// reserved
						);
		packetizer_data_i[0 +: 128]              	    = tlp_memrd_hdr;		// Send HDR
		packetizer_data_i[128 +: 128]					= 'd0;
		// CRC 계산

		#(CLK_PERIOD_PS);
	endtask
	
	task send_cpl(output logic [31:0] crc_correct_data);
		$display("                                                                                                                       <---- [T=%4t ns]|     Send CPL Reqest! | SEQ_NUM : %3d" ,$time, seq_num);
		seq_num 							= seq_num + 1;

		tl_d_en_i           				= S_HDR;
		tlp_cpl_hdr 	= gen_tlp_cplx_hdr(
							FMT_WODATA_3DW,           // fmt
							TYPE_COMPLETION,         // tlp_type = Completion (ex: CPL)
							3'b000,           // tc
							1'b0,             // ln
							1'b0,             // th
							1'b0,             // td
							1'b0,             // ep
							3'b000,           // attr
							2'b00,			  // at
							10'd0,            // length = 1DW
							16'h0000,         // completer_id (device BDF)
							3'b000,           // cpl_status = Successful
							1'b0,             // bcm
							12'd0,            // byte_cnt = 4 bytes (1DW)
							16'h0000,         // requester_id
							10'd0,            // tag
							7'd0,             // lower_addr (for byte offset)
							1'd0
						);
		packetizer_data_i[0 +: 96]              	    = tlp_cpl_hdr;		// Send HDR
		packetizer_data_i[96 +: 160]					= 'd0;
		#(CLK_PERIOD_PS);
	endtask

	task send_cpld(input logic [9:0] payload_len, output logic [31:0] crc_correct_data);
		$display("                                                                                                                       <---- [T=%4t ns]|     Send CPLD Reqest! | SEQ_NUM : %3d" ,$time, seq_num);
		seq_num 							= seq_num + 1;

		tl_d_en_i           				= S_HDR;
		tlp_cpld_hdr 	= gen_tlp_cplx_hdr(
							FMT_WDATA_3DW,    // fmt
							TYPE_COMPLETION,  // tlp_type = Completion (ex: CPL)
							3'b000,           // tc
							1'b0,             // ln
							1'b0,             // th
							1'b0,             // td
							1'b0,             // ep
							3'b000,           // attr
							2'b00,			  // at
							payload_len,      // length = 1DW
							16'h0000,         // completer_id (device BDF)
							3'b000,           // cpl_status = Successful
							1'b0,             // bcm
							12'd0,            // byte_cnt = 4 bytes (1DW)
							16'h0000,         // requester_id
							10'd0,            // tag
							7'd0,             // lower_addr (for byte offset)
							1'd0
						);
		packetizer_data_i[0 +: 96]             	    = tlp_cpld_hdr;		// Send HDR
		packetizer_data_i[96 +: 160]					= 'd0;

		#(CLK_PERIOD_PS);
		tmp	= 'd1;
		tl_d_en_i           				= S_DATA;
		for (int i = 0; i < payload_len / 8 + ((payload_len % 8 == 0)? 0 : 1); i++) begin						// Send DATA
			for (int j = 0; j < 8; j++) begin
				if(i == payload_len / 8) begin
					if( j < payload_len % 8) begin
						packetizer_data_i[32*j +: 32] 		= tmp;
						tmp = tmp + 'd1;
					end
					else begin
						packetizer_data_i[32*j +: 32] 		= 'd0;
					end
				end
				else begin
					packetizer_data_i[32*j +: 32] 		= tmp;
					tmp = tmp + 'd1;
				end
			end
			#(CLK_PERIOD_PS);
		end

	endtask

	task idle_cycle();
		tl_d_en_i          			  = S_IDLE;
		packetizer_data_i             = '0;
		#(CLK_PERIOD_PS);
	endtask

    function automatic logic [31:0] gen_crc32(
        input logic [(PIPE_DATA_WIDTH*8)-1:0]   data,
        input int                               byte_len
    );
        int total_bits      					= byte_len * 8;
        int start_idx       					= (PIPE_DATA_WIDTH * 8) - 1;                 // MSB부터 시작
        int end_idx         					= (PIPE_DATA_WIDTH * 8) - total_bits;        // 유효비트 끝 지점 (inclusive)

        logic [31:0] crc = 32'hFFFF_FFFF;

        for (int i = start_idx; i >= end_idx; i--) begin
            logic bit_in = data[i] ^ crc[31];
            crc = (crc << 1) ^ (bit_in ? 32'h04C11DB7 : 32'h0);
        end

        return ~crc;
    endfunction


	integer correct_LCRC[100];
	task test_case(input logic [9:0] payload_len);
		idle_cycle();
		send_memrd(				correct_LCRC[seq_num - 1]);
		send_memwr(payload_len, correct_LCRC[seq_num - 1]);
		send_cpl(				correct_LCRC[seq_num - 1]);
		send_cpld(payload_len,	correct_LCRC[seq_num - 1]);
		send_memrd(				correct_LCRC[seq_num - 1]);
		send_cpl(				correct_LCRC[seq_num - 1]);
		send_cpld(payload_len,	correct_LCRC[seq_num - 1]);
		send_memwr(payload_len,	correct_LCRC[seq_num - 1]);
		idle_cycle();
		idle_cycle();
		idle_cycle();
		send_memrd(				correct_LCRC[seq_num - 1]);
		idle_cycle();
		send_cpl(				correct_LCRC[seq_num - 1]);
		idle_cycle();
		send_cpld(payload_len,	correct_LCRC[seq_num - 1]);
		idle_cycle();
		send_memwr(payload_len,	correct_LCRC[seq_num - 1]);
	endtask


   // -------------------------------------------------------------------
   // Output Monitor
   // -------------------------------------------------------------------
	logic [1:0]			tl_d_en_d, tl_d_en_2d;
	always_ff @(posedge sclk) begin
		tl_d_en_d 		<= tl_d_en_i;
		tl_d_en_2d		<= tl_d_en_d;
	end
	
    function string decode_tl_d_en(input logic [1:0] tl_d_en);
        case (tl_d_en)
            2'b00: decode_tl_d_en = "IDLE";
            2'b01: decode_tl_d_en = "HDR";
            2'b10: decode_tl_d_en = "DATA";
            default: decode_tl_d_en = "???";
        endcase
    endfunction


    function string decode_fmt(input logic [2:0] fmt);
        case (fmt)
            3'b000: decode_fmt = "3DW_WO_DATA";
            3'b010: decode_fmt = "3DW_W_DATA";
            3'b001: decode_fmt = "4DW_WO_DATA";
            3'b011: decode_fmt = "4DW_W_DATA";
			default: decode_fmt	= "???????";
        endcase
    endfunction

	logic 			test_start;
	always_ff @(posedge sclk) begin
		if(test_start) begin
			$display("============================================================================================================================================");
			$write("[T=%4t ns]| tl_d_en_i  : %5s | fmt  : %12s | dw_size    : %5d       | data_i  : ", $time, decode_tl_d_en(tl_d_en_i), decode_fmt(u_packetizer.fmt), u_packetizer.dw_size);
			for (int i = 7; i >= 0; i--) begin
				$write("%h ", packetizer_data_i[i*32 +: 32]);  // 32비트씩 슬라이싱
			end
			$write("|\n");
			$write  ("           | tl_d_en_d  : %5s | fmt_d: %12s | dw_size_d  : %5d       | data_d  : ", decode_tl_d_en(tl_d_en_d), decode_fmt(u_packetizer.fmt_d), u_packetizer.dw_size_d);
			for (int i = 0; i < 8; i++) begin
				$write("%h ", u_packetizer.data_d[7-i]);
			end
			$write("|\n");
			$write ("           | tl_d_en_2d : %5s | outstanding_cnt: %2d | s2d_ptr: %1d | Reserved : %b | sort_2d : ", decode_tl_d_en(tl_d_en_2d), u_packetizer.outstanding_payload_cnt, u_packetizer.s2d_ptr, u_packetizer.reserved_2d);
			for (int i = 0; i < 8; i++) begin
				$write("%h ", u_packetizer.sort_2d[7-i]);
			end
			$write("|\n");
			$display("------------------------------------------------------------------------------------------------------------------------------------------|");
			$display(" NEXT_TLP_SEQ_NUM | WE |    STRB    |                                         PK_DATA_O                                                   |");

			$write(" %10d       |%3d | %10b |      ", next_tlp_seq, packetizer_wren_o, packetizer_stp_strb_o);
			for (int i = 0; i < 8; i++) begin
				$write("%h ", packetizer_data_o[7-i]);
			end
			$write("\n");
			$display("==========================================================================================================================================");
		end
	end
    /*
	int seq_cnt = 0;
	always_ff @(posedge sclk) begin
		if (lcrc_en) begin
			// DUT에서 생성된 LCRC와 TB에서 생성된 LCRC를 비교
			if (dut.lcrc != right_LCRC[seq_cnt]) begin
				$fatal("[T=%0t ns] LCRC mismatch! seq_cnt=%0d | DUT LCRC: %h, TB LCRC: %h", 
						$time, seq_cnt, dut.lcrc, right_LCRC[seq_cnt]);
			end else begin
				$display("[T=%0t ns] LCRC match! seq_cnt=%0d | DUT LCRC: %h, TB LCRC: %h", 
						$time, seq_cnt, dut.lcrc, right_LCRC[seq_cnt]);
			end
			seq_cnt += 1;
		end
	end
	*/

  // -------------------------------------------------------------------
  // Initial Block (Based on T0~T6 Timeline)
  // -------------------------------------------------------------------

	
	initial begin
		// Reset
		$display("-------------------------------------------------------------------------------------------------------------------|");
		$display("");
		$display("");
		$display("[T=%4t ns]|     Reset Test!", $time);
		$display("");
		srst_n   			= 0;
		packetizer_data_i   = '0;
		tl_d_en_i 			= 2'b00;
		test_start			= 'd1;

		repeat (5) @(posedge sclk);			// After 5 CLK Cycle

		srst_n   	= 1;
		seq_num  	= 'd0;
		#(CLK_PERIOD_PS/2);
		repeat (10) idle_cycle();
		// Timeline
		test_start	= 'd1;
		$display("-------------------------------------------------------------------------------------------------------------------|");
		$display("");
		$display("");
		$display("                                                                                                                       <---- [T=%4t ns]|     Test Start!", $time);
		$display("");
		// T0: MEMRD HDR
		for(int i=1; i<16; i++) begin
			test_case(i);
		end
		// T7~ Wait for processing
		repeat (20) idle_cycle();

		$finish;
	end

endmodule
