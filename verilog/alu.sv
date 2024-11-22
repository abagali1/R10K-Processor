`include "sys_defs.svh"
`include "ISA.svh"

module alu (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack,
    input logic         stall,
    input logic         rd_in,

    input BR_TASK       rem_br_task,
    input BR_MASK       rem_b_id,

    output FU_PACKET    fu_pack,
    output logic        data_ready
);
    DATA result, opa, opb;

    RS_PACKET out;

    always_comb begin
        out = is_pack.decoded_vals;
        out.b_mask = (rem_br_task == CLEAR) ? out.b_mask ^ rem_b_id : is_pack.decoded_vals.b_mask;
    end

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


    always_ff @(posedge clock) begin
        if (reset || (rem_br_task == SQUASH && (is_pack.decoded_vals.b_mask & rem_b_id) != '0)) begin
            data_ready  <= '0;
            fu_pack         <= '0;
        end else if (stall) begin
            data_ready  <= data_ready;
            fu_pack         <= fu_pack;
        end else if (rd_in) begin
            data_ready  <= 1;
            fu_pack         <= '{result: result, decoded_vals: out, pred_correct: 0};
;
        end else begin
            data_ready  <= '0;
            fu_pack         <= '0;
        end
    end

    `ifdef DEBUG
        always_ff @(posedge clock) begin
            $display("============== ALU ================");
            $display("   Packet Inst: %0d, Result: %0x, Data_ready: %0d, Stall: %0d", fu_pack.decoded_vals.decoded_vals.inst, fu_pack.result, data_ready, stall);
            
        end
    `endif

endmodule