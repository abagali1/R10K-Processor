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

    parameter DEPTH = 16;
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
    MAP_TABLE_PACKET    [N-1:0]             r1_p_reg;
    MAP_TABLE_PACKET    [N-1:0]             r2_p_reg;
    MAP_TABLE_PACKET    [DEPTH:0]           out_mt; // output map table for architectural mt

    MAP_TABLE_PACKET [DEPTH:0] mt_model;
    PHYS_REG_IDX free_list_model [$:(DEPTH)];
    TEST_INST inst_buf [$:((DEPTH)*2)];
    TEST_READY ready_buf [$:((DEPTH)*2)];

    PHYS_REG_IDX [N-1:0] t_old_data_model;
    MAP_TABLE_PACKET [N-1:0] r1_p_reg_model;
    MAP_TABLE_PACKET [N-1:0] r2_p_reg_model;
    
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

    // TEST 5 Variables
    TEST_INST inst1, inst2;
    PHYS_REG_IDX fl1, fl2;

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
        set_insts(1);
        @(negedge clock);
        clear_inputs();

        $display("Set Instruction to ready");
        set_ready(1);
        @(negedge clock);
        clear_inputs();

        $display("PASSED TEST 2");

        // ------------------------------ Test 3 ------------------------------ //
        $display("\nTest 3: Read/Write then Ready DEPTH instructions");
        generate_insts(DEPTH);

        $display("Input DEPTH instructions");
        while (inst_buf.size() > 0) begin
            set_insts(N);
            @(negedge clock);
            clear_inputs();
        end

        $display("Set DEPTH instructions to ready");
        while (ready_buf.size() > 0) begin
            set_ready(N);
            @(negedge clock);
            clear_inputs();
        end

        $display("PASSED TEST 3");

        // ------------------------------ Test 4 ------------------------------ //
        $display("\nTest 4: Read/Write/Ready concurrently DEPTH instructions");
        generate_insts(DEPTH);

        $display("DEPTH instructions");
        while (inst_buf.size() > 0) begin
            set_insts(N);
            @(negedge clock);
            clear_inputs();
            set_ready(N);
        end

        $display("PASSED TEST 4");

        if (N > 1) begin
            // ------------------------------ Test 5 ------------------------------ //
            
            $display("\nTest 5: Read/Write Dependent Instructions");
            generate_dependent_insts(2); // both insts are r1 = r1 + r1

            r1_p_reg_model = '0;
            r2_p_reg_model = '0;
            t_old_data_model = '0;

            inst1 = inst_buf[0];
            inst2 = inst_buf[1];
            fl1 = free_list_model[0];
            fl2 = free_list_model[1];

            r1_p_reg_model[0] = mt_model[inst1.r1];
            r2_p_reg_model[0] = mt_model[inst1.r2];
            t_old_data_model[0] = mt_model[inst1.dr];

            r1_p_reg_model[1] = fl1;
            r2_p_reg_model[1] = fl1;
            t_old_data_model[1] = fl1;

            set_insts(2);
            @(negedge clock);
            clear_inputs();

            if (t_old_data_model !== t_old_data) begin
                $error("@@@ FAILED @@@");
                $error("Test Error: Model t_old_data mismatch, expected:");
                for (int i = 0; i < N; i++) begin
                    $display("   [%0d] but got [%0d]", t_old_data_model[i], t_old_data[i]);
                end
                $finish;
            end
            if (r1_p_reg_model !== r1_p_reg) begin
                $error("@@@ FAILED @@@");
                $error("Test Error: Model r1_p_reg mismatch, expected [%0d] but got [%0d]", r1_p_reg_model, r1_p_reg);
                $finish;
            end
            if (r2_p_reg_model !== r2_p_reg) begin
                $error("@@@ FAILED @@@");
                $error("Test Error: Model r2_p_reg mismatch, expected [%0d] but got [%0d]", r2_p_reg_model, r2_p_reg);
                $finish;
            end

            $display("PASSED TEST 5");
        end
        



        $display("@@@ PASSED ALL TESTS @@@");
        $finish;
    end


    // Correctness Verification
    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
        if (reset === 0) begin
            check_mt();
            add_to_fl();
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

    function void add_to_fl();
        for (int i = 0; i < N; i++) begin
            if (t_old_data[i] !== 0) begin
                free_list_model.push_back(t_old_data[i]);
                $display("ADD_TO_FL: adding %0d back to free list", t_old_data[i]);
            end
        end
    endfunction

    function void generate_insts(int num);
        PHYS_REG_IDX count;
        clear_queues();
        count = 1;
        for (int i = 0; i < num; i++) begin
            if (count > DEPTH - 2) begin
                count = 1;
            end
            inst_buf.push_back('{count, count+1, count+2});
            count += 3;
        end
    endfunction

    function void generate_dependent_insts(int num);
        clear_queues();
        for (int i = 0; i < num; i++) begin
            inst_buf.push_back('{1, 1, 1});
        end
    endfunction

    function void clear_queues();
        while (inst_buf.size() > 0) begin
            inst_buf.pop_front();
        end
        while (ready_buf.size() > 0) begin
            ready_buf.pop_front();
        end
    endfunction

    function void set_insts(int num_in);
        TEST_INST inst;
        int num;
        num = inst_buf.size() > num_in ? num_in: inst_buf.size();
        //$display("INST SIZE: %0d", num);
        for (int i = 0; i < num; i++) begin
            inst = inst_buf.pop_front();
            free_reg[i] = free_list_model[0];
            ready_buf.push_back('{arch_idx: inst.dr, phys_idx: free_list_model[0]});

            r1_idx[i] = inst.r1;
            r2_idx[i] = inst.r2;
            dest_reg_idx[i] = inst.dr;
            incoming_valid[i] = 1;

            mt_model[inst.dr] = '{free_list_model.pop_front(), 0, 1};
        end
    endfunction

    function void set_ready(int num_in);
        TEST_READY r_pack;
        int num;
        num = ready_buf.size() > num_in ? num_in : ready_buf.size();
        for (int i = 0; i < num; i++) begin
            r_pack = ready_buf.pop_front();
            ready_reg_idx[i] = r_pack.arch_idx;
            ready_phys_idx[i] = r_pack.phys_idx;
            ready_valid[i] = 1;
            if (mt_model[r_pack.arch_idx].reg_idx == r_pack.phys_idx) begin
                mt_model[r_pack.arch_idx].ready = 1;
            end
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
        PHYS_REG_IDX i;
        int taken;
        while (free_list_model.size() > 0) begin
            free_list_model.pop_front();
        end
        i = 1;
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

        $display("   r1_p_reg:");
        for (int i = 0; i < N; i++) begin
            $display("      reg_idx=%0d   ready=%0d   valid=%0d", r1_p_reg[i].reg_idx, r1_p_reg[i].ready, r1_p_reg[i].valid);
        end
        $display("");

        $display("   r2_p_reg:");
        for (int i = 0; i < N; i++) begin
            $display("      reg_idx=%0d   ready=%0d   valid=%0d", r2_p_reg[i].reg_idx, r2_p_reg[i].ready, r2_p_reg[i].valid);
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