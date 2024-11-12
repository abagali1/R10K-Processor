`include "sys_defs.svh"

module map_table #(
    parameter DEPTH = `ARCH_REG_SZ,
    parameter N = `N
)
(
    input                                               clock,
    input                                               reset, 

    input REG_IDX                   [N-1:0]             r1_idx,
    input REG_IDX                   [N-1:0]             r2_idx,       
    input REG_IDX                   [N-1:0]             dest_reg_idx, // dest_regs that are getting mapped to a new phys_reg from free_list
    input PHYS_REG_IDX              [N-1:0]             free_reg,  // comes from the free list
    input logic                     [N-1:0]             incoming_valid, // inputs to expect                       

    input REG_IDX                   [N-1:0]             ready_reg_idx, // readys from CDB - arch reg
    input PHYS_REG_IDX              [N-1:0]             ready_phys_idx, // corresponding phys reg
    input logic                     [N-1:0]             ready_valid, // one hot encoded inputs to expect

    input logic                                         in_mt_en,
    input MAP_TABLE_PACKET          [DEPTH:0]           in_mt,


    output PHYS_REG_IDX             [N-1:0]             t_old_data, //?
    output MAP_TABLE_PACKET         [N-1:0]             r1_p_reg,
    output MAP_TABLE_PACKET         [N-1:0]             r2_p_reg,
    
    output MAP_TABLE_PACKET         [DEPTH:0]           out_mt // output map table for architectural mt
);

    // Leave 0th entry empty, reduces (-1/+1) logic throughout
    MAP_TABLE_PACKET [DEPTH:0] entries, next_entries;

    always_comb begin
        next_entries = (in_mt_en) ? in_mt : entries;
        t_old_data = '0;
        r1_p_reg = '0;
        r2_p_reg = '0;

        // check that the arch reg hasn't been mapped to a new register
        // Set ready bits
        for (int i = 0; i < N; i++) begin
            if (ready_valid[i]) begin
                next_entries[ready_reg_idx[i]].ready = (next_entries[ready_reg_idx[i]].reg_idx == ready_phys_idx[i]) ? 1 : 0;
            end
        end

        for (int i = 0; i < N; i++) begin
            if (incoming_valid[i]) begin
                // read registers
                t_old_data[i] = next_entries[dest_reg_idx[i]].reg_idx;
                r1_p_reg[i] = next_entries[r1_idx[i]];
                r2_p_reg[i] = next_entries[r2_idx[i]];

                // write registers back as we read them
                next_entries[dest_reg_idx[i]].reg_idx = free_reg[i];
                next_entries[dest_reg_idx[i]].ready = 0;
            end
        end

        out_mt = next_entries;
    end

    always @(posedge clock) begin
        if (reset) begin
            for (int i = 1; i <= DEPTH; i++) begin
                entries[i].reg_idx <= i;
                entries[i].valid <= 1;
                entries[i].ready <= 1;  
            end
        end else begin
            entries <= next_entries;
        end
    end

    `ifdef DEBUG_MT
        always @(posedge clock) begin
            $display("=================== MAP TABLE ===================");
            $display("");

        end
    `endif

endmodule