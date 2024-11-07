`include "sys_defs.svh"
`include "psel_gen.sv"
`include "rs_psel.sv"

module RS #(
    parameter DEPTH = `RS_SZ,
    parameter N = `N
)
(
    input                                                           clock,
    input                                                           reset,

    input RS_PACKET                 [N-1:0]                         rs_in,
    input CDB_PACKET                [N-1:0]                         cdb_in,

    // ebr logic
    input BR_MASK                                                   br_id,
    input BR_TASK                                                   br_task,

    // busy bits from FUs to mark when available to issue
    input logic                     [`NUM_FU_ALU-1:0]              fu_alu_busy,
    input logic                     [`NUM_FU_MULT-1:0]             fu_mult_busy,
    input logic                     [`NUM_FU_LD-1:0]               fu_ld_busy,
    input logic                     [`NUM_FU_STORE-1:0]            fu_store_busy,
    input logic                     [`NUM_FU_BR-1:0]               fu_br_busy, 

    output logic                    [$clog2(N+1)-1:0]              num_accept,

    // output packets directly to FUs (they all are pipelined)
    output RS_PACKET                [`NUM_FU_ALU-1:0]              issued_alu, 
    output RS_PACKET                [`NUM_FU_MULT-1:0]             issued_mult,
    output RS_PACKET                [`NUM_FU_LD-1:0]               issued_ld,
    output RS_PACKET                [`NUM_FU_STORE-1:0]            issued_store,
    output RS_PACKET                                               issued_br,

    output logic                    [$clog2(DEPTH+1)-1:0]          open_entries

    `ifdef DEBUG
    ,   output ROB_ENTRY_PACKET [DEPTH-1:0] debug_entries
    `endif
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic [DEPTH-1:0] open_spots, next_open_spots;
    wor [DEPTH-1:0] all_issued_insts; // also keeps track of position of instructions being issued w.r.t RS entries

    RS_PACKET [DEPTH-1:0] entries, next_entries;
    logic [LOG_DEPTH:0] num_entries, next_num_entries;

    // grant bus for the psel that selects the open spots that can be dispatched to
    logic [N-1:0][DEPTH-1:0] dis_entries_bus;

    // Issuing psel wires
    logic [DEPTH-1:0] alu_req, mult_req, ld_req, store_req, br_req;

    // Which specific FUs are being issued to
    logic [`NUM_FU_ALU-1:0] alu_issued;
    logic [`NUM_FU_MULT-1:0] mult_issued;
    logic [`NUM_FU_LD-1:0] ld_issued;
    logic [`NUM_FU_STORE-1:0] store_issued;
    logic [`NUM_FU_BR-1:0] br_issued;

    // Number issued per FU
    logic [$clog2(`NUM_FU_ALU+1)-1:0] num_alu_issued;
    logic [$clog2(`NUM_FU_MULT+1)-1:0] num_mult_issued;
    logic [$clog2(`NUM_FU_LD+1)-1:0] num_ld_issued;
    logic [$clog2(`NUM_FU_STORE+1)-1:0] num_store_issued;
    logic [$clog2(`NUM_FU_BR+1)-1:0] num_br_issued;

    assign open_entries = DEPTH - num_entries;

    rs_psel #(
        .DEPTH(DEPTH),
        .NUM_FU(`NUM_FU_ALU)
    )
    alu_psel (
        .inst_req(alu_req),
        .fu_req(~fu_alu_busy),
        .num_issued(num_alu_issued),
        .fu_issued_insts(alu_issued),
        .all_issued_insts(all_issued_insts)
    );

    rs_psel #(
        .DEPTH(DEPTH),
        .NUM_FU(`NUM_FU_MULT)
    )
    mult_psel (
        .inst_req(mult_req),
        .fu_req(~fu_mult_busy),
        .num_issued(num_mult_issued),
        .fu_issued_insts(mult_issued),
        .all_issued_insts(all_issued_insts)
    );

    rs_psel #(
        .DEPTH(DEPTH),
        .NUM_FU(`NUM_FU_LD)
    )
    ld_psel (
        .inst_req(ld_req),
        .fu_req(~fu_ld_busy),
        .num_issued(num_ld_issued),
        .fu_issued_insts(ld_issued),
        .all_issued_insts(all_issued_insts)
    );

    rs_psel #(
        .DEPTH(DEPTH),
        .NUM_FU(`NUM_FU_STORE)
    )
    store_psel (
        .inst_req(store_req),
        .fu_req(~fu_store_busy),
        .num_issued(num_store_issued),
        .fu_issued_insts(store_issued),
        .all_issued_insts(all_issued_insts)
    );

    rs_psel #(
        .DEPTH(DEPTH),
        .NUM_FU(`NUM_FU_BR)
    )
    br_psel (
        .inst_req(br_req),
        .fu_req(~fu_br_busy),
        .num_issued(num_br_issued),
        .fu_issued_insts(br_issued),
        .all_issued_insts(all_issued_insts)
    );

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(N))
    inst_psel (
        .req(next_open_spots),
        .gnt(),
        .gnt_bus(dis_entries_bus),
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
                end 
                if (entries[i].fu_type == MULT_INST) begin
                    mult_req[i] = 1;
                end 
                if (entries[i].fu_type == LD_INST) begin
                    ld_req[i] = 1;
                end 
                if (entries[i].fu_type == STORE_INST) begin
                    store_req[i] = 1;
                end  
                if (entries[i].fu_type == BR_INST) begin
                    br_req[i] = 1;
                end
            end
        end
    end

    // Combinational Logic
    always_comb begin
        next_entries = entries;
        next_num_entries = num_entries;
        next_open_spots = open_spots | all_issued_insts;

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
        if (br_task == SQUASH) begin
            for (int i = 0; i < DEPTH; i++) begin
                if ((entries[i].b_mask & br_id) != 0) begin
                    next_entries[i] = 0;
                    next_open_spots[i] = 1;
                    next_num_entries--;
                end
            end
        end 
        if (br_task == CLEAR) begin
            for (int i = 0; i < DEPTH; i++) begin
                if ((entries[i].b_mask & br_id) != 0) begin
                    next_entries[i].b_mask = entries[i].b_mask ^ br_id;
                end
            end
        end

        // sets all issued entries to be empty
        next_entries = next_entries & ~next_open_spots; // sussy, next_entries is of type RS_PACKET but next_open_spots is logic

        // Reads in new entries (parallelized)
        for (int i = 0; i < N; ++i) begin
            if (rs_in[i].valid && dis_entries_bus[i]) begin
                for (int j = 0; j < DEPTH; j++) begin
                    if (dis_entries_bus[i][j]) begin
                        next_entries[j] = rs_in[i];
                        next_open_spots[j] = 0;
                    end
                end
            end
        end

        // next_num_entries logic
        next_num_entries = next_num_entries - (num_alu_issued + num_mult_issued + num_ld_issued + num_store_issued + num_br_issued) + num_accept;
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            entries <= 0;
            num_entries <= 0;
            open_spots <= '1;
        end else begin
            entries <= next_entries;
            num_entries <= next_num_entries;
            open_spots <= next_open_spots;
        end
    end
endmodule