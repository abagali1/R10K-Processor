/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  cpu.sv                                              //
//                                                                     //
//  Description :  Top-level module of the verisimple processor;       //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline together.                       //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"

// comment comment blub blub hehe

module cpu (
    input clock, // System clock
    input reset, // System reset
    
    input INST_PACKET [7:0] in_insts,
    input logic [3:0] num_input,

    // Note: these are assigned at the very bottom of the module
    output COMMIT_PACKET [`N-1:0] committed_insts,

    output logic         [3:0] ib_open,
    output ADDR                PC
);

    //////////////////////////////////////////////////
    //                                              //
    //               amrita trying                  //
    //                                              //
    //////////////////////////////////////////////////

    // the start of amrita ducking around

    // fake fetch

    ADDR NPC;

    assign PC = NPC;

    always @(posedge clock) begin
        if (reset) begin
            NPC <= 0;
        end else begin
            NPC <= PC + num_input * 4;
        end
    end

    //////////////////////////////////////////////////
    //                                              //
    //               pipeline wires                 //
    //                                              //
    //////////////////////////////////////////////////


    // output of ib
    INST_PACKET [`N-1:0] ib_insts;

    // output of dispatch
    DECODED_PACKET [`N-1:0] dis_insts;
    logic [$clog2(`N+1)-1:0] num_dis;

    // output of RS
    logic [$clog2(`N+1)-1:0] rs_open;

    // output of ROB
    logic [$clog2(`N+1)-1:0] rob_open, num_retired; 
    ROB_PACKET [`N-1:0] retiring_data; // rob entry packet, but want register vals to update architectural map table + free list
    logic [$clog2(`ARCH_REG_SZ)-1:0] rob_tail;

    // output of MT
    PHYS_REG_IDX             [`N-1:0]             t_old_data;
    MAP_TABLE_PACKET         [`N-1:0]             r1_p_reg;
    MAP_TABLE_PACKET         [`N-1:0]             r2_p_reg;
    MAP_TABLE_PACKET         [`ARCH_REG_SZ:0]     out_mt;

    // output of freelist
    FREE_LIST_PACKET [`N-1:0]                 fl_reg; // displayed available reg idxs, these are always output, and only updated based on rd_num
    logic            [$clog2(`ROB_SZ+1)-1:0]  fl_head_ptr;

    // output of br stack
    // CHECKPOINT  cp_out;
    logic br_full;
    
    // hardcoded values
    assign br_full = 0;

    logic [`NUM_FU_ALU-1:0]    fu_alu_busy;
    logic [`NUM_FU_MULT-1:0]   fu_mult_busy;
    logic [`NUM_FU_LD-1:0]     fu_ld_busy;
    logic [`NUM_FU_STORE-1:0]  fu_store_busy;
    logic [`NUM_FU_BR-1:0]     fu_br_busy;

    assign fu_alu_busy   = '1;
    assign fu_mult_busy  = '1;
    assign fu_ld_busy    = '1;
    assign fu_store_busy = '1;
    assign fu_br_busy    = '1;

     

    inst_buffer buffet (
        .clock(clock),
        .reset(reset),

        .in_insts(in_insts),                 
        .num_dispatch(num_dis),
        .num_accept(num_input),

        .dispatched_insts(ib_insts),
        .open_entries(ib_open)
    );

    dispatch disbitch (
        .clock(clock),
        .reset(reset),
        .rob_open(rob_open),
        .rs_open(rs_open),
        .insts(ib_insts),
        .bs_full(br_full),

        .num_dispatch(num_dis), 
        .out_insts(dis_insts)
    );

    REG_IDX      [`N-1:0] dis_r1_idx;
    REG_IDX      [`N-1:0] dis_r2_idx;       
    REG_IDX      [`N-1:0] dis_dest_reg_idx; // dest_regs that are getting mapped to a new phys_reg from free_list
    PHYS_REG_IDX [`N-1:0] dis_free_reg;  // comes from the free list
    logic        [`N-1:0] dis_incoming_valid;

    always_comb begin
        for (int i = 0; i < `N; i++) begin
            dis_r1_idx[i] = dis_insts[i].reg1;
            dis_r2_idx[i] = dis_insts[i].reg2;       
            dis_dest_reg_idx[i] = dis_insts[i].dest_reg_idx; // dest_regs that are getting mapped to a new phys_reg from free_list
            dis_free_reg[i] = fl_reg[i].reg_idx;  // comes from the free list
            dis_incoming_valid[i] = dis_insts[i].valid;
        end
    end

    free_list flo_from_progressive (
        .clock(clock),
        .reset(reset),

        .rd_num(num_dis),  // number of regs to take off of the free list
        .wr_num(num_retired),  // number of regs to add back to the free list
        .wr_reg(0),//{retiring_data.t_old, retiring_data.valid}),  // reg idxs to add to free list
        .br_en(0),  // enable signal for EBR
        .head_ptr_in(0),//cp_out.fl_head),  // free list copy for EBR

        .rd_reg(fl_reg),
        .head_ptr(fl_head_ptr)
    );


    map_table im_the_map (
        .clock(clock),
        .reset(reset), 

        .r1_idx(dis_r1_idx),
        .r2_idx(dis_r2_idx),       
        .dest_reg_idx(dis_dest_reg_idx), // dest_regs that are getting mapped to a new phys_reg from free_list
        .free_reg(dis_free_reg),  // comes from the free list
        .incoming_valid(dis_incoming_valid), // inputs to expect                       

        .ready_reg_idx(0), // readys from CDB - arch reg
        .ready_phys_idx(0), // corresponding phys reg
        .ready_valid(0), // one hot encoded inputs to expect

        .in_mt_en(0),
        .in_mt(0),//cp.rec_mt),

        .t_old_data(t_old_data), //?
        .r1_p_reg(r1_p_reg),
        .r2_p_reg(r2_p_reg),
        .out_mt(out_mt)
    );

    rs rasam (
        .clock(clock),
        .reset(reset),

        .rs_in(dis_insts),
        .t_in(fl_reg),
        .t1_in(r1_p_reg),
        .t2_in(r2_p_reg),
        .b_mask_in(0),

        .cdb_in(0),

        // ebr logic
        .br_id(0),
        .br_task(0),

        // busy bits from FUs to mark when available to issue
        .fu_alu_busy(fu_alu_busy),
        .fu_mult_busy(fu_mult_busy),
        .fu_ld_busy(fu_ld_busy),
        .fu_store_busy(fu_store_busy),
        .fu_br_busy(fu_br_busy), 

        .num_accept(num_dis),

        // output packets directly to FUs (they all are pipelined)
        .issued_alu(0), 
        .issued_mult(0),
        .issued_ld(0),
        .issued_store(0),
        .issued_br(0),

        .open_entries(rs_open)
    );

    rob robert (
        .clock(clock), 
        .reset(reset),

        .wr_data(dis_insts),
        .t(dis_free_reg),
        .t_old(t_old_data),

        .complete_t(0), // comes from the CDB
        .num_accept(num_dis), // input signal from min block, dependent on open_entries 
        .br_tail(0),
        .br_en(0),                        

        .retiring_data(retiring_data), // rob entry packet, but want register vals to update architectural map table + free list
        .open_entries(rob_open), // number of open entires AFTER retirement
        .num_retired(num_retired),
        .out_tail(rob_tail)
    );

    // br_stack pancake (
    //     .clock(clock),
    //     .reset(reset),

    //     .valid_assign(),
    //     .in_PC(),
    //     .in_mt(out_mt),
    //     .in_fl_head(fl_head_ptr),
    //     .in_rob_tail(rob_tail),
    
    //     .cdb_in(),
    
    //     .br_task(), // not defined here. in main sysdefs
    //     .rem_b_id(), // b_id to remove
    
    
    //     .cp_out(cp_out),
    //     .full(br_full)
    // );

    //////////////////////////////////////////////////
    //                                              //
    //               Pipeline Outputs               //
    //                                              //
    //////////////////////////////////////////////////

    // Output the committed instruction to the testbench for counting
    // assign committed_insts[0] = wb_packet;

    // DEBUG OUTPUTS
    `ifdef DEBUG
        int cycle = 0;
        always @(posedge clock) begin
            $display("====================== CPU ======================");
            $display("@@@ Cycle %0d @@@", cycle);
            $display("Time: %0t", $time);
            cycle++;
        end
    `endif

endmodule // pipeline
