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
    DATA result;
    DATA opa;
    DATA opb;
    FU_PACKET out, next_out;

    assign fu_pack = out;
    assign opa = is_pack.rs1_value;
    assign opb = is_pack.rs2_value;

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

    assign next_out = '{result: result, decoded_vals: is_pack.decoded_vals, pred_correct: 0};

    always_ff @(posedge clock) begin
        if (reset) begin
            data_ready  <= '0;
            out         <= '0;
        end else if (stall) begin
            data_ready  <= data_ready;
            out         <= out;
        end else if (rd_in) begin
            data_ready  <= 1;
            out         <= next_out;
        end else begin
            data_ready  <= '0;
            out         <= '0;
        end
    end

    `ifdef DEBUG
        always_ff @(posedge clock) begin
            $display("============== ALU ================");

            $display("   Packet Inst: %0d, Result: %0x, Data_ready: %0d, Stall: %0d", out.decoded_vals.decoded_vals.inst, out.result, data_ready, stall);
            
        end
    `endif

    

endmodule