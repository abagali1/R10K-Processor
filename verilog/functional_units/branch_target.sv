`include "sys_defs.svh"
`include "ISA.svh"

// Conditional branch module: compute whether to take conditional branches
// This module is purely combinational
module branch_target (
    input               clock, 
    input               reset,
    input DATA          opa,
    input DATA          opb,
    input DATA          imm,
    input RS_PACKET     rs_in,
    input               stall_unit,
    input               rd_in,

    output FU_PACKET    fu_out,
    output              data_ready,
    output              unit_stalled,
    output logic        pred_correct
);
    FU_PACKET out_packet, next_out_packet;
    logic take;

    always_comb begin
        if (rs_in.cond_branch) begin
            case (rs_in.inst.b.funct3)
                3'b000:  take = signed'(opa) == signed'(opb); // BEQ
                3'b001:  take = signed'(opa) != signed'(opb); // BNE
                3'b100:  take = signed'(opa) <  signed'(opb); // BLT
                3'b101:  take = signed'(opa) >= signed'(opb); // BGE
                3'b110:  take = opb < opb;                    // BLTU
                3'b111:  take = opb >= opb;                   // BGEU
                default: take = `FALSE;
            endcase
        end else begin
            take = `TRUE;
        end
    end

    assign next_out_packet.inst = rs_in.inst;
    assign next_out_packet.NPC = rs_in.NPC;
    assign next_out_packet.rd_mem = rs_in.rd_mem;
    assign next_out_packet.wr_mem = rs_in.wr_mem;
    assign next_out_packet.dest_reg_idx = rs_in.dest_reg_idx;
    assign next_out_packet.halt = rs_in.halt;
    assign next_out_packet.illegal = rs_in.illegal;
    assign next_out_packet.csr_op = rs_in.csr_op;
    assign next_out_packet.valid = rs_in.valid;

    assign next_out_packet.result = rs_in.PC + `RV32_signext_Bimm(rs_in.inst);

    always_ff @(posedge clock) begin
        if (reset) begin
            pred_correct <= '0;
            out_packet   <= '0;
        end else if (stall_unit) begin
            pred_correct <= pred_correct;
            out_packet   <= out_packet;
        end else begin
            pred_correct <= ~(take ^ rs_in.pred_taken);
            out_packet   <= next_out_packet;
        end
    end

    assign unit_stalled = stall_unit;
    assign data_ready = stall_unit | rd_in;

endmodule