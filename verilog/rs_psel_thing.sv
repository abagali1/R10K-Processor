module RS_PSEL #(parameter DEPTH, N, NUM_FU)
(
    input logic [DEPTH-1:0] inst_req,
    input logic [NUM_FU-1:0] fu_req,

);

    logic [DEPTH-1:0] inst_gnt,
    logic [NUM_FU-1:0][DEPTH-1:0] inst_gnt_bus,

    logic [NUM_FU-1:0] fu_gnt,
    logic [NUM_FU-1:0][NUM_FU-1:0] fu_gnt_bus

    psel_gen #(
        .WIDTH(DEPTH),
        .REQS(NUM_FU))
    inst_psel (
        .req(inst_req),
        .gnt(inst_gnt),
        .gnt_bus(inst_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(NUM_FU),
        .REQS(NUM_FU))
    fu_psel (
        .req(fu_req),
        .gnt(fu_gnt),
        .gnt_bus(fu_gnt_bus),
        .empty()
    );

endmodule