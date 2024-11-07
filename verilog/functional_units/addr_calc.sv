`include "sys_defs.svh"
`include "ISA.svh"

module addr_calc (
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
    output              unit_stalled
);
    FU_PACKET out_packet, next_out_packet;
    DATA base, offset;

    always_ff @(posedge clock) begin
        if (reset) begin
            out_packet <= '0;
        end else if (stall_unit) begin
            out_packet <= out_packet;
        end else begin
            out_packet <= next_out_packet;
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

    assign base = (rs_in.uncond_branch) ? rs_in.PC : opa;
    assign offset = (rs_in.uncond_branch) ? `RV32_signext_Jimm(rs_in.inst) :
                    (rs_in.wr_mem) ? `RV32_signext_Simm(rs_in.inst) :
                    (rs_in.wr_mem) ? `RV32_signext_Iimm(rs_in.inst) : '0;   //covers JALR
    assign next_out_packet.result = base + offset;

    assign data_ready = stall_unit | rd_in;
    assign unit_stalled = stall_unit;
endmodule