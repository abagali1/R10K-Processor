/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.sv                                          //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  //
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"

module regfile #(
    parameter DEPTH = `PHYS_REG_SZ_R10K,
    parameter NUM_FU = `NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_STORE + `NUM_FU_LD + `NUM_FU_BR
)(
    input         clock, // system clock
    // note: no system reset, register values must be written before they can be read
    input  REG_IDX  [NUM_FU-1:0]     read_idx_1, read_idx_2, write_idx,
    input           [NUM_FU-1:0]     write_en,
    input  DATA     [NUM_FU-1:0]     write_data,

    output DATA     [NUM_FU-1:0]     read_out_1, read_out_2
);

    // Intermediate data before accounting for register 0
    DATA  rdata2, rdata1;
    // Don't read or write when dealing with register 0
    logic [NUM_FU-1:0] re1, re2;
    logic [NUM_FU-1:0] we;

    // Technically we only need 31 registers since reg 0 is hard wired to 0
    // But since we're not grading area, just set size to 32 to make interface
    // easier and avoid having to subtract 1 from all addresses
    memDP #(
        .WIDTH      ($bits(DATA)), // 32-bit registers
        .DEPTH      (DEPTH),
        .READ_PORTS (2*NUM_FU), // 2 read ports
        .WRITE_PORTS(NUM_FU),
        .BYPASS_EN  (1)) // Allow internal forwarding
    regfile_mem (
        .clock(clock),
        .reset(1'b0),   // must be written before read
        .re   ({re2,        re1}),
        .raddr({read_idx_2, read_idx_1}),
        .rdata({rdata2,     rdata1}),
        .we   (we),
        .waddr(write_idx),
        .wdata(write_data)
    );

    // Read port 1
    always_comb begin
        for (int i = 0; i < 2*NUM_FU; i++) begin
            if (read_idx_1 == `ZERO_REG) begin
                read_out_1 = '0;
                re1        = 1'b0;
            end else begin
                read_out_1 = rdata1;
                re1        = 1'b1;
            end
        end
    end

    // Read port 2
    always_comb begin
        for (int i = 0; i < 2*NUM_FU; i++) begin
            if (read_idx_2 == `ZERO_REG) begin
                read_out_2 = '0;
                re2        = 1'b0;
            end else begin
                read_out_2 = rdata2;
                re2        = 1'b1;
            end
        end
    end

    // Write port
    // Can't write to zero register
    assign we = write_en && (write_idx != `ZERO_REG);

endmodule // regfile
