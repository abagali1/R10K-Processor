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
    output logic        data_ready
);
    FU_PACKET out, next_out;
    DATA rs1, rs2;
    logic take;

    assign fu_pack = out;

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

    // Set Next Out
    always_comb begin
        if (stall) begin
            next_out = out;
            data_ready = '0;
        end else begin
            next_out = '{alu_result: '0, decoded_vals: is_pack.decoded_vals, take_conditional: take};
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