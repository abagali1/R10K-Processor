`include "sys_defs.svh"
`include "ISA.svh"

module btb #(
    parameter DEPTH = `BRANCH_TARGET_BUFFER_SIZE
)
(
    input               clock, 
    input               reset,

    input ADDR          rd_pc,

    input logic         wr_en,
    input ADDR          wr_pc,
    input ADDR          wr_target,

    output logic        is_branch,
    output ADDR         pred_target
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    ADDR [DEPTH-1:0] btb, next_btb;

    assign pred_target = btb[rd_pc[LOG_DEPTH-1:0]];
    assign is_branch = |btb[rd_pc[LOG_DEPTH-1:0]];

    always_comb begin
        next_btb = btb;
        if (wr_en) begin
            next_btb[wr_pc[LOG_DEPTH-1:0]] = wr_target;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            btb <= '0;
        end else begin
            btb <= next_btb;
        end
    end

endmodule