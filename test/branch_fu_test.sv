/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  branch_fu_test.sv                                    //
//                                                                     //
//  Description :  Testbench module for the branch_fu                   //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

include "sys_defs.svh"
include "ISA.svh"

module branch_fu_tb();

    // Define parameters for the test
    parameter N = 3; // Number of entries, for example
    
    // Declare signals
    logic clock;
    logic reset;
    ISSUE_PACKET is_pack;     // Instruction packet input
    logic rd_en;              // Read enable to trigger the branch FU
    FU_PACKET fu_pack;        // Output packet from the FU
    BR_TASK br_task;          // Branch task (CLEAR/SQUASH/NOTHING)
    logic data_ready;         // Indicates if data is ready

    // Instantiate the branch_fu module
    branch_fu #(
        .N(N)
    ) dut (
        .clock(clock),
        .reset(reset),
        .is_pack(is_pack),
        .rd_en(rd_en),
        .fu_pack(fu_pack),
        .br_task(br_task),
        .data_ready(data_ready)
    );

    // Clock generation
    always begin
        #(CLOCK_PERIOD / 2.0);
        clock = ~clock;
    end

    // Initialize the test
    initial begin
        $display("\nStart Testbench");

        clock = 0;
        reset = 1;
        rd_en = 0;
        clear_inputs();

        // Reset DUT
        @(negedge clock);
        @(negedge clock);
        reset = 0;

        // ------------------------------ Test 1 ------------------------------ //
        $display("\nTest 1: Conditional Branch (BEQ)");

        // Prepare a BEQ instruction packet
        is_pack = '0;
        is_pack.decoded_vals.inst.b.funct3 = 3'b000;  // BEQ
        is_pack.rs1_value = 10;
        is_pack.rs2_value = 10;
        is_pack.valid = 1;

        rd_en = 1;  // Enable reading to trigger FU logic

        @(negedge clock);
        rd_en = 0;  // Disable reading after the first cycle

        // Check that the branch was taken (BEQ)
        assert(fu_pack.result == is_pack.decoded_vals.NPC);
        assert(br_task == CLEAR);

        $display("PASSED TEST 1: BEQ Branch Taken");

        // ------------------------------ Test 2 ------------------------------ //
        $display("\nTest 2: Conditional Branch (BNE)");

        $finish;
    end

    // Function to clear inputs before each test
    task clear_inputs();
        is_pack = '0;
        rd_en = 0;
        fu_pack = '0;
        br_task = NOTHING;
        data_ready = 0;
    endtask

    // Debugging output (optional)
    ifdef DEBUG
        always @(posedge clock) begin
            
        end
    endif

endmodule
