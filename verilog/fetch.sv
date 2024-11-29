`include "sys_defs.svh"

module fetch #(
    parameter N = `N,
    parameter NUM_MEM_TAGS = `NUM_MEM_TAGS
)
(
    input logic                     clock,
    input logic                     reset,

    input ADDR                      target,
    input logic                     br_en,
    input logic                     ibuff_open,

    input MEM_TAG                   mem_transaction_tag,
    input logic                     mem_transaction_started,
    input MEM_TAG                   mem_data_tag,
    input DATA                      mem_data,

    output logic                    mem_en,
    output ADDR                     mem_addr,

    output INST_PACKET [N-1:0]      out_insts,
    output logic [$clog2(N)-1:0]    num_insts
);
    INST_PACKET [N-1:0] next_out_insts;
    logic [$clog2(N)-1:0] next_num_insts;

    // 16 possible transaction tags from memory (1 based indexing as 0 is unused)
    ADDR [`NUM_MEM_TAGS-1:0] mshr_data, next_mshr_data;
    logic [`NUM_MEM_TAGS-1:0] mshr_valid, next_mshr_valid;
    ADDR next_mem_addr, prefetch_target;
    DATA cache_write_data;
    logic cache_write_en;

    assign mem_en = ~(&next_mshr_valid);

    // calculate prefetch target
        // Q: how can we check multiple cache entries to find the next item not in the cache?
        // perhaps return this from cache based on previous cache search?
        // when the branch predictor predicts taken, how do we update this value
            // i dont think we need to squash prefetched mem requests, as they could still
            // be useful in the cache if we mispredict

    // TODO: needs review? maybe i'm missing an edge case...
    // if there is a branch, prefetch_target = target
    // if the icache isn't valid, prefetch_target = next_miss_addr
    // otherwise, prefetch_target = current_fetch_addr + 8 (next instruction)
    always_comb begin
        prefetch_target = br_en ? target :
                         ~icache_valid ? next_miss_addr :
                         current_fetch_addr + 8;
    end

    // check cache validity and make request
    always_comb begin
        next_mem_addr = mem_addr;
        if (~icache_valid_out) begin
            next_mem_addr = prefetch_target;
        end
    end

    // update mshr when transaction tag recieved
    always_comb begin
        next_mshr_data = mshr_data;
        if (mem_transaction_started) begin
            next_mshr_data[mem_transaction_tag] = mem_addr;
            next_mshr_valid[mem_transaction_tag] = 1;
        end
    end

    // check for mshr eviction and cache updates
    always_comb begin
        cache_write_en = '0;
        cache_write_data = '0;
        if (mem_data_tag != 0 && mshr_valid[mem_data_tag]) begin
            cache_write_en = 1;
            cache_write_data = mem_data;
            next_mshr_data[mem_data_tag] = '0;
            next_mshr_valid[mem_data_tag] = '0;
            // this logic writes to cache but doesn't put data in out_insts
            // this is because we retrieve two insts from memory with every request
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
        // Q: how do we know if data from MSHR is still fetching? do we need to add a separate bit for ready or not?
        // or is it that when its done fetching data, we evict it, so things in MSHR are only ever fetching?
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

    

    // Q: does cache need to have be N-way read?
    // icache icache_0 (
    //     // inputs
    //     .clock                      (clock),
    //     .reset                      (reset),
    //     .proc2Icache_addr           (prefetch_target),
    //     .write_en                   (cache_write_en),
    //     .write_data                 (cache_write_data),
    //     // outputs
    //     .Icache_data_out            (icache_out),
    //     .Icache_valid_out           (icache_valid)
    // );

    always_ff @(posedge clock) begin
        if (reset || br_en) begin
            out_insts       <= '0;
            num_insts       <= '0;
            mshr_data       <= '0;
            mshr_valid      <= '0;
            mem_addr        <= '0;
        end else begin
            out_insts       <= next_out_insts;
            num_insts       <= next_num_insts;
            // TODO: ^^ handle ibuff_open in always comb
            mshr_data       <= next_mshr_data;
            mshr_valid      <= next_mshr_valid;
            if (mem_en) begin
                mem_addr    <= next_mem_addr;
            end
        end
    end
endmodule