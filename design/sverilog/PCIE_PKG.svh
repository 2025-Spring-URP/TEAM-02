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
    /*
    * TODO:
    */

    // Bit 단위의 연속적인 패킷을 만드는데 "packed" 명령어를 사용함. 1) 비트슬라이싱 가능 2) MSB부터 정렬됨
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

    // Generate TLP Memory Write Request Header
    function automatic tlp_memory_req_hdr_t gen_tlp_memwr_hdr(           //automatic을 통해 독립적으로 변수를 생성하여, 여러 프로세서 생성 시 독립적 동작 가능.
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
        input   logic   [63:0]      address,        //
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
        tlp_memwr_hdf.attr_h        = attr[2];
        tlp_memwr_hdr.attr_l        = attr[1:0];
        tlp_memwr_hdr.at            = at;
        tlp_memwr_hdr.length_h      = length[9:8];
        tlp_memwr_hdr.length_l      = length[7:0];
        tlp_memwr_hdr.requester_id  = requester_id;
        tlp_memwr_hdr.tg_h          = tag[9];
        tlp_memwr_hdr.th_m          = tag[8];
        tlp_memwr_hdr.tag           = tag[7:0];
        tlp_memwr_hdr.byte_enable   = {Last_DW_BE[3:0], First_DW_BE[3:0]};
        tlp_memwr_hdr.addr_h        = {address[39:32], address[47:40], address[55:48], address[63:56]};
        tlp_memwr_hdr.addr_m        = {address[15: 8], address[23:16], address[31:24]};
        tlp_memwr_hdr.addr_l        = {address[ 7: 2]};
        tlp_memwr_hdr.reserved      = reserved;

        return tlp_memwr_hdr;
    endfunction

    //Align Data Payload at Address
    function automatic align_tlp_memwr(
        input   logic   [ADDR_WIDTH-1:0]    addr
    );
    if (addr[7:0] != 'b1000_0000) begin
        
    end
    endfunction

    // synopsys translate_off

    // Error Handling
    function automatic check_tlp_read_req_size(
        input   logic   [9:0]   length
    );
    if (length > MAX_READ_REQ_SIZE) begin
        $display();
    end

    endfunction

    // Error Handling
    function automatic check_tlp_max_payload_violation(

    );
    if ( > MAX_PAYLOAD_SIZE) begin
        $display();
    end

    endfunction   

    // Error Handling
    function automatic check_tlp_read_completion_boundary(

    );
    if ( > READ_COMPLETION_BOUNDARY) begin
        $display();
    end

    endfunction   

    // Completion 
    typedef struct packed{

    } cpl_hdr;

    // Flow Control Packet Header       --> DLLP
    typedef struct packed{

    } fcp_hdr;
    

    /* [Read Completion Boundary(RCB Check) & Completion MAX_PAYLOAD_SIZE Rule]
    * ---------------------------------------------------------------------------------
    *  Written by LYS v1 (not completed)
    *  2.3.1.1 Data Return for Read Requests (pg 170)
    *  --------------------------------------------------------------------------------
    *  1) First Completion must start with the address specified in the request
    *  2) All Completions between, but not including, the first and final Completions must be an integer multiple of RCB bytes in length
    *  3) Multiple Memory Read Completions for a single Read Request must return data in increasing address order
    *  4) Final Completion must end at the address that satisfies the entire Request
    *  5) If all the Memory Read Completions for a single Read Request have a Successful Completion Status, the sum of
          their payloads must equal the size requested
    *  6)
    *  ----------------------------------------------------------------------------------
    */
    function automatic check_cpld_max_payload_violation(

    ); 
    if ( > MAX_PAYLOAD_SIZE) begin
        $display();
    end
    endfunction

    // Completion Data Naturally Align Check
    function automatic check_(

    );
    if ( > MAX_PAYLOAD_SIZE) begin
        $display();
    end
    endfunction

    // Posted Requset Acceptance Rule - Posted Request must arrive Posted Buffer Until 10us
    function automatic check_posted_request_acceptance_rule_violation(
    
    );
        
    endfunction





    // synopsys translate_on


endpackage