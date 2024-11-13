/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  br_stack_test.sv                                    //
//                                                                     //
//  Description :  Testbench module for the br_stack                   //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////
// for noop shouldn't assign b_id should be 0s
`include "sys_defs.svh"
`include "ISA.svh"

module br_stack_tb();

    parameter DEPTH = `BRANCH_PRED_SZ;
    parameter N = 2;
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic                                                       clock;
    logic                                                       reset;
    DECODED_PACKET                                              dis_inst; 
    ADDR                                                        in_PC;
    MAP_TABLE_PACKET        [`ARCH_REG_SZ-1:0]                  in_mt;
    logic                   [$clog2(`ROB_SZ+1)-1:0]             in_fl_head;
    logic                   [$clog2(`PHYS_REG_SZ_R10K)-1:0]     in_rob_tail;

    CDB_PACKET              [N-1:0]                             cdb_in;
    BR_TASK                                                     br_task;
    logic                   [DEPTH-1:0]                         rem_b_id;

    logic                   [DEPTH-1:0]                         assigned_b_id;
    CHECKPOINT                                                  cp_out;
    logic                                                       full;

    `ifdef DEBUG
        CHECKPOINT [DEPTH-1:0] debug_entries;
        CHECKPOINT [DEPTH-1:0] debug_free_entries;
        logic [DEPTH-1:0] debug_stack_gnt;
    `endif

    CHECKPOINT [DEPTH-1:0] model_entries;
    ADDR test_in_PC;
    MAP_TABLE_PACKET [`ARCH_REG_SZ-1:0]  test_in_mt;  
    logic [$clog2(`ROB_SZ+1)-1:0] test_in_fl_head;
    logic [$clog2(`PHYS_REG_SZ_R10K)-1:0] test_in_rob_tail;
    DECODED_PACKET dis_inst_temp;
   
    br_stack #(
        .DEPTH(DEPTH),
        .N(N)
    )
    dut (
        .clock(clock),
        .reset(reset),
        .dis_inst(dis_inst),  
        .in_PC(in_PC),  
        .in_mt(in_mt),  
        .in_rob_tail(in_rob_tail),  
        .cdb_in(cdb_in),  
        .br_task(br_task),   
        .rem_b_id(rem_b_id),   
        
        .assigned_b_id(assigned_b_id),
        .cp_out(cp_out),
        .full(full)

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

        dis_inst_temp = '0;
        test_in_PC = '0;
        test_in_mt = '0;  
        test_in_fl_head = '0;
        test_in_rob_tail = '0;
        
        // ------------------------------ Test 1 ------------------------------ //
        $display("\nTest 1: Test Checkpoint Coming In\n");
        // send in checkpoint and check all the outputs are correct
        
        clear_inputs();
        @(negedge clock);  

        // test_in_PC = '0;

        // test_in_mt[0] = {13, 1, 1};
        // test_in_mt[1] = {14, 1, 1}; 
        // test_in_mt[2] = {15, 1, 1};   

        // test_in_fl_head = 5'b00001;
        // test_in_rob_tail = 6'b000100;

        // dis_inst_temp.uncond_branch = 1;
        // dis_inst_temp.valid = 1;

        in_PC = 0;

        in_mt[0] = {32'd13, 1'b1, 1'b1};
        in_mt[1] = {32'd14, 1'b1, 1'b1}; 
        in_mt[2] = {32'd15, 1'b1, 1'b1};   

        in_fl_head = 5'b00001;
        in_rob_tail = 6'b000100;


        dis_inst.uncond_branch = 1;
        dis_inst.valid = 1;

        //add_checkpoint(test_in_PC, test_in_mt, test_in_fl_head, test_in_rob_tail, dis_inst_temp); 

        @(negedge clock);  
        @(negedge clock);  

        dis_inst.uncond_branch = 0;
        dis_inst.valid = 0;

        @(negedge clock);  

        // ------------------------------ Test 2 ------------------------------ //
        $display("\nTest 2: Squash Branch, Check Dependent Checkpoints\n");
        
        // if you squash the first branch that came in, 
        // it should get rid of all the dependent checkpoints

        // add in 2 checkpoints (two branches?)
        // squash the first branch

        // check that all checkpoints = 0

        // probably will need to add in debug signals to view all the checkpoints at any given time
        // also maybe output a signal from the psel about which checkpoint idx to check in test bench

        // ------------------------------ Test 3 ------------------------------ //
         $display("\nTest 3: Clear Checkpoint, Check Bits in other Checkpoints\n");
        
        // if you clear one of the checkpoints, it should get rid of the 
        // corresponding bits in all of the masks of the other checkpoints

        // add in 3 checkpoints with different branch_ids but one is  
        // clear the second one

        // ------------------------------ Test 4 ------------------------------ //
        $display("\nTest 4: CDB Outputs Register\n");
        // when cdb outputs a register that's updated, recover maptable in 
        // checkpoint should also update

        // ------------------------------ Test 5 ------------------------------ //
         $display("\nTest 5: Squash and Take in New Checkpoint\n");
        // squash and try to take in a new checkpoint

        // ------------------------------ Test 6 ------------------------------ //
         $display("\nTest 6: Clear Checkpoint, Add in a New One\n");
        // when you clear a checkpoint and add in a new one,
        //  want to make sure the bit mask is correct

        $finish;
    end

    int cycle_number = 0;
    // Correctness Verification
    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
        print_entries();
        //print_model_entries();
        // print_stack_gnt();
        // check_entries();
        $display("\n@@@ FINISHED CYCLE NUMBER: %0d @@@ \n", cycle_number);
        cycle_number++;
    end

// updating

function void clear_inputs();
    in_PC = '0;
    in_mt = '0;  
    in_rob_tail = '0;
    cdb_in = '0;
    br_task = '0;
    rem_b_id = '0;
endfunction

function void add_checkpoint(ADDR test_in_PC, MAP_TABLE_PACKET [`ARCH_REG_SZ-1:0] test_in_mt, logic [$clog2(`ROB_SZ+1)-1:0] test_in_fl_head, logic [$clog2(`PHYS_REG_SZ_R10K)-1:0] test_in_rob_tail, DECODED_PACKET dis_inst_temp);
    //stack_gnt = data.b_id;
    in_PC = test_in_PC;
    in_mt = test_in_mt;
    in_fl_head = test_in_fl_head;
    in_rob_tail = test_in_rob_tail;
    dis_inst = dis_inst_temp;
