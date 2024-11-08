/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  cdb_test.sv                                         //
//                                                                     //
//  Description :  Testbench module for the CDB                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"
module cdb_tb ();
    parameter N = 2;
    parameter NUM_FU = `NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD + `NUM_FU_STORE + `NUM_FU_BR;

    logic         [NUM_FU-1:0] fu_done;
    FU_PACKET     [NUM_FU-1:0] wr_data;

    CDB_PACKET   [N-1:0]      entries;
    logic        [NUM_FU-1:0] stall_sig;    

    cdb #(
        .N(N),
        .NUM_FU(NUM_FU)
    )
    dut (
        .fu_done(fu_done),
        .wr_data(fu_done),

        .entries(entries),
        .stall_sig(stall_sig), 

        `ifdef DEBUG   
        `endif 
    );

    always begin 
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    initial begin
        $display("\nStart Testbench");
    end

    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
    end

    // functions here

endmodule
   
