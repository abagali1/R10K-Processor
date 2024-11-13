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

    parameter N = 5; // Number of instructions per dispatch

    localparam LOG_N = $clog2(N+1);

    logic                                  clock;
    logic                                  reset;
    INST_PACKET              [N-1:0]       insts;
    logic                                  bs_full;
    logic                    [LOG_N-1:0]   rob_open;
    logic                    [LOG_N-1:0]   rs_open;

    logic                    [LOG_N-1:0]   num_dispatch;
    DECODED_PACKET           [N-1:0]       out_insts;

    `ifdef DEBUG
        logic [$clog2(N+1)-1:0] debug_num_valid_inst;
    `endif

    //INST_PACKET [$:(N)] dispatch_model;
    INST_PACKET [N-1:0] insts_temp; 
    INST instruction = 32'h00000013;
    ADDR pc; 
    ADDR npc; 

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

        `ifdef DEBUG
        , .debug_num_valid_inst(debug_num_valid_inst)
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
        pc = 0;
        npc = 4;
        @(negedge clock);

        reset = 0;
        insts_temp = '0;

        // population instructions
        for (int i = 0; i < N; i++) begin            
            insts_temp[i].inst = instruction;
            insts_temp[i].PC = pc;
            insts_temp[i].NPC = npc;
            insts_temp[i].valid = 1;
            instruction = instruction + 2;
            pc = pc + 4;
        end
        
        // ------------------------------ Test 1 ------------------------------ //
        $display("\nTest 1: Dispatch Min of Instructions");
        
        // N valid instructions
        // rob_open = 2
        // rs_open = 3
        // bs_full = 0
        // so should dispatch 2!

        rob_open = 2;
        rs_open = 3;
        bs_full = 0;
        insts = insts_temp;
        print_in_insts();
        print_other_inputs();
        @(negedge clock);
        @(negedge clock);
        rob_open = 0;
        rs_open = 0;
        bs_full = 0;

        $display("PASSED TEST 1");

        // ------------------------------ Test 2 ------------------------------ //
        $display("\nTest 2:");

        reset = 1;
        @(negedge clock);
        reset = 0;

        // N valid instructions
        // first instruction is branch
        // rob_open = 2
        // rs_open = 3
        // bs_full = 1
        // so should dispatch nothing!

        rob_open = 2;
        rs_open = 3;
        bs_full = 0;
        insts = insts_temp;
        print_in_insts();
        print_other_inputs();
        @(negedge clock);
        @(negedge clock);
        rob_open = 0;
        rs_open = 0;
        bs_full = 0;

        $display("PASSED TEST 2");

        // ------------------------------ Test 3 ------------------------------ //
        $display("\nTest 3:");

        // N valid instructions
        // first instruction is branch
        // rob_open = 4
        // rs_open = 3
        // bs_full = 0
        // so should dispatch up to 3;

        $display("PASSED TEST 3");

        // ------------------------------ Test 4 ------------------------------ //
        $display("\nTest 4:");

        // N valid instructions
        // third instruction is branch
        // rob_open = 4
        // rs_open = 3
        // bs_full = 0
        // so should dispatch up to branch, two instructions;

        $display("PASSED TEST 4");

        $finish;
    end

    int cycle_number = 0;
    always @(posedge clock) begin     
        #(`CLOCK_PERIOD * 0.2);
        print_out_insts();
        print_num_dispatch();
        print_other_inputs();
        $display("@@@ FINISHED CYCLE NUMBER: %0d @@@ \n", cycle_number);
        cycle_number++;
    end

    // functions



    // print

    function void print_in_insts();
        $display("input instructions");
        for (int i = 0; i < N; i++) begin
            $display("i: %0d, inst: %0d, pc: %0d", i, insts[i].inst, insts[i].PC);
        end
    endfunction

    function void print_out_insts();
        $display("output instructions");
        for (int i = 0; i < N; i++) begin
            $display("i: %0d, inst: %0d, pc: %0d", i, out_insts[i].inst, out_insts[i].PC);
        end
    endfunction

    function void print_num_dispatch();
        $display("num_dispatch: %0d\n", num_dispatch);
    endfunction

    function void print_other_inputs();
        $display("\nrob_open: %0d", rob_open);
        $display("rs_open: %0d", rs_open);
        $display("bs_full: %0d", bs_full);
        $display("valid_inst: %0d\n", dut.num_valid_inst);
    endfunction

endmodule