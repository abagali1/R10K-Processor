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
        end
    end

    // construct out_insts
    always_comb begin
        // Q: how to coalesce data exiting the mshr with cache hits?
        // this is an issue because inst buffer needs to be in-order (i think)
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