`include "sys_defs.svh"

typedef struct packed {
    PHYS_REG_IDX reg_idx;
    // some reg_val;
    logic valid;
} CDB;

module CDB #(
    parameter N = `N
)
(
    input logic         [NUM_FU-1:0] fu_done,
    input FU_PACKET     [NUM_FU-1:0] wr_data,
    
    input logic                      br_done,
    input FU_PACKET                  br_data,

    output CDB_PACKET [N-1:0]        entries;
    output CDB_PACKET                br_out;
    output logic      [NUM_FU-1:0]   stall_sig;          

);
    localparam NUM_FU = `NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD + `NUM_FU_STORE;
    localparam FU_PACKET_WIDTH = $bits(br_data);
    
    CDB_PACKET [N-1:0] entries;

    logic [NUM_FU-1:0] cdb_gnt;
    logic [N-1:0][NUM_FU-1:0] cdb_gnt_bus;

    assign num_req = (br_done) ? N-1 : N;
    assign stall_sig = ~cdb_gnt;

    psel_gen #(
        .WIDTH(NUM_FU),
        .REQS(num_req)) 
    alu_psel (
        .req(fu_done),
        .gnt(cdb_gnt),
        .gnt_bus(cdb_gnt_bus),
        .empty()
    );

    logic FU_PACKET [N-1:0][NUM_FU-1:0] anded_packets;
    logic FU_PACKET [N-1:0] selected_packet;

    generate
        genvar i, j;
        for (i = 0; i < num_req; i = i + 1) begin
            for (j = 0; j < NUM_FU; j = j + 1) begin
                assign anded_packets[i][j] = wr_data[j] & '{FU_PACKET_WIDTH{one_hot[i][j]}};
            end
            assign selected_packet[i] = |anded_packets[i];
        end
    endgenerate
    
    // then set the CDB output packet for both entries and br_out

endmodule