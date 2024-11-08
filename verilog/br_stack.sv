`include "sys_defs.svh"
`include "psel_gen.sv"

typedef struct packed {
    logic valid;
    logic [`BRANCH_PRED_SZ-1:0] b_id;
    logic [`BRANCH_PRED_SZ-1:0] b_mask;
    ADDR rec_PC;
    MAP_TABLE_PACKET [`ARCH_REG_SZ-1:0] rec_mt;
    logic [$clog2(`ROB_SZ+1)-1:0] fl_head;
    logic [$clog2(`PHYS_REG_SZ_R10K)-1:0] rob_tail;
} CHECKPOINT;

module BR_STACK #(
    parameter DEPTH = 32,
    parameter N = `N
)(
    input                                                               clock,
    input                                                               reset,

    input                                                               valid_assign,
    input ADDR                                                          in_PC,
    input MAP_TABLE_PACKET          [`ARCH_REG_SZ-1:0]                  in_mt,
    input logic                     [$clog2(`ROB_SZ+1)-1:0]             in_fl_head,
    input logic                     [$clog2(`PHYS_REG_SZ_R10K)-1:0]     in_rob_tail,
    
    input CDB_PACKET                [N-1:0]                             cdb_in,
    
    input BR_TASK                                                       br_task,
    input logic                     [`BRANCH_PRED_SZ-1:0]               rem_b_id, // b_id to remove
    
    
    output CHECKPOINT                                                   cp_out,
    output logic                                                        full
);

    CHECKPOINT [`BRANCH_PRED_SZ-1:0] entries;
    CHECKPOINT [`BRANCH_PRED_SZ-1:0] next_entries;

    logic [`BRANCH_PRED_SZ-1:0] free_entries;
    logic [`BRANCH_PRED_SZ-1:0] next_free_entries;
    
    logic [`BRANCH_PRED_SZ-1:0] stack_gnt;

    psel_gen #(
        .WIDTH(`BRANCH_PRED_SZ),
        .REQS(1)
    ) stack (
        .req(free_entries),
        .gnt(stack_gnt),
        .gnt_bus(),
        .empty()
    );

    assign full = next_free_entries == 0;

    always_comb begin
        next_entries = entries;
        next_free_entries = free_entries;

        // ok something to consider, the outputted checkpoint may not be fully updated by the 
        // ready bits in the current cycle's cdb.
        // so this might be something that we check for again after recovering the map table

        // Branch clear or branch squash
        if (br_task == SQUASH) begin
            for (int i = 0; i < `BRANCH_PRED_SZ; i++) begin
                if (entries[i].b_id == rem_b_id) begin
                    cp_out = entries[i];
                end
                if (entries[i].b_mask & rem_b_id) begin
                    next_entries[i] = '0;
                    next_free_entries[i] = 0;
                end
            end
        end 

        if (br_task == CLEAR) begin
            for (int i = 0; i < `BRANCH_PRED_SZ; i++) begin
                // the following also might be an issue
                // i am setting next_entries[i] twice in the case that b_id == rem_b_id and that is sus
                if (entries[i].b_id == rem_b_id) begin
                    next_entries[i] = '0;
                    next_free_entries[i] = 0;
                end
                if (entries[i].b_mask & rem_b_id) begin
                    next_entries[i].b_mask &= ~rem_b_id;
                end
            end
        end

        // Set checkpoint
        if (valid_assign) begin
            for (int k = 0; k < `BRANCH_PRED_SZ; k++) begin
                if (stack_gnt[k]) begin
                    next_entries[k].valid = 1;
                    next_entries[k].b_id = stack_gnt;
                    next_entries[k].rec_PC = in_PC;
                    next_entries[k].rec_mt = in_mt;
                    next_entries[k].fl_head = in_fl_head;
                    next_entries[k].rob_tail = in_rob_tail;

                    for (int i = 0; i < `BRANCH_PRED_SZ; i++) begin
                        next_entries[k].b_mask |= next_entries[k + i].b_id;
                    end

                    next_free_entries[k] = 0;
                end 
            end
        end

        // Set ready bit for everything in the map table
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < `BRANCH_PRED_SZ; j++) begin
                if (cdb_in[i].p_reg_idx == entries[j].rec_mt[cdb_in[i].reg_idx]) begin
                    next_entries[j].rec_mt[cdb_in[i].reg_idx].ready = 1;
                end
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            entries <= '0;
            free_entries <= '1;
        end else begin
            entries <= next_entries;
            free_entries <= next_free_entries;
        end
    end

endmodule
