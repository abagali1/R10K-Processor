`include "sys_defs.svh"

module issue #(
    parameter NUM_FU = `NUM_FUS
)(
    input                                          clock,
    input                                          reset,

    input  DATA           [NUM_FU-1:0]             reg_data_1,
    input  DATA           [NUM_FU-1:0]             reg_data_2,

    input RS_PACKET       [`NUM_FU_ALU-1:0]        issued_alu, 
    input RS_PACKET       [`NUM_FU_MULT-1:0]       issued_mult,
    input RS_PACKET       [`NUM_FU_LD-1:0]         issued_ld,
    input RS_PACKET       [`NUM_FU_STORE-1:0]      issued_st,
    input RS_PACKET       [`NUM_FU_BR-1:0]         issued_br,

    input logic           [NUM_FU-`NUM_FU_BR:0]    stall_sig,

    output logic          [`NUM_FU_ALU-1:0]        alu_rd_en, 
    output logic          [`NUM_FU_MULT-1:0]       mult_rd_en,
    output logic          [`NUM_FU_LD-1:0]         ld_rd_en,
    output logic          [`NUM_FU_STORE-1:0]      st_rd_en,
    output logic          [`NUM_FU_BR-1:0]         br_rd_en,

    output ISSUE_PACKET   [`NUM_FU_ALU-1:0]        issued_alu_pack, 
    output ISSUE_PACKET   [`NUM_FU_MULT-1:0]       issued_mult_pack,
    output ISSUE_PACKET   [`NUM_FU_LD-1:0]         issued_ld_pack,
    output ISSUE_PACKET   [`NUM_FU_STORE-1:0]      issued_st_pack,
    output ISSUE_PACKET   [`NUM_FU_BR-1:0]         issued_br_pack,

    output PHYS_REG_IDX   [NUM_FU-1:0]             reg_idx_1,
    output PHYS_REG_IDX   [NUM_FU-1:0]             reg_idx_2
);

    logic [`NUM_FU_ALU-1:0] alu_rd_en_vals;
    PHYS_REG_IDX [`NUM_FU_ALU-1:0] alu_reg_1, alu_reg_2;

    logic [`NUM_FU_MULT-1:0] mult_rd_en_vals;
    PHYS_REG_IDX [`NUM_FU_MULT-1:0] mult_reg_1, mult_reg_2;

    logic [`NUM_FU_LD-1:0] ld_rd_en_vals;
    PHYS_REG_IDX [`NUM_FU_LD-1:0] ld_reg_1, ld_reg_2;

    logic [`NUM_FU_STORE-1:0] st_rd_en_vals;
    PHYS_REG_IDX [`NUM_FU_STORE-1:0] st_reg_1, st_reg_2;

    logic [`NUM_FU_BR-1:0] br_rd_en_vals;
    PHYS_REG_IDX [`NUM_FU_BR-1:0] br_reg_1, br_reg_2;

    // ----- ALU -----

    // alu issuing signals
    always_comb begin    
        alu_rd_en_vals = '0;
        for (int i = 0; i <`NUM_FU_STORE; i++) begin
            alu_rd_en_vals[i] = issued_alu[i].decoded_vals.valid & ~stall_sig[i];
            alu_reg_1[i] = issued_alu[i].t1.reg_idx;
            alu_reg_2[i] = issued_alu[i].t2.reg_idx;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            alu_rd_en <= 0;
        end else begin
            alu_rd_en <= alu_rd_en_vals;
        end 
    end
    
    // ----- MULT -----

    // mult issuing signals
    always_comb begin    
        mult_rd_en_vals = '0;
        for (int i = 0; i <`NUM_FU_STORE; i++) begin
            mult_rd_en_vals[i] = issued_mult[i].decoded_vals.valid & ~stall_sig[i];
            mult_reg_1[i] = issued_mult[i].t1.reg_idx;
            mult_reg_2[i] = issued_mult[i].t2.reg_idx;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            mult_rd_en <= 0;
        end else begin
            mult_rd_en <= mult_rd_en_vals;
        end 
    end
    
    // ----- LD -----

    // load issuing signals
    always_comb begin    
        ld_rd_en_vals = '0;
        for (int i = 0; i <`NUM_FU_STORE; i++) begin
            ld_rd_en_vals[i] = issued_ld[i].decoded_vals.valid & ~stall_sig[i];
            ld_reg_1[i] = issued_ld[i].t1.reg_idx;
            ld_reg_2[i] = issued_ld[i].t2.reg_idx;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            ld_rd_en <= 0;
        end else begin
            ld_rd_en <= ld_rd_en_vals;
        end 
    end
    
    // ----- STORE -----

    // store issuing signals
    always_comb begin    
        st_rd_en_vals = '0;
        for (int i = 0; i <`NUM_FU_STORE; i++) begin
            st_rd_en_vals[i] = issued_st[i].decoded_vals.valid & ~stall_sig[i];
            st_reg_1[i] = issued_st[i].t1.reg_idx;
            st_reg_2[i] = issued_st[i].t2.reg_idx;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            st_rd_en <= 0;
        end else begin
            st_rd_en <= st_rd_en_vals;
        end 
    end

    // ----- BRANCH -----

    // branch issuing signals
    always_comb begin    
        br_rd_en_vals = '0;
        for (int i = 0; i <`NUM_FU_BR; i++) begin
            br_rd_en_vals[i] = issued_br[i].decoded_vals.valid;
            br_reg_1[i] = issued_br[i].t1.reg_idx;
            br_reg_2[i] = issued_br[i].t2.reg_idx;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            br_rd_en <= 0;
        end else begin
            br_rd_en <= br_rd_en_vals;
        end 
    end

    // ---- REGFILE INPUT ----

    always_comb begin
        reg_idx_1 = '0;
        reg_idx_2 = '0;

        // ALU
        for (int a = 0; a < `NUM_FU_ALU; a++) begin
            reg_idx_1[a] = alu_reg_1[a];
            reg_idx_2[a] = alu_reg_2[a];
        end

        // MULT
        for (int m = 0; m < `NUM_FU_MULT; m++) begin
            reg_idx_1[(`NUM_FU_ALU) + m] = mult_reg_1[m];
            reg_idx_2[(`NUM_FU_ALU) + m] = mult_reg_2[m];
        end

        // LD
        for (int l = 0; l < `NUM_FU_LD; l++) begin
            reg_idx_1[(`NUM_FU_ALU + `NUM_FU_MULT) + l] = ld_reg_1[l];
            reg_idx_2[(`NUM_FU_ALU + `NUM_FU_MULT) + l] = ld_reg_2[l];
        end

        // STORE
        for (int s = 0; s < `NUM_FU_STORE; s++) begin
            reg_idx_1[(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LD) + s] = st_reg_1[s];
            reg_idx_2[(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LD) + s] = st_reg_2[s];
        end

        // BR
        for (int b = 0; b < `NUM_FU_BR; b++) begin
            reg_idx_1[(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LD + `NUM_FU_STORE) + b] = br_reg_1[b];
            reg_idx_2[(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LD + `NUM_FU_STORE) + b] = br_reg_2[b];
        end
    end

    // ---- ISSUE PACKET ----

    always_comb begin
        // ALU
        for (int a = 0; a < `NUM_FU_ALU; a++) begin
            issued_alu_pack[a].decoded_vals = issued_alu;
            issued_alu_pack[a].rs1_value = reg_data_1[a];
            issued_alu_pack[a].rs2_value = reg_data_2[a];
        end

        // MULT
        for (int m = 0; m < `NUM_FU_MULT; m++) begin
            issued_mult_pack[m].decoded_vals = issued_mult[m];
            issued_mult_pack[m].rs1_value = reg_data_1[(`NUM_FU_ALU) + m]; 
            issued_mult_pack[m].rs2_value = reg_data_2[(`NUM_FU_ALU) + m]; 
        end

        // LD
        for (int l = 0; l < `NUM_FU_LD; l++) begin
            issued_ld_pack[l].decoded_vals = issued_ld[l];
            issued_ld_pack[l].rs1_value = reg_data_1[(`NUM_FU_ALU + `NUM_FU_MULT) + l];
            issued_ld_pack[l].rs2_value = reg_data_2[(`NUM_FU_ALU + `NUM_FU_MULT) + l];
        end

        // STORE
        for (int s = 0; s < `NUM_FU_STORE; s++) begin
            issued_st_pack[s].decoded_vals = issued_st[s];
            issued_st_pack[s].rs1_value = reg_data_1[(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LD) + s];
            issued_st_pack[s].rs2_value = reg_data_2[(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LD) + s];
        end

        // BR
        for (int b = 0; b < `NUM_FU_BR; b++) begin
            issued_br_pack[b].decoded_vals = issued_br[b];
            issued_br_pack[b] = reg_data_1[(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LD + `NUM_FU_STORE) + b];
            issued_br_pack[b] = reg_data_2[(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LD + `NUM_FU_STORE) + b];
        end
    end


endmodule