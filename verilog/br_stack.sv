`include "sys_defs.svh"

`ifndef _PSEL
`define _PSEL
`include "psel_gen.sv"
`endif

module br_stack #(
    parameter DEPTH = `BRANCH_PRED_SZ,
    parameter N = `N
)(
    input                                                                   clock,
    input                                                                   reset,

    input DECODED_PACKET                                                    dis_inst, // first dispatched instruction
    input MAP_TABLE_PACKET          [`ARCH_REG_SZ-1:0]                      in_mt,
    input logic                     [$clog2(`ROB_SZ+1)-1:0]                 in_fl_head,
    input logic                     [$clog2(`PHYS_REG_SZ_R10K)-1:0]         in_rob_tail,
    
    input CDB_PACKET                [N-1:0]                                 cdb_in,
    
    input BR_TASK                                                           br_task, // not defined here. in main sysdefs
    input BR_MASK                                                           rem_b_id, // b_id to remove
    
    output BR_MASK                                                          assigned_b_id, // b_id given to a dispatched branch instruction
    output CHECKPOINT                                                       cp_out,
    output logic                                                            full

    `ifdef DEBUG
    ,   CHECKPOINT                  [DEPTH-1:0]                             debug_entries,
        logic                       [DEPTH-1:0]                             debug_free_entries,
        logic                       [DEPTH-1:0]                             debug_stack_gnt
    `endif

);

    CHECKPOINT [DEPTH-1:0] entries;
    CHECKPOINT [DEPTH-1:0] next_entries;

    logic [DEPTH-1:0] free_entries; // bit map of whether an entry is free (1 if free)
    logic [DEPTH-1:0] next_free_entries;
    
    logic [DEPTH-1:0] stack_gnt;

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(1)
    ) stack (
        .req(free_entries),
        .gnt(stack_gnt),
        .gnt_bus(),
        .empty()
    );

    // WE DO NOTHING IF FULL
    assign full = free_entries == 0;

    always_comb begin
        next_entries = entries;
        next_free_entries = free_entries;

        `ifdef DEBUG
            debug_entries = entries;
            debug_free_entries = free_entries;
            debug_stack_gnt = stack_gnt;
        `endif

        // Branch clear or branch squash
        if (br_task == SQUASH) begin
            for (int i = 0; i < DEPTH; i++) begin
                if (entries[i].b_id == rem_b_id) begin
                    cp_out = entries[i];
                end
                if (entries[i].b_mask & rem_b_id) begin
                    next_entries[i] = '0;
                    next_free_entries[i] = 1;
                end
            end
        end 

        if (br_task == CLEAR) begin
            for (int i = 0; i < DEPTH; i++) begin
                if (entries[i].b_id == rem_b_id) begin
                    next_entries[i] = '0;
                    next_free_entries[i] = 1;
                end else if (entries[i].b_mask & rem_b_id) begin
                    next_entries[i].b_mask &= ~rem_b_id;
                end
            end
        end

        // Set checkpoint
        assigned_b_id = '0;
        if (dis_inst.valid && (dis_inst.uncond_branch || dis_inst.cond_branch)) begin // check me on this
            for (int k = 0; k < DEPTH; k++) begin
                if (stack_gnt[k]) begin
                    next_entries[k].valid = 1;
                    next_entries[k].b_id = stack_gnt;
                    //next_entries[k].rec_PC = dis_inst.PC;
                    next_entries[k].rec_mt = in_mt;
                    next_entries[k].fl_head = in_fl_head;
                    next_entries[k].rob_tail = in_rob_tail;

                    for (int i = 0; i < DEPTH; i++) begin
                        next_entries[k].b_mask |= next_entries[i].b_id;
                    end

                    next_free_entries[k] = 0;
                end 
            end
            assigned_b_id = stack_gnt;
        end

        // Set ready bit for everything in the map table
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < DEPTH; j++) begin
                if (cdb_in[i].p_reg_idx == entries[j].rec_mt[cdb_in[i].reg_idx].reg_idx) begin // CHECK is this not supposed entries[j].rec_mt[cdb_in[i].reg_idx].reg_idx
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

    `ifdef DEBUG
        always @(posedge clock) begin
            $display("============== BRANCH STACK ==============\n");
            $display("  Entries:");
            $display("-------------------------------------");
            $display("i | b_id |  b_mask | fl_head | rob_tail  |");
            for (int i = 0; i < DEPTH; i++) begin
                $display("%02d|  %02d  |  %02d  |  %02d  |   %01d   |", i, entries[i].b_id, entries[i].b_mask, entries[i].fl_head, entries[i].rob_tail);
            end
            $display("");
        end
    `endif

endmodule
