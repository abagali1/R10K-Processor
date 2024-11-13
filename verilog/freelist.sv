`include "sys_defs.svh"


module free_list #(
    parameter DEPTH = `ROB_SZ,
    parameter N = `N
)
(
    input                                               clock,
    input                                               reset,
    input                   [$clog2(N+1)-1:0]           rd_num,  // number of regs to take off of the free list
    input                   [$clog2(N+1)-1:0]           wr_num,  // number of regs to add back to the free list
    input FREE_LIST_PACKET  [N-1:0]                     wr_reg,  // reg idxs to add to free list
    input logic                                         br_en,  // enable signal for EBR
    input logic             [$clog2(DEPTH+1)-1:0]       head_ptr_in,  // free list copy for EBR

    // save head pointer and tail pointer, instead of free list copy

    output FREE_LIST_PACKET [N-1:0]                     rd_reg,   // displayed available reg idxs, these are always output, and only updated based on rd_num
    // output 
    // output logic            [$clog2(N+1)-1:0] num_avail, // broadcasting number of regs available (not needed)
    output logic            [$clog2(DEPTH+1)-1:0]       head_ptr

    `ifdef DEBUG
    , output logic [$clog2(DEPTH)-1:0] debug_head,
      output logic [$clog2(DEPTH)-1:0] debug_tail,
      output FREE_LIST_PACKET [DEPTH-1:0]  out_fl   // free list to output
    `endif 
    
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic [LOG_DEPTH-1:0] head, next_head;
    logic [LOG_DEPTH-1:0] tail, next_tail;
    logic [$clog2(DEPTH+1)-1:0] num_entries, next_num_entries;

    FREE_LIST_PACKET [DEPTH-1:0] entries, next_entries;
 
    // assign num_avail = (num_entries + wr_num > N) ? N : num_entries + wr_num; // only dependent on what is being written in, not what is being read out

    always_comb begin
        rd_reg = '0;
        next_entries = entries;

        `ifdef DEBUG
          out_fl = entries;
        `endif
        next_num_entries = num_entries + wr_num - rd_num;

        next_head = (br_en) ? head_ptr_in : head;
        next_tail = (tail + wr_num) % DEPTH;

        for (int i = 0; i < N; i++) begin
            if (i < wr_num) begin
                next_entries[(tail +  i) % DEPTH] = wr_reg[i];
            end
        end

        for (int i = 0; i < N; i++) begin
            if (i < rd_num) begin
                rd_reg[i] = next_entries[(next_head + i) % DEPTH];
            end
        end
        
        `ifdef DEBUG
            debug_head = next_head;
            debug_tail = tail;
        `endif

        next_head = (next_head + rd_num) % DEPTH;
    end

    always @(posedge clock) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            for (int i = 0; i < DEPTH; i++) begin
                entries[i].reg_idx <= i + `ARCH_REG_SZ;
                entries[i].valid <= 1;
                // should we be incrementing tail here?
            end
            num_entries <= DEPTH;
        end else begin
            head <= next_head;
            tail <= next_tail;
            entries <= next_entries;
            num_entries <= next_num_entries;
        end
    end

    `ifdef DEBUG
        always @(posedge clock) begin
            // $display("=================== FREE LIST ===================\n");
            // $display("  Entries:");
            // $display("  ---------------------------");
            // $display("  |  i |  reg_idx |  valid  |");
            // $display("  ---------------------------");
            // for (int i = 0; i < DEPTH; i++) begin
            //     $display("  | %2d |    %2d    |    %0d    |", i, entries[i].reg_idx, entries[i].valid);
            // end
            // $display("");

            $display("   FREELIST   ");
            $display("--------------");
            $display(rd_num);
            for (int i = 0; i < rd_num; i++) begin
                if (rd_reg[i].valid) begin
                    $display("\t%0d\t", rd_reg[i].reg_idx);
                end
            end
        end
    `endif

endmodule