
`include "sys_defs.svh"

// This is a pipelined multiplier that multiplies two 64-bit integers and
// returns the low 64 bits of the result.
// This is not an ideal multiplier but is sufficient to allow a faster clock
// period than straight multiplication.

module mult (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack,
    input logic         stall,
    input logic         rd_in,

    output FU_PACKET    fu_pack,
    output logic        data_ready
);
    // keep track of each instruction's is_pack
    RS_PACKET [`MULT_STAGES-1:0] orig_packets;

    MULT_FUNC [`MULT_STAGES-2:0] internal_funcs;
    MULT_FUNC func_out;

    logic [(64*(`MULT_STAGES-1))-1:0] internal_sums, internal_mcands, internal_mpliers;
    logic [`MULT_STAGES-2:0] internal_dones;

    logic [63:0] mcand, mplier, product;
    logic [63:0] mcand_out, mplier_out; // unused, just for wiring
    logic done;

    // instantiate an array of mult_stage modules
    // this uses concatenation syntax for internal wiring, see lab 2 slides
    mult_stage mstage [`MULT_STAGES-1:0] (
        .clock (clock),
        .reset (reset),
        .stall (stall),
        .func        ({internal_funcs,   is_pack.decoded_vals.decoded_vals.inst.r.funct3}),
        .start       ({internal_dones,   rd_in}), // forward prev done as next start
        .prev_sum    ({internal_sums,    64'h0}), // start the sum at 0
        .mplier      ({internal_mpliers, mplier}),
        .mcand       ({internal_mcands,  mcand}),
        .product_sum ({product,    internal_sums}),
        .next_mplier ({mplier_out, internal_mpliers}),
        .next_mcand  ({mcand_out,  internal_mcands}),
        .next_func   ({func_out,   internal_funcs}),
        .done        ({done,       internal_dones}) // done when the final stage is done
    );

    // Sign-extend the multiplier inputs based on the operation
    always_comb begin
        case (is_pack.decoded_vals.decoded_vals.inst.r.funct3)
            M_MUL, M_MULH, M_MULHSU: mcand = {{(32){is_pack.rs1_value[31]}}, is_pack.rs1_value};
            default:                 mcand = {32'b0, is_pack.rs1_value};
        endcase
        case (is_pack.decoded_vals.decoded_vals.inst.r.funct3)
            M_MUL, M_MULH: mplier = {{(32){is_pack.rs2_value[31]}}, is_pack.rs2_value};
            default:       mplier = {32'b0, is_pack.rs2_value};
        endcase
    end

    always_ff begin
        if (~stall & rd_in) begin 
            // if it's not stalled and we're reading, shift orig_packets and store is_pack in spot 0
            orig_packets <= {orig_packets[`MULT_STAGES-2:0], is_pack.decoded_vals};
        end else begin
            orig_packets <= orig_packets;
        end
    end

    // Use the high or low bits of the product based on the output func
    assign fu_pack.alu_result = (func_out == M_MUL) ? product[31:0] : product[63:32];
    // populate the rest of fu_pack using the final element of orig_packets
    assign fu_pack.decoded_vals = orig_packets[`MULT_STAGES-1];
    assign data_ready = ~stall & done;

endmodule // mult


module mult_stage (
    input clock, reset, start,
    input stall,
    input [63:0] prev_sum, mplier, mcand,
    input MULT_FUNC func,

    output logic [63:0] product_sum, next_mplier, next_mcand,
    output MULT_FUNC next_func,
    output logic done
);

    parameter SHIFT = 64/`MULT_STAGES;

    logic [63:0] partial_product, shifted_mplier, shifted_mcand;

    assign partial_product = mplier[SHIFT-1:0] * mcand;

    assign shifted_mplier = {SHIFT'('b0), mplier[63:SHIFT]};
    assign shifted_mcand = {mcand[63-SHIFT:0], SHIFT'('b0)};

    always_ff @(posedge clock) begin
        if (stall) begin
            product_sum <= product_sum;
            next_mplier <= next_mplier;
            next_mcand  <= next_mcand;
            next_func   <= next_func;
        end else begin
            product_sum <= prev_sum + partial_product;
            next_mplier <= shifted_mplier;
            next_mcand  <= shifted_mcand;
            next_func   <= func;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            done <= 1'b0;
        end else begin
            done <= start;
        end
    end

endmodule // mult_stage
