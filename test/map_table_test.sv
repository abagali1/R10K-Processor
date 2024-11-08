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

typedef struct packed {
    PHYS_REG_IDX r1;
    PHYS_REG_IDX r2;
    PHYS_REG_IDX dr;
} TEST_INST;

typedef struct packed {
    REG_IDX arch_idx;
    PHYS_REG_IDX phys_idx;
} TEST_READY;

module map_table_tb();

    parameter DEPTH = 8;
    parameter N = 3;

    logic                                   clock;
    logic                                   reset;
    REG_IDX             [N-1:0]             r1_idx;
    REG_IDX             [N-1:0]             r2_idx;      
    REG_IDX             [N-1:0]             dest_reg_idx; // dest_regs that are getting mapped to a new phys_reg from free_list
    PHYS_REG_IDX        [N-1:0]             free_reg;  // comes from the free list
    logic               [N-1:0]             incoming_valid;
    REG_IDX             [N-1:0]             ready_reg_idx;
    PHYS_REG_IDX        [N-1:0]             ready_phys_idx;
    logic               [N-1:0]             ready_valid;
    logic                                   in_mt_en;
    MAP_TABLE_PACKET    [DEPTH:0]           in_mt;
    PHYS_REG_IDX        [N-1:0]             t_old_data;
    PHYS_REG_IDX        [N-1:0]             r1_p_reg;
    PHYS_REG_IDX        [N-1:0]             r2_p_reg;
    MAP_TABLE_PACKET    [DEPTH:0]           out_mt; // output map table for architectural mt

    MAP_TABLE_PACKET [DEPTH:0] mt_model;
    PHYS_REG_IDX free_list_model [$:(DEPTH)];
    TEST_INST inst_buf [$:((DEPTH)*2)];
    TEST_READY ready_buf [$:((DEPTH)*2)];
    
    map_table #(
        .DEPTH(DEPTH),
        .N(N))
    dut (
        .clock(clock),
        .reset(reset),
        .r1_idx(r1_idx),
        .r2_idx(r2_idx),
        .dest_reg_idx(dest_reg_idx),
        .free_reg(free_reg),
        .incoming_valid(incoming_valid),
        .ready_reg_idx(ready_reg_idx),
        .ready_phys_idx(ready_phys_idx),
        .ready_valid(ready_valid),
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
        
        @(negedge clock);

        $display("PASSED TEST 1");

        // ------------------------------ Test 2 ------------------------------ //
        $display("\nTest 2: Read/Write/Ready a single instruction");
        generate_insts(1);
        fill_free_list();

        $display("Input a single instruction");
        set_free_regs(1);
        set_insts(1);
        @(negedge clock);
        clear_inputs();

        $display("Set Instruction to ready");
        set_ready(1);
        @(negedge clock);

        $display("PASSED TEST 2");

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
        r1_idx = '0;
        r2_idx = '0;      
        dest_reg_idx = '0;
        free_reg = '0;
        incoming_valid = '0;
        ready_reg_idx = '0;
        ready_phys_idx = '0;
        ready_valid = '0;
        in_mt_en = '0;
        in_mt = '0;
    endfunction

    function void generate_insts(int num);
        PHYS_REG_IDX count = 1;
        for (int i = 0; i < num; i++) begin
            if (count > DEPTH - 2) begin
                count = 1;
            end
            inst_buf.push_back('{count, count+1, count+2});
            count += 3;
        end
    endfunction

    function void set_free_regs(int num_in);
        int num;
        num = free_list_model.size() > num_in ? num_in: free_list_model.size();
        for (int i = 0; i < num; i++) begin
            free_reg[i] = free_list_model[i];
        end
    endfunction

    function void set_insts(int num);
        TEST_INST inst;
        for (int i = 0; i < num; i++) begin
            inst = inst_buf.pop_front();
            ready_buf.push_back('{inst.dr, free_list_model[0]});

            r1_idx = inst.r1;
            r2_idx = inst.r2;
            dest_reg_idx = inst.dr;
            incoming_valid[i] = 1;
            mt_model[inst.dr] = '{free_list_model.pop_front(), 0, 1};
        end
    endfunction

    function void set_ready(int num);
        TEST_READY r_pack;
        for (int i = 0; i < num; i++) begin
            r_pack = ready_buf.pop_front();
            ready_reg_idx[i] = r_pack.arch_idx;
            ready_phys_idx[i] = r_pack.phys_idx;
            ready_valid[i] = 1;
            mt_model[r_pack.arch_idx].ready = 1;
        end
    endfunction

    function void init_model();
        for (int i = 0; i <= DEPTH; i++) begin
            mt_model[i].reg_idx = i;
            mt_model[i].valid = 1;
            mt_model[i].ready = 1;
        end
    endfunction


    function void fill_free_list();
        PHYS_REG_IDX i = 1;
        int taken;
        while (free_list_model.size() < DEPTH) begin
            taken = 0;
            for (int j = 1; j <= DEPTH; j++) begin
                if (out_mt[j].reg_idx == i) begin
                    taken = 1;
                    break;
                end
            end
            if (taken == 0) begin
                free_list_model.push_back(i);
            end
            i++;
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

        $display("INPUTS:");

        $display("   Register Values:");
        for (int i = 0; i < N; i++) begin
            $display("      R1=%0d   R2=%0d   DR=%0d   Valid=%0d", r1_idx[i], r2_idx[i], dest_reg_idx[i], incoming_valid[i]);
        end
        $display("");
    
        $write("   free_reg: ");
        for (int i = 0; i < N; i++) begin
            $write("[%0d],", free_reg[i]);
        end
        $display("");

        $display("   Ready Register Signals:");
        for (int i = 0; i < N; i++) begin
            $display("      arch_reg_idx=%0d   phys_reg_idx=%0d   valid=%0d", ready_reg_idx[i], ready_phys_idx[i], ready_valid[i]);
        end
        $display("");

        $display("   in_mt_en=%0d", in_mt_en);
        if (in_mt_en) begin
            $display("   MT IN:");
            for (int i = 1; i <= DEPTH; i++) begin
                $display("      entries[%0d]: reg_idx=%0d, ready=%0d, valid=%0d", i, in_mt[i].reg_idx, in_mt[i].ready, in_mt[i].valid);
            end
        end
        $display("");

        $display("OUTPUTS:");

        $write("   r1_p_reg: ");
        for (int i = 0; i < N; i++) begin
            $write("[%0d],", r1_p_reg[i]);
        end
        $display("");

        $write("   r2_p_reg: ");
        for (int i = 0; i < N; i++) begin
            $write("[%0d],", r2_p_reg[i]);
        end
        $display("");

        $write("   t_old_data: ");
        for (int i = 0; i < N; i++) begin
            $write("[%0d],", t_old_data[i]);
        end
        $display("");

        $display("   Map Table Data");
        for (int i = 1; i <= DEPTH; i++) begin
            $display("      entries[%0d]: reg_idx=%0d, ready=%0d, valid=%0d", i, out_mt[i].reg_idx, out_mt[i].ready, out_mt[i].valid);
        end
        $display("");

        cycle_number++;
    end

endmodule