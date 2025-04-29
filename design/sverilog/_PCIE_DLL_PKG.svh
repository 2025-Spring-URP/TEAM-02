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


    // synopsys translation_off
    // ----------------------------------------------------------------------------------------------------------------------------------------------------------------
    //                                                                  For Verification
    // ----------------------------------------------------------------------------------------------------------------------------------------------------------------

    // Flow Control Packet Header
    /* ---------------------------------------
    *    DLLP Type Encodings | pg 222
    *    -------------------------------------
    *    0x00           |  ACK
    *    0x01           |  MRInit
    *    0x02           |  Data_Link_Feature
    *    0x10           |  NAK
    *    0x20           |  PM_Enter L1
    *    0x21           |  PM_Enter_L23
    *    0x23           |  PM_Active_State_Requset_L1
    *    0x24           |  PM_Request_Ack
    *    0x30           |  Vendor-specific
    *    0x31           |  NOP
    *    ---------------+------------------------
    *          vvv      |  Virtual Channel ID
    *    0100_0vvv      |  InitFC-P (v[2:0] specifies Virtual Channel)
    *    0110_0vvv      |  InitFC1-NP
    *    0110_0vvv      |  InitFC1-Cpl
    *    0111_0vvv      |  MRInitFC1
    *    1100_0vvv      |  InitFC2-P
    *    1101_0vvv      |  InitFC2-NP
    *    1110_0vvv      |  InitFC2-Cpl
    *    1111_0vvv      |  MRInitFC2
    *    1000_0vvv      |  UpdateFC-P
    *    1001_0vvv      |  UpdateFC-NP
    *    1010_0vvv      |  UpdateFC-Cpl
    *    1011_0vvv      |  MRUpdateFC
    *    All others -   |  Reserved
    *-------------------------------------------*/

    function automatic dllp_ACKNAK_packet_t gen_dllp_ACK(
        input   logic   [11:0]      seq_num,
        input   logic   [15:0]      crc16
    );
        dllp_ACKNAK_packet_t                dllp_ack_packet;
        dllp_ack_packet.dllp_type                       = 'h00;         // ACK : 0000_0000
        dllp_ack_packet.reserved_h                      = 'd0;          //Reserved
        dllp_ack_packet.reserved_l                      = 'd0;          //Reserved
        dllp_ack_packet.acknak_seq_num_h                = seq_num[11:8];
        dllp_ack_packet.acknak_seq_num_l                = seq_num[7:0];
        dllp_ack_packet.crc16                           = crc16;

        return dllp_ack_packet;
    endfunction

    function automatic dllp_ACKNAK_packet_t gen_dllp_NAK(
        input   logic   [11:0]      seq_num,
        input   logic   [15:0]      crc16
    );
        dllp_ACKNAK_packet_t       dllp_nak_packet;
        dllp_nak_packet.dllp_type                       = 'h10;         // NAK : 0001_0000
        dllp_nak_packet.reserved_h                      = 'd0;          //Reserved
        dllp_nak_packet.reserved_l                      = 'd0;          //Reserved
        dllp_nak_packet.acknak_seq_num_h                = seq_num[11:8];
        dllp_nak_packet.acknak_seq_num_l                = seq_num[7:0];
        dllp_nak_packet.crc16                           = crc16;

        return dllp_nak_packet;
    endfunction

    function automatic dllp_NOP_packet_t gen_dllp_NOP(
        input   logic   [23:0]      arbitrary_value,    // @ ?
        input   logic   [15:0]      crc16
    );
        dllp_NOP_packet_t       dllp_nop_packet;
        dllp_nop_packet.dllp_type                       = 'h31;         // NOP : 0011_0001
        dllp_nop_packet.arbitrary_value                 = arbitrary_value;
        dllp_nop_packet.crc16                           = crc16;
    endfunction

    function automatic dllp_FC_packet_t gen_dllp_FC_packet(
        input   logic   [3:0]       ptype,              // P, NP, Cpl
        input   logic   [2:0]       vcid,
        input   logic   [1:0]       hdrScale,
        input   logic   [7:0]       hdrFC,
        input   logic   [1:0]       dataScale,
        input   logic   [11:0]      dataFC,
        input   logic   [15:0]      crc16
    );
        dllp_FC_packet_t           dllp_FC_packet;
        dllp_FC_packet.dllp_type[7:4]              = ptype;
        dllp_FC_packet.dllp_type[3]                = 0;
        dllp_FC_packet.dllp_type[2:0]              = vcid;
        dllp_FC_packet.hdrScale                    = hdrScale;
        dllp_FC_packet.hdrFC_h                     = hdrFC[7:2];
        dllp_FC_packet.hdrFC_l                     = hdrFC[1:0];
        dllp_FC_packet.dataScale                   = dataScale;
        dllp_FC_packet.dataFC_h                    = dataFC[11:8];
        dllp_FC_packet.dataFC_l                    = dataFC[7:0];
        dllp_FC_packet.crc16                       = crc16;

        return dllp_FC_packet;
    endfunction

    function automatic dllp_FC_packet_t insert_crc16(
        input dllp_FC_packet_t raw_packet,
        input logic [15:0]      crc
    );
        dllp_FC_packet_t final_packet = raw_packet;
        final_packet.crc16 = crc;

        return final_packet;
    endfunction
    // ----------------------------------------------------------------------------------------------------
    //                    Flow Control Rule                                  | pg 
    // -----------------------------------------------------------------------------------------------------
    /* Scaled Flow Control Rules(FCPE - Flow Control Protocol Error) (not yet) (pg 220)
    *  - If Scaled Flow Control is unsupported, then Header Credit < 127(max), Payload Credit < 2047(max)
    *  - If Scaled Flow Control is supported, then Header Credit < 
    */
    if (Scale_Factor ==  2'b0x) begin                  
        function automatic (
        
        );
        hdr             <= 127
        payload         <= 2047
            
        endfunction
    end else if (Scale_Factor == 2'b11) begin
        function automatic (
        
        );
        hdr             <= 509
        payload         <= 8188

        endfunction
    end else begin                     
        function automatic (
        
        );
        hdr             <= 2032
        payload         <= 32752

        endfunction
    end


    // ----------------------------------------------------------------------------------------------------
    //                    LCRC and Sequence Number Rules (TLP Transmitter)   | pg 228
    // -----------------------------------------------------------------------------------------------------



    // synopsys translate_on

endpackage

`endif