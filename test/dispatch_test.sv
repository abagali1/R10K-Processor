/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dispatch_test.sv                                     //
//                                                                     //
//  Description :  Testbench module for the Dispatch module             //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module dispatch_tb();

    parameter N = 3; // Number of instructions per dispatch

    localparam LOG_N = $clog2(N+1);

    logic                                  clock;
    logic                                  reset;

    INST_PACKET [N-1:0]                   insts;
    logic                                  bs_full;

    logic [LOG_N-1:0]                     rob_open;
    logic [LOG_N-1:0]                     rs_open;

    logic [LOG_N-1:0]                     num_dispatch;
    DECODED_PACKET [N-1:0]                out_insts;

    // Initialize instances of the modules and signals
    dispatch #(
        .N(N)
    ) dut (
        .clock(clock),
        .reset(reset),
        .rob_open(rob_open),
        .rs_open(rs_open),
        .insts(insts),
        .bs_full(bs_full),

        .num_dispatch(num_dispatch),
        .out_insts(out_insts)
    );

    // Clock generation
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    initial begin
        $display("\nStart Testbench");

        clock = 0;
        reset = 1;

    end

endmodule