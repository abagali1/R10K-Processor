`include "sys_defs.svh"
`include "ISA.svh"

module btb #(
    parameter DEPTH = `BRANCH_TARGET_BUFFER_SIZE,
    parameter PREFETCH_DISTANCE = `PREFETCH_DISTANCE,
    parameter PREFETCH_INSTS = `PREFETCH_DISTANCE*2
)
(
    input                                           clock, 
    input                                           reset,

    input ADDR      [PREFETCH_INSTS-1:0]            rd_pc,

    input logic                                     wr_en,
    input ADDR                                      wr_pc,
    input ADDR                                      wr_target,

    output logic    [PREFETCH_INSTS-1:0]         is_branch,
    output ADDR     [PREFETCH_INSTS-1:0]         pred_target
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    ADDR [DEPTH-1:0] btb, next_btb;

    always_comb begin
        pred_target = '0;
        is_branch = '0;
        for (int i = 0; i < PREFETCH_INSTS; i++) begin
            pred_target[i] = btb[rd_pc[i][LOG_DEPTH-1:0]];
            is_branch[i] = |btb[rd_pc[i][LOG_DEPTH-1:0]];
        end
    end

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