module rs_psel #(
    parameter DEPTH, 
    parameter NUM_FU
)
(
    input logic [DEPTH-1:0] inst_req, // which insts can be issued for this FU
    input logic [NUM_FU-1:0] fu_req, // which FUs (for this op) are ready
    output logic [$clog2(NUM_FU+1)-1:0] num_issued,
    output logic [NUM_FU-1:0] fu_issued_insts, // issued insts w.r.t current FU
    output logic [DEPTH-1:0] all_issued_insts  // issued insts w.r.t all RS entires
);

    logic [DEPTH-1:0] inst_gnt; // many hot encoded
    logic [NUM_FU-1:0][DEPTH-1:0] inst_gnt_bus; // one-hot

    logic [NUM_FU-1:0] fu_gnt;
    logic [NUM_FU-1:0][NUM_FU-1:0] fu_gnt_bus;

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

    always_comb begin
        all_issued_insts = '0;
        num_issued = '0;
        fu_issued_insts = '0;

        for(int i=0;i<NUM_FU;i++) begin
            if(fu_gnt_bus[i] && inst_gnt_bus[i]) begin 
                all_issued_insts |= inst_gnt_bus[i];
                fu_issued_insts |= fu_gnt_bus[i];
            end
        end

        for(int i=0;i<DEPTH;i++) begin
            if(all_issued_insts[i]) begin
                num_issued++;
            end
        end
    end

endmodule