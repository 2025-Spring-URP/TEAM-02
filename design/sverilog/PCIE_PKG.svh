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
    localparam  ADDR_WIDTH          = 64;
    localparam  LANE_COUNT          = 4;
    localparam  PIPE_DATA_WIDTH     = 256;
    /*
    * TODO:
    */
    
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
        input   logic   [63:0]      address
    );
        tlp_memory_req_hdr_t        tlp_memwr_hdr;
        tlp_memwr_hdr.addr_h        = {address[39:32], address[47:40], address[55:48], address[63:56]};
        /*
        * TODO:
        */
    endfunction

endpackage