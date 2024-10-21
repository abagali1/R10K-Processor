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
    
    output ROB_ENTRY_PACKET         [N-1:0] retiring_data, // rob entry packet, but want register vals to update architectural map table + free list
    output logic                    [$clog2(DEPTH+1)-1:0] open_entries, // number of open entires AFTER retirement
    output logic                    [$clog2(N+1)-1:0] num_retired

    `ifdef `DEBUG 
    ,    output logic [DEPTH-1:0] debug_entries
    `endif
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    //typedef enum logic [1:0] {EMPTY, LOAD, FULL} STATE;

    logic [LOG_DEPTH-1:0] head, next_head;
    logic [LOG_DEPTH-1:0] tail, next_tail;

    ROB_ENTRY_PACKET [DEPTH-1:0] entries, next_entries;

    // use head and tail because this updates between clock cycles, so will update to correct value
    // with head and tail on posedge
    // keeping the original version alongside simplified comb logic
    // assign num_entries = (tail >= head) ? (tail - head) : (DEPTH - head + tail);
    // assign open_entries = DEPTH - num_entries;
    // DONE
    // output (up to N) completed entries
    always_comb begin
        next_head = head;
        retiring_data = '0;
        num_retired = '0;
        open_entries = (tail >= head) ? (DEPTH - (tail - head)) : (head - tail);

        // Dependent for-loop to retire instructions. 
        // We must retire instructions first in order to accept the highest # of incoming instructions
        for (int i = 0; i < N; ++i) begin
            if (entries[head+i].complete) begin
                retiring_data[i] = entries[head];
                next_head = (head + i) % DEPTH;
                open_entries++;
                num_retired++;
            end else begin
                break;
            end
        end

        // These statements are dependent on updated num_accept
        next_entries = entries;
        next_tail = (tail + num_accept) % DEPTH; // next_tail points to one past the youngest inst

        for(int j=0;j < N; ++j) begin
            if(j < num_accept) begin
                next_entries[(tail+j) % DEPTH] = wr_data[j];
            end

            for(int k=0; k < DEPTH; ++k) begin
                if(entries[j].t == complete_t[k]) begin
                    next_entries[j].complete = 'b1;
                end
            end
        end

        `ifdef DEBUG
            debug_entries = entries;
        `endif
    end

    // Incoming insts from dispatch (up to min(N, open_entries))
    // advance tail, num_entries += num_accept

    // update state
    always_ff @(posedge clock) begin
        if (reset) begin
            //state <= EMPTY;
            head <= '0;
            tail <= '0;
            entries <= '0;
        end else begin
            //state <= next_state;
            head <= next_head;
            tail <= next_tail;
            entries <= next_entries;
        end
    end

endmodule