`include "sys_defs.svh"
`include "ISA.svh"

module predictor #(
    parameter DEPTH = `BRANCH_HISTORY_TABLE_SIZE;
)
(
    input               clock, 
    input               reset,

    input ADDR                              rd_pc,
    input logic     [$clog2(DEPTH)-1:0]     rd_bhr,

    input logic                             wr_en,
    input logic                             wr_taken,
    input ADDR                              wr_pc,
    input logic     [$clog2(DEPTH)-1:0]     wr_bhr,

    output logic                            pred
);
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic [LOG_DEPTH-1:0] rd_index, wr_index;

    assign rd_index = rd_pc[LOG_DEPTH-1:0] ^ rd_bhr;
    assign wr_index = wr_pc[LOG_DEPTH-1:0] ^ wr_bhr;

    logic [DEPTH-1:0] bht_taken;
    logic [DEPTH-1:0] bht_wr_en;
    logic [DEPTH-1:0] bht_pred;
    
    generate
        genvar i;
        for (i = 0; i < DEPTH; i++) begin
            counter i_bht (
                .clock(clock),
                .reset(reset),
                .taken(bht_taken[i]),
                .wr_en(bht_wr_en[i]),
                .pred(bht_pred[i])
            );
        end
    endgenerate

    assign pred = bht_pred[rd_index];

    always_comb begin
        bht_taken = '0;
        bht_wr_en = '0;
        if (wr_en) begin
            bht_taken[wr_index] = wr_taken;
            bht_wr_en[wr_index] = 1;
        end
    end

endmodule