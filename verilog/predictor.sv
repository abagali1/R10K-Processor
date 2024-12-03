`include "sys_defs.svh"
`include "ISA.svh"
//`include "btb.sv"
//`include "counter.sv"

module predictor #(
    parameter BHR_DEPTH = `BRANCH_HISTORY_REG_SZ,
    parameter BHT_DEPTH = `BRANCH_HISTORY_TABLE_SIZE
)
(
    input                                   clock, 
    input                                   reset,

    input ADDR                              rd_pc, // pc of current branch
    input logic     [BHR_DEPTH-1:0]         rd_bhr, // current branch history register

    input logic                             wr_en, // enabled when a branch gets resolved to update predictor
    input logic                             wr_taken, // true if resolved branch is taken
    input ADDR                              wr_target, // target address of a branch
    input ADDR                              wr_pc, // pc of the branch instruction
    input logic     [BHR_DEPTH-1:0]         wr_bhr, // branch history register of this instruction when predicted

    output logic                            pred_taken, // true if predictor predicts branch is taken
    output ADDR                             pred_target // predicted target address
);
    logic is_branch;

    logic [BHR_DEPTH-1:0] rd_index, wr_index;

    assign rd_index = rd_pc[BHR_DEPTH-1:0] ^ rd_bhr;
    assign wr_index = wr_pc[BHR_DEPTH-1:0] ^ wr_bhr;

    logic [BHT_DEPTH-1:0] bht_taken;
    logic [BHT_DEPTH-1:0] bht_wr_en;
    logic [BHT_DEPTH-1:0] bht_pred;
    
    generate
        genvar i;
        for (i = 0; i < BHT_DEPTH; i++) begin
            counter i_bht (
                .clock(clock),
                .reset(reset),
                .taken(bht_taken[i]),
                .wr_en(bht_wr_en[i]),
                .pred(bht_pred[i])
            );
        end
    endgenerate

    btb bibibop (
        .clock(clock),
        .reset(reset),
        .rd_pc(rd_pc),
        .wr_en(wr_en),
        .wr_pc(wr_pc),
        .wr_target(wr_target),
        .is_branch(is_branch),
        .pred_target(pred_target)
    );

    assign pred_taken = is_branch ? bht_pred[rd_index] : 0;

    always_comb begin
        bht_taken = '0;
        bht_wr_en = '0;
        if (wr_en) begin
            bht_taken[wr_index] = wr_taken;
            bht_wr_en[wr_index] = 1;
        end
    end

endmodule