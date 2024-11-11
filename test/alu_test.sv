/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  freelist_test.sv                                    //
//                                                                     //
//  Description :  Testbench module for the free list                  //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module alu_tb();
    logic               clock; 
    logic               reset;
    ISSUE_PACKET        is_pack;
    logic               stall;
    logic               rd_in;

    FU_PACKET           fu_pack;

    DATA                rs1, rs2;
    RS_PACKET           rs_pack;
    DATA                expected;

    // // queue declaration for free_list model
    // FREE_LIST_PACKET free_list_model [$:(DEPTH)];
    // FREE_LIST_PACKET free_list_model_copy [$:(DEPTH)];

    // // other variables
    // FREE_LIST_PACKET entry_one;
    // FREE_LIST_PACKET entry_random;
    // FREE_LIST_PACKET  [2:0] pr_list;
    // logic [$clog2(DEPTH)-1:0] k = 0;

    alu dut (
        .clock(clock),
        .reset(reset),
        .is_pack(is_pack),
        .stall(stall),
        .rd_in(rd_in),
        .fu_pack(fu_pack)
    );

    always begin 
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    initial begin
        $display("\nStart Testbench");

        clock = 0;
        reset = 1;
        rd_in = 0;
        stall = 0;
        rs_pack = '{
            inst: 0,
            PC: 0,
            NPC: 1,
            opa_select: OPA_IS_RS1,
            opb_select: OPB_IS_RS2,
            dest_reg_idx: 0,
            alu_func: ALU_ADD,
            mult: 0,
            rd_mem: 0,
            wr_mem: 0,
            cond_branch: 0,
            uncond_branch: 0,
            halt: 0,
            illegal: 0,
            csr_op: 0,
            t: '{reg_idx: 32, valid: 1},
            t1: '{reg_idx: 32, ready: 0, valid: 1},
            t2: '{reg_idx: 32, ready: 0, valid: 1},
            b_mask: '{},
            fu_type: '{},
            pred_taken: 0,
            valid: 1
        };
        is_pack.rs_packet = rs_pack;

        @(negedge clock);
        @(negedge clock);
        reset = 0;
        
        // ------------------------------ Test 1 ------------------------------ //
        $display("\nTest 1: Check basic addition");
        
        is_pack.rs1_value = 0;
        is_pack.rs2_value = 0;
        expected = 0;
        @(negedge clock);
        
        is_pack.rs1_value = 1;
        is_pack.rs2_value = 2;
        expected = 3;
        @(posedge clock);

        is_pack.rs1_value = 0;
        is_pack.rs2_value = 8;
        expected = 8;
        @(negedge clock);

        $display("PASSED TEST 1");
    end

    int cycle_number = 0;
    // Correctness Verification
    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
        $display("expected: %d", expected);
        $display("result: %d\n", fu_pack.alu_result);
        check_expected();
        $display("@@@ FINISHED CYCLE NUMBER: %0d @@@ \n", cycle_number);
        cycle_number++;
    end

    function void check_expected();
        if (expected != fu_pack.alu_result) begin
            $error("@@@ FAILED @@@");
            $error("Check entry error: expected %0d, but got %0d", expected, fu_pack.alu_result);
            $finish;
        end
    endfunction

endmodule