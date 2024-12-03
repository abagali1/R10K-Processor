`include "sys_defs.svh"
`include "ISA.svh"

module bhr #(
    parameter DEPTH = `BRANCH_HISTORY_REG_SZ
)
(
    input                           clock, 
    input                           reset,

    input logic                     wr_en,
    input logic                     taken,

    output logic    [DEPTH-1:0]     out_bhr
);
    logic [DEPTH-1:0] state, next_state;
    assign out_bhr = state;

    assign next_state = wr_en ? {state[DEPTH-2:0], taken}: state;

    always_ff @(posedge clock) begin
        if (reset) begin
            state <= '0;
        end else begin
            state <= next_state;
        end
    end

endmodule