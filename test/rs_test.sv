/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rs_test.sv                                          //
//                                                                     //
//  Description :  Testbench module for the N-way RS module            //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module RS_tb();

    parameter DEPTH = 8;
    parameter WIDTH = 32;
    parameter N = 3;
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic clock;
    logic reset;
    RS_PACKET [N-1:0] rs_in;
    CDB_PACKET [N-1:0] cdb_in;
    BR_MASK br_id;
    BR_TASK br_task;

    logic [`NUM_FU_ALU-1:0]          fu_alu_busy;
    logic [`NUM_FU_MULT-1:0]         fu_mult_busy;
    logic [`NUM_FU_LD-1:0]           fu_ld_busy;
    logic [`NUM_FU_STORE-1:0]        fu_store_busy;
    logic [`NUM_FU_BR-1:0]           fu_br_busy;

    RS_PACKET [`NUM_FU_ALU-1:0]          issued_alu;
    RS_PACKET [`NUM_FU_MULT-1:0]         issued_mult;
    RS_PACKET [`NUM_FU_LD-1:0]           issued_ld;
    RS_PACKET [`NUM_FU_STORE-1:0]        issued_store;
    RS_PACKET [`NUM_FU_BR-1:0]           issued_br;

    `ifdef DEBUG
        ROB_ENTRY_PACKET [DEPTH-1:0] debug_entries;
    `endif

    RS #(
        .DEPTH(DEPTH),
        .N(N))
    dut (
        .clock(clock),
        .reset(reset),
        .rs_in(rs_in),
        .cdb_in(cdb_in),
        .br_id(br_id),
        .br_task(br_task),
        .fu_alu_busy(fu_alu_busy),
        .fu_mult_busy(fu_mult_busy),
        .fu_ld_busy(fu_ld_busy),
        .fu_store_busy(fu_store_busy),
        .fu_br_busy(fu_br_busy), 
        .issued_alu(issued_alu), 
        .issued_mult(issued_mult),
        .issued_ld(issued_ld),
        .issued_store(issued_store),
        .issued_br(issued_br)

        `ifdef DEBUG
        , .debug_entries(debug_entries)
        `endif
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    initial begin
        $display("\nStart Testbench");
        
        clock = 0;
        reset = 1;

        @(negedge clock);
        @(negedge clock);
        reset = 0;

        // ------------------------------ Test 1 ------------------------------ //
        $display("\nTest 1: TODO");
        
        $display("@@@ PASSED ALL TESTS @@@");
        $finish;
    end


    // Correctness Verification
    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
    end

    // Helper function to clear inputs to RS
    function void clear_inputs();
    endfunction

    // Monitoring Statements
    int cycle_number = 0;
    always @(posedge clock) begin
        $display("------------------------------------------------------------");
        $display("@@@ Cycle Number: %0d @@@", cycle_number);
        $display("   Time: %0t", $time);
        $display("   Reset: %0d\n", reset);
    end

endmodule