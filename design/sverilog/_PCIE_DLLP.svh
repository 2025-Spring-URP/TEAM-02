// Copyright Sungkyunkwan University
// Author: YongSeong Lim <xidid430rr@gmail.com>
// Description:

// Follows PCIe gen5 specification 1.1

package _PCIE_DLLP;

    localparam NEXT_TRANSMIT_SEQ_BITS   = 12;               // Set 000h in DL_Inactive state
    localparam ACKD_SEQ_BITS            = 12;               // Set to FFFh in DL_Inactive state

    localparam REPLAY_NUM_BITS          = 2;                //  Set to 00b in DL_Inactive state

    // Flow Control Packet Header
    typedef struct packed{

    } fcp_hdr;


    // synopsys translation_off

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
        hdr <= 127
        payload <= 2047
            
        endfunction
    end else if (Scale_Factor == 2'b11) begin
        function automatic (
        
        );
        hdr <= 509
        payload <= 8188

        endfunction
    end else begin                     
        function automatic (
        
        );
        hdr <= 2032
        payload <= 32752

        endfunction
    end


    // ----------------------------------------------------------------------------------------------------
    //                    LCRC and Sequence Number Rules (TLP Transmitter)   | pg 228
    // -----------------------------------------------------------------------------------------------------



    // synopsys translate_on

endpackage