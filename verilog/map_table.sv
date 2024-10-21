`include "sys_defs.svh"

module map_table #(
    parameter N = `1,
    parameter DEPTH = `PHYS_REG_SIZE_R10K
)
(
    input                           clock,
    input                           reset,
    input PHYS_REG_IDX  [N-1:0]     wr_reg_idx,
    input PHYS_REG_IDX  [N-1:0]     wr_reg_data, 
    input PHYS_REG_IDX  [2*N-1:0]   rd_reg_idx,
    output PHYS_REG_IDX [N-1:0]     t_old_data,
    output PHYS_REG_IDX [2*N-1:0]   rd_reg_data,
);

endmodule