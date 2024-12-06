`include "sys_defs.svh"
//import "DPI-C" function string decode_inst(int inst);
//`include "icache.sv"

module fetch #(
    parameter N = `N,
    parameter NUM_MEM_TAGS = `NUM_MEM_TAGS,
    parameter INST_BUFF_DEPTH = `INST_BUFF_DEPTH,
    parameter PREFETCH_DISTANCE = `PREFETCH_DISTANCE
)
(
    input logic                     clock,
    input logic                     reset,

    input ADDR                      target,
    input logic                     arbiter_signal, // high when fetch can use memory
    input BR_TASK                   br_task,  // taken or squashed, whenever target chanegs
    input logic [$clog2(INST_BUFF_DEPTH+1)-1:0] ibuff_open, // number of open instruction buffer entries

    input MEM_TAG                   mem_transaction_tag, // Memory tag for current transaction (0 = can't accept)
    //input logic                     mem_transaction_handshake,
    input MEM_TAG                   mem_data_tag, // Tag for finished transactions (0 = no value)
    input MEM_BLOCK                 mem_data, // Data for a load

    output logic                    mem_en,
    output ADDR                     mem_addr_out,   // address we want to read from memory
    //output MEM_COMMAND              mem_command,

    output INST_PACKET  [3:0]       out_insts, // hardcoded to 4
    output logic        [2:0]       out_num_insts, // need 3 bits to represent 4
    output ADDR                     NPC

    `ifdef DEBUG
    ,   output  ADDR [NUM_MEM_TAGS:1] debug_mshr_data,
        output  logic [NUM_MEM_TAGS:1] debug_mshr_valid
    `endif
);
    //typedef enum logic [1:0] {FETCH, PREFETCH, STALL, DEF} STATE;

    //STATE state, next_state;
    INST_PACKET [3:0] next_out_insts;
    logic [2:0] num_insts, next_num_insts;
    
    assign out_num_insts = num_insts;

    // 16 possible transaction tags from memory (1 based indexing as 0 is unused)
    // this should be 15:1 (16 entries, 0 is unused = 15 entries)
    ADDR    [NUM_MEM_TAGS:1]   mshr_data, next_mshr_data;
    logic   [NUM_MEM_TAGS:1]   mshr_valid, next_mshr_valid;
    logic found_in_mshr;

    `ifdef DEBUG
        assign debug_mshr_data = mshr_data;
        assign debug_mshr_valid = mshr_valid;
    `endif
    
    //ADDR cache_target, prefetch_target, next_prefetch_target;
    logic           cache_write_en;
    MEM_BLOCK       cache_write_data;
    ADDR            cache_write_addr;

    MEM_BLOCK   [PREFETCH_DISTANCE-1:0] cache_read_data;
    logic       [PREFETCH_DISTANCE-1:0] icache_valid, icache_alloc;

    //logic mem_transaction_started;
    logic mem_done;


    //logic valid_insts;
    logic [2:0] insts_to_return;
    //logic br_en;

    ADDR prefetch_target, cache_target, next_cache_target;

    //ADDR mem_addr;

    // TODO
    assign mem_done = mem_data_tag != 0 & mshr_valid[mem_data_tag];
    
    //assign mem_command = mem_en ? MEM_LOAD : MEM_NONE;
    //assign br_en = br_task == SQUASH | br_task == CLEAR;
    // removed br_en, we should only clear state on a squash, a "clear" task means our prediction was correct and we should keep chugging

    assign mshr_full = &next_mshr_valid;
    //assign mem_en = ~mshr_full & ~icache_valid;

    // if there is a branch, prefetch_target = target
    // if the icache isn't valid, prefetch_target = next_miss_addr
    // otherwise, prefetch_target = current_fetch_addr + 8 (next instruction)
    always_comb begin
        cache_write_en = '0;
        cache_write_addr = '0;
        cache_write_data = '0;
        next_mshr_data = mshr_data;
        next_mshr_valid = mshr_valid;
        mem_en = 0;
        prefetch_target = '0;
        //cache_target = target;

        // check for mshr eviction and cache updates
        // mem is finsihed, write to cache
        // MEM TO CACHE
        if (mem_done) begin
            cache_write_en = 1;
            cache_write_data = mem_data;
            cache_write_addr = mshr_data[mem_data_tag];
            next_mshr_data[mem_data_tag] = '0;
            next_mshr_valid[mem_data_tag] = '0;
        end

        // FETCHING + PREFETCHING
        mem_addr_out = '0;

        //$display("MSHRFULL: %0d", ~mshr_full);
        $display("ARBITER SIGNAL: %0d", arbiter_signal);
        if (arbiter_signal & ~mshr_full) begin
            for (int i = 0; i < PREFETCH_DISTANCE; i++) begin
                // check if in icache first\
                found_in_mshr = 0;
                $write("\nicache alloc %b\n", icache_alloc);
                if (~icache_valid[i]) begin
                    // check in mhr
                    prefetch_target = ({cache_target[31:3], 3'b0} + (i*8));
                    for (int j = 1; j <= NUM_MEM_TAGS; j++) begin
                        $display("MSHR_DATA: %d,  PREFETCH_TARGET %d, EQUALS? %0d, SUMMARY: %0d", mshr_data[j], prefetch_target, (mshr_data[j] == prefetch_target), (mshr_valid[j] & (mshr_data[j][31:3] == prefetch_target[31:3])));
                        if (mshr_valid[j] & (mshr_data[j][31:3] == prefetch_target[31:3])) begin
                            found_in_mshr = 1;
                            break;
                        end
                    end
                    if (~found_in_mshr) begin
                        // request from memory
                        mem_en = 1;
                        mem_addr_out = prefetch_target;
                        //mem_command = MEM_LOAD;

                        next_mshr_data[mem_transaction_tag] = prefetch_target;
                        next_mshr_valid[mem_transaction_tag] = 1;
                        break;
                    end
                end
            end
        end
    end
    
    logic [2:0] j;
    // FETCH TO INST_BUF
    always_comb begin
        next_num_insts = '0;
        next_out_insts = '0;
        next_cache_target = NPC;
        
        $write("ICACHE VALID: %b", icache_valid);
        // Changed this to three to handle this case
        // [0|1] [1|1] [1|1]
        // Now it can output 4 instructions instead of the previous 3
        for (int i = 0; i < PREFETCH_DISTANCE; i++) begin
            // if the cache block is valid, increment next_num_insts by 2 (2 insts per block)
            if (icache_valid[i]) begin
                if (~target[2] | i > 0) begin 
                    next_num_insts += 2;
                end else begin
                    next_num_insts += 1;
                end
            end else begin
                break;
            end
        end

        next_num_insts = next_num_insts > 4 ? 4 : next_num_insts; // min(next_num_insts, 4)

        next_num_insts = (next_num_insts < (ibuff_open - num_insts)) ? next_num_insts : (ibuff_open - num_insts);

        // Note: Temporary design decision, we only read instructions from icache, this could waste some cycles (faster to implement rn)
        // case: cache hit
        // [0|1] [1|1] [1|1]
        // i = 0; i < next_num_insts + target[2]
        // TODO: J is gross, we use it to get all four instructions out in the [0|1] [1|1] [1|1] case.
        j = '0;
        for (int i = 0; i < 4; i++) begin
            ADDR current;
            current = NPC + (i * 4);
            j = i + NPC[2];
            $write("\nCACHE_READ_DATA[i/2].word_level[current[2]] = %b AND target = %b AND valid = %b\n", cache_read_data[j/2].word_level[current[2]], NPC, icache_valid[j/2]);
            if (j < next_num_insts + NPC[2]) begin
                //$write("SETTING OUT INST: %h -- %s %b\n", current, decode_inst(cache_read_data[j/2].word_level[current[2]]), icache_valid[j/2]);
                next_out_insts[i].inst = cache_read_data[j/2].word_level[current[2]];
                next_out_insts[i].valid = 1'b1;
                next_out_insts[i].PC = current;
                next_out_insts[i].NPC = current + 4;
                next_out_insts[i].pred_taken = 1'b0; // TODO branch prediction

                next_cache_target = next_cache_target > current ? next_cache_target : current + 4;
            end else begin
                break;
            end
        end
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
        .proc2Icache_addr           (NPC),
        .br_task                    (br_task),
        .alloc_addr                 (mem_addr_out),
        .alloc_en                   (mem_en),
        .write_en                   (cache_write_en),
        .write_addr                 (cache_write_addr),
        .write_data                 (cache_write_data),
        // outputs
        .Icache_data_out            (cache_read_data),
        .Icache_valid_out           (icache_valid),
        .Icache_alloc_out           (icache_alloc)
    );

    assign NPC = (br_task == SQUASH) ? target : cache_target;

    always_ff @(posedge clock) begin
        if (reset) begin // TODO squash doesn't necessarily mean to empty everything, could be beneficial to keep icache (imagine short loops)
            out_insts            <= '0;
            num_insts            <= '0;
            cache_target         <= '0;
            mshr_data            <= '0;
            mshr_valid           <= '0;
            //mem_addr             <= '0;
        end else if (br_task == SQUASH) begin
            out_insts            <= '0;
            num_insts            <= '0;
            cache_target         <= next_cache_target;
        end else begin
            out_insts            <= next_out_insts;
            num_insts            <= next_num_insts;
            // TODO: ^^ handle ibuff_open in always comb
            mshr_data            <= next_mshr_data;
            mshr_valid           <= next_mshr_valid;
            //mem_addr             <= next_mem_addr;
            cache_target         <= next_cache_target;
        end
        
        for (int i = 0; i < 4; i++) begin
            $display("OUT INSTSS: %b", out_insts[i]);
        end
        $display("MEM DONE: %b %b %b %b", mem_done, cache_write_en, cache_write_addr, cache_write_data);

        //$display("          mem_addr: %h -- mem_en: %b -- mem_transaction_handshake: %b", mem_addr, mem_en, mem_transaction_handshake);
        //$display("          cache_target: %h -- cache_write_en: %b -- icache_valid: %b", cache_target, cache_write_en, icache_valid);
    end
endmodule
