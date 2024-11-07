/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rs_test.sv                                          //
//                                                                     //
//  Description :  Testbench module for the N-way RS module            //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

/*
    ASSUMPTIONS:
        - Infinite ROB
        - Infinite free list
*/

`include "sys_defs.svh"
`include "ISA.svh"

module RS_tb();

    parameter DEPTH = 32;
    parameter N = 3;
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic                               clock;
    logic                               reset;
    RS_PACKET   [N-1:0]                 rs_in;
    CDB_PACKET  [N-1:0]                 cdb_in;
    logic       [$clog2(N+1)-1:0]       num_accept;
    BR_MASK                             br_id;
    BR_TASK                             br_task;

    logic       [`NUM_FU_ALU-1:0]       fu_alu_busy;
    logic       [`NUM_FU_MULT-1:0]      fu_mult_busy;
    logic       [`NUM_FU_LD-1:0]        fu_ld_busy;
    logic       [`NUM_FU_STORE-1:0]     fu_store_busy;
    logic       [`NUM_FU_BR-1:0]        fu_br_busy;

    RS_PACKET   [`NUM_FU_ALU-1:0]       issued_alu;
    RS_PACKET   [`NUM_FU_MULT-1:0]      issued_mult;
    RS_PACKET   [`NUM_FU_LD-1:0]        issued_ld;
    RS_PACKET   [`NUM_FU_STORE-1:0]     issued_store;
    RS_PACKET   [`NUM_FU_BR-1:0]        issued_br;

    logic       [$clog2(DEPTH+1)-1:0]   open_entries;

    `ifdef DEBUG
        ROB_ENTRY_PACKET [DEPTH-1:0] debug_entries;
    `endif

    RS_PACKET model_rs[$:(DEPTH)];
    RS_PACKET decoded_inst_buffer[$:(DEPTH*2)];
    RS_PACKET issued_alu_buffer[$:(`NUM_FU_ALU)];
    RS_PACKET issued_mult_buffer[$:(`NUM_FU_MULT)];
    RS_PACKET issued_ld_buffer[$:(`NUM_FU_LD)];
    RS_PACKET issued_store_buffer[$:(`NUM_FU_STORE)];
    RS_PACKET issued_br_buffer[$:(`NUM_FU_BR)]; 

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
        .issued_alu(issued_alu), 
        .issued_mult(issued_mult),
        .issued_ld(issued_ld),
        .issued_store(issued_store),
        .issued_br(issued_br),
        .open_entries(open_entries)

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
        add_alu_ops(N);

        $display("@@@ PASSED ALL TESTS @@@");
        $finish;
    end


    // Correctness Verification
    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
    end

    // Helper function to clear inputs to RS
    function void clear_inputs();
        num_accept = 0;
        rs_in = 0;
        cdb_in = 0;
        br_id = 0;
        br_task = 0;
        fu_alu_busy = 0;
        fu_mult_busy = 0;
        fu_ld_busy = 0;
        fu_store_busy = 0;
    endfunction

    function void add_alu_ops(int num);
        RS_PACKET inst;
        for(int i=0;i<num;i++) begin
            inst.t  = '{reg_idx: 0, valid: 1};
            inst.t1 = '{reg_idx: 0, valid: 1, ready: 1};
            inst.t2 = '{reg_idx: 0, valid: 1, ready: 1};
            inst.b_mask = '0;
            inst.fu_type = ALU_INST;
            inst.pred_taken = 0;
        end
    endfunction

    function void dispatch_no_br();
        num_accept = N < DEPTH-model_rs.size() ? N : DEPTH-model_rs.size();

        for(int i=0;i<num_accept;i++) begin
            rs_in[i] = decoded_inst_buffer.pop_front();
            
        end
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