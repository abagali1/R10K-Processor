`include "sys_defs.svh"

module fetch #(
    parameter N = `N,
    parameter NUM_MEM_TAGS = `NUM_MEM_TAGS
)
(
    input logic                     clock,
    input logic                     reset,

    input ADDR                      target,
    input logic                     br_en,  // taken or squashed, whenever target chanegs
    input logic                     ibuff_open,

    input MEM_TAG                   mem_transaction_tag,
    input logic                     mem_transaction_handshake,
    input MEM_TAG                   mem_data_tag,
    input DATA                      mem_data,

    output logic                    mem_en,
    output ADDR                     mem_addr,

    output INST_PACKET [3:0]        out_insts,
    output logic [1:0]              num_insts
);
    typedef enum logic [1:0] {FETCH, PREFETCH, STALL} STATE;

    STATE state, next_state;
    INST_PACKET [N-1:0] next_out_insts;
    logic [$clog2(N)-1:0] next_num_insts;

    // 16 possible transaction tags from memory (1 based indexing as 0 is unused)
    ADDR [`NUM_MEM_TAGS-1:0] mshr_data, next_mshr_data;
    logic [`NUM_MEM_TAGS-1:0] mshr_valid, next_mshr_valid, 
    
    ADDR next_mem_addr, cache_target, prefetch_target, prev_prefetch_target;
    DATA cache_write_data;
    logic cache_write_en;
    logic mem_transaction_started;

    assign mshr_full = &next_mshr_valid;
    assign mem_en = ~mshr_full & ~icache_valid;

    // if there is a branch, prefetch_target = target
    // if the icache isn't valid, prefetch_target = next_miss_addr
    // otherwise, prefetch_target = current_fetch_addr + 8 (next instruction)
    always_comb begin
        prefetch_target =   (state == FETCH) ? target : 
                            (state == PREFETCH) ? prev_prefetch_target + 8 :
                            (state == STALL) ? prev_prefetch_target : '0;
        next_state = (state == FETCH) ? PREFETCH :
                     (state == PREFETCH & mshr_full & ~icache_valid) ? STALL :
                     (state == STALL & ~mshr_full) ? PREFETCH : state;
        next_mem_addr = (state == FETCH | mem_transaction_handshake) ? prefetch_target : mem_addr;
    end
    
    always_comb begin
        cache_write_en = '0;
        cache_write_data = '0;
        next_out_insts = '0;
        next_mshr_data = mshr_data;
        cache_target = prefetch_target;

        // check for mshr eviction and cache updates
        if (mem_data_tag != 0 & mshr_valid[mem_data_tag]) begin
            cache_write_en = 1;
            cache_write_data = mem_data;
            cache_target = next_mshr_data[mem_data_tag];
            next_mshr_data[mem_data_tag] = '0;
            next_mshr_valid[mem_data_tag] = '0;
        end

        // update mshr when transaction tag recieved
        if (mem_transaction_handshake) begin
            next_mshr_data[mem_transaction_tag] = mem_addr;
            next_mshr_valid[mem_transaction_tag] = 1;
        end

        // perform coalescing logic
        // TODO rohan -- this 1:0 type notation prob isn't right if target is odd
        if (cache_write_en) begin
            next_out_insts[1:0] = cache_write_data;
            if (cache_valid) begin
                next_out_insts[3:0] = cache_read_data;
            end
        end else if (cache_valid) begin
            next_out_insts[1:0] = cache_read_data;
        end
    end

    MEM_BLOCK mshr_data_current;
    MEM_BLOCK cache_data_current;

    // construct out_insts
    always_comb begin
        // Q: how to coalesce data exiting the mshr with cache hits?
        // this is an issue because inst buffer needs to be in-order (i think)
        // could only push ready data, and only advance prefetch target to the first non-ready instruction
            // might necessitate refetching from cache? waste of ports but otherwise we'd need a large intermed storage solution

        next_out_insts = '0;
        next_num_insts = '0;
        if (ibuff_open) begin
            // grab mshr data
            for (int i = 0; i < 2 && next_num_insts < N; i++) begin
                if (mshr_valid_insts[i]) begin
                    next_out_insts[next_num_insts].inst = mshr_data_current.word_level[i];
                    next_out_insts[next_num_insts].PC = mshr_addr + (i * 4);
                    next_out_insts[next_num_insts].valid = 1'b1;
                    next_num_insts = next_num_insts + 1;
                end
            end

            // grab cache data if we need more data?
            if (next_num_insts < N && icache_valid) begin
                for (int i = 0; i < 2 && next_num_insts < N; i++) begin
                    if (cache_valid_insts[i]) begin
                        next_out_insts[next_num_insts].inst = icache_out.word_level[i];
                        next_out_insts[next_num_insts].PC = cache_addr + (i * 4);
                        next_out_insts[next_num_insts].valid = 1'b1;
                        next_num_insts = next_num_insts + 1;
                    end
                end
            end
        end
    end

    // icache icache_0 (
    //     // inputs
    //     .clock                      (clock),
    //     .reset                      (reset),
    //     .proc2Icache_addr           (cache_target),
    //     .write_en                   (cache_write_en),
    //     .write_data                 (cache_write_data),
    //     // outputs
    //     .Icache_data_out            (cache_read_data),
    //     .Icache_valid_out           (cache_valid)
    // );

    always_ff @(posedge clock) begin
        if (reset || br_en) begin
            state                <= FETCH;
            out_insts            <= '0;
            num_insts            <= '0;
            mshr_data            <= '0;
            mshr_valid           <= '0;
            mem_addr             <= '0;
            prev_prefetch_target <= '0;
        end else begin
            state                <= next_state;
            out_insts            <= next_out_insts;
            num_insts            <= next_num_insts;
            // TODO: ^^ handle ibuff_open in always comb
            mshr_data            <= next_mshr_data;
            mshr_valid           <= next_mshr_valid;
            mem_addr             <= next_mem_addr;
            prev_prefetch_target <= prefetch_target;
        end
    end
endmodule




// prefetch
// i cache hit - return
// i cache miss - create mshr - send data request
// constantly check if data return transaction tag is equal to a transaction tag in mshr - if it is:
// COALESCE
// if mshr addr == target addr, return data to fetch then put in cache
// else just put in cache
// 