`include "sys_defs.svh"

module RS #(
    parameter DEPTH = 32,
    parameter N = `N,
)
(
    input                               clock,
    input                               reset,

    input RS_PACKET [N-1:0]             rs_in,
    input CDB_PACKET [N-1:0]            cdb_in,

    // ebr logic
    input BR_MASK                       br_id,                   
    input BR_TASK                       br_task,                   

    // busy bits from FUs to mark when available to issue
    input logic [`NUM_FU_ALU-1:0]          fu_alu_busy,
    input logic [`NUM_FU_MULT-1:0]         fu_mult_busy,
    input logic [`NUM_FU_LD-1:0]           fu_ld_busy,
    input logic [`NUM_FU_STORE-1:0]        fu_store_busy,
    input logic [`NUM_FU_BR-1:0]           fu_br_busy, // don't think is necessary

    // output packets directly to FUs
    output RS_PACKET [`NUM_FU_ALU-1:0]          issued_alu, // [[], [], [], []]
    output RS_PACKET [`NUM_FU_MULT-1:0]         issued_mult,
    output RS_PACKET [`NUM_FU_LD-1:0]           issued_ld,
    output RS_PACKET [`NUM_FU_STORE-1:0]        issued_store,
    output RS_PACKET [`NUM_FU_BR-1:0]           issued_br,

    output logic [$clog2(DEPTH+1)-1:0]          open_entries,

    `ifdef DEBUG
    ,   output ROB_ENTRY_PACKET [DEPTH-1:0] debug_entries
    `endif
);
    RS_PACKET [DEPTH-1:0] entries, next_entries;
    logic [LOG_DEPTH:0] num_entries, next_num_entries;

    always_comb begin
        next_entries = entries;

        // TODO: Mark ready tags incoming from CDB

        // TODO: copy paste for every FU
        for (int i = 0; i < `NUM_FU_ALU; ++i) begin
            if (~fu_alu_busy[i]) begin
                for (int j = 0; j < DEPTH; ++j) begin
                    if (next_entries[j].valid & next_entries[j].t1.ready & next_entries[j].t2.ready) begin
                        issued_alu[i] = entries[j];
                        next_entries[j] = 0;
                        break;
                    end
                end
            end
        end

        for (int i = 0; i < `NUM_FU_MULT; ++i) begin
            if (~fu_mult_busy[i]) begin
                for (int j = 0; j < DEPTH; ++j) begin
                    if (next_entries[j].valid & next_entries[j].t1.ready & next_entries[j].t2.ready) begin
                        issued_mult[i] = entries[j];
                        next_entries[j] = 0;
                        break;
                    end
                end
            end
        end

        // read in new entries
        for (int i = 0; i < N; ++i) begin
            if (rs_in[i].valid) begin
                for (int j = 0; j < DEPTH; ++j) begin
                    if (~next_entries[j].valid) begin
                        next_entries[j] = rs_in[i];
                    end
                end
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            entries <= 0;
        end else begin
            entries <= next_entries;
        end
    end
endmodule