// N-way ROB 

// Input: wr_data, N array of packets with [0] being the oldest, [N-1] being the youngest

`include "sys_defs.svh"

module ROB #(
    parameter DEPTH = `PHYS_REG_SZ_R10K,
    parameter N = `N
)
(
    input                           clock, 
    input                           reset,
    input ROB_ENTRY_PACKET          [N-1:0] wr_data, 
    input PHYS_REG_IDX              [N-1:0] complete_t, // comes from the FU
    input                           [$clog2(N+1)-1:0] num_accept, // input signal from min block, dependent on open_entries 
    input logic                     [$clog2(DEPTH)-1:0] br_tail,
    input logic                     br_en,                        

    output ROB_ENTRY_PACKET         [N-1:0] retiring_data, // rob entry packet, but want register vals to update architectural map table + free list
    output logic                    [$clog2(N+1)-1:0] open_entries, // number of open entires AFTER retirement
    output logic                    [$clog2(N+1)-1:0] num_retired,
    output logic                    [$clog2(DEPTH)-1:0] out_tail


    `ifdef DEBUG
    ,   output ROB_ENTRY_PACKET [DEPTH-1:0] debug_entries,
        output logic [$clog2(DEPTH)-1:0] debug_head,
        output logic [$clog2(DEPTH)-1:0] debug_tail
    `endif
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    //typedef enum logic [1:0] {EMPTY, LOAD, FULL} STATE;

    logic [LOG_DEPTH-1:0] head, next_head;
    logic [LOG_DEPTH-1:0] tail, next_tail;
    logic [LOG_DEPTH:0] num_entries, next_num_entries;

    ROB_ENTRY_PACKET [DEPTH-1:0] entries, next_entries;

    // use head and tail because this updates between clock cycles, so will update to correct value
    // with head and tail on posedge
    // keeping the original version alongside simplified comb logic
    // assign num_entries = (tail >= head) ? (tail - head) : (DEPTH - head + tail);
    assign open_entries = (DEPTH - num_entries + num_retired > N) ? N : DEPTH - num_entries + num_retired;
    // DONE
    // output (up to N) completed entries
    always_comb begin
        next_head = head;
        retiring_data = '0;
        num_retired = '0;
        next_num_entries = num_entries;
        next_entries = entries;

        // Dependent for-loop to retire instructions. 
        // We must retire instructions first in order to accept the highest # of incoming instructions
        for (int i = 0; i < N; ++i) begin
            if (entries[(head+i) % DEPTH].valid & entries[(head+i) % DEPTH].complete) begin
                retiring_data[i] = entries[(head+i) % DEPTH];
                next_entries[(head+i) % DEPTH] = '0;
                next_head = (((head+i) % DEPTH) + 1) % DEPTH;
                next_num_entries--;
                num_retired++;
            end else begin
                break;
            end
        end

        // These statements are dependent on updated num_accept
        next_tail = (br_en) ? br_tail : (tail + num_accept) % DEPTH; // next_tail points to one past the youngest inst
        next_num_entries += num_accept;

        for(int j=0;j < N; ++j) begin
            if(j < num_accept) begin
                next_entries[(tail+j) % DEPTH] = wr_data[j];
            end

            for(int k=0; k < DEPTH; ++k) begin
                if(entries[k].valid & entries[k].t == complete_t[j]) begin
                    next_entries[k].complete = 'b1;
                end
            end
        end

        // two assumptions:
        // - branch is the first instruction in the the dispatched instruction window
        // - only one branch per dispatched instruction window
        out_tail = tail; 
        
        `ifdef DEBUG
            debug_entries = entries;
            debug_head = head;
            debug_tail = tail;
        `endif
    end

    // Incoming insts from dispatch (up to min(N, open_entries))
    // advance tail, num_entries += num_accept

    // update state
    always_ff @(posedge clock) begin
        if (reset) begin
            num_entries <= '0;
            head <= '0;
            tail <= '0;
            entries <= '0;
        end else begin
            num_entries <= next_num_entries;
            head <= next_head;
            tail <= next_tail;
            entries <= next_entries;
        end
    end

endmodule