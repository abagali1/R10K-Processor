/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  inst_buffer_test.sv                                 //
//                                                                     //
//  Description :  Testbench module for the N-way ROB module           //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module inst_buffer_tb();

    parameter DEPTH = 8;
    parameter N = 3; 
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic                                  clock;
    logic                                  reset;

    INST_PACKET      [DEPTH-1:0]           in_insts;
    logic            [$clog2(N+1)-1:0]     num_dispatch;
    logic            [$clog2(DEPTH+1)-1:0] num_accept;

    INST_PACKET      [N-1:0]               dispatched_insts;
    logic            [$clog2(DEPTH+1)-1:0] open_entries;

    INST_PACKET inst_buffer_model [DEPTH-1:0];

    `ifdef DEBUG
        INST_PACKET [DEPTH-1:0]     debug_entries;
        logic            [LOG_DEPTH-1:0] debug_head;
        logic            [LOG_DEPTH-1:0] debug_tail;
    `endif
    
    INST_PACKET inst_buffer_model [$:(DEPTH)];

    inst_buffer #(
        .DEPTH(DEPTH),
        .N(N)
    ) dut (
        .clock(clock),
        .reset(reset),
        .in_insts(in_insts),
        .num_dispatch(num_dispatch),
        .num_accept(num_accept),

        .dispatched_insts(dispatched_insts),
        .open_entries(open_entries)

        `ifdef DEBUG
        , .debug_entries(debug_entries),
            .debug_head(debug_head),
            .debug_tail(debug_tail)
        `endif
    );

    always begin
        #(`CLOCK_PERIOD / 2.0);
        clock = ~clock;
    end

    // Test sequence
    initial begin
        $display("\nStart Testbench");

        // population input instructions with random instructions
        int instruction = 1;
        int pc = 1; 
        int npc = 5; 
        for (int i = 0; i < DEPTH; i++) begin
            in_insts[0] = {instruction, pc, npc, 1};
            instruction++;
            pc++;
            npc += 4;
        end
    
        $finish;
    end

    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
    end
    
    // functions

    function void print_input_inst();
        for (int i = 0; i < DEPTH; i++) begin
            $display("index: %d", i);
            $display("")
        end
    endfunction

endmodule