/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  br_stack_test.sv                                    //
//                                                                     //
//  Description :  Testbench module for the br_stack                   //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module br_stack_tb();

    parameter DEPTH = `ROB_SZ;
    parameter N = 2;
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic                                                       clock;
    logic                                                       reset;
    logic                                                       valid_assign; 
    ADDR                                                        in_PC;
    MAP_TABLE_PACKET        [`ARCH_REG_SZ-1:0]                  in_mt;
    logic                   [$clog2(`ROB_SZ+1)-1:0]             in_fl_head;
    logic                   [$clog2(`PHYS_REG_SZ_R10K)-1:0]     in_rob_tail;

    CDB_PACKET              [N-1:0]                             cdb_in;
    BR_TASK                                                     br_task;
    logic                   [DEPTH-1:0]                         rem_b_id;

    CHECKPOINT                                                  cp_out;
    logic                                                       full;


    // CHECKPOINT [DEPTH-1] branch_stack_model;

   

    BR_STACK #(
        .DEPTH(DEPTH),
        .N(N)
    )
    dut (
        .clock(clock),
        .reset(reset),
        .valid_assign(valid_assign),  
        .in_PC(in_PC),  
        .in_mt(in_mt),  
        .in_rob_tail(in_rob_tail),  
        .cdb_in(cdb_in),  
        .br_task(br_task),   
        .rem_b_id(rem_b_id),   
        
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
        // initialize inputs to 0/null/default/nothing

        @(negedge clock);
        @(negedge clock);
        reset = 0;
        

        // ------------------------------ Test 1 ------------------------------ //
        $display("Running Test 1");
        // if you squash the first branch that came in, 
        // it should get rid of all the checkpoints

        // add in 2 checkpoints (two branches?)
        // squash the first branch

        // check that all checkpoints = 0

        // probably will need to add in debug signals to view all the checkpoints at any given time
        // also maybe output a signal from the psel about which checkpoint idx to check in test bench





        // ------------------------------ Test 2 ------------------------------ //
        $display("Running Test 2");
        // if you clear one of the checkpoints, it should get rid of the 
        // corresponding bits in all of the masks of the other checkpoints

        // add in 3 checkpoints with different branch_ids but one is  
        // clear the second one





        
        // ------------------------------ Test 3 ------------------------------ //
        $display("Running Test 3");
        // when cdb outputs a register that's updated, recover maptable in 
        // checkpoint should also update



        // ------------------------------ Test 4 ------------------------------ //
        $display("Running Test 4");
        // squash and try to take in a new checkpoint


        
        // ------------------------------ Test 4 ------------------------------ //
        $display("Running Test 5");
        // when you clear a checkpoint and add in a new one,
        //  want to make sure the bit mask is correct


        $finish;

    end

    int cycle_number = 0;
    // Correctness Verification
    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
        // print_model();
        // print_free_list();
        // $display("rd_num: %d\n", rd_num);
        // check_entries();
        $display("@@@ FINISHED CYCLE NUMBER: %0d @@@ \n", cycle_number);
        cycle_number++;
    end
endmodule


function void clear_inputs();
    valid_assign = '0  
    in_PC = '0
    in_mt = '0  
    in_rob_tail = '0
    cdb_in = '0
    br_task = '0
    rem_b_id = '0

endfunction

function 

function void add_checkpoint(CHECKPOINT data);
        


endfunction




// if you squash the first branch that came in, it should get rid of all the checkpoints
// if you clear one of the checkpoints, it should get rid of the corresponding bits in all of the masks of the other checkpoints
// when cdb outputs a register that's updated, recover maptable in checkpoint should also update
// squash and try to take in a new checkpoint
// when you clear a checkpoint and add in a new one, want to make sure the bit mask is correct


