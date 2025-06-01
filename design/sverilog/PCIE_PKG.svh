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
        tlp_cpl_hdr.byte_count_h    = byte_cnt[11:8];
        tlp_cpl_hdr.byte_count_l    = byte_cnt[7:0];
        tlp_cpl_hdr.requester_id    = requester_id;
        tlp_cpl_hdr.tg_h            = tag[9];
        tlp_cpl_hdr.tg_m            = tag[8];
        tlp_cpl_hdr.tag_l           = tag[7:0];
        tlp_cpl_hdr.lower_addr      = lower_addr;
        tlp_cpl_hdr.reserved        = reserved;

        return      tlp_cpl_hdr;
    endfunction

    typedef struct packed {
        logic   [191:0]     padding;
        logic   [15:0]      crc;
        logic   [7:0]       data_fc_l;  
        logic   [1:0]       hdr_fc_l;
        logic   [1:0]       data_scale;
        logic   [3:0]       data_fc_h;
        logic   [1:0]       hdr_scale;
        logic   [5:0]       hdr_fc_h;
        logic   [7:0]       dllptype;
        logic   [15:0]      frametoken;
    } dllp_fc_init_t;

    function automatic dllp_fc_init_t get_dllp_fc_init(
        input   logic   [7:0]   dllptype
    );
        dllp_fc_init_t      dllp_fc_init;
        
        dllp_fc_init.frametoken   = 'hACF0;
        dllp_fc_init.dllptype     = dllptype;
        dllp_fc_init.hdr_scale    = 'b01;
        dllp_fc_init.hdr_fc_h     = 'b1000_00;
        dllp_fc_init.hdr_fc_l     = 'b00;
        dllp_fc_init.data_scale   = 'b01;
        dllp_fc_init.data_fc_h    = 'b0000;
        dllp_fc_init.data_fc_l    = 'b1000_0000;
        dllp_fc_init.crc          = {16{1'b0}};
        dllp_fc_init.padding      = {192{1'b0}};  // 192비트 맞춤

        return dllp_fc_init;
    endfunction

    typedef struct packed {
        logic   [63:0]     padding; //8B Padding

        //LCRC, 4B
        logic   [31:0]      lcrc;

        // Header 16B
        logic   [5:0]       addr_l;
        logic   [1:0]       reserved;
        logic   [23:0]      addr_m;
        logic   [31:0]      addr_h;
        logic   [7:0]       byte_enable;
        logic   [7:0]       tag;
        logic   [15:0]      requester_id;

        logic   [7:0]       length_l;
        logic               td;
        logic               ep;
        logic   [1:0]       attr_l;
        logic   [1:0]       at;
        logic   [1:0]       length_h;
        logic               tg_h;
        logic   [2:0]       tc;
        logic               tg_m;
        logic               attr_h;
        logic               ln;
        logic               th;
        logic   [2:0]       fmt;
        logic   [4:0]       tlp_type;

        // Frametoken 4B
        logic   [7:0]       seq_number_l;
        logic   [3:0]       fcrc;
        logic   [3:0]       seq_number_h;
        logic               fp;
        logic   [6:0]       tlp_length_h;
        logic   [3:0]       tlp_length_l;
        logic   [3:0]       frame_type;
    } tlp_memory_read_t;


    function automatic tlp_memory_read_t get_tlp_memory_read(
        input   logic   [1:0]   count,
        input   logic   [63:0]  address
    );
        tlp_memory_read_t      tlp_memory_read;

        tlp_memory_read.tlp_length_l    = 'b0110;
        tlp_memory_read.frame_type      = 'b1111;
        tlp_memory_read.fp              = 'b0;
        tlp_memory_read.tlp_length_h    = 'b000_0000;
        tlp_memory_read.fcrc            = 'b0000;
        tlp_memory_read.seq_number_h    = 'h0;
        tlp_memory_read.seq_number_l    = count & ('hFF);
        tlp_memory_read.fmt             = 'b001;
        tlp_memory_read.tlp_type        = 'b00000;
        tlp_memory_read.tg_h            = 'b0;
        tlp_memory_read.tc              = 'b000;
        tlp_memory_read.tg_m            = 'b0;
        tlp_memory_read.attr_h          = 'b0;
        tlp_memory_read.ln              = 'b0;
        tlp_memory_read.th              = 'b0;
        tlp_memory_read.td              = 'b0;
        tlp_memory_read.ep              = 'b0;
        tlp_memory_read.attr_l          = 'b00;
        tlp_memory_read.at              = 'b00;
        tlp_memory_read.length_l        = (count+1'b1) * 4;
        tlp_memory_read.length_h        = 'h0;
        tlp_memory_read.requester_id    = 'b00000000_00001_000;
        tlp_memory_read.tag             = count & ('hFF);
        tlp_memory_read.byte_enable     = 'h00;
        tlp_memory_read.addr_h          = {address[39:32], address[47:40], address[55:48], address[63:56]};
        tlp_memory_read.addr_m          = {address[15:8], address[23:16], address[31:24]};
        tlp_memory_read.addr_l          = address[7:2];
        tlp_memory_read.reserved        = 'b00;
        tlp_memory_read.lcrc            = 'h0;
        tlp_memory_read.padding         = 'h0; //24B Padding
        
        return tlp_memory_read;
    endfunction

    typedef struct packed {
        // Header 16B
        logic   [5:0]       addr_l;
        logic   [1:0]       reserved;
        logic   [23:0]      addr_m;
        logic   [31:0]      addr_h;
        logic   [7:0]       byte_enable;
        logic   [7:0]       tag;
        logic   [15:0]      requester_id;

        logic   [7:0]       length_l;
        logic               td;
        logic               ep;
        logic   [1:0]       attr_l;
        logic   [1:0]       at;
        logic   [1:0]       length_h;
        logic               tg_h;
        logic   [2:0]       tc;
        logic               tg_m;
        logic               attr_h;
        logic               ln;
        logic               th;
        logic   [2:0]       fmt;
        logic   [4:0]       tlp_type;

        // Frametoken 4B
        logic   [7:0]       seq_number_l;
        logic   [3:0]       fcrc;
        logic   [3:0]       seq_number_h;
        logic               fp;
        logic   [6:0]       tlp_length_h;
        logic   [3:0]       tlp_length_l;
        logic   [3:0]       frame_type;

        // Padding
        logic   [95:0]     padding; //12B Padding
    } tlp_memory_write_t;


    function automatic tlp_memory_write_t get_tlp_memory_write(
        input   int             count,
        input   int             payload_size,
        input   logic   [63:0]  address
    );
        tlp_memory_write_t      tlp_memory_write;

        tlp_memory_write.tlp_length_l    = 'b0110;
        tlp_memory_write.frame_type      = 'b1111;
        tlp_memory_write.fp              = 'b0;
        tlp_memory_write.tlp_length_h    = 'b000_0010;
        tlp_memory_write.fcrc            = 'b0000;
        tlp_memory_write.seq_number_h    = 'h0;
        tlp_memory_write.seq_number_l    =  count & ('hFF);
        tlp_memory_write.fmt             = 'b011;
        tlp_memory_write.tlp_type        = 'b00000;
        tlp_memory_write.tg_h            = 'b0;
        tlp_memory_write.tc              = 'b000;
        tlp_memory_write.tg_m            = 'b0;
        tlp_memory_write.attr_h          = 'b0;
        tlp_memory_write.ln              = 'b0;
        tlp_memory_write.th              = 'b0;
        tlp_memory_write.td              = 'b0;
        tlp_memory_write.ep              = 'b0;
        tlp_memory_write.attr_l          = 'b00;
        tlp_memory_write.at              = 'b00;
        tlp_memory_write.length_l        = 'h20;
        tlp_memory_write.length_h        = 'h0;
        tlp_memory_write.requester_id    = 'b00000000_00001_000;
        tlp_memory_write.tag             = 'h0;
        tlp_memory_write.byte_enable     = 'h00;
        tlp_memory_write.addr_h          = {address[39:32], address[47:40], address[55:48], address[63:56]};
        tlp_memory_write.addr_m          = {address[15:8], address[23:16], address[31:24]};
        tlp_memory_write.addr_l          = address[7:2];
        tlp_memory_write.reserved        = 'b00;
        tlp_memory_write.padding         = 'h0;
        
        return tlp_memory_write;
    endfunction

    localparam  [255:0] PCIE_CRC_16_COEFF[15:0] = '{
    256'hDC7F_DD6A_38F0_3E77_F5F5_2A2C_636D_B05C_3978_EA30_CD50_E0D9_9B06_93D4_746B_2431,   // [15]
    256'h3240_33DF_2488_214C_0F0F_BF3A_52DB_6872_25C4_9F28_ABF8_90B5_5685_DA3E_4E5E_B629,   // [14]
    256'h455F_C485_AAB4_2ED1_F272_F5B1_4A00_0465_2B9A_A5A4_98AC_A883_3044_7ECB_5344_7F25,   // [13]
    256'h7ED0_3F28_EDAA_291F_0CCC_50F4_C66D_B26E_ACB5_B8E2_8106_B498_0324_ACB1_DDC9_1BA3,   // [12]
    256'h6317_C2FE_4E25_2AF8_7393_0256_005B_696B_6F22_3641_8DD3_BA95_9A94_C58C_9A8F_A9E0,   // [11]
    256'hB18B_E17F_2712_957C_39C9_812B_002D_B4B5_B791_1B20_C6E9_DD4A_CD4A_62C6_4D47_D4F0,   // [10]
    256'hD8C5_F0BF_9389_4ABE_1CE4_C095_8016_DA5A_DBC8_8D90_6374_EEA5_66A5_3163_26A3_EA78,   // [9]
    256'hEC62_F85F_C9C4_A55F_0E72_604A_C00B_6D2D_6DE4_46C8_31BA_7752_B352_98B1_9351_F53C,   // [8]
    256'hF631_7C2F_E4E2_52AF_8739_3025_6005_B696_B6F2_2364_18DD_3BA9_59A9_4C58_C9A8_FA9E,   // [7]
    256'h7B18_BE17_F271_2957_C39C_9812_B002_DB4B_5B79_11B2_0C6E_9DD4_ACD4_A62C_64D4_7D4F,   // [6]
    256'hE1F3_8261_C1C8_AADC_143B_6625_3B6C_DDF9_94C4_62E9_CB67_AE33_CD6C_C0C2_4601_1A96,   // [5]
    256'hF0F9_C130_E0E4_556E_0A1D_B312_9DB6_6EFC_CA62_3174_E5B3_D719_E6B6_6061_2300_8D4B,   // [4]
    256'h2403_3DF2_4882_14C0_F0FB_F3A5_2DB6_8722_5C49_F28A_BF89_0B55_685D_A3E4_E5EB_6294,   // [3]
    256'h9201_9EF9_2441_0A60_787D_F9D2_96DB_4391_2E24_F945_5FC4_85AA_B42E_D1F2_72F5_B14A,   // [2]
    256'hC900_CF7C_9220_8530_3C3E_FCE9_4B6D_A1C8_9712_7CA2_AFE2_42D5_5A17_68F9_397A_D8A5,   // [1]
    256'hB8FF_BAD4_71E0_7CEF_EBEA_5458_C6DB_60B8_72F1_D461_9AA1_C1B3_360D_27A8_E8D6_4863};  // [0]


    localparam  [255:0] PCIE_CRC_32_COEFF[31:0] = '{
    256'hDC7F_DD6A_38F0_3E77_F5F5_2A2C_636D_B05C_3978_EA30_CD50_E0D9_9B06_93D4_746B_2431,   // [31]
    256'h3240_33DF_2488_214C_0F0F_BF3A_52DB_6872_25C4_9F28_ABF8_90B5_5685_DA3E_4E5E_B629,   // [30]
    256'h455F_C485_AAB4_2ED1_F272_F5B1_4A00_0465_2B9A_A5A4_98AC_A883_3044_7ECB_5344_7F25,   // [29]
    256'h7ED0_3F28_EDAA_291F_0CCC_50F4_C66D_B26E_ACB5_B8E2_8106_B498_0324_ACB1_DDC9_1BA3,   // [28]
    256'h6317_C2FE_4E25_2AF8_7393_0256_005B_696B_6F22_3641_8DD3_BA95_9A94_C58C_9A8F_A9E0,   // [27]
    256'hB18B_E17F_2712_957C_39C9_812B_002D_B4B5_B791_1B20_C6E9_DD4A_CD4A_62C6_4D47_D4F0,   // [26]
    256'hD8C5_F0BF_9389_4ABE_1CE4_C095_8016_DA5A_DBC8_8D90_6374_EEA5_66A5_3163_26A3_EA78,   // [25]
    256'hEC62_F85F_C9C4_A55F_0E72_604A_C00B_6D2D_6DE4_46C8_31BA_7752_B352_98B1_9351_F53C,   // [24]
    256'hF631_7C2F_E4E2_52AF_8739_3025_6005_B696_B6F2_2364_18DD_3BA9_59A9_4C58_C9A8_FA9E,   // [23]
    256'h7B18_BE17_F271_2957_C39C_9812_B002_DB4B_5B79_11B2_0C6E_9DD4_ACD4_A62C_64D4_7D4F,   // [22]
    256'hE1F3_8261_C1C8_AADC_143B_6625_3B6C_DDF9_94C4_62E9_CB67_AE33_CD6C_C0C2_4601_1A96,   // [21]
    256'hF0F9_C130_E0E4_556E_0A1D_B312_9DB6_6EFC_CA62_3174_E5B3_D719_E6B6_6061_2300_8D4B,   // [20]
    256'h2403_3DF2_4882_14C0_F0FB_F3A5_2DB6_8722_5C49_F28A_BF89_0B55_685D_A3E4_E5EB_6294,   // [19]
    256'h9201_9EF9_2441_0A60_787D_F9D2_96DB_4391_2E24_F945_5FC4_85AA_B42E_D1F2_72F5_B14A,   // [18]
    256'hC900_CF7C_9220_8530_3C3E_FCE9_4B6D_A1C8_9712_7CA2_AFE2_42D5_5A17_68F9_397A_D8A5,   // [17]
    256'hB8FF_BAD4_71E0_7CEF_EBEA_5458_C6DB_60B8_72F1_D461_9AA1_C1B3_360D_27A8_E8D6_4863,   // [16]
    256'hDC7F_DD6A_38F0_3E77_F5F5_2A2C_636D_B05C_3978_EA30_CD50_E0D9_9B06_93D4_746B_2431,   // [15]
    256'h3240_33DF_2488_214C_0F0F_BF3A_52DB_6872_25C4_9F28_ABF8_90B5_5685_DA3E_4E5E_B629,   // [14]
    256'h455F_C485_AAB4_2ED1_F272_F5B1_4A00_0465_2B9A_A5A4_98AC_A883_3044_7ECB_5344_7F25,   // [13]
    256'h7ED0_3F28_EDAA_291F_0CCC_50F4_C66D_B26E_ACB5_B8E2_8106_B498_0324_ACB1_DDC9_1BA3,   // [12]
    256'h6317_C2FE_4E25_2AF8_7393_0256_005B_696B_6F22_3641_8DD3_BA95_9A94_C58C_9A8F_A9E0,   // [11]
    256'hB18B_E17F_2712_957C_39C9_812B_002D_B4B5_B791_1B20_C6E9_DD4A_CD4A_62C6_4D47_D4F0,   // [10]
    256'hD8C5_F0BF_9389_4ABE_1CE4_C095_8016_DA5A_DBC8_8D90_6374_EEA5_66A5_3163_26A3_EA78,   // [9]
    256'hEC62_F85F_C9C4_A55F_0E72_604A_C00B_6D2D_6DE4_46C8_31BA_7752_B352_98B1_9351_F53C,   // [8]
    256'hF631_7C2F_E4E2_52AF_8739_3025_6005_B696_B6F2_2364_18DD_3BA9_59A9_4C58_C9A8_FA9E,   // [7]
    256'h7B18_BE17_F271_2957_C39C_9812_B002_DB4B_5B79_11B2_0C6E_9DD4_ACD4_A62C_64D4_7D4F,   // [6]
    256'hE1F3_8261_C1C8_AADC_143B_6625_3B6C_DDF9_94C4_62E9_CB67_AE33_CD6C_C0C2_4601_1A96,   // [5]
    256'hF0F9_C130_E0E4_556E_0A1D_B312_9DB6_6EFC_CA62_3174_E5B3_D719_E6B6_6061_2300_8D4B,   // [4]
    256'h2403_3DF2_4882_14C0_F0FB_F3A5_2DB6_8722_5C49_F28A_BF89_0B55_685D_A3E4_E5EB_6294,   // [3]
    256'h9201_9EF9_2441_0A60_787D_F9D2_96DB_4391_2E24_F945_5FC4_85AA_B42E_D1F2_72F5_B14A,   // [2]
    256'hC900_CF7C_9220_8530_3C3E_FCE9_4B6D_A1C8_9712_7CA2_AFE2_42D5_5A17_68F9_397A_D8A5,   // [1]
    256'hB8FF_BAD4_71E0_7CEF_EBEA_5458_C6DB_60B8_72F1_D461_9AA1_C1B3_360D_27A8_E8D6_4863};  // [0]

    /*
    function automatic logic is_static0_err(cxl_flit_payload_t p);
        is_static0_err                  = 1'b0;
        if (is_llcrd_flit(p) | is_retry_flit(p) | is_init_flit(p)) begin
            cxl_control_flit_pld_t          payload;
            payload                         = p;

            is_static0_err                  = (payload.static0 != 24'd0);
        end
    endfunction
    */

endpackage

`endif
