/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rob_test.sv                                   //
//                                                                     //
//  Description :  Testbench module for the N-way ROB module           //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module ROB_tb();

    parameter DEPTH = 8;
    parameter WIDTH = 32;
    parameter N = 3;
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic                                  clock;
    logic                                  reset;
    ROB_ENTRY_PACKET [N-1:0]               wr_data;
    PHYS_REG_IDX     [N-1:0]               complete_t;
    logic            [$clog2(N+1)-1:0]     num_accept;
    ROB_ENTRY_PACKET [N-1:0]               retiring_data;
    logic            [$clog2(DEPTH+1)-1:0] open_entries;
    logic            [$clog2(N+1)-1:0]     num_retired;

    `ifdef DEBUG
        ROB_ENTRY_PACKET [DEPTH-1:0]     entry_data;
        logic            [LOG_DEPTH-1:0] debug_head;
        logic            [LOG_DEPTH-1:0] debug_tail;
    `endif

    ROB_ENTRY_PACKET rob_model [$:(DEPTH)];
    ROB_ENTRY_PACKET inst_buf [$:(DEPTH*2)];
    PHYS_REG_IDX complete_queue [$:(DEPTH)];

    ROB_ENTRY_PACKET empty_packet = '{op_code: 0, t: 0, t_old: 0, complete: 0, valid: 0};

    ROB #(
        .DEPTH(DEPTH),
        .N(N))
    dut (
        .clock(clock),
        .reset(reset),
        .wr_data(wr_data),
        .complete_t(complete_t),
        .num_accept(num_accept),

        .retiring_data(retiring_data),
        .open_entries(open_entries),
        .num_retired(num_retired)

        `ifdef DEBUG
        , .debug_entries(entry_data),
        .debug_head(debug_head),
        .debug_tail(debug_tail)
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
        num_accept = 0;
        wr_data = 0;
        complete_t = 0;

        @(negedge clock);
        @(negedge clock);
        reset = 0;

        // ---------- Test 1 ---------- //
        $display("\nTest 1: Write and Read 1 Entry with a 1 cycle wait");

        $display("Write 1 value");
        num_accept = 1;
        generate_instructions(1);
        add_entries(1);
        @(negedge clock);
        clear_inputs();

        $display("Wait one cycle");
        @(negedge clock);

        $display("Mark instruction complete");
        set_complete(1); // set here
        @(negedge clock);
        clear_inputs();

        $display("Retire instruction");
        @(negedge clock);

        // ---------- Test 2 ---------- //
        $display("\nTest 2:");


        $display("@@@ PASSED ALL TESTS @@@");
        $finish;
    end


    // Correctness Verification
    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
        check_open_entries();
        check_retired_entries();
    end

    // Helper function to clear inputs to ROB
    function void clear_inputs();
        num_accept = 0;
        wr_data = 0;
        complete_t = 0;
    endfunction

    // Helper function that adds entries to rob_model and writes them to wr_data, also adds tag to complete queue
    function void add_entry(int num);
        for (int i = 0; i < (num < N ? num : N); i++) begin
            wr_data[i] = inst_buf.pop_front();
            rob_model.push_back(wr_data[i]);
            complete_queue.push_back(wr_data[i].t);
        end
    endfunction

    // Generates N instructions and adds them to the instruction buffer
    function void generate_instructions(int num);
        integer i;
        logic [6:0] op;
        for (i = 0; i < num; i++) begin
            op = i[6:0];
            inst_buf.push_back('{op_code: op, t: (i+1) % DEPTH, t_old: 5'b0, complete: 1'b0, valid: 1'b1});
        end
    endfunction

    // Helper Function to set complete_t
    function void set_complete(int num);
        for (int i = 0; i < num; i++) begin
            complete_t[i] = complete_queue.pop_front();
        end
    endfunction

    // Open entries validation
    function void check_open_entries();
        if (open_entries != (DEPTH - rob_model.size() + num_retired)) begin
            $error("@@@ FAILED @@@");
            $error("Open entries error: expected %0d, but got %0d", (DEPTH - rob_model.size() + num_retired), open_entries);
            $finish;
        end
    endfunction

    // Retired Entries Validation
    function void check_retired_entries();
        for (int i = 0; i < num_retired; i++) begin
            ROB_ENTRY_PACKET inst = rob_model.pop_front();
            if (inst.op_code != retiring_data[i].op_code) begin
                $error("@@@ FAILED @@@");
                $error("Retirement data error: opcode expected (%0d), but got %0d!", inst.op_code, retiring_data[i].op_code);
                $finish;
            end
            if (inst.t != retiring_data[i].t) begin
                $error("@@@ FAILED @@@");
                $error("Retirement data error: opcode[%0d]: t expected (%0d), but got %0d!", inst.op_code, inst.t, retiring_data[i].t);
                $finish;
            end
            if (inst.t_old != retiring_data[i].t_old) begin
                $error("@@@ FAILED @@@");
                $error("Retirement data error: opcode[%0d]: t_old expected (%0d), but got %0d!", inst.op_code, inst.t_old, retiring_data[i].t_old);
                $finish;
            end
            if (~retiring_data[i].complete) begin
                $error("@@@ FAILED @@@");
                $error("Retirement data error: opcode[%0d]: instruction not marked complete", inst.op_code);
                $finish;
            end
        end
    endfunction

    // Monitoring Statements
    int cycle_number = 0;
    always @(posedge clock) begin
        $display("------------------------------------------------------------");
        $display("@@@ Cycle Number: %0d @@@");
        $display("   Time: %0t", $time);
        $display("   Reset: %0d\n", reset);
        $display("   Open Entries: %0d", open_entries);
        $display("   Retired Entries: %0d\n", num_retired);

        $display("   Write Data:");
        for (int i = 0; i < num_accept; i++) begin
            $display("      wr_data[%0d]: op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
                i, wr_data[i].op_code, wr_data[i].t, wr_data[i].t_old, wr_data[i].complete, wr_data[i].valid
            );
        end
        $display("");

        $display("   Retiring Data:");
        for (int i = 0; i < num_retired; i++) begin
            $display("      retiring_data[%0d]: op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
                i, retiring_data[i].op_code, retiring_data[i].t, retiring_data[i].t_old,
                retiring_data[i].complete, retiring_data[i].valid
            );
        end
        $display("");

        `ifdef DEBUG
            $display("   Debug Information:");
            $display("      Head: %0d", debug_head);
            $display("      Tail: %0d", debug_tail);
            $display("      Entries: ");
            for (int j = 0; j < DEPTH; j++) begin
                $display("         entry_data[%0d]:  op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
                    j, entry_data[j].op_code, entry_data[j].t, entry_data[j].t_old,
                    entry_data[j].complete, entry_data[j].valid
                );
            end
            $display("");
        `endif

        cycle_number++;
    end

endmodule