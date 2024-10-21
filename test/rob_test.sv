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

`timescale 1ns/1ps

`include "sys_defs.svh"
`include "ISA.svh"

module ROB_tb();

  // Parameters
  parameter DEPTH = 32;
  parameter WIDTH = 32;
  parameter N = 1;
  localparam LOG_DEPTH = $clog2(DEPTH);

  // Signals
  logic clock;
  logic reset;
  ROB_ENTRY_PACKET [N-1:0] wr_data;
  logic [N-1:0][4:0] complete_t;
  logic [$clog2(N+1)-1:0] num_accept;
  ROB_ENTRY_PACKET [N-1:0] retiring_data;
  logic [LOG_DEPTH:0] open_entries;

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
    .open_entries(open_entries)
  );

  // Generate System Clock
    always begin
    #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end


  initial begin
      clock = 0;
      reset = 1;

      // initially reset the rob
      #30 reset = 0;
      @(negedge clock)

      // test 1: write one entry
      
      // wr_data initiallized to have an arbitrary op_code, t=4, t_old=1, complete=0, valid=1
      wr_data[0] = '{op_code: 7'b0110011, t: 5'd4, t_old: 5'd1, complete: 1'b0, valid: 1'b1};
      complete_t[0] = 5'd1;
      num_accept = 2'd1;
      @(negedge clock)
      num_accept = 2'd0;
      complete_t[0] = 5'd1;
      @(negedge clock)
      num_accept = 2'd0;
      complete_t[0] = 5'd4;
      @(negedge clock)
      @(negedge clock)
      @(negedge clock)

      //test2: write 2 entries
      

      // check_completed_entries();
      // check_retired_entries();

      // test 3: read entries

      // test 4: write when full

      // test 5: read when empty

      // test 6: read and write in concurrent cycles

      // test 7: read and write in concurrent cycles when full

      // test 8: read and write in concurrent cycles when full, but

    
      $finish;
    end


  always @(posedge clock) begin
    $display("Time=%0t", $time);
    $display("open_entries=%0d", open_entries);
    for (int i = 0; i < N; i++) begin
      $display("retiring_data[%0d]: op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
               i, retiring_data[i].op_code, retiring_data[i].t, retiring_data[i].t_old,
               retiring_data[i].complete, retiring_data[i].valid);
    end
    $display("----------------------");
  end



  function void check_open_entries(int expected);
    if (open_entries != expected) begin
      $error("Open entries error: expected %0d, but got %0d", expected, open_entries);
    end
  endfunction

  function void check_completed_entries();
    for (int i = 0; i < N; i++) begin
      if (!retiring_data[i].complete) begin
        $error("Completion error: retiring_data[%0d] should be complete, but it's not", i);
      end
    end
  endfunction

  function void check_retired_entries();
    for (int i = 0; i < N; i++) begin
      if (retiring_data[i].op_code != i + 1 || retiring_data[i].t != i + 1 || retiring_data[i].t_old != i) begin
        $error("Retirement error: retiring_data[%0d] doesn't match expected values", i);
      end
    end
    check_open_entries(DEPTH);
  endfunction

endmodule