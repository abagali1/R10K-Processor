`include "sys_defs.svh"
`include "ISA.svh"

module addr_calc (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack,
    input               stall,
    input               rd_in,

    output FU_PACKET    fu_out,
    output              data_ready
);
    FU_PACKET out_packet, next_out_packet;
    DATA opa, opb;

    assign fu_out = out_packet;

    // ALU opA mux
    always_comb begin
        case (is_pack.decoded_vals.decoded_vals.opa_select)
            OPA_IS_RS1:  opa = is_pack.rs1_value;
            OPA_IS_NPC:  opa = is_pack.decoded_vals.decoded_vals.NPC;
            OPA_IS_PC:   opa = is_pack.decoded_vals.decoded_vals.PC;
            OPA_IS_ZERO: opa = 0;
            default:     opa = 32'hdeadface; // dead face
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (is_pack.decoded_vals.decoded_vals.opb_select)
            OPB_IS_RS2:   opb = is_pack.rs2_value;
            OPB_IS_I_IMM: opb = `RV32_signext_Iimm(is_pack.decoded_vals.decoded_vals.inst);
            OPB_IS_S_IMM: opb = `RV32_signext_Simm(is_pack.decoded_vals.decoded_vals.inst);
            OPB_IS_B_IMM: opb = `RV32_signext_Bimm(is_pack.decoded_vals.decoded_vals.inst);
            OPB_IS_U_IMM: opb = `RV32_signext_Uimm(is_pack.decoded_vals.decoded_vals.inst);
            OPB_IS_J_IMM: opb = `RV32_signext_Jimm(is_pack.decoded_vals.decoded_vals.inst);
            default:      opb = 32'hfacefeed; // face feed
        endcase
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            out_packet <= '0;
        end else if (stall) begin
            out_packet <= out_packet;
        end else begin
            out_packet <= next_out_packet;
        end
    end

    assign next_out_packet.decoded_vals = is_pack.decoded_vals;
    assign next_out_packet.alu_result = opa + opb;

    assign data_ready = ~stall & rd_in;
endmodule