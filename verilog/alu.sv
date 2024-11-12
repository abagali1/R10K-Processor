`include "sys_defs.svh"
`include "ISA.svh"

module alu (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack,
    input logic         stall,
    input logic         rd_in,

    output FU_PACKET    fu_pack,
    output logic        data_ready
);
    DATA result, opa, opb;
    FU_PACKET out, next_out;

    assign fu_pack = out;

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

    // ALU Compute Result
    always_comb begin
        case (is_pack.decoded_vals.decoded_vals.alu_func)
            ALU_ADD:  result = opa + opb;
            ALU_SUB:  result = opa - opb;
            ALU_AND:  result = opa & opb;
            ALU_SLT:  result = signed'(opa) < signed'(opb);
            ALU_SLTU: result = opa < opb;
            ALU_OR:   result = opa | opb;
            ALU_XOR:  result = opa ^ opb;
            ALU_SRL:  result = opa >> opb[4:0];
            ALU_SLL:  result = opa << opb[4:0];
            ALU_SRA:  result = signed'(opa) >>> opb[4:0]; // arithmetic from logical shift
            // here to prevent latches:
            default:  result = 32'hfacebeec;
        endcase
    end

    // Set Next Out
    always_comb begin
        if (stall) begin
            next_out = out;
            data_ready = '0;
        end else begin
            next_out = '{alu_result: result, decoded_vals: is_pack.decoded_vals, take_conditional: 0};
            data_ready = rd_in;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            out <= '0;
        end else begin
            out <= next_out;
        end
    end

endmodule