endfunction
    
function void set_task(BR_TASK tasky);
    br_task = tasky;
endfunction

// checking

function void check_free_entries(logic free);
    if (debug_free_entries != free) begin
        $error("@@@ FAILED @@@");
        $error("Check free entry error: expected %0d, but got %0d", free, debug_free_entries);
        $finish;
    end
endfunction

function void check_entries();
    for (int i = 0; i < DEPTH; i++) begin
        if (model_entries[i].b_id != debug_entries[i].b_id) begin
            $error("@@@ FAILED @@@");
            $error("Check entry error: expected %0d, but got %0d", model_entries[i].b_id, debug_entries[i].b_id);
            $finish;
        end
        if (model_entries[i].b_mask != debug_entries[i].b_mask) begin
            $error("@@@ FAILED @@@");
            $error("Check entry error: expected %0d, but got %0d", model_entries[i].b_mask, debug_entries[i].b_mask);
            $finish;
        end
        if (model_entries[i].rec_PC != debug_entries[i].rec_PC) begin
            $error("@@@ FAILED @@@");
            $error("Check entry error: expected %0d, but got %0d", model_entries[i].rec_PC, debug_entries[i].rec_PC);
            $finish;
        end
        if (model_entries[i].fl_head != debug_entries[i].fl_head) begin
            $error("@@@ FAILED @@@");
            $error("Check entry error: expected %0d, but got %0d", model_entries[i].fl_head, debug_entries[i].fl_head);
            $finish;
        end
        if (model_entries[i].rob_tail != debug_entries[i].rob_tail) begin
            $error("@@@ FAILED @@@");
            $error("Check entry error: expected %0d, but got %0d", model_entries[i].rob_tail, debug_entries[i].rob_tail);
            $finish;
        end
    end
endfunction

// printing

function void print_entries();
    $display("\nEntries\n");
    for (int i = 0; i < DEPTH; i++) begin
        $display("index: %0d, b_id: %0d, b_mask: %0d, rec_PC: %0d, fl_head: %0d, rob_tail: %0d", i, dut.next_entries[i].b_id, dut.next_entries[i].b_mask, dut.next_entries[i].rec_PC, dut.next_entries[i].fl_head, dut.next_entries[i].rob_tail);
    end
endfunction

function void print_model_entries();
    $display("\nModel Entries\n");
    for (int i = 0; i < DEPTH; i++) begin
        $display("index: %0d, b_id: %0d, b_mask: %0d, rec_PC: %0d, fl_head: %0d, rob_tail: %0d", i, model_entries[i].b_id, model_entries[i].b_mask, model_entries[i].rec_PC, model_entries[i].fl_head, model_entries[i].rob_tail);
    end
endfunction

function void print_free_entries();
    $display("\nFree Entries: %0d", debug_free_entries);
endfunction

function void print_br_task();
    $display("\nBR Task: %0d", br_task);
endfunction

// can use to print out cp_out
function void print_checkpoint(CHECKPOINT data);
    $display("\nCheckpoints\n");
    $display("b_id: %0d, b_mask: %0d, rec_PC: %0d, fl_head: %0d, rob_tail: %0d\n", data.b_id, data.b_mask, data.rec_PC, data.fl_head, data.rob_tail);
endfunction

function void print_stack_gnt();
    $display("\nStack Grant");
    for (int i = 0; i < DEPTH; i++) begin
        $display("%0d ", debug_stack_gnt[i]);
    end
endfunction

endmodule


// if you squash the first branch that came in, it should get rid of all the checkpoints
// if you clear one of the checkpoints, it should get rid of the corresponding bits in all of the masks of the other checkpoints
// when cdb outputs a register that's updated, recover maptable in checkpoint should also update
// squash and try to take in a new checkpoint
// when you clear a checkpoint and add in a new one, want to make sure the bit mask is correct


