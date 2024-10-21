// N-way ROB 

// Input: wr_data, N array of packets with [0] being the oldest, [N-1] being the youngest

typedef struct packed {
    logic     [6:0] op_code;
    logic     [4:0] t;
    logic     [4:0] t_old, // look up t_old in arch map table to get arch reg and update to t on retire
    logic           complete,
    logic           valid
} ROB_ENTRY_PACKET;

module ROB #(
    parameter DEPTH = 32,
    parameter WIDTH = 32,
    parameter N = 1
) (
    input                           clock, 
    input                           reset,
    input ROB_ENTRY_PACKET          [N-1:0] wr_data, 
    input                           [N-1:0][4:0] complete_t, // comes from the FU
    input                           [$clog2(N)-1:0] num_accept, // input signal from min block, also controls how many entries are dispatched
    
    output ROB_ENTRY_PACKET         [N-1:0] retiring_data, // rob entry packet, but want register vals to update architectural map table + free list
    output logic                    [LOG_DEPTH-1:0] open_entries // min(open_entries, N, open RS entries)
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    //typedef enum logic [1:0] {EMPTY, LOAD, FULL} STATE;

    logic [LOG_DEPTH-1:0] head, next_head;
    logic [LOG_DEPTH-1:0] tail, next_tail;

    logic ROB_ENTRY_PACKET [DEPTH-1:0] entries, next_entries;

    // use head and tail because this updates between clock cycles, so will update to correct value
    // with head and tail on posedge
    // keeping the original version alongside simplified comb logic
    // assign num_entries = (tail >= head) ? (tail - head) : (DEPTH - head + tail);
    // assign open_entries = DEPTH - num_entries;
    assign open_entries = (tail >= head) ? (DEPTH - tail + head) : (head - tail);

    // DONE
    // output (up to N) completed entries
    always_comb begin
        next_head = head;
        for (int i = 0; i < N; ++i) begin
            if (entries[head+i].complete) begin
                retiring_data[i] = entries[head];
                next_head = (head + i) % DEPTH;
            end else begin
                break;
            end
        end
    end

    // Incoming insts from dispatch (up to min(N, open_entries))
    // advance tail, num_entries += num_accept

    always_comb begin
        next_entries = entries;
        next_tail = (tail + num_accept) % DEPTH;

        for (int j = 0; j < N; ++j) begin
            if (wr_data[j].valid) begin
                next_entries[tail+j] = wr_data[j];
            end
            for(int k=0; k < DEPTH; ++k) begin
                if(entries[j].t == complete_t[k]) begin
                    next_entries[j].complete = 'b1;
                end
            end
        end
    end

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