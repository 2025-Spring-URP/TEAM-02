// Copyright Sungkyunkwan University
// Author: YongSeong Lim <xidid430rr@gmail.com>
// Description:

// Follows PCIe gen5 specification 1.1

`ifndef ____PCIE_DLL_PKG_SVH__
`define ____PCIE_DLL_PKG_SVH__


package _PCIE_DLL_PKG;

    localparam NEXT_TRANSMIT_SEQ_BITS   = 12;                   // Set 000h in DL_Inactive state
    localparam ACKD_SEQ_BITS            = 12;                   // Set to FFFh in DL_Inactive state

    localparam REPLAY_NUM_BITS          = 2;                    //  Set to 00b in DL_Inactive state

    typedef struct packed {                                // ACK & NAK Packet      
        // Header 6B
        logic   [15:0]              crc16;

        logic   [7:0]               acknak_seq_num_l;
        logic   [3:0]               reserved_l;
        logic   [3:0]               acknak_seq_num_h;
        logic   [7:0]               reserved_h;
        logic   [7:0]               dllp_type;
    } dllp_ACKNAK_packet_t;

    typedef struct packed {                                 // DLCMSM Packet : InitFC, UpdateFC  
        // Header 6B
        logic   [15:0]              crc16;

        logic   [7:0]               dataFC_l;
        logic   [1:0]               hdrFC_l;
        logic   [1:0]               dataScale;
        logic   [3:0]               dataFC_h;
        logic   [1:0]               hdrScale;
        logic   [5:0]               hdrFC_h;
        logic   [7:0]               dllp_type;
    } dllp_FC_packet_t;

endpackage

`endif