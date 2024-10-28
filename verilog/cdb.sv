`include "sys_defs.svh"

typedef struct packed {
    PHYS_REG_IDX reg_idx;
    // some reg_val;
    logic valid;
} CDB;

module CDB #(
    parameter N = `N
)
(
    input FU_PACKET     [NUM_FU-1:0] wr_data,

    output CDB_PACKET [N-1:0]        entries;
    output logic      [NUM_FU-1:0]   stall_sig;          

);
    localparam NUM_FU = `NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD + `NUM_FU_STORE;
    CDB_PACKET [N-1:0] entries;


    always_comb begin
        int num_completed = 0;
        stall_sig = '0;

        // so this might be an issue... since the FUs are directly mapped to the input of the
        // CDB, the CDB might choose the same N FUs to complete and at some point this will resolve
        // BUT... we probably will get better performance if we completed the oldest inst first
        for (int i = 0; i < NUM_FU; i++) begin
            if (num_completed < N & wr_data[i].completed) begin
                entries[num_completed].reg_idx = wr_data[i].dest_reg;
                entries[num_completed].val = wr_data[i].val;
                entries[num_completed].valid = 1;
                stall_sig[i] = 0;
                num_completed++;
            end else if (num_completed == N & wr_data[i].completed) begin
                stall_sig[i] = 1; //outputs signal to tell FU to stall
            end
        end
        for (int j = num_completed; j < N; j++) begin
            entries[j].valid = 0;
        end
    end

endmodule