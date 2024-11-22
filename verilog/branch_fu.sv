`include "sys_defs.svh"
`include "ISA.svh"
`include "basic_adder.sv"

// Conditional branch module: compute whether to take conditional branches
module branch_fu (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack, // print this
    input logic         rd_en,
    
    input BR_TASK       rem_br_task,
    input BR_MASK       rem_b_id,

    output FU_PACKET    fu_pack, // print out all outputs
    output BR_TASK      br_task,
    output logic        data_ready

    `ifdef DEBUG
        , ADDR debug_branch_target
    `endif 
);
    ADDR target, branch_target;
    logic taken, correct;

    assign correct = is_pack.decoded_vals.decoded_vals.pred_taken == taken;

    assign target = taken ? branch_target : is_pack.decoded_vals.decoded_vals.NPC;

    basic_adder branch_target_calc (
        .is_pack(is_pack),
        .result(branch_target)
    );

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

    `ifdef DEBUG
        assign debug_branch_target = branch_target;
    `endif

    always_ff @(posedge clock) begin
        if (reset || (rem_br_task == SQUASH && (is_pack.decoded_vals.b_mask & rem_b_id) != '0)) begin
            fu_pack     <= '{result: '0, decoded_vals: '0, pred_correct: '1};
            data_ready  <= '0;
            br_task     <= NOTHING;
        end else if (rd_en) begin
            fu_pack     <= '{result: target, decoded_vals: is_pack.decoded_vals, pred_correct: correct};
            data_ready  <= 1;
            br_task     <= (correct ? CLEAR : SQUASH);
        end else begin
            fu_pack     <= '{result: '0, decoded_vals: '0, pred_correct: '1};
            data_ready  <= '0;
            br_task     <= NOTHING;
        end
    end

    `ifdef DEBUG
        always @(posedge clock) begin #2;
            $display("============== BRANCH FU ==============\n");
            $display("  rd_en: %b",  rd_en);
            $display("  Issue Packet:");
            $display("  b_id: %0d, b_mask: %0d, rs1_value: %0d, rs2_value: %0d", is_pack.decoded_vals.b_id, is_pack.decoded_vals.b_mask, is_pack.rs1_value, is_pack.rs2_value);
            $display("  FU Packet Out:");
            $display("  branch target: %x, prediction correct: %0d, br task: %0s", fu_pack.result, correct, br_task.name());
            $display("  rem_br_task: %0s, rem_b_id: %0b, is_pack b_mask: %0b", rem_br_task, rem_b_id, is_pack.decoded_vals.b_mask);
            // gonna let you finish this anup
        end
    `endif

endmodule
