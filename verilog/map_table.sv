`include "sys_defs.svh"

typedef struct packed {
    PHYS_REG_IDX reg_idx;
    logic valid;
    logic ready;
} MAP_TABLE_PACKET;

module map_table #(
    parameter DEPTH = `PHYS_REG_SIZE_R10K,
    parameter N = `N
)
(
    input                                               clock,
    input                                               reset, 
    input REG_IDX                   [N-1:0]             r1_idx,
    input REG_IDX                   [N-1:0]             r2_idx,       
    input REG_IDX                   [N-1:0]             dest_reg_idx, // dest_regs that are getting mapped to a new phys_reg from free_list
    input PHYS_REG_IDX              [N-1:0]             wr_reg_data,  // comes from the free list

    input REG_IDX                   [N-1:0]             ready_reg_idx,
    input PHYS_REG_IDX              [N-1:0]             ready_phys_idx,

    input logic                                         in_mt_en,
    input MAP_TABLE_PACKET          [`ARCH_REG_SZ-1:0]  in_mt,


    output PHYS_REG_IDX             [N-1:0]             t_old_data,
    output PHYS_REG_IDX             [N-1:0]             r1_p_reg,
    output PHYS_REG_IDX             [N-1:0]             r2_p_reg,
    
    output MAP_TABLE_PACKET         [`ARCH_REG_SZ-1:0]  out_mt // output map table for architectural mt
);

// r1+r2=r3 //p4
// r4+r3=r3 //p5, p4
// r3+r4=r5

MAP_TABLE_PACKET [`ARCH_REG_SZ-1:0] entries, next_entries;

always_comb begin
    next_entries = (in_mt_en) ? in_mt : entries;

    // check that the arch reg hasn't been mapped to a new register
    for (int i = 0; i < N; i++) begin
        next_entries[ready_reg_idx[i]-1].ready = (next_entries[ready_reg_idx[i]-1].reg_idx == ready_phys_idx[i]) ? 1 : 0;
    end

    for (int i = 0; i < N; i++) begin
        // read registers
        t_old_data[i] = next_entries[dest_reg_idx[i]-1].reg_idx;
        r1_p_reg[i] = next_entries[r1_idx[i]-1].reg_idx;
        r2_p_reg[i] = next_entries[r2_idx[i]-1].reg_idx;

        // write registers
        next_entries[dest_reg_idx[i]-1].reg_idx = wr_reg_data[i]; // sussy
        next_entries[dest_reg_idx[i]-1].ready = 0;
    end

    // i'm not sure why i chose entries and not next_entries
    out_mt = entries;
end

always @(posedge clock) begin
    if (reset) begin
       for (int i = 0; i < DEPTH; i++) begin
            entries[i].reg_idx <= i;
            entries[i].valid <= 1;
            entries[i].ready <= 1;
        end
    end else begin
        entries <= next_entries;
    end
end

endmodule