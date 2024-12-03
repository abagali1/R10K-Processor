`include "sys_defs.svh"
`include "icache.sv"

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
    logic [`NUM_MEM_TAGS-1:0] mshr_valid, next_mshr_valid;
    
    ADDR next_mem_addr, cache_target, prefetch_target, prev_prefetch_target;
    MEM_BLOCK cache_write_data, cache_read_data;
    logic cache_write_en;
    logic mem_transaction_started;

    MEM_BLOCK Icache_data_out;
    logic     Icache_valid_out; 
    ADDR      next_invalid_line;

    logic icache_valid;

    logic valid_insts;
    logic insts_to_return;
    

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


        // TODO: so this needs to be kept to coalesce the mshr val with the icache vals
        // but we need to return min(ibuff_open, valid icache insts) from icache
        // so presumably this has to come first. 

        // perform coalescing logic
        // a few cases:

        // case: new memory data from mshr (indicated by cache_write_en)
        if (cache_write_en) begin
            if (ibuff_open) begin
                // iterate through 4 potential returns
                for (int i = 0; i < 4; i++) begin
                    ADDR current = target + i * 4;
                    // if the address is in the same block as cache_target
                    if (current[31:3] == cache_target[31:3]) begin
                        next_out_insts[i].inst = cache_write_data.word_level[current[2]];
                        if (next_out_insts[i].inst) begin
                            next_out_insts[i].valid = 1'b1;
                            next_out_insts[i].PC = current;
                            next_out_insts[i].NPC = current + 4;
                            next_out_insts[i].pred_taken = 1'b0;
                            next_num_insts = next_num_insts + 1;
                        end
                    end
                    // Check if this address hits in the cache
                    else if (icache_valid && current[31:3] == cache_target[31:3]) begin
                        next_out_insts[i].inst = cache_read_data.word_level[current[2]];
                        if (next_out_insts[i].inst) begin
                            next_out_insts[i].valid = 1'b1;
                            next_out_insts[i].PC = current;
                            next_out_insts[i].NPC = current + 4;
                            next_out_insts[i].pred_taken = 1'b0;
                            next_num_insts = next_num_insts + 1;
                        end
                    end
                end
            end
        end 
        // case: cache hit
        else if (icache_valid) begin
            // cache hit handling
            for (int i = 0; i < 4; i++) begin
                ADDR current = target + i * 4;
                // same block
                if (current[31:3] == cache_target[31:3]) begin
                    next_out_insts[i].inst = cache_read_data.word_level[current[2]];
                    // if (next_out_insts[i].inst) begin
                    //     next_out_insts[i].valid = 1'b1;
                    //     next_out_insts[i].PC = current;
                    //     next_out_insts[i].NPC = current + 4;
                    //     next_out_insts[i].pred_taken = 1'b0;
                    //     next_num_insts = next_num_insts + 1;
                    // end
                end
            end
        end




        // RETURN LOGIC TO RETURN MIN(IBUFF, VALID INSTS IN CACHE)

        // counts valid instructions in current cache line
        valid_insts = '0;
        for (int i = 0; i < 4; i++) begin
            logic adr = target + (i * 4);
            if (icache_valid && (adr[31:3] == cache_target[31:3] && cache_read_data.word_level[i][31:0] != '0)) begin
                valid_insts = valid_insts + 1;
            end
        end

        insts_to_return = (valid_insts < ibuff_open) ? valid_insts : ibuff_open;

        // output instructions up to the calculated limit
        next_num_insts = '0;
        for (int i = 0; i < 4 && next_num_insts < insts_to_return; i++) begin
            ADDR current = target + (i * 4);
            if (icache_valid && current[31:3] == cache_target[31:3]) begin
                next_out_insts[next_num_insts].inst = cache_read_data.word_level[current[2]];
                if (next_out_insts[next_num_insts].inst != '0) begin
                    next_out_insts[next_num_insts].valid = 1'b1;
                    next_out_insts[next_num_insts].PC = current;
                    next_out_insts[next_num_insts].NPC = current + 4;
                    next_out_insts[next_num_insts].pred_taken = 1'b0;
                    next_num_insts = next_num_insts + 1;
                end
            end
        end

        // Update prefetch target to next invalid line from icache
        prefetch_target = next_invalid_line;
    end



    // old next_out_insts composition - [for reference]
    // always_comb begin
    //     next_out_insts = '0;
    //     next_num_insts = '0;

    //     if (ibuff_open) begin
    //         // First try MSHR data
    //         for (int i = 0; i < 2 && next_num_insts < N; i++) begin
    //             if (mshr_valid_insts[i]) begin
    //                 next_out_insts[next_num_insts].inst = mshr_data_current.word_level[i];
    //                 next_out_insts[next_num_insts].PC = mshr_write_addr + (i * 4);
    //                 next_out_insts[next_num_insts].valid = 1'b1;
    //                 next_num_insts = next_num_insts + 1;
    //             end
    //         end

    //         // Then try cache data if MSHR didn't have it
    //         if (next_num_insts < N && icache_valid) begin
    //             for (int i = 0; i < 2 && next_num_insts < N; i++) begin
    //                 if (!mshr_valid_insts[i]) begin
    //                     next_out_insts[next_num_insts].inst = icache_out.word_level[i];
    //                     next_out_insts[next_num_insts].PC = cache_target + (i * 4);
    //                     next_out_insts[next_num_insts].valid = 1'b1;
    //                     next_num_insts = next_num_insts + 1;
    //                 end
    //             end
    //         end
    //     end
    // end

    icache icache_0 (
        // inputs
        .clock                      (clock),
        .reset                      (reset),
        .proc2Icache_addr         (cache_target),
        .write_en                   (cache_write_en),
        .write_data                 (cache_write_data),
        // outputs
        .Icache_data_out            (cache_read_data),
        .Icache_valid_out           (icache_valid),
        .next_invalid_line          (next_invalid_line)
    );

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



