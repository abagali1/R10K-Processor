`include "sys_defs.svh"

typedef struct packed {
    PHYS_REG_IDX reg_idx;
    DATA reg_val;
    logic valid;
} CDB_PACKET;

module CDB #(
    parameter N = `N
)
(
    input logic         [NUM_FU-1:0] fu_done,
    input FU_PACKET     [NUM_FU-1:0] wr_data,

    output CDB_PACKET   [N-1:0]      entries;
    output logic        [NUM_FU-1:0] stall_sig;          

);
    localparam NUM_FU = `NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD + `NUM_FU_STORE + `NUM_FU_BR;
    localparam FU_PACKET_WIDTH = $bits(wr_data[0]);

    logic [NUM_FU-1:0] cdb_gnt;
    logic [N-1:0][NUM_FU-1:0] cdb_gnt_bus;

    assign num_req = (br_done) ? N-1 : N;
    assign stall_sig = ~cdb_gnt;

    psel_gen #(
        .WIDTH(NUM_FU),
        .REQS(N)) 
    cdb_arb (
        .req(fu_done),
        .gnt(cdb_gnt),
        .gnt_bus(cdb_gnt_bus),
        .empty()
    );

    wor FU_PACKET [N-1:0] selected_packets;

    generate
        genvar i, j;
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < NUM_FU; j = j + 1) begin
                assign selected_packets[i] = cdb_gnt_bus[i][j] ? wr_data[j] : '0;
            end
        end
    endgenerate
    
    always_comb begin
        for (int i = 0; i < N; i++) begin
            entries[i].reg_idx = selected_packets[i].reg_idx;
            entries[i].reg_val = selected_packets[i].reg_idx;
            entries[i].valid = (selected_packets[i]) ? 1 : 0;
        end
    end

endmodule