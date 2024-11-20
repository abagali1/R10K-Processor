`include "sys_defs.svh"
`include "ISA.svh"

module addr_calc (
    input               clock, 
    input               reset,
    input ISSUE_PACKET  is_pack,
    input               stall,
    input               rd_in,

    output FU_PACKET    fu_out,
    output logic        data_ready
);
    FU_PACKET out_packet, next_out_packet;

    assign next_out_packet.result = is_pack.rs1_value + is_pack.rs2_value;

    always_ff @(posedge clock) begin
        if (reset) begin
            out_packet <= '0;
            data_ready <= '0;
        end else if (stall) begin
            out_packet <= out_packet;
            data_ready <= data_ready;
        end else if (rd_in) begin
            out_packet <= next_out_packet;
            data_ready <= 1;
        end else begin
            out_packet <= '0;
            data_ready <= '0;
        end
    end

    assign next_out_packet.decoded_vals = is_pack.decoded_vals;
    assign fu_out = out_packet;
endmodule