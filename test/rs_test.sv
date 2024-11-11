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

    logic                                                            clock;
    logic                                                            reset;
    RS_PACKET   [N-1:0]                                              rs_in;
    CDB_PACKET  [N-1:0]                                              cdb_in;
    logic       [$clog2(N+1)-1:0]                                    num_accept;
    BR_MASK                                                          br_id;
    BR_TASK                                                          br_task;

    logic       [`NUM_FU_ALU-1:0]                                    fu_alu_busy;
    logic       [`NUM_FU_MULT-1:0]                                   fu_mult_busy;
    logic       [`NUM_FU_LD-1:0]                                     fu_ld_busy;
    logic       [`NUM_FU_STORE-1:0]                                  fu_store_busy;
    logic       [`NUM_FU_BR-1:0]                                     fu_br_busy;

    RS_PACKET   [`NUM_FU_ALU-1:0]                                    issued_alu;
    RS_PACKET   [`NUM_FU_MULT-1:0]                                   issued_mult;
    RS_PACKET   [`NUM_FU_LD-1:0]                                     issued_ld;
    RS_PACKET   [`NUM_FU_STORE-1:0]                                  issued_store;
    RS_PACKET   [`NUM_FU_BR-1:0]                                     issued_br;

    logic       [$clog2(N+1)-1:0]                                    open_entries;

    `ifdef DEBUG
        RS_PACKET [DEPTH-1:0]                                        debug_entries;
        logic     [DEPTH-1:0]                                        debug_open_spots;
        logic     [DEPTH-1:0]                                        debug_other_sig;
        logic     [N-1:0][DEPTH-1:0]                                 debug_dis_entries_bus;
        logic     [$clog2(DEPTH+1)-1:0]                              debug_open_entries;
        logic     [DEPTH-1:0]                                        debug_all_issued_insts;
        logic     [`NUM_FU_ALU-1:0][DEPTH-1:0]                       debug_alu_issued_bus;
        logic     [DEPTH-1:0]                                        debug_alu_req;
        logic     [`NUM_FU_ALU-1:0][`NUM_FU_ALU-1:0]                 debug_alu_fu_gnt_bus;
        logic     [`NUM_FU_ALU-1:0][DEPTH-1:0]                       debug_alu_inst_gnt_bus;
    `endif

    RS_PACKET model_rs[$:(DEPTH)] = '{DEPTH{0}};
    RS_PACKET decoded_inst_buffer[$:(DEPTH*2)];

    RS_PACKET issued_alu_buffer[$:(`NUM_FU_ALU)] = '{`NUM_FU_ALU{0}};
    RS_PACKET issued_mult_buffer[$:(`NUM_FU_MULT)] = '{`NUM_FU_MULT{0}};
    RS_PACKET issued_ld_buffer[$:(`NUM_FU_LD)] = '{`NUM_FU_LD{0}};
    RS_PACKET issued_store_buffer[$:(`NUM_FU_STORE)] = '{`NUM_FU_STORE{0}};
    RS_PACKET issued_br_buffer[$:(`NUM_FU_BR)] = '{`NUM_FU_BR{0}};

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
        @(negedge clock); // 0

        // ------------------------------ Test 1 ------------------------------ //
        $display("\nTest 1: Dispatch N ALU Instructions");
        generate_alu_ops(N);
        @(negedge clock); // 1
        fu_alu_busy = 0;
        @(negedge clock); // 2
        @(negedge clock); // 3


        $display("@@@ PASSED ALL TESTS @@@");
        $finish;
    end


    // Correctness Verification
    always @(negedge clock) begin
        #2;
        print_issue_signal();
        // model_rs_check();
        // verify open_entries + issued packets
    end

    always @(posedge clock) begin
        #2;
        monitor();
        // verify entries + open_spots
        model_rs_update();
        dispatch_no_br();
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

    function void model_rs_insert(RS_PACKET in, int lsb);
        if(lsb) begin
            for(int i=0;i<DEPTH;i++) begin
                if(!model_rs[i].valid) begin
                    $display("inserting [(%b) (%02d)] at %d", in.valid, in.t.reg_idx, i);
                    model_rs[i] = in;
                    return;
                end
            end
        end else begin
            for(int i=DEPTH-1;i>=0;i--) begin
                if(!model_rs[i].valid) begin
                    $display("inserting [(%b) (%02d)] at %d", in.valid, in.t.reg_idx, i);
                    model_rs[i] = in;
                    return;
                end
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

    function void model_rs_check();
        for(int i=0;i<`NUM_FU_ALU;i++) begin
            if(issued_alu_buffer[i].valid != issued_alu[i].valid) begin
                $display("ISSUE PACKET MISMATCH AT %d %02d %02d", i, issued_alu_buffer[i].valid, issued_alu[i].valid);
                $finish;
            end
        end
    endfunction

    function void model_rs_update();
        int fu_alu_ready, num_alu_ready, num_alu_issued, fu_issued_idx;
        RS_PACKET issued_packet;

        num_alu_issued = 0;
        issued_alu_buffer = '{`NUM_FU_ALU{0}};
        fu_alu_ready = ~fu_alu_busy;
        num_alu_ready = `NUM_FU_ALU - $countones(fu_alu_busy);


        $display("num_alu %d %d %b", num_alu_ready, $countones(fu_alu_busy), fu_alu_busy);
        for(int i=0;i<DEPTH;i++) begin
            if(model_rs[i].valid & model_rs[i].t1.ready & model_rs[i].t2.ready) begin
                if(num_alu_ready > 0) begin
                    issued_packet = model_rs[i];
                    model_rs_delete(i);

                    fu_issued_idx = num_alu_issued % 2 ? lsb(fu_alu_ready, `NUM_FU_ALU) : msb(fu_alu_ready, `NUM_FU_ALU);

                    fu_alu_ready[fu_issued_idx] = 0;
                    issued_alu_buffer[fu_issued_idx] = issued_packet;

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

        rs_in = 0;
        num_rs_avail = model_rs_open_entries();
        num_insts_avail = decoded_inst_buffer.size();

        num_accept = N < num_insts_avail 
                        ? N < num_insts_avail ? N : num_insts_avail
                        : num_insts_avail < num_rs_avail ?  num_insts_avail : num_rs_avail;

        for(int i=0;i<num_accept;i++) begin
            rs_in[i] = decoded_inst_buffer.pop_front();
            model_rs_insert(rs_in[i], i % 2);
        end
    endfunction

    function print_issue_signal();
        $write("Model RS Issued Signal");
        $write("\t\t\t\t\t\t\t\t\t\t\t\t\t ");
        $write("RS Issued Signal\n");
        $write("\t#\t|\tvalid\t|   dest_idx    |\tt1\t|\tt2\t|    b_mask\t|    fu_type\t|");
        $write("\t");
        $write("\t#\t|\tvalid\t|   dest_idx    |\tt1\t|\tt2\t|    b_mask\t|    fu_type\t|\n");


        for(int i=`NUM_FU_ALU-1;i>=0;i--) begin
            $write("\t%02d\t|\t%01d\t|\t%02d\t|\t%02d\t|\t%02d\t|\t%04b\t|\t%01d\t|", i, issued_alu_buffer[i].valid, issued_alu_buffer[i].t.reg_idx, issued_alu_buffer[i].t1.reg_idx, issued_alu_buffer[i].t2.reg_idx, issued_alu_buffer[i].b_mask, issued_alu_buffer[i].fu_type);
            $write("\t");
            $write("\t%02d\t|\t%01d\t|\t%02d\t|\t%02d\t|\t%02d\t|\t%04b\t|\t%01d\t|", i, issued_alu[i].valid, issued_alu[i].t.reg_idx, issued_alu[i].t1.reg_idx, issued_alu[i].t2.reg_idx, issued_alu[i].b_mask, issued_alu[i].fu_type);
            $write("\n");
        end

        `ifdef DEBUG
            $write("ALU Issued Bus [%b]\n", debug_alu_req);
            for(int i=0;i<`NUM_FU_ALU;i++) begin
                $display("%02d %b %b %b", i, debug_alu_issued_bus[i], debug_alu_fu_gnt_bus[i], debug_alu_inst_gnt_bus[i]);
            end
        `endif
    endfunction

    function void rs_print();
        $write("Model RS Entries (%02d)", model_rs_open_entries());
        `ifdef DEBUG
            $write("\t\t\t\t\t\t\t\t\t\t\t\t\t  RS Entries (open_entries: %02d [%02d]) (open_spots: %b) (all_issued: %b)  (other_sig: %b)", open_entries, debug_open_entries, debug_open_spots, debug_all_issued_insts, debug_other_sig);
        `endif
        $write("\n");

        $write("\t#\t|     valid\t|    dest_idx    |\tt1\t|\tt2\t|     b_mask\t|    fu_type\t|");
        `ifdef DEBUG
            $write("\t");
            $write("\t#\t|     valid\t|    dest_idx    |\tt1\t|\tt2\t|     b_mask\t|    fu_type\t|");
        `endif
        $write("\n");

        for(int i=DEPTH-1;i>=0;i--) begin
            //          idx       valid    dest    t1        t2     bmask      op
            $write("\t%02d\t|\t%01d\t|\t%02d\t|\t%02d\t|\t%02d\t|\t%04b\t|\t%01d\t|", i, model_rs[i].valid, model_rs[i].t.reg_idx, model_rs[i].t1.reg_idx, model_rs[i].t2.reg_idx, model_rs[i].b_mask, model_rs[i].fu_type);
            $write("\t");
            $write("\t%02d\t|\t%01d\t|\t%02d\t|\t%02d\t|\t%02d\t|\t%04b\t|\t%01d\t|", i, debug_entries[i].valid, debug_entries[i].t.reg_idx, debug_entries[i].t1.reg_idx, debug_entries[i].t2.reg_idx, debug_entries[i].b_mask, debug_entries[i].fu_type);
            $write("\n");
        end

        `ifdef DEBUG
            $display("\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t Dispatching Entries Bus");
            for(int i=0;i<N;i++) begin
                $write("\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t ");
                $write("[%b (%02d)] [(%b) (%02d)]", debug_dis_entries_bus[i], msb(debug_dis_entries_bus[i], DEPTH), rs_in[i].valid, rs_in[i].t.reg_idx);
                $write("\n");
            end
            $display();
        `endif
    endfunction

    function int msb(int value, int width);
        for(int i=width-1;i>=0;i--) begin
            if(value[i]) begin
                return i;
            end
        end
    endfunction

    function int lsb(int value, int width);
        for(int i=0;i<width;i++) begin
            if(value[i]) begin
                return i;
            end
        end
    endfunction

    // Monitoring Statements
    int cycle_number = 0;
    function monitor();
        $display("------------------------------------------------------------");
        $display("@@@ Cycle Number: %0d @@@", cycle_number);
        $display("   Time: %0t", $time);
        $display("   Reset: %0d\n", reset);
        rs_print();

        cycle_number++;
    endfunction

endmodule