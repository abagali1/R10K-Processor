/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.sv                                          //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  //
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
//`include "memDP.sv"

module regfile #(
    parameter DEPTH = `PHYS_REG_SZ_R10K,
    parameter NUM_FU = `NUM_FUS,
    parameter N = `N
)(
    input         clock, // system clock
    input         reset,
    // note: no system reset, register values must be written before they can be read
    input  PHYS_REG_IDX     [NUM_FU-1:0]        read_idx_1, read_idx_2, 
    input  PHYS_REG_IDX     [N-1:0]            write_idx,
    input                   [N-1:0]            write_en,
    input  DATA             [N-1:0]            write_data,

    output DATA             [NUM_FU-1:0]        read_out_1, read_out_2
);

    // Intermediate data before accounting for register 0
    DATA [NUM_FU-1:0] rdata2, rdata1;
    // Don't read or write when dealing with register 0
    logic [NUM_FU-1:0] re1, re2;
    logic [N-1:0] we;

    // Technically we only need 31 registers since reg 0 is hard wired to 0
    // But since we're not grading area, just set size to 32 to make interface
    // easier and avoid having to subtract 1 from all addresses
    memDP #(
        .WIDTH      ($bits(DATA)), // 32-bit registers
        .DEPTH      (DEPTH),
        .READ_PORTS (2*NUM_FU), // 2 read ports
        .WRITE_PORTS(N),
        .BYPASS_EN  (1)) // don't need internal forwarding
    regfile_mem (
        .clock(clock),
        .reset(reset),   // must be written before read
        .re   ({re2,        re1}),
        .raddr({read_idx_2, read_idx_1}),
        .rdata({rdata2,     rdata1}),
        .we   (we),
        .waddr(write_idx),
        .wdata(write_data)
    );

    // Read port 1
    always_comb begin
        for (int i = 0; i < NUM_FU; i++) begin
            if (read_idx_1[i] == `ZERO_REG) begin
                re1[i]        = 1'b0;
                read_out_1[i] = '0;
            end else begin
                re1[i]        = 1'b1;
                read_out_1[i] = rdata1[i];
            end
        end
    end

    // Read port 2
    always_comb begin
        for (int i = 0; i < NUM_FU; i++) begin
            if (read_idx_2[i] == `ZERO_REG) begin
                re2[i]        = 1'b0;
                read_out_2[i] = '0;
            end else begin
                re2[i]        = 1'b1;
                read_out_2[i] = rdata2[i];
            end
        end
    end

    // Write port
    // Can't write to zero register
    always_comb begin
        for (int i = 0; i < N; i++) begin
            we[i] = write_en[i] & (write_idx[i] != `ZERO_REG);
        end
    end

    // `ifdef DEBUG
    //     always @(posedge clock) begin
    //         $display("--------------- REGFILE ---------------");

    //         $display("Inputs:");

    //         $display("read_idx_1:");
    //         for (int i = 0; i < NUM_FU; i++) begin
    //             $write("| %2d", read_idx_1[i]);
    //         end
    //         $display("");

    //         $display("read_idx_2:");
    //         for (int i = 0; i < NUM_FU; i++) begin
    //             $write("| %2d", read_idx_2[i]);
    //         end
    //         $display("");

    //         $display("write_en:");
    //         for (int i = 0; i < N; i++) begin
    //             $write("| %2d", write_en[i]);
    //         end
    //         $display("");

    //         $display("write_idx:");
    //         for (int i = 0; i < N; i++) begin
    //             $write("| %2d", write_idx[i]);
    //         end
    //         $display("");

    //         $display("write_data:");
    //         for (int i = 0; i < N; i++) begin
    //             $write("| %2d", write_data[i]);
    //         end
    //         $display("\n");

    //         $display("Outputs:");

    //         $display("read_out_1:");
    //         for (int i = 0; i < NUM_FU; i++) begin
    //             $write("| %2d", read_out_1[i]);
    //         end
    //         $display("");

    //         $display("read_out_2:");
    //         for (int i = 0; i < NUM_FU; i++) begin
    //             $write("| %2d", read_out_2[i]);
    //         end
    //         $display("\n");
    //     end
    // `endif 

endmodule // regfile
