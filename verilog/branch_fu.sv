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
    output logic        data_ready,
    output logic        br_taken

    `ifdef DEBUG
        , ADDR debug_branch_target
    `endif 
);
    ADDR target, branch_target;
    logic taken, correct;

    assign br_taken = taken;

    RS_PACKET out;

    always_comb begin
        out = is_pack.decoded_vals;
        out.b_mask = (rem_br_task == CLEAR) ? out.b_mask ^ rem_b_id : is_pack.decoded_vals.b_mask;
    end

    assign correct = is_pack.decoded_vals.decoded_vals.pred_taken == taken; // TODO: Add target addr check

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
            fu_pack     <= '{result: '0, decoded_vals: '0, pred_correct: '1, rs2_value: 0, ld_state: 0, target_addr: 0};
            data_ready  <= '0;
            br_task     <= NOTHING;
        end else if (rd_en) begin
            fu_pack     <= '{result: target, decoded_vals: out, pred_correct: correct, rs2_value: 0, ld_state: 0, target_addr: 0};
            data_ready  <= 1;
            br_task     <= (correct ? CLEAR : SQUASH);
        end else begin
            fu_pack     <= '{result: '0, decoded_vals: '0, pred_correct: '1, rs2_value: 0, ld_state: 0, target_addr: 0};
            data_ready  <= '0;
            br_task     <= NOTHING;
        end
    end

    `ifdef DEBUG
        `ifndef DC
            always @(posedge clock) begin #2;
                $display("============== BRANCH FU ==============\n");
                $display("  rd_en: %b",  rd_en);
                $display("  Issue Packet PC: 0x%05x", is_pack.decoded_vals.decoded_vals.PC);
                $display("  pred: %s, b_id: %0d, b_mask: %0d, rs1_value: %0d, rs2_value: %0d", is_pack.decoded_vals.decoded_vals.pred_taken ? "T" : "NT", is_pack.decoded_vals.b_id, is_pack.decoded_vals.b_mask, is_pack.rs1_value, is_pack.rs2_value);
                $display("  FU Packet Out:");
                $display("  result: %s, branch target: %x, prediction correct: %0d, br task: %0s", taken ? "T" : "NT", fu_pack.result, correct, br_task.name());
                $display("  rem_br_task: %0s, rem_b_id: %0b, is_pack b_mask: %0b", rem_br_task, rem_b_id, is_pack.decoded_vals.b_mask);
                // gonna let you finish this anup
            end
        `endif
    `endif

endmodule
