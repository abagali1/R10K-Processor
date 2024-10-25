`include "sys_defs.svh"

typedef struct packed {
    PHYS_REG_IDX reg_idx;
    logic valid;
} FREE_LIST_PACKET;

module free_list #(
    parameter DEPTH = `ROB_SZ,
    parameter N = `N,
)
(
    input                                        clock,
    input                                        reset,
    input                   [$clog2(N+1)-1:0]    rd_num,  // number of regs to take off of the free list
    input                   [$clog2(N+1)-1:0]    wr_num,  // number of regs to add back to the free list
    input FREE_LIST_PACKET  [N-1:0]              wr_reg,  // reg idxs to add to free list
    input logic                                  br_en,  // enable signal for EBR
    input FREE_LIST_PACKET  [DEPTH-1:0]          br_fl,  // free list copy for EBR

    output FREE_LIST_PACKET [N-1:0]             rd_reg,   // displayed available reg idxs, these are always output, and only updated based on rd_num
    output FREE_LIST_PACKET [DEPTH-1:0]         out_fl,   // free list to output
    output logic            [$clog2(DEPTH+1)-1:0] num_avail // broadcasting number of regs available

    `ifdef DEBUG
    `endif 
    
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic [LOG_DEPTH-1:0] head, next_head;
    logic [LOG_DEPTH-1:0] tail, next_tail;
    logic [$clog2(DEPTH+1)-1:0] num_entries, next_num_entries;

    FREE_LIST_PACKET [DEPTH-1:0] entries, next_entries;

    assign next_head = (head + rd_num) % DEPTH;
    assign next_tail = (tail + wr_num) % DEPTH; 
    assign num_avail = num_entries + wr_num;

    always_comb begin
        rd_reg = '0;
        next_entries = (br_en) ? br_fl : entries;
        out_fl = entries;
        next_num_entries = num_entries + wr_num - rd_num;

        for (int i = 0; i < N; i++) begin
            next_entries[(tail +  i) % DEPTH] = wr_reg[i];
        end

        for (int i = 0; i < N; i++) begin
            if (next_entries[(head + i) % DEPTH].valid) begin
                rd_reg[i] = next_entries[(head + i) % DEPTH];
                next_entries[(head + i) % DEPTH] = 0;
            end
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            for (int i = 0; i < DEPTH; i++) begin
                entries[i].reg_idx <= i + `ARCH_REG_SZ;
                entries[i].valid <= 1;
            end
            num_entries <= DEPTH;
        end else begin
            head <= next_head;
            tail <= next_tail;
            entries <= next_entries;
            num_entries <= next_num_entries;
        end
    end

endmodule