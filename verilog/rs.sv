`include "sys_defs.svh"

module RS #(
    parameter N = 1,
)

(
    input                           clock,
    input                           reset,
    input RS_IN_PACKET [N-1:0]      rs_in,
    input CDB_BROADCAST             cdb_broadcast,
    output RS_OUT_PACKET [N-1:0]    issued_insts
    output logic [N-1:0]            stalled
);
endmodule