`include "sys_defs.svh"
`include "ISA.svh"

// Conditional branch module: compute whether to take conditional branches
module conditional_branch (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack,
    input logic         stall, // I don't think we should ever stall this
    input logic         rd_in,

    output FU_PACKET    fu_pack;
);
    FU_PACKET out, next_out;
    DATA rs1, rs2;
    logic take;

    assign rs1 = is_pack.rs1_value;
    assign rs2 = is_pack.rs2_value;

    assign fu_pack = out;

    // Combinational logic for choosing taken
    always_comb begin
        case (is_pack.rs_packet.inst.b.funct3)
            3'b000:  take = signed'(rs1) == signed'(rs2); // BEQ
            3'b001:  take = signed'(rs1) != signed'(rs2); // BNE
            3'b100:  take = signed'(rs1) <  signed'(rs2); // BLT
            3'b101:  take = signed'(rs1) >= signed'(rs2); // BGE
            3'b110:  take = rs1 < rs2;                    // BLTU
            3'b111:  take = rs1 >= rs2;                   // BGEU
            default: take = `FALSE;
        endcase
    end

    // Set Next Out
    always_comb begin
        if (stall) begin
            next_out = out;
        end else begin
            next_out = '{alu_result: '0, is_pack: is_pack, take_conditional: take};
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