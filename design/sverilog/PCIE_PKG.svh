// Copyright Sungkyunkwan University
// Author: Sanghyun Park <psh2018314072@gmail.com>
// Description:

// Follows PCIe gen5 specification 1.1

`ifndef __PCIE_PKG_SVH__
`define __PCIE_PKG_SVH__

package PCIE_PKG;

    //----------------------------------------------------------
    // PCIe constants
    //----------------------------------------------------------
    localparam  ADDR_WIDTH                  = 64;
    localparam  LANE_COUNT                  = 4;
    localparam  PIPE_DATA_WIDTH             = 256; //32B
    localparam  MAX_PAYLOAD_SIZE            = 128;
    localparam  MAX_READ_REQ_SIZE           = 512;
    localparam  READ_COMPLETION_BOUNDARY    = 64;


    typedef struct packed {                               // Byte 단위로는 LSB부터 전송, Byte내의 Bit단위에서는 MSB부터 전송
        logic   [5:0]    addr_l;        // [127:122]        MSB
        logic   [1:0]    reserved;      // [121:120]
        logic   [23:0]   addr_m;        // [119:96]
        logic   [31:0]   addr_h;        // [95:64]
        logic   [7:0]    byte_enable;   // [63:56]
        logic   [7:0]    tag;           // [55:48]
        logic   [15:0]   requester_id;  // [47:32]
        
        logic   [7:0]    length_l;      // [31:24]
        logic            td;            // [23]
        logic            ep;            // [22]
        logic   [1:0]    attr_l;        // [21:20]
        logic   [1:0]    at;            // [19:18]
        logic   [1:0]    length_h;      // [17:16]
        logic            tg_h;          // [15]
        logic   [2:0]    tc;            // [14:12]
        logic            tg_m;          // [11]
        logic            attr_h;        // [10]
        logic            ln;            // [9]
        logic            th;            // [8]
        logic   [2:0]    fmt;           // [7:5]
        logic   [4:0]    tlp_type;      // [4:0]            LSB
    } tlp_memory_req_hdr_t;


    typedef struct packed {
        logic [3:0]   fcrc;            // [31:28]
        logic [7:0]   tlp_seq_num_h;   // [27:24]
        logic [3:0]   tlp_seq_num_l;   // [23:16]
        logic         fp;              // [15]
        logic [6:0]   tlp_len_h;       // [14:8]
        logic [3:0]   tlp_len_l;       // [7:4]
        logic [3:0]   ones;            // [3:0]
    } stp_t;





    typedef struct packed {                                 // pg 154
        logic                reserved;         // [95]          MSB
        logic   [6:0]        lower_addr;       // [94:88]
        logic   [7:0]        tag_l;            // [87:80]
        logic   [15:0]       requester_id;     // [79:64]

        logic   [7:0]        byte_cnt_l;       // [63:56]
        logic   [2:0]        cpl_status;       // [55:53]
        logic                bcm;              // [52]
        logic   [3:0]        byte_cnt_h;       // [51:48]
        logic   [15:0]       completer_id;     // [47:32]

        logic   [7:0]        length_l;         // [31:24]
        logic                td;               // [23]
        logic                ep;               // [22]
        logic   [1:0]        attr_l;           // [21:20]
        logic   [1:0]        at;               // [19:18]
        logic   [1:0]        length_h;         // [17:16]
        logic                tag_h;            // [15]
        logic   [2:0]        tc;               // [14:12]
        logic                tag_m;            // [11]
        logic                attr_h;           // [10]
        logic                ln;               // [9]
        logic                th;               // [8]
        logic   [2:0]        fmt;              // [7:5]
        logic   [4:0]        tlp_type;         // [4:0]         LSB
    } tlp_cpl_hdr_t;


    typedef struct packed {                                // ACK & NAK Packet      
        // Header 6B
        logic   [15:0]              zeros;
        logic   [15:0]              crc16;

        logic   [7:0]               acknak_seq_num_l;
        logic   [3:0]               reserved_l;
        logic   [3:0]               acknak_seq_num_h;
        logic   [7:0]               reserved_h;
        logic   [7:0]               dllp_type;
    } dllp_ACKNAK_packet_t;

    typedef struct packed {                                 // NOP Packet                     
        // Header 6B
        logic   [15:0]              zeros;
        logic   [15:0]              crc16;

        logic   [23:0]              arbitrary_value;
        logic   [7:0]               dllp_type;
    } dllp_NOP_packet_t;

    typedef struct packed {                                 // DLCMSM Packet : InitFC, UpdateFC  
        // Header 6B
        logic   [15:0]              zeros;
        logic   [15:0]              crc16;

        logic   [7:0]               dataFC_l;
        logic   [1:0]               hdrFC_l;
        logic   [1:0]               dataScale;
        logic   [3:0]               dataFC_h;
        logic   [1:0]               hdrScale;
        logic   [5:0]               hdrFC_h;
        logic   [7:0]               dllp_type;
    } dllp_FC_packet_t;

        // Generate TLP Memory Write Request Header
    function automatic tlp_memory_req_hdr_t gen_tlp_memxr_hdr(           //automatic을 통해 독립적으로 변수를 생성하여, 여러 프로세서 생성 시 독립적 동작 가능.
        input   logic   [2:0]       fmt,            // Format of TLP
        input   logic   [4:0]       tlp_type,       // Type of TLP
        input   logic   [2:0]       tc,             // Traffic Class            : for QoS
        input   logic   [2:0]       attr,           // Attribute                : ID-based Ordering | Relaxed Ordering | No Snoop 
        input   logic               ln,             // Lightweight Notification : LN Protocol Usable
        input   logic               th,             // TLP Processing Hint      : PH Heeader exist
        input   logic               td,             // TLP Digest               : TLP Digest Field Exist (ex CRC)
        input   logic               ep,             // Error Poisoned           : TLP packet has Error Data
        input   logic   [1:0]       at,             // Address Type             : Check Address will be translated by ATC(Address Translation Cache) or Physical or TA
        input   logic   [9:0]       length,         // the Number Of DW, 4bytes
        input   logic   [15:0]      requester_id,   // the Owner of This TLP packet, ex) BDF
        input   logic   [9:0]       tag,            // Order Identification of this Transaction, For Multi Outstanding Transaction
        input   logic   [3:0]       Last_DW_BE,     // Valid Byte Enable of Last 4 bytes, For Align
        input   logic   [3:0]       First_DW_BE,    // Valid Byte Enable of First 4 bytes, For Align
        input   logic   [63:2]      address,        //
        input   logic   [1:0]       reserved        // Processing Hint          : Specify using TPH(Steering Tag), For Improve Cache Locality
    );
        tlp_memory_req_hdr_t        tlp_memwr_hdr;  //구조체 생성자

        tlp_memwr_hdr.fmt           = fmt;
        tlp_memwr_hdr.tlp_type      = tlp_type;
        tlp_memwr_hdr.tc            = tc;
        tlp_memwr_hdr.ln            = ln;
        tlp_memwr_hdr.th            = th;
        tlp_memwr_hdr.td            = td;
        tlp_memwr_hdr.ep            = ep;
        tlp_memwr_hdr.attr_h        = attr[2];
        tlp_memwr_hdr.attr_l        = attr[1:0];
        tlp_memwr_hdr.at            = at;
        tlp_memwr_hdr.length_h      = length[9:8];
        tlp_memwr_hdr.length_l      = length[7:0];
        tlp_memwr_hdr.requester_id  = requester_id;
        tlp_memwr_hdr.tg_h          = tag[9];
        tlp_memwr_hdr.tg_m          = tag[8];
        tlp_memwr_hdr.tag           = tag[7:0];
        tlp_memwr_hdr.byte_enable   = {Last_DW_BE[3:0], First_DW_BE[3:0]};
        tlp_memwr_hdr.addr_h        = {address[39:32], address[47:40], address[55:48], address[63:56]};
        tlp_memwr_hdr.addr_m        = {address[15: 8], address[23:16], address[31:24]};
        tlp_memwr_hdr.addr_l        = {address[ 7: 2]};
        tlp_memwr_hdr.reserved      = reserved;

        return tlp_memwr_hdr;
    endfunction

    // fmt |             Cpl status
    // ----+------------------------------------------
    // 000 | SC  (Success Completion)
    // 001 | UR  (Unsupported Request)
    // 010 | CRS (Configuration Request Retry Status)
    // 100 | CA  (Completion Abort)

    function automatic  tlp_cpl_hdr_t gen_tlp_cplx_hdr(
        input   logic   [2:0]       fmt,
        input   logic   [4:0]       tlp_type,
        input   logic   [2:0]       tc,
        input   logic               ln,
        input   logic               th,
        input   logic               td,
        input   logic               ep,
        input   logic   [2:0]       attr,
        input   logic   [1:0]       at,
        input   logic   [9:0]       length,
        input   logic   [15:0]      completer_id,
        input   logic   [2:0]       cpl_status,
        input   logic               bcm,
        input   logic   [11:0]      byte_cnt,
        input   logic   [15:0]      requester_id,
        input   logic   [9:0]       tag,
        input   logic   [6:0]       lower_addr,
        input   logic               reserved    
    );
        tlp_cpl_hdr_t               tlp_cpl_hdr;

        tlp_cpl_hdr.fmt             = fmt;
        tlp_cpl_hdr.tlp_type        = tlp_type;
        tlp_cpl_hdr.tc              = tc;
        tlp_cpl_hdr.ln              = ln;
        tlp_cpl_hdr.th              = th;
        tlp_cpl_hdr.td              = td;
        tlp_cpl_hdr.ep              = ep;
        tlp_cpl_hdr.attr_h          = attr[2];
        tlp_cpl_hdr.attr_l          = attr[1:0];
        tlp_cpl_hdr.at              = at;
        tlp_cpl_hdr.length_h        = length[9:8];
        tlp_cpl_hdr.length_l        = length[7:0];
        tlp_cpl_hdr.completer_id    = completer_id;
        tlp_cpl_hdr.cpl_status      = cpl_status;
        tlp_cpl_hdr.bcm             = bcm;
        tlp_cpl_hdr.byte_cnt_h      = byte_cnt[11:8];
        tlp_cpl_hdr.byte_cnt_l      = byte_cnt[7:0];
        tlp_cpl_hdr.requester_id    = requester_id;
        tlp_cpl_hdr.tag_h           = tag[9];
        tlp_cpl_hdr.tag_m           = tag[8];
        tlp_cpl_hdr.tag_l           = tag[7:0];
        tlp_cpl_hdr.lower_addr      = lower_addr;
        tlp_cpl_hdr.reserved        = reserved;

        return      tlp_cpl_hdr;
    endfunction


endpackage

`endif
