`include "sys_defs.svh"
`include "ISA.svh"

// ALU: computes the result of FUNC applied with operands A and B
// This module is purely combinational
module alu (
    input               clock, 
    input               reset,
    input DATA          opa,
    input DATA          opb,
    input RS_PACKET     rs_in,
    input logic         stall_unit,
    input logic         rd_in,

    output FU_PACKET    fu_out,
    output logic        data_ready,
    output logic        unit_stalled
);
    FU_PACKET out_packet, next_out_packet;

    always_comb begin
        if (~stall_unit) begin
            // forward rs packet info
            next_out_packet.inst = rs_in.inst;
            next_out_packet.NPC = rs_in.NPC;
            next_out_packet.rd_mem = rs_in.rd_mem;
            next_out_packet.wr_mem = rs_in.wr_mem;
            next_out_packet.dest_reg_idx = rs_in.dest_reg_idx;
            next_out_packet.halt = rs_in.halt;
            next_out_packet.illegal = rs_in.illegal;
            next_out_packet.csr_op = rs_in.csr_op;
            next_out_packet.valid = rs_in.valid;
            case (rs_in.alu_func)
                ALU_ADD:  next_out_packet.result = opa + opb;
                ALU_SUB:  next_out_packet.result = opa - opb;
                ALU_AND:  next_out_packet.result = opa & opb;
                ALU_SLT:  next_out_packet.result = signed'(opa) < signed'(opb);
                ALU_SLTU: next_out_packet.result = opa < opb;
                ALU_OR:   next_out_packet.result = opa | opb;
                ALU_XOR:  next_out_packet.result = opa ^ opb;
                ALU_SRL:  next_out_packet.result = opa >> opb[4:0];
                ALU_SLL:  next_out_packet.result = opa << opb[4:0];
                ALU_SRA:  next_out_packet.result = signed'(opa) >>> opb[4:0]; // arithmetic from logical shift
                // here to prevent latches:
                default:  next_out_packet.result = 32'hfacebeec;
            endcase
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            out_packet <= '0;
        end else if (stall_unit) begin
            out_packet <= out_packet;
        end else begin
            out_packet <= next_out_packet;
        end
    end

    assign fu_out = out_packet;
    assign unit_stalled = stall_unit;
    assign data_ready = stall_unit | rd_in;

endmodule // alu