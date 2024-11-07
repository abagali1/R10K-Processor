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
    //input logic [`NUM_FU_BR-1:0]           fu_br_busy, 

    // output packets directly to FUs (they all are pipelined)
    output RS_PACKET [`NUM_FU_ALU-1:0]          issued_alu, 
    output RS_PACKET [`NUM_FU_MULT-1:0]         issued_mult,
    output RS_PACKET [`NUM_FU_LD-1:0]           issued_ld,
    output RS_PACKET [`NUM_FU_STORE-1:0]        issued_store,
    output RS_PACKET                            issued_br,

    output logic [$clog2(DEPTH+1)-1:0]          open_entries

    `ifdef DEBUG
    ,   output ROB_ENTRY_PACKET [DEPTH-1:0] debug_entries
    `endif
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    RS_PACKET [DEPTH-1:0] entries, next_entries;
    logic [LOG_DEPTH:0] num_entries, next_num_entries;

    assign open_entries = DEPTH - num_entries;

    // Issuing psel wires
    logic [DEPTH-1:0] alu_req, mult_req, ld_req, store_req, br_req;
    logic [DEPTH-1:0] alu_gnt, mult_gnt, ld_gnt, store_gnt, br_gnt;
    logic [`NUM_FU_ALU-1:0][DEPTH-1:0] alu_gnt_bus
    logic [`NUM_FU_MULT-1:0][DEPTH-1:0] mult_gnt_bus;
    logic [`NUM_FU_LOAD-1:0][DEPTH-1:0] ld_gnt_bus;
    logic [`NUM_FU_STORE-1:0][DEPTH-1:0] store_gnt_bus;
    logic [`NUM_FU_BR-1:0][DEPTH-1:0] br_gnt_bus;

    // Free psel wires
    logic [`NUM_FU_ALU-1:0]      f_alu_req, f_alu_gnt;
    logic [`NUM_FU_MULT-1:0]     f_mult_req, f_mult_gnt;
    logic [`NUM_FU_LD-1:0]       f_ld_req, f_ld_gnt;
    logic [`NUM_FU_STORE-1:0]    f_store_req, f_store_gnt;

    logic [`NUM_FU_ALU-1:0][`NUM_FU_ALU-1:0]       f_alu_gnt_bus;
    logic [`NUM_FU_MULT-1:0][`NUM_FU_MULT-1:0]     f_mult_gnt_bus;
    logic [`NUM_FU_LD-1:0][`NUM_FU_LD-1:0]         f_ld_gnt_bus;
    logic [`NUM_FU_STORE-1:0][`NUM_FU_STORE-1:0]   f_store_gnt_bus;

    // Issuing Priority Selectors, one for each type of FU
    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_ALU)) 
    alu_psel (
        .req(alu_req),
        .gnt(alu_gnt),
        .gnt_bus(alu_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_MULT)) 
    mult_psel (
        .req(mult_req),
        .gnt(mult_gnt),
        .gnt_bus(mult_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_LD)) 
    ld_psel (
        .req(ld_req),
        .gnt(ld_gnt),
        .gnt_bus(ld_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_STORE)) 
    store_psel (
        .req(store_req),
        .gnt(store_gnt),
        .gnt_bus(store_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_STORE)) 
    store_psel (
        .req(store_req),
        .gnt(store_gnt),
        .gnt_bus(store_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(`NUM_FU_BR)) 
    br_psel (
        .req(br_req),
        .gnt(br_gnt),
        .gnt_bus(br_gnt_bus),
        .empty()
    );

    // Busy Psels
    psel_gen #(
        .WIDTH(`NUM_FU_ALU),
        .REQS(`NUM_FU_ALU)) 
    f_alu_psel (
        .req(~fu_alu_busy),
        .gnt(f_alu_gnt),
        .gnt_bus(f_alu_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(`NUM_FU_MULT),
        .REQS(`NUM_FU_MULT)) 
    f_mult_psel (
        .req(~fu_mult_busy),
        .gnt(f_mult_gnt),
        .gnt_bus(f_mult_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(`NUM_FU_LD),
        .REQS(`NUM_FU_LD)) 
    f_ld_psel (
        .req(~fu_ld_busy),
        .gnt(f_ld_gnt),
        .gnt_bus(f_ld_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(`NUM_FU_STORE),
        .REQS(`NUM_FU_STORE)) 
    f_store_psel (
        .req(~fu_store_busy),
        .gnt(f_store_gnt),
        .gnt_bus(f_store_gnt_bus),
        .empty()
    );

    // Logic for assigning req to issuing psels
    always_comb begin
        alu_req = 0;
        mult_req = 0;
        ld_req = 0;
        store_req = 0;
        br_req = 0;
        for (int i = 0; i < DEPTH; i++) begin
            if (entries[i].valid & entries[i].t1.ready & entries[i].t2.ready) begin
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

    // Combinational Logic
    always_comb begin
        next_entries = entries;
        next_num_entries = num_entries;

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

        // Reads Psel logic and issues (parallelized)
        for (int i = 0; i < DEPTH; i++) begin
            for (int j = 0; j < `NUM_FU_ALU; j++) begin
                if (alu_gnt_bus[j][i]) begin
                    for (int k = 0; k < `NUM_FU_ALU; k++) begin
                        if (f_alu_gnt_bus[j][k]) begin
                            issued_alu[k] = next_entries[i];
                            next_entries[i] = 0;
                        end
                    end
                end
            end
            for (int j = 0; j < `NUM_FU_MULT; j++) begin
                if (mult_gnt_bus[j][i]) begin
                    for (int k = 0; k < `NUM_FU_MULT; k++) begin
                        if (f_mult_gnt_bus[j][k]) begin
                            issued_mult[k] = next_entries[i];
                            next_entries[i] = 0;
                        end
                    end
                end
            end
            for (int j = 0; j < `NUM_FU_LD; j++) begin
                if (ld_gnt_bus[j][i]) begin
                    for (int k = 0; k < `NUM_FU_LD; k++) begin
                        if (f_ld_gnt_bus[j][k]) begin
                            issued_ld[k] = next_entries[i];
                            next_entries[i] = 0;
                        end
                    end
                end
            end
            for (int j = 0; j < `NUM_FU_STORE; j++) begin
                if (store_gnt_bus[j][i]) begin
                    for (int k = 0; k < `NUM_FU_STORE; k++) begin
                        if (f_store_gnt_bus[j][k]) begin
                            issued_store[k] = next_entries[i];
                            next_entries[i] = 0;
                        end
                    end
                end
            end
            if (br_gnt[i]) begin
                issued_br = next_entries[i];
                next_entries[i] = 0;
            end
        end

        // Reads in new entries
        for (int i = 0; i < N; ++i) begin
            if (rs_in[i].valid) begin
                for (int j = 0; j < DEPTH; ++j) begin
                    if (~next_entries[j].valid) begin
                        next_entries[j] = rs_in[i];
                    end
                end
            end
        end

        // next_num_entries logic
        for (int i = 0; i < `NUM_FU_ALU; i++) begin
            if (issued_alu[i].valid) begin
                next_num_entries--;
            end
        end
        for (int i = 0; i < `NUM_FU_MULT; i++) begin
            if (issued_mult[i].valid) begin
                next_num_entries--;
            end
        end
        for (int i = 0; i < `NUM_FU_LD; i++) begin
            if (issued_ld[i].valid) begin
                next_num_entries--;
            end
        end
        for (int i = 0; i < `NUM_FU_STORE; i++) begin
            if (issued_store[i].valid) begin
                next_num_entries--;
            end
        end
        if (issued_br.valid) begin
            next_num_entries--;
        end
        
        next_num_entries += num_accept;
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