/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rob_queue_test.sv                                   //
//                                                                     //
//  Description :  Testbench module for the N-way ROB module           //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module ROB_queue_tb();

  // Parameters
  parameter DEPTH = 8;
  parameter WIDTH = 32;
  parameter N = 3;
  localparam LOG_DEPTH = $clog2(DEPTH);

  // Signals
  logic                     clock;
  logic                     reset;
  ROB_ENTRY_PACKET          [N-1:0] wr_data;
  PHYS_REG_IDX              [N-1:0] complete_t;
  logic                     [$clog2(N+1)-1:0] num_accept;
  ROB_ENTRY_PACKET          [N-1:0] retiring_data;
  logic                     [$clog2(DEPTH+1)-1:0] open_entries;
  logic                     [$clog2(N+1)-1:0] num_retired;

  `ifdef DEBUG
    ROB_ENTRY_PACKET [DEPTH-1:0] entry_data;
    logic [LOG_DEPTH-1:0] debug_head;
    logic [LOG_DEPTH-1:0] debug_tail;
  `endif

  // Instantiate the ROB
  ROB #(
    .DEPTH(DEPTH),
    .N(N)
  ) rob_inst (
    // inputs
    .clock(clock),
    .reset(reset),
    .wr_data(wr_data),
    .complete_t(complete_t),
    .num_accept(num_accept),

    // outputs
    .retiring_data(retiring_data),
    .open_entries(open_entries),
    .num_retired(num_retired)

    // debugging
    `ifdef DEBUG
    , .debug_entries(entry_data),
    .debug_head(debug_head),
    .debug_tail(debug_tail)
    `endif
  );

  // Queue Instantiations
  ROB_ENTRY_PACKET rob_model [$:(DEPTH - 1)];
  ROB_ENTRY_PACKET inst_buff [$:(DEPTH*2)-1];

  // Generate System Clock
  always begin
    #(`CLOCK_PERIOD/2.0);
      clock = ~clock;
  end

  always @(posedge clock) begin
    #(`CLOCK_PERIOD * 0.2);
  end
  
  initial begin
    clock = 0;
    reset_state();
    reset = 1;
    @(posedge clock)
    #5 reset = 0;

    //*** TESTBENCHES ***//

    // TEST 1
    
    // add N instructions, when the ROB is empty, complete ALL => exepct AL retired
    fetch_entries();
    add_entries(N); // DISPATCH

    @(negedge clock)
    @(posedge clock) // INST added to ROB
    
    clear_entry_data();
    set_complete(get_complete_regs(0, N)); // COMPLETE

    @(negedge clock)

    check_open_entries();
    check_retired_entries();

    @(posedge clock) 
    @(negedge clock)

    check_open_entries();
    check_retired_entries();

    @(posedge clock)
    @(negedge clock) 
    
    $display("PASSED TEST 1");

    // TEST 2: 
    // reset_state();
    // clear_entry_data();
    // reset = 1;
    // @(posedge clock)
    // #5 reset = 0;

    
     // TEST 2: add N instructions, when the ROB is full
    reset_state();
    @(posedge clock)
    #5 reset = '0;

    fetch_entries();
    @(negedge clock)
    $display("AFTER LINE 125");

    // verify rob is empty
    @(posedge clock)
    check_open_entries(); // should be all open
    check_retired_entries(); // none should retire
    @(negedge clock)
    $display("AFTER LINE 130");
    @(posedge clock)

    // fill the rob mostly with entries
    for (int i = 0; i < (DEPTH / N); i++) begin
      @(posedge clock);
      add_entries(N);
    end

    // @(negedge clock)
    // clear_entry_data();

    @(posedge clock)
    // finish filling the rob with what is left over
    add_entries(DEPTH % N);
    $display("NUM_ACCEPT=%0d", num_accept);
 
    @(negedge clock)
    $display("AFTER LINE 142");

    // verify rob is full
    @(posedge clock)
    @(posedge clock)
    check_open_entries();
    check_retired_entries();
    $display("AFTER LINE 144");

    // set N entries to complete
    set_complete(get_complete_regs(0, N));
    @(negedge clock)
    add_entries(N-1);
    $display("AFTER LINE 151");
    
    @(posedge clock)
    // should be of DEPTH - 1 entries
    check_open_entries();
    check_retired_entries();
    $display("AFTER LINE 157");

    $display("@@@ TEST 2 PASSED");

    $display("@@@ PASSED");
    $finish;

  /*
    // add N instructions, when the ROB is full
    for (int i = 0; i < (DEPTH / N); i++) begin
      add_entries(N);
    end

    reset();
    @(posedge clock)

    #5 reset = 0;

    // add N instructions, when the ROB has stuff but not full

    reset();
    @(posedge clock)

    #5 reset = 0;
    // add less than N instructions, when the ROB is empty
    
    reset();
    @(posedge clock)

    #5 reset = 0;
    // add less than N instructions, when the ROB is full
    
    reset();
    @(posedge clock)

    #5 reset = 0;
    // add less than N instructions, when the ROB has stuff but not full

    reset();
    @(posedge clock)

    #5 reset = 0; */
  end 

  // On Every Clock Cycle
  always @(posedge clock) begin
    $display("  Time=%0t", $time);
    $display("  Reset=%0d", reset);
    $display("  open_entries=%0d", open_entries);
    $display("  number of entries retired=%0d", num_retired);
    `ifdef DEBUG
      $display("  head=%0d", debug_head);
      $display("  tail=%0d", debug_tail);
      $display("  entries: ");
      for (int j = 0; j < DEPTH-open_entries; j++) begin
        $display("    entry_data[%0d]:  op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
                j, entry_data[j].op_code, entry_data[j].t, entry_data[j].t_old,
                entry_data[j].complete, entry_data[j].valid);
      end
    `endif

    $display("  retiring data: ");
    for (int i = 0; i < num_retired; i++) begin
      $display("    retiring_data[%0d]: op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
               i, retiring_data[i].op_code, retiring_data[i].t, retiring_data[i].t_old,
               retiring_data[i].complete, retiring_data[i].valid);
    end
    $display("----------------------");
  end

  //*** FUNCTIONSSSS ***//

  /* Function: Fetch Entries
    Create entries to put into instruction buffer. Generate 
  */
  function void fetch_entries();
    integer i;
    logic [6:0] op;
    for(i = 0; i < (DEPTH*2); i++) begin
      op = i[6:0];
      inst_buff.push_back('{op_code: op, t: (i+1) % DEPTH, t_old: i % DEPTH, complete: 1'b0, valid: 1'b1 });
    end
  endfunction

  function void reset_state();
    inst_buff.delete();
    rob_model.delete();
    wr_data = '0;
    complete_t = '0;
    num_accept = '0;
    reset = '1;
  endfunction

  function void add_entries(int num_add);
    num_accept = num_add;
    for (int i = 0; i < num_add; i++) begin
      wr_data[i] = inst_buff.pop_front();
      rob_model.push_back(wr_data[i]); // the gannon strat
    end
  endfunction

  function void clear_entry_data();
    num_accept = 0;
    for (int i = 0; i < N; i++) begin
      wr_data[i] = '0;
    end
  endfunction
  
  function void check_open_entries();
    if (open_entries != (DEPTH - rob_model.size() + num_retired)) begin
      $error("@@@ FAILED");
      $error("Open entries error: expected %0d, but got %0d", (DEPTH - rob_model.size() + num_retired), open_entries);
      $finish;
    end
  endfunction

  function void set_complete(PHYS_REG_IDX [N-1:0] complete_idx);
    complete_t = complete_idx;
    for (int j = 0; j < N; j++) begin
      for (int k=0; k < rob_model.size(); ++k) begin
        if(rob_model[k].t == complete_idx[j]) begin
          rob_model[k].complete = 'b1;
        end
      end
    end
  endfunction
  
  function void check_retired_entries();
    for (int i = 0; i < num_retired; i++) begin
      ROB_ENTRY_PACKET inst = rob_model.pop_front();
      if (inst.op_code != retiring_data[i].op_code) begin
        $error("@@@ FAILED");
        $error("Retirement data error: opcode expected (%0d), but got %0d!", inst.op_code, retiring_data[i].op_code);
        $finish;
      end
      if (inst.t != retiring_data[i].t) begin
        $error("@@@ FAILED");
        $error("Retirement data error: t expected (%0d), but got %0d!", inst.t, retiring_data[i].t);
        $finish;
      end
      if (inst.t_old != retiring_data[i].t_old) begin
        $error("@@@ FAILED");
        $error("Retirement data error: t_old expected (%0d), but got %0d!", inst.t_old, retiring_data[i].t_old);
        $finish;
      end
    end
  endfunction

  function void print_rob_model();
    $display("rob model");
    for (int j = 0; j < rob_model.size(); j++) begin
        $display("rob_model[%0d]:  op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
                j, rob_model[j].op_code, rob_model[j].t, rob_model[j].t_old,
                rob_model[j].complete, rob_model[j].valid);
    end
    $display("rob model completed");
  endfunction

  function void print_inst_buffer();
    $display("instruction buffer");
    $display("instruction buffer size: %d", inst_buff.size());
    for (int i = 0; i < inst_buff.size(); i++) begin
      $display("inst_buff[%0d]: op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
               i, inst_buff[i].op_code, inst_buff[i].t, inst_buff[i].t_old,
               inst_buff[i].complete, inst_buff[i].valid);
    end
    $display("instruction buffer completed");
  endfunction
  
  function PHYS_REG_IDX[N-1:0] get_complete_regs(int start_insts, int end_insts);
    PHYS_REG_IDX[N-1:0] idxs;
    for(int i=start_insts; i < end_insts;i++) begin
      idxs[i-start_insts] = (i + 1) % DEPTH;
    end
    return idxs;
  endfunction

endmodule