`include "sys_defs.svh"
`include "psel_gen.sv"

module RS #(
    parameter DEPTH = 32,
    parameter N = `N
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
    input logic [`NUM_FU_BR-1:0]           fu_br_busy, 

    // output packets directly to FUs (they all are pipelined)
    output RS_PACKET [`NUM_FU_ALU-1:0]          issued_alu, 
    output RS_PACKET [`NUM_FU_MULT-1:0]         issued_mult,
    output RS_PACKET [`NUM_FU_LD-1:0]           issued_ld,
    output RS_PACKET [`NUM_FU_STORE-1:0]        issued_store,
    output RS_PACKET [`NUM_FU_BR-1:0]           issued_br,

    output logic [$clog2(DEPTH+1)-1:0]          open_entries

    `ifdef DEBUG
    ,   output ROB_ENTRY_PACKET [DEPTH-1:0] debug_entries
    `endif
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    RS_PACKET [DEPTH-1:0] entries, next_entries;
    logic [LOG_DEPTH:0] num_entries, next_num_entries;

    assign open_entries = DEPTH - num_entries;

    // Psel wires
    logic [DEPTH-1:0] alu_req, mult_req, ld_req, store_req, br_req;
    logic [DEPTH-1:0] alu_gnt, mult_gnt, ld_gnt, store_gnt, br_gnt;
    logic [DEPTH*N-1:0] alu_gnt_bus, mult_gnt_bus, ld_gnt_bus, store_gnt_bus, br_gnt_bus;
    logic alu_empty, mult_empty, ld_empty, store_empty, br_empty;

    logic [LOG_DEPTH:0] alu_idx, mult_idx, ld_idx, store_idx, br_idx;

    // Priority Selectors, one for each type of FU
    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_ALU)) 
    alu_psel (
        .req(alu_req),
        .gnt(alu_gnt),
        .gnt_bus(alu_gnt_bus),
        .empty(alu_empty)
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_MULT)) 
    mult_psel (
        .req(mult_req),
        .gnt(mult_gnt),
        .gnt_bus(mult_gnt_bus),
        .empty(mult_empty)
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_LD)) 
    ld_psel (
        .req(ld_req),
        .gnt(ld_gnt),
        .gnt_bus(ld_gnt_bus),
        .empty(ld_empty)
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_STORE)) 
    store_psel (
        .req(store_req),
        .gnt(store_gnt),
        .gnt_bus(store_gnt_bus),
        .empty(store_empty)
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_BR)) 
    br_psel (
        .req(br_req),
        .gnt(br_gnt),
        .gnt_bus(br_gnt_bus),
        .empty(br_empty)
    );

    // Logic for assigning req to psels
    always_comb begin
        alu_req = 0;
        mult_req = 0;
        ld_req = 0;
        store_req = 0;
        br_req = 0;
        for (int i = 0; i < DEPTH; i++) begin
            if (entries[i].t1.ready & entries[i].t2.ready) begin
                if (entries[i].fu_type == ALU_INST) begin
                    alu_req[i] = 1;
                end else if (entries[i].fu_type == MULT_INST) begin
                    mult_req[i] = 1;
                end else if (entries[i].fu_type == LD_INST) begin
                    ld_req[i] = 1;
                end else if (entries[i].fu_type == STORE_INST) begin
                    store_req[i] = 1;
                end else if (entries[i].fu_type == BR_INST) begin
                    br_req[i] = 1;
                end
            end
        end
    end

    always_comb begin
        next_entries = entries;

        // Marks entry tags as ready (parallelized)
        for (int i = 0; i < N; i++) begin
            if (cdb_in[i].valid) begin
                for (int j = 0; j < DEPTH; j++) begin
                    if (entries[j].valid) begin
                        if (entries[j].t1.reg_idx == cdb_in[i].reg_idx) begin
                            next_entries[j].t1.ready = 1;
                        end
                        if (entries[j].t2.reg_idx == cdb_in[i].reg_idx) begin
                            next_entries[j].t2.ready = 1;
                        end
                    end
                end
            end
        end

        // Branch mask logic
        if (br_task != NOTHING) begin
            if (br_task == SQUASH) begin
                for (int i = 0; i < DEPTH; i++) begin
                    if ((entries[i].b_mask & br_id) != 0) begin
                        next_entries[i] = 0;
                        next_num_entries--;
                    end
                end
            end else if (br_task == CLEAR) begin
                for (int i = 0; i < DEPTH; i++) begin
                    if ((entries[i].b_mask & br_id) != 0) begin
                        next_entries[i].b_mask = entries[i].b_mask ^ br_id;
                    end
                end
            end
        end

        // Reads Psel logic and issues
        alu_idx = 0;
        mult_idx = 0;
        ld_idx = 0;
        store_idx = 0;
        br_idx = 0;
        for (int i = 0; i < DEPTH; i++) begin
            if (alu_gnt[i]) begin
                if (~fu_alu_busy[i]) begin
                    issued_alu[alu_idx] = next_entries[i];
                    next_entries[i] = 0;
                    next_num_entries--;
                end
                alu_idx++;
            end else if (mult_gnt[i]) begin
                if (~fu_mult_busy[i]) begin
                    issued_mult[mult_idx] = next_entries[i];
                    next_entries[i] = 0;
                    next_num_entries--;
                end
                mult_idx++;
            end else if (ld_gnt[i]) begin
                if (~fu_ld_busy[i]) begin
                    issued_ld[ld_idx] = next_entries[i];
                    next_entries[i] = 0;
                    next_num_entries--;
                end
                ld_idx++;
            end else if (store_gnt[i]) begin
                if (~fu_store_busy[i]) begin
                    issued_store[store_idx] = next_entries[i];
                    next_entries[i] = 0;
                    next_num_entries--;
                end
                store_idx++;
            end else if (br_gnt[i]) begin
                if (~fu_br_busy[i]) begin
                    issued_br[br_idx] = next_entries[i];
                    next_entries[i] = 0;
                    next_num_entries--;
                end
                br_idx++;
            end
        end

        // Reads in new entries
        for (int i = 0; i < N; ++i) begin
            if (rs_in[i].valid) begin
                for (int j = 0; j < DEPTH; ++j) begin
                    if (~next_entries[j].valid) begin
                        next_entries[j] = rs_in[i];
                        next_num_entries++;
                    end
                end
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            entries <= 0;
            num_entries <= 0;
        end else begin
            entries <= next_entries;
            num_entries <= next_num_entries;
        end
    end
endmodule