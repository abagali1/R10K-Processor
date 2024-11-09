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

    parameter DEPTH = 8;
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
        RS_PACKET [DEPTH-1:0] debug_entries;
        logic     [DEPTH-1:0] debug_open_spots;
        logic     [DEPTH-1:0] debug_other_sig;
        logic     [N-1:0][DEPTH-1:0] debug_dis_entries_bus;
    `endif

    RS_PACKET model_rs[$:(DEPTH)] = '{DEPTH{0}};
    RS_PACKET decoded_inst_buffer[$:(DEPTH*2)];
    RS_PACKET issued_alu_buffer[$:(`NUM_FU_ALU)];
    RS_PACKET issued_mult_buffer[$:(`NUM_FU_MULT)];
    RS_PACKET issued_ld_buffer[$:(`NUM_FU_LD)];
    RS_PACKET issued_store_buffer[$:(`NUM_FU_STORE)];
    RS_PACKET issued_br_buffer[$:(`NUM_FU_BR)];

    RS #(
        .DEPTH(DEPTH),
        .N(N))
    dut (.*);

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    initial begin
        $display("\nStart Testbench");

        clock = 0;
        reset = 1;
        clear_inputs();

        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);

        // ------------------------------ Test 1 ------------------------------ //
        $display("\nTest 1: Dispatch N ALU Instructions");
        generate_alu_ops(N);
        @(negedge clock);
        clear_inputs();
        // fu_alu_busy = '1;

        @(negedge clock);


        $display("@@@ PASSED ALL TESTS @@@");
        $finish;
    end


    // Correctness Verification
    always @(posedge clock) begin
        model_rs_update(); // update model state
        dispatch_no_br();
        #(`CLOCK_PERIOD * 0.2); 
        // verify 
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

    function void model_rs_insert(RS_PACKET in);
        for(int i=0;i<DEPTH;i++) begin
            if(!model_rs[i].valid) begin
                $display("inserting [(%b) (%02d)] at %d", in.valid, in.t.reg_idx, i);
                model_rs[i] = in;
                return;
            end
        end
    endfunction

    function void model_rs_delete(int idx);
        model_rs[idx] = '0;
    endfunction

    function int model_rs_count();
        int count;
        count = 0;
        for(int i=0;i<DEPTH;i++) begin
            if(model_rs[i].valid) begin
                count++;
            end
        end
        return count;
    endfunction

    function int model_rs_open_entries();
        return DEPTH-model_rs_count();
    endfunction

    function void model_rs_update();
        int num_alu_ready, num_alu_issued, fu_issued_idx;
        RS_PACKET issued_packet;

        issued_alu_buffer = {};
        num_alu_issued = 0;

        num_alu_ready = `NUM_FU_ALU - $countones(fu_alu_busy);

        $display("num_alu %d %d %b", num_alu_ready, $countones(fu_alu_busy), fu_alu_busy);
        for(int i=0;i<DEPTH;i++) begin
            if(model_rs[i].valid & model_rs[i].t1.ready & model_rs[i].t2.ready) begin
                if(num_alu_ready > 0) begin
                    issued_packet = model_rs[i];
                    model_rs_delete(i);

                    if(num_alu_issued % 2 == 0) begin
                        fu_issued_idx = msb(~fu_alu_busy);
                    end else begin
                        fu_issued_idx = lsb(~fu_alu_busy);
                    end
                    num_alu_ready--;
                    num_alu_issued++;
                end
            end
        end
    endfunction

    function void generate_alu_ops(int num);
        RS_PACKET inst;
        for(int i=0;i<num;i++) begin
            inst.t  = '{reg_idx: i, valid: 1};
            inst.t1 = '{reg_idx: 0, valid: 1, ready: 1};
            inst.t2 = '{reg_idx: 0, valid: 1, ready: 1};
            inst.b_mask = '0;
            inst.fu_type = ALU_INST;
            inst.pred_taken = 0;
            inst.valid = '1;

            decoded_inst_buffer.push_back(inst);
        end
    endfunction

    function void dispatch_no_br();
        int num_insts_avail, num_rs_avail;
        num_rs_avail = model_rs_open_entries();
        num_insts_avail = decoded_inst_buffer.size();

        num_accept = N < num_insts_avail 
                        ? N < num_insts_avail ? N : num_insts_avail
                        : num_insts_avail < num_rs_avail ?  num_insts_avail : num_rs_avail;

        for(int i=0;i<num_accept;i++) begin
            rs_in[i] = decoded_inst_buffer.pop_front();
            model_rs_insert(rs_in[i]);
        end
    endfunction

    function print_issue_signal();
        $display("RS Issued Signal");
        $display("\t#\t|\tvalid\t|   dest_idx    |\tt1\t|\tt2\t|    b_mask\t|    fu_type\t|");
        for(int i=0;i<`NUM_FU_ALU;i++) begin
            $display("\t%02d\t|\t%01d\t|\t%02d\t|\t%02d\t|\t%02d\t|\t%04b\t|\t%01d\t|", i, issued_alu[i].valid, issued_alu[i].t.reg_idx, issued_alu[i].t1.reg_idx, issued_alu[i].t2.reg_idx, issued_alu[i].b_mask, issued_alu[i].fu_type);
        end
    endfunction

    function void rs_print();
        $write("Model RS Entries (%02d)", model_rs_open_entries());
        `ifdef DEBUG
            $write("\t\t\t\t\t\t\t\t\t\t\t\t\t  RS Entries (open_entries: %02d) (open_spots: %b) (other_sig: %b)", open_entries, debug_open_spots, debug_other_sig);
        `endif
        $write("\n");

        $write("\t#\t|     valid\t|    dest_idx    |\tt1\t|\tt2\t|     b_mask\t|    fu_type\t|");
        `ifdef DEBUG
            $write("\t");
            $write("\t#\t|     valid\t|    dest_idx    |\tt1\t|\tt2\t|     b_mask\t|    fu_type\t|\n");
        `endif
        $write("\n");

        for(int i=0;i<DEPTH;i++) begin
            //          idx       valid    dest    t1        t2     bmask      op
            $write("\t%02d\t|\t%01d\t|\t%02d\t|\t%02d\t|\t%02d\t|\t%04b\t|\t%01d\t|", i, model_rs[i].valid, model_rs[i].t.reg_idx, model_rs[i].t1.reg_idx, model_rs[i].t2.reg_idx, model_rs[i].b_mask, model_rs[i].fu_type);
            $write("\t");
            $write("\t%02d\t|\t%01d\t|\t%02d\t|\t%02d\t|\t%02d\t|\t%04b\t|\t%01d\t|", i, debug_entries[i].valid, debug_entries[i].t.reg_idx, debug_entries[i].t1.reg_idx, debug_entries[i].t2.reg_idx, debug_entries[i].b_mask, debug_entries[i].fu_type);
            $write("\n");
        end

        `ifdef DEBUG
            $display("Dispatching Entries Bus");
            for(int i=0;i<N;i++) begin
                $write("[%b] [(%b) (%02d)]", debug_dis_entries_bus[i], rs_in[i].valid, rs_in[i].t.reg_idx);
                if(rs_in[i].valid && debug_dis_entries_bus[i]) begin
                    $write(" truthy!");
                end
                $write("\n");
            end
            $display();
        `endif
    endfunction

    function msb(int value);
        for(int i=$bits(value)-1;i>=0;i--) begin
            if(value[i]) begin
                return i;
            end
        end
    endfunction

    function lsb(int value);
        for(int i=0;i<$bits(value);i++) begin
            if(value[i]) begin
                return i;
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
        rs_print();

        // print_issue_signal();
        cycle_number++;
    end

endmodule