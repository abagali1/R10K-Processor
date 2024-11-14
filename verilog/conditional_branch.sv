`include "sys_defs.svh"
`include "ISA.svh"

// Conditional branch module: compute whether to take conditional branches
module conditional_branch (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack,
    input logic         stall, // I don't think we should ever stall this
    input logic         rd_in,

    output FU_PACKET    fu_pack,
    output BR_TASK      br_task,
    output logic        data_ready
);
    FU_PACKET out, next_out;
    DATA rs1, rs2, target;
    logic take, correct;

    assign fu_pack = out;
    assign correct = is_pack.decoded_vals.decoded_vals.pred_taken == take;

    // Combinational logic for choosing taken
    always_comb begin
        case (is_pack.decoded_vals.decoded_vals.inst.b.funct3)
            3'b000:  take = signed'(is_pack.rs1_value) == signed'(is_pack.rs2_value); // BEQ
            3'b001:  take = signed'(is_pack.rs1_value) != signed'(is_pack.rs2_value); // BNE
            3'b100:  take = signed'(is_pack.rs1_value) <  signed'(is_pack.rs2_value); // BLT
            3'b101:  take = signed'(is_pack.rs1_value) >= signed'(is_pack.rs2_value); // BGE
            3'b110:  take = is_pack.rs1_value < is_pack.rs2_value;                    // BLTU
            3'b111:  take = is_pack.rs1_value >= is_pack.rs2_value;                   // BGEU
            default: take = `FALSE;
        endcase
    end

    basic_adder branch_target (
        .is_pack(is_pack),
        .result(target)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            out         <= '0;
            data_ready  <= '0;
            br_task     <= NOTHING;
        end else if (stall) begin
            out         <= out;
            data_ready  <= data_ready;
            br_task     <= br_task;
        end else if (rd_in) begin
            out         <= '{alu_result: target, decoded_vals: is_pack.decoded_vals, take_conditional: take};
            data_ready  <= 1;
            br_task     <= (correct ? CLEAR : SQUASH);
        end else begin
            out         <= '0;
            data_ready  <= '0;
            br_task     <= NOTHING;
        end
    end

endmodule