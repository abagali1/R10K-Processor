`include "sys_defs.svh"

module #(
    parameter N=1,
)
(
    input clock,
    input reset,
    input add_reg,
    input get_reg,
    input REG_IDX reg_data,
    output REG_IDX out_reg,
    output out_valid
);
endmodule