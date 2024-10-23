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
  ) dut (
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

  // Generate System Clock
  always begin
    #(`CLOCK_PERIOD/2.0);
      clock = ~clock;
  end

  initial begin
    // Initialize
    clock = 0;
    reset = 1;
    @(posedge clock)


  end

  // Monitoring Statements
  int cycle_number = 0;
  always @(posedge clock) begin
    $display("------------------------------------------------------------");
    $display("@@@ Cycle Number: %0d @@@");
    $display("   Time: %0t", $time);
    $display("   Reset: %0d\n", reset);
    $display("   Open Entries: %0d", open_entries);
    $display("   Retired Entries: %0d\n", num_retired);

    `ifdef DEBUG
      $display("   Debug Information:");
      $display("      Head: %0d", debug_head);
      $display("      Tail: %0d", debug_tail);
      $display("      Entries: ");
      for (int j = 0; j < DEPTH; j++) begin
        $display("         entry_data[%0d]:  op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
                j, entry_data[j].op_code, entry_data[j].t, entry_data[j].t_old,
                entry_data[j].complete, entry_data[j].valid);
      end
      $display("");
    `endif

    $display("   Retiring Data:");
    for (int i = 0; i < num_retired; i++) begin
      $display("      retiring_data[%0d]: op_code=%0d, t=%0d, t_old=%0d, complete=%0b, valid=%0b",
               i, retiring_data[i].op_code, retiring_data[i].t, retiring_data[i].t_old,
               retiring_data[i].complete, retiring_data[i].valid);
    end
    $display("");

    cycle_number++;
  end

endmodule