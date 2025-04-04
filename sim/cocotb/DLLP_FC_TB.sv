// Copyright Sungkyunkwan University
// Author: YongSeong Lim <xidid430rr@gmail.com>
// Description:
/*  This is only for Flow Control Situation
*
*
*/
// Follows PCIe gen5 specification 1.1




class Dummy_Adder_EX;                                       // Constraint Random Verification(CRV) 방법론
  // Define the inputs and output
  rand bit [3:0] A, B;
  rand bit [4:0] C;

  // Define the constraints
  constraint c_adder { 	A inside {[0:15]};                  // A의 랜덤 값이 0~15 의 값을 갖도록 제한
  						B inside {[0:15]};
  						C == A + B;                         // C == A+B로 제한한
					}

  function void display();
    $display("A=0x%0h B=0x%0h C=0x%0h", A, B, C);
  endfunction
endclass




module DLLP_FC_TB();


// Instantiate DUT
U_PCIE_DLLP PCIE_DLLP(

);

endmodule