`include "sys_defs.svh"
`include "ISA.svh"

// Conditional branch module: compute whether to take conditional branches
module branch_fu (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack, // print this
    input logic         rd_en,

    output FU_PACKET    fu_pack, // print out all outputs
    output BR_TASK      br_task,
    output logic        data_ready
);
    FU_PACKET out;
    ADDR target, branch_target;
    logic taken, correct;

    assign fu_pack = out;
    assign correct = is_pack.decoded_vals.decoded_vals.pred_taken == taken;

    assign target = taken ? branch_target : is_pack.decoded_vals.decoded_vals.NPC;

    // Combinational logic for choosing taken
    always_comb begin
        case (is_pack.decoded_vals.decoded_vals.inst.b.funct3)
            3'b000:  taken = signed'(is_pack.rs1_value) == signed'(is_pack.rs2_value); // BEQ
            3'b001:  taken = signed'(is_pack.rs1_value) != signed'(is_pack.rs2_value); // BNE
            3'b100:  taken = signed'(is_pack.rs1_value) <  signed'(is_pack.rs2_value); // BLT
            3'b101:  taken = signed'(is_pack.rs1_value) >= signed'(is_pack.rs2_value); // BGE
            3'b110:  taken = is_pack.rs1_value < is_pack.rs2_value;                    // BLTU
            3'b111:  taken = is_pack.rs1_value >= is_pack.rs2_value;                   // BGEU
            default: taken = `FALSE;
        endcase
    end

    basic_adder branch_target_calc (
        .is_pack(is_pack),
        .result(branch_target)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            out         <= '0;
            data_ready  <= '0;
            br_task     <= NOTHING;
        end else if (rd_en) begin
            out         <= '{result: target, decoded_vals: is_pack.decoded_vals, pred_correct: correct};
            data_ready  <= 1;
            br_task     <= (correct ? CLEAR : SQUASH);
        end else begin
            out         <= '0;
            data_ready  <= '0;
            br_task     <= NOTHING;
        end
    end

    `ifdef DEBUG
        always @(posedge clock) begin
            $display("============== BRANCH FU ==============\n");
            $display("  Issue Packet:");
            $display("  b_id: %0d, b_mask: %0d, rs_1value: %0d, rs2_value: %0d", is_pack.decoded_vals.b_id, is_pack.decoded_vals.b_mask, is_pack.rs_1value, is_pack.rs2_value);
            $display("  FU Packet Out:");
            $display("i | b_id |  b_mask | rec_PC | fl_head | rob_tail  |");
            for (int i = 0; i < DEPTH; i++) begin
                $display("%02d|  %02d  |   %02d   |   %02d   |  %02d  |   %01d   |", i, entries[i].b_id, entries[i].b_mask, entries[i].rec_PC, entries[i].fl_head, entries[i].rob_tail);
            end
            $display("");
        end
    `endif

endmodule