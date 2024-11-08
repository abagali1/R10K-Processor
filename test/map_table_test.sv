/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  map_table_test.sv                                         //
//                                                                     //
//  Description :  Testbench module for the N-way ROB module           //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module map_table_tb();

    parameter DEPTH = 32;
    parameter N = 3;

    logic                                   clock;
    logic                                   reset;
    REG_IDX             [N-1:0]             r1_idx;
    REG_IDX             [N-1:0]             r2_idx;      
    REG_IDX             [N-1:0]             dest_reg_idx; // dest_regs that are getting mapped to a new phys_reg from free_list
    PHYS_REG_IDX        [N-1:0]             wr_reg_data;  // comes from the free list
    logic               [N-1:0]             incoming_valid;
    REG_IDX             [N-1:0]             ready_reg_idx;
    PHYS_REG_IDX        [N-1:0]             ready_phys_idx;
    logic                                   in_mt_en;
    MAP_TABLE_PACKET    [`ARCH_REG_SZ-1:0]  in_mt;
    PHYS_REG_IDX        [N-1:0]             t_old_data;
    PHYS_REG_IDX        [N-1:0]             r1_p_reg;
    PHYS_REG_IDX        [N-1:0]             r2_p_reg;
    MAP_TABLE_PACKET    [`ARCH_REG_SZ-1:0]  out_mt; // output map table for architectural mt

    MAP_TABLE_PACKET [DEPTH:0] mt_model;
    
    map_table #(
        .DEPTH(DEPTH),
        .N(N))
    dut (
        .clock(clock),
        .reset(reset),
        .r1_idx(r1_idx),
        .r2_idx(r2_idx),
        .dest_reg_idx(dest_reg_idx),
        .wr_reg_data(wr_reg_data),
        .incoming_valid(incoming_valid),
        .ready_reg_idx(ready_reg_idx),
        .ready_phys_idx(ready_phys_idx),
        .in_mt_en(in_mt_en),
        .in_mt(in_mt),

        .t_old_data(t_old_data),
        .r1_p_reg(r1_p_reg),
        .r2_p_reg(r2_p_reg),
        .out_mt(out_mt)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    initial begin
        $display("\nStart Testbench");
        
        clock = 0;
        reset = 1;
        clear_inputs();
        init_model();

        @(negedge clock);
        @(negedge clock);
        reset = 0;

        // ------------------------------ Test 1 ------------------------------ //
        $display("\nTest 1: Correct instantiation of Map Table");
        
        $display("PASSED TEST 1");

        $display("@@@ PASSED ALL TESTS @@@");
        $finish;
    end


    // Correctness Verification
    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
        if (reset === 0) begin
            check_mt();
        end
    end

    // Helper function to clear inputs to map_table
    function void clear_inputs();
        r1_idx = 0;
        r2_idx = 0;      
        dest_reg_idx = 0;
        wr_reg_data = 0;
        incoming_valid = 0;
        ready_reg_idx = 0;
        ready_phys_idx = 0;
        in_mt_en = 0;
        in_mt = 0;
    endfunction

    function void init_model();
        for (int i = 0; i <= DEPTH; i++) begin
            mt_model[i].reg_idx = i;
            mt_model[i].valid = 1;
            mt_model[i].ready = 1;
        end
    endfunction

    function void check_mt();
        for (int i = 1; i <= DEPTH; i++) begin
            if (out_mt[i].valid !== mt_model[i].valid) begin
                $error("@@@ FAILED @@@");
                $error("Test Error: Model valid mismatch in row i=[%0d], expected v=[%0d] but got v=[%0d]", i, mt_model[i].valid, out_mt[i].valid);
                $finish;
            end
            if (out_mt[i].reg_idx !== mt_model[i].reg_idx) begin
                $error("@@@ FAILED @@@");
                $error("Test Error: Model reg_idx mismatch in row i=[%0d], expected r=[%0d] but got r=[%0d]", i, mt_model[i].reg_idx, out_mt[i].reg_idx);
                $finish;
            end
            if (out_mt[i].ready !== mt_model[i].ready) begin
                $error("@@@ FAILED @@@");
                $error("Test Error: Model ready mismatch in row i=[%0d], expected r=[%0d] but got r=[%0d]", i, mt_model[i].ready, out_mt[i].ready);
                $finish;
            end
        end
    endfunction

    // Monitoring Statements
    int cycle_number = 0;
    always @(posedge clock) begin
        $display("------------------------------------------------------------");
        $display("@@@ Cycle Number: %0d @@@", cycle_number);
        $display("   Time: %0t", $time);
        $display("   Reset: %0d\n", reset);

        cycle_number++;
    end

endmodule