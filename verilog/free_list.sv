`include "sys_defs.svh"

typedef struct packed {
    REG_IDX reg_idx;
    logic valid;
} FREE_LIST_PACKET;

module free_list #(
    parameter DEPTH = 32// ???
    parameter N = `N,
)
(
    input                                       clock,
    input                                       reset,
    input                   [$clog2(N+1)-1:0]   rd_num,  // number of regs to take off of the free list
    input                   [$clog2(N+1)-1:0]   wr_num,  // number of regs to add back to the free list
    input FREE_LIST_PACKET  [N-1:0]             wr_reg,  // reg idxs to add to free list

    output FREE_LIST_PACKET [N-1:0]             rd_reg   // displayed available reg idxs, these are always output, and only updated based on rd_num

    `ifdef DEBUG
    `endif 
    
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic [LOG_DEPTH-1:0] head, next_head, tmp_head;
    logic [LOG_DEPTH-1:0] tail, next_tail;

    FREE_LIST_PACKET [DEPTH-1:0] entries, next_entries;

    assign next_head = (head + rd_num) % DEPTH;
    assign next_tail = (tail + wr_num) % DEPTH;

    always_comb begin
        rd_reg = '0;
        next_entries = entries;

        for (int i = 0; i < N; i++) begin
            tmp_head = (head + i) % DEPTH;
            if (entries[tmp_head].valid) begin
                rd_reg[i] = entries[tmp_head];
                next_entries[tmp_head] = 0;
            end
        end

        for (int i = 0; i < N; i++) begin
            next_entries[(tail + i) % DEPTH] = wr_reg[i];
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            entries <= 0;
        end else begin
            head <= next_head;
            tail <= next_tail;
            entries <= next_entries;
        end
    end

endmodule