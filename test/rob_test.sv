/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rob_test.sv                                         //
//                                                                     //
//  Description :  Testbench module for the N-way ROB module           //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////



`timescale 1ns/1ps

`include "sys_defs.svh"

module ROB_tb();

  // Parameters
  parameter DEPTH = 32;
  parameter WIDTH = 32;
  parameter N = 4;
  localparam LOG_DEPTH = $clog2(DEPTH);

  // Signals
  logic clock;
  logic reset;
  ROB_ENTRY_PACKET [N-1:0] wr_data;
  logic [N-1:0][4:0] complete_t;
  logic [$clog2(N)-1:0] num_accept;
  ROB_ENTRY_PACKET [N-1:0] retiring_data;
  logic [LOG_DEPTH-1:0] open_entries;

  // Instantiate the ROB
  ROB #(
    .DEPTH(DEPTH),
    .WIDTH(WIDTH),
    .N(N)
  ) rob_inst (
    .clock(clock),
    .reset(reset),
    .wr_data(wr_data),
    .complete_t(complete_t),
    .num_accept(num_accept),
    .retiring_data(retiring_data),
    .open_entries(open_entries)
  );

  // Generate System Clock
    always begin
    #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

  // Test stimulus
  initial begin
    clock = 0;
    reset = 1;

    wr_data = '{default:0};
    complete_t = '{default:0};
    num_accept = 0;

    // Reset the ROB
    #20 reset = 0;

    // Test 1: Write entries
    #10;
    for (int i = 0; i < N; i++) begin
      wr_data[i].op_code = i + 1;
      wr_data[i].t = i + 1;
      wr_data[i].t_old = i;
      wr_data[i].complete = 0;
      wr_data[i].valid = 1;
    end
    num_accept = N;
    #10;

    

  // Monitor
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

endmodule