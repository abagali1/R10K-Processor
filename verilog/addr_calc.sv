`include "sys_defs.svh"
`include "ISA.svh"

module addr_calc (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack,
    input               stall,
    input               rd_in,

    output FU_PACKET    fu_out,
    output              data_ready
);
    FU_PACKET out_packet, next_out_packet;
    DATA base, offset;

    always_ff @(posedge clock) begin
        if (reset) begin
            out_packet <= '0;
        end else if (stall_unit) begin
            out_packet <= out_packet;
        end else begin
            out_packet <= next_out_packet;
        end
    end

    assign next_out_packet.decoded_vals = is_pack.decoded_vals;

    assign base = (is_pack.decoded_vals.decoded_vals.uncond_branch) ? is_pack.decoded_vals.decoded_vals.PC : is_pack.rs1_value;
    assign offset = (is_pack.decoded_vals.decoded_vals.uncond_branch) ? `RV32_signext_Jimm(is_pack.decoded_vals.decoded_vals.inst) :
                    (is_pack.decoded_vals.decoded_vals.wr_mem) ? `RV32_signext_Simm(is_pack.decoded_vals.decoded_vals.inst) : `RV32_signext_Iimm(rs_in.inst);   //covers JALR
    assign next_out_packet.alu_result = base + offset;

    assign data_ready = ~stall & rd_in;
endmodule