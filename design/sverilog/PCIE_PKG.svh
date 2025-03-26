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

    typedef struct packed {
        // Header 16B
        logic   [5:0]               addr_l;
        logic   [1:0]               reserved;
        logic   [23:0]              addr_m;
        logic   [31:0]              addr_h;
        logic   [7:0]               byte_enable;
        logic   [7:0]               tag;
        logic   [15:0]              requester_id;

        logic   [7:0]               length_l;
        logic                       td;
        logic                       ep;
        logic   [1:0]               attr_l;
        logic   [1:0]               at;
        logic   [1:0]               length_h;
        logic                       tg_h;
        logic   [2:0]               tc;
        logic                       tg_m;
        logic                       attr_h;
        logic                       ln;
        logic                       th;
        logic   [2:0]               fmt;
        logic   [4:0]               tlp_type;
    } tlp_memory_req_hdr_t;

    function automatic tlp_memory_req_hdr_t gen_tlp_memwr_hdr(
        input   logic   [63:0]      address,
        input   logic   [3:0]       first_dbe,
        input   logic   [3:0]       last_dbe,
        input   logic   [9:0]       length,
        input   logic   [9:0]       tag,
        input   logic   [15:0]      requester_id
    );
   
        tlp_memory_req_hdr_t        tlp_memwr_hdr;
        
        tlp_memwr_hdr.addr_l        = address[7:2]; // Address (Low)
        tlp_memwr_hdr.reserved      = 2'b00; // No Processing Hint
        tlp_memwr_hdr.addr_m        = {address[15:8], address[23:16], address[31:24]};
        tlp_memwr_hdr.addr_h        = {address[39:32], address[47:40], address[55:48], address[63:56]}; // Address (High)
        tlp_memwr_hdr.byte_enable   = {last_dbe, first_dbe}; // [7:4]: Last DW Enable, [3:0]: First DW Enable
        tlp_memwr_hdr.tag           = tag[7:0]; // tag
        tlp_memwr_hdr.requester_id  = requester_id;

        tlp_memwr_hdr.length_l      = length;
        tlp_memwr_hdr.td            = 1'b0; // No TLP Digest in this project
        tlp_memwr_hdr.ep            = 1'b0; // Not Error Poisoned
        tlp_memwr_hdr.attr_l        = 2'b00; // No Attributes
        tlp_memwr_hdr.at            = 2'b00; // Untranslated Address
        tlp_memwr_hdr.tg_h          = tag[9];
        tlp_memwr_hdr.tc            = 3'b000; // Normal Traffic Class
        tlp_memwr_hdr.tg_m          = tag[8];
        tlp_memwr_hdr.attr_h        = 1'b0; // No Attributes
        tlp_memwr_hdr.ln            = 1'b0; // Reserved
        tlp_memwr_hdr.th            = 1'b0; // No TLP Hint
        tlp_memwr_hdr.fmt           = 3'b010; // 4 DW Header
        tlp_memwr_hdr.tlp_type      = 5'b00000; // Memory Write

        return tlp_memwr_hdr;

    endfunction

endpackage

`endif