`include "PCIE_PKG.svh"

`define TIMEOUT_DELAY   100000000
`define RANDOM_SEED     12123344

module PCIE_TOP_TB ();

    import PCIE_PKG::*;

    reg                     pclk;
    reg                     preset_n;

    // timeout
	initial begin
		#`TIMEOUT_DELAY $display("Timeout!");
		$finish;
	end

    // clock generation
    initial begin
        pclk                    = 1'b0;

        forever #10 pclk        = !pclk;
    end

    // reset generation
    initial begin
        preset_n                = 1'b0;     // active at time 0

        repeat (3) @(posedge pclk);          // after 3 cycles,
        preset_n                = 1'b1;     // release the reset
    end

    // inject random seed
    initial begin
        $srandom(`RANDOM_SEED);
    end

    
    initial begin
        /*
        *
        */
    end
endmodule