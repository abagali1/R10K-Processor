/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rob_test.sv                                         //
//                                                                     //
//  Description :  Testbench module for the N-way ROB module           //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

// typedef struct packed {
//     logic     [6:0] op_code;
//     logic     [4:0] t;
//     logic     [4:0] t_old; // look up t_old in arch map table to get arch reg and update to t on retire
//     logic           complete;
//     logic           valid;
// } ROB_ENTRY_PACKET;


`include "sys_defs.svh"
`include "ISA.svh"

module ROB_tb();

  // Parameters
  parameter DEPTH = 8;
  parameter WIDTH = 32;
  parameter N = 2;
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

    `ifdef DEBUG
    , .debug_entries(entry_data),
    .debug_head(debug_head),
    .debug_tail(debug_tail)
    `endif
  );

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
      reset = 1;
      @(posedge clock)

      // initially reset the rob
      #5 reset = 0;

      
      


        /* 
          TEST 1: write and complete one entry
          N: 1
          Current State: Empty
        */

        // wr_data initiallized to have an arbitrary op_code, t=4, t_old=1, complete=0, valid=1
        // DISPATCH
        wr_data[0] = '{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t[0] = 5'd1; // this line shouldn't do anything, we complete with "t" not "t_old"
        num_accept = 2'd1;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        // COMPLETE
        wr_data[0] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        num_accept = 2'd0;
        @(negedge clock)

        check_open_entries(DEPTH-1);
        check_retired_entries(0);
        @(posedge clock) // Instruction marked complete

        complete_t[0] = 5'd4; // mark previously inserted instruction as complete
        @(negedge clock)

        check_open_entries(DEPTH-1);
        check_retired_entries(0);
        @(posedge clock)

        // RETIRE
        complete_t[0] = 5'd1;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(1);
        check_retired_data('{'{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}, '{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b1, valid: 1'b1}});
        @(posedge clock)

        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)
        $display("PASSED TEST 1");
        
        /*
          TEST 2: Write two entries, then complete two entries in order
          N: 2
          Current State: Empty
        */

        // Reset ROB
        reset = 1;
        @(posedge clock);
        reset = 0;

        // Write first entry
        wr_data[0] = '{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t[0] = 5'd1;
        num_accept = 2'd1;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        // Write second entry
        wr_data[0] = '{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t[0] = 5'd1;
        num_accept = 2'd1;
        @(negedge clock)

        check_open_entries(DEPTH-1);
        check_retired_entries(0);
        @(posedge clock)

        // Write nothing, check both entries are in
        wr_data[0] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        num_accept = 2'd0;
        @(negedge clock)

        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)

        // Complete first entry
        complete_t[0] = 5'd4; 
        @(negedge clock)

        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)

        // Complete second entry, check first entry is retired
        complete_t[0] = 5'd5;
        @(negedge clock)

        check_open_entries(DEPTH-1);
        check_retired_entries(1);
        check_retired_data('{'{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0},'{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b1, valid: 1'b1}});
        @(posedge clock)

        // Check second entry is retired
        complete_t[0] = 5'd1;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(1);
        check_retired_data('{'{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0},'{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b1, valid: 1'b1}});
        @(posedge clock)

        @(negedge clock)
        
        // Check cleared ROB
        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)
        $display("PASSED TEST 2");


        /*
          TEST 3: Write two entries, then complete two entries out of order
          N: 1
          Current State: Empty
        */

        // Reset ROB
        reset = 1;
        @(posedge clock);
        reset = 0;

        // Write first entry
        wr_data[0] = '{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t[0] = 5'd1;
        num_accept = 2'd1;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        // Write second entry
        wr_data[0] = '{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t[0] = 5'd1;
        num_accept = 2'd1;
        @(negedge clock)

        check_open_entries(DEPTH-1);
        check_retired_entries(0);
        @(posedge clock)

        // Write nothing, check both entries are in
        wr_data[0] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        num_accept = 2'd0;
        @(negedge clock)

        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)

        // Complete second entry
        complete_t[0] = 5'd5; 
        @(negedge clock)

        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)

        // Complete first entry
        complete_t[0] = 5'd4;
        @(negedge clock)

        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)

        // Check first entry is retired
        complete_t[0] = 5'd1;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(2);
        check_retired_data('{'{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b1, valid: 1'b1},'{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b1, valid: 1'b1}});
        @(posedge clock)

        @(negedge clock)
        
        // Check cleared ROB
        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)
        $display("PASSED TEST 3");
        

      /*
          TEST 4: Write two entries at the same time (change num_accept=2)
          N: 2
          Current State: Empty
        */

        // Reset ROB
        reset = 1;
        @(posedge clock);
        reset = 0;

        // Write first entry
        wr_data[0] = '{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        // Write second entry
        wr_data[1] = '{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t = '{5'd1, 5'd1};
        // accept 2 entries at a time
        num_accept = 2'd2;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        // Write nothing, check both entries are in
        wr_data[0] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        wr_data[1] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        num_accept = 2'd0;
        @(negedge clock)

        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)
        $display("LINE 316");


        // Complete first entry
        complete_t = '{5'd4, 5'd1}; 
        @(negedge clock)

        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)

        // Complete second entry, check first entry is retired
        complete_t = '{5'd5, 5'd1};
        @(negedge clock)

        check_open_entries(DEPTH-1);
        check_retired_entries(1);
        check_retired_data('{'{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0},'{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b1, valid: 1'b1}});
        @(posedge clock)

        // Check second entry is retired
        complete_t = '{5'd1, 5'd1};
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(1);
        check_retired_data('{'{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0},'{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b1, valid: 1'b1}});
        @(posedge clock)

        @(negedge clock)
        
        // Check cleared ROB
        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        $display("@@@ TEST 4 PASSED");

      /*
          TEST 5: 
          N: 2
          Current State: Empty
        */

        // Reset ROB
        reset = 1;
        @(posedge clock);
        reset = 0;

        // Write first and second entry
        wr_data[0] = '{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        wr_data[1] = '{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t = '{5'd1, 5'd1};
        num_accept = 2'd2;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        // Write third and fourth entry
        wr_data[0] = '{op_code: 7'b1110000, t: 5'd6, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        wr_data[1] = '{op_code: 7'b0000111, t: 5'd7, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t[0] = 5'd1;
        complete_t[1] = 5'd1;
        num_accept = 2'd2;
        @(negedge clock)

        //TODO
        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)
        $display("AFTER LINE 392");

        wr_data[0] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        wr_data[1] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        num_accept = 0;
        @(negedge clock)

        check_open_entries(DEPTH-4);
        check_retired_entries(0);
        @(posedge clock)

        // Complete third and fourth entry
        complete_t[0] = 5'd6; 
        complete_t[1] = 5'd7; 
        @(negedge clock)

        check_open_entries(DEPTH-4);
        check_retired_entries(0);
        @(posedge clock)

        // Complete first and second entry
        complete_t[0] = 5'd4; 
        complete_t[1] = 5'd5; 
        @(negedge clock)

        check_open_entries(DEPTH-4);
        check_retired_entries(0);
        @(posedge clock)

        @(negedge clock)

        //TODO
        check_open_entries(DEPTH-2);
        $display("after LINE 428");
        check_retired_entries(2);
        check_retired_data('{'{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b0, valid: 1'b1},'{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b0, valid: 1'b1}});
        @(posedge clock)

        // Check second entry is retired
        complete_t[0] = 5'd1;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(2);
        check_retired_data('{'{op_code: 7'b0000111, t: 5'd7, t_old: 5'd1, complete: 1'b0, valid: 1'b1},'{op_code: 7'b1110000, t: 5'd6, t_old: 5'd1, complete: 1'b0, valid: 1'b1}});
        @(posedge clock)

        @(negedge clock)
        
        // Check cleared ROB
        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        $display("@@@ TEST 5 PASSED");


        /*
          TEST 6: Write two entries at the same time (change num_accept=2), complete two entries at the same time in order
          N: 2
          Current State: Empty
        */

        // Reset ROB
        reset = 1;
        @(posedge clock);
        reset = 0;

        // Write first entry
        wr_data[0] = '{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        // Write second entry
        wr_data[1] = '{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t = '{5'd1, 5'd1};
        // accept 2 entries at a time
        num_accept = 2'd2;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        // Write nothing, check both entries are in
        wr_data[0] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        wr_data[1] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        num_accept = 2'd0;
        @(negedge clock)

        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)
        $display("AFTER LINE 483");

        // TODO: ask in OH: having this negedge causes the test case to fail. why?
        @(negedge clock)

        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)
        // TODO: to here

        // Complete both entries
        complete_t = '{5'd4, 5'd5}; 
        @(negedge clock)

        //TODO
        check_open_entries(DEPTH-2);
        check_retired_entries(0);
        @(posedge clock)
        $display("AFTER LINE 495");

        complete_t = '{5'd1, 5'd1}; 
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(2);
        check_retired_data('{'{op_code: 7'b0101010, t: 5'd5, t_old: 5'd1, complete: 1'b0, valid: 1'b1},'{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b1, valid: 1'b1}});
        @(posedge clock)

        @(negedge clock)
        
        // Check cleared ROB
        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        $display("@@@ TEST 6 PASSED");
        

        // ??? test 5: read when empty ???

        // test 6: read and write in concurrent cycles

        // test 7: read and write in concurrent cycles when full

        // test 8: read and write in concurrent cycles when full, but

        
        // REMAINING TESTS 
        // - head and tail wrappings around end of buffer
        // - full ROB simultaneous read and write

      
      
    /*
      if (N == 2) begin
        
          TEST 1: write and complete one entry
          N: 2
          Current State: Empty
        

        // wr_data initiallized to have an arbitrary op_code, t=4, t_old=1, complete=0, valid=1
        // DISPATCH
        wr_data[0] = '{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
        complete_t[0] = 5'd1; // this line shouldn't do anything, we complete with "t" not "t_old"
        num_accept = 2'd1;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

        // COMPLETE
        wr_data[0] = '{op_code: 7'b0000000, t: 5'd0, t_old: 5'd0, complete: 1'b0, valid: 1'b0}; // overwrite with 0s
        num_accept = 2'd0;
        @(negedge clock)

        check_open_entries(DEPTH-1);
        check_retired_entries(0);
        @(posedge clock) // Instruction marked complete

        complete_t[0] = 5'd4; // mark previously inserted instruction as complete
        @(negedge clock)

        check_open_entries(DEPTH-1);
        check_retired_entries(0);
        @(posedge clock)

        // RETIRE
        complete_t[0] = 5'd1;
        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(1);
        check_retired_data('{'{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b1, valid: 1'b1}});
        @(posedge clock)

        @(negedge clock)

        check_open_entries(DEPTH);
        check_retired_entries(0);
        @(posedge clock)

      end
    */


      $display("@@@ PASSED");
      $finish;
    end


  always @(posedge clock) begin
    $display("Time=%0t", $time);
    $display("Reset=%0d", reset);
    $display("open_entries=%0d", open_entries);
    $display("number of entries retired=%0d", num_retired);
    `ifdef DEBUG
      $display("entries: ");
      for (int j = 0; j < N; j++) begin
        $display("entry_data[%0d]:  op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
                j, entry_data[j].op_code, entry_data[j].t, entry_data[j].t_old,
                entry_data[j].complete, entry_data[j].valid);
      end
      $display("head=%0d", debug_head);
      $display("tail=%0d", debug_tail);
    `endif

    $display("retiring data: ");
    for (int i = 0; i < N; i++) begin
      $display("retiring_data[%0d]: op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
               i, retiring_data[i].op_code, retiring_data[i].t, retiring_data[i].t_old,
               retiring_data[i].complete, retiring_data[i].valid);
    end
    $display("----------------------");
  end



  function void check_open_entries(int expected);
    if (open_entries != expected) begin
      $error("@@@ FAILED");
      $error("Open entries error: expected %0d, but got %0d", expected, open_entries);
      $finish;
    end
  endfunction

  function void check_completed_entries();
    for (int i = 0; i < N; i++) begin
      if (!retiring_data[i].complete) begin
        $error("@@@ FAILED");
        $error("Completion error: retiring_data[%0d] should be complete, but it's not", i);
        $finish;
      end
    end
  endfunction

  function void check_retired_entries(int expected);
    if(num_retired != expected) begin
      $error("@@@ FAILED");
      $error("Retirement error: expected (%0d) retires, but got %0d!", expected, num_retired);
      $finish;
    end
    // for (int i = 0; i < N; i++) begin
    //   if (retiring_data[i].op_code != i + 1 || retiring_data[i].t != i + 1 || retiring_data[i].t_old != i) begin
    //     $error("Retirement error: retiring_data[%0d] doesn't match expected values", i);
    //   end
    // end
    // check_open_entries(DEPTH);
  endfunction

  function void check_retired_data(ROB_ENTRY_PACKET [N-1:0] expected);
    for(int i = 0; i < N; ++i) begin
      if (retiring_data[i].valid) begin
        if (retiring_data[i].op_code != expected[i].op_code) begin
          $error("@@@ FAILED");
          $error("Retirement data error: opcode expected (%0d), but got %0d!", expected[i].op_code, retiring_data[i].op_code);
          $finish;
        end
        if (retiring_data[i].t != expected[i].t) begin
          $error("@@@ FAILED");
          $error("Retirement data error: t expected (%0d), but got %0d!", expected[i].t, retiring_data[i].t);
          $finish;
        end
        if (retiring_data[i].t_old != expected[i].t_old) begin
          $error("@@@ FAILED");
          $error("Retirement data error: t_old expected (%0d), but got %0d!", expected[i].t_old, retiring_data[i].t_old);
          $finish;
        end
      end
    end
    
  endfunction

endmodule