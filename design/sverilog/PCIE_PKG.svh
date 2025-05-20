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

    typedef struct packed {                                 // pg 154
        logic                reserved;         // [95]          MSB
        logic   [6:0]        lower_addr;       // [94:88]
        logic   [7:0]        tag;              // [87:80]
        logic   [15:0]       requester_id;     // [79:64]

        logic   [7:0]        byte_count_l;     // [63:56]
        logic   [2:0]        cpl_status;       // [55:53]
        logic                bcm;              // [52]
        logic   [3:0]        byte_count_h;     // [51:48]
        logic   [15:0]       completer_id;     // [47:32]

        logic   [7:0]        length_l;         // [31:24]
        logic                td;               // [23]
        logic                ep;               // [22]
        logic   [1:0]        attr_l;           // [21:20]
        logic   [1:0]        at;               // [19:18]
        logic   [1:0]        length_h;         // [17:16]
        logic                tg_h;             // [15]
        logic   [2:0]        tc;               // [14:12]
        logic                tg_m;             // [11]
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

    // fmt |             Cpl status
    // ----+------------------------------------------
    // 000 | SC  (Success Completion)
    // 001 | UR  (Unsupported Request)
    // 010 | CRS (Configuration Request Retry Status)
    // 100 | CA  (Completion Abort)


endpackage

`endif
