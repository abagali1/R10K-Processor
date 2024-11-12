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

    assign ib_open = 8;

    always @(posedge clock) begin
        if (reset) begin
            NPC <= 0;
        end else begin
            NPC <= PC + num_input * 4;
        end
    end

    // // output of ib
    // INST_PACKET [`N-1:0] ib_insts;
    // logic [2:0] ib_open;

    // // output of dispatch
    // DECODED_PACKET [`N-1:0] dis_insts;
    // logic [$clog2(`N+1)-1:0] num_dis;

    // // output of RS
    // logic [$clog2(`N+1)-1:0] rs_open;

    // // output of ROB
    // logic [$clog2(`N+1)-1:0] rob_open, num_retired; 
    // ROB_PACKET [`N-1:0] retiring_data; // rob entry packet, but want register vals to update architectural map table + free list
    // logic [$clog2(`ARCH_REG_SZ)-1:0] rob_tail;

    // // output of MT
    // PHYS_REG_IDX             [`N-1:0]             t_old_data;
    // MAP_TABLE_PACKET         [`N-1:0]             r1_p_reg;
    // MAP_TABLE_PACKET         [`N-1:0]             r2_p_reg;
    // MAP_TABLE_PACKET         [`ARCH_REG_SZ:0]     out_mt;

    // // output of freelist
    // FREE_LIST_PACKET [`N-1:0]                 fl_reg; // displayed available reg idxs, these are always output, and only updated based on rd_num
    // logic            [$clog2(`ROB_SZ+1)-1:0]  fl_head_ptr;

    // // output of br stack
    // CHECKPOINT  cp_out;
    // logic       br_full;


    // inst_buffer inst_buffer (
    //     .clock(clock),
    //     .reset(reset),

    //     .in_insts(in_insts),                 
    //     .num_dispatch(num_dis),
    //     .num_accept(),
    
    //     .dispatched_insts(ib_insts),
    //     .open_entries(ib_open)
    // )

    // dispatch dispatch(
    //     .clock(clock),
    //     .reset(reset),
    //     .rob_open(rob_open),
    //     .rs_open(rs_open),
    //     .insts(ib_insts),
    //     .bs_full(br_full),

    //     .num_dispatch(num_dis), 
    //     .out_insts(dis_insts)
    // )

    // RS rs (
    //     .clock(clock),
    //     .reset(reset),

    //     .rs_in(dis_insts),
    //     .t_in(fl_reg),
    //     .t1_in(r1_p_reg),
    //     .t2_in(r2_p_reg),
    //     .b_mask_in(),

    //     .cdb_in(),

    //     // ebr logic
    //     .br_id(),
    //     .br_task(),

    //     // busy bits from FUs to mark when available to issue
    //     .fu_alu_busy(),
    //     .fu_mult_busy(),
    //     .fu_ld_busy(),
    //     .fu_store_busy(),
    //     .fu_br_busy(), 

    //     .num_accept(),

    //     // output packets directly to FUs (they all are pipelined)
    //     .issued_alu(), 
    //     .issued_mult(),
    //     .issued_ld(),
    //     .issued_store(),
    //     .issued_br(),

    //     .open_entries(rs_open)
    // )

    // ROB rob (
    //     .clock(clock), 
    //     .reset(reset),

    //     .wr_data(dis_insts),
    //     .t(fl_reg.reg_idx),
    //     .t_old(t_old),

    //     .complete_t(), // comes from the CDB
    //     .num_accept(num_dis), // input signal from min block, dependent on open_entries 
    //     .br_tail(),
    //     .br_en(),                        

    //     .retiring_data(retiring_data), // rob entry packet, but want register vals to update architectural map table + free list
    //     .open_entries(rob_open), // number of open entires AFTER retirement
    //     .num_retired(num_retired),
    //     .out_tail(rob_tail)
    // )

    // free_list free_list(
    //     .clock(clock),
    //     .reset(clock),

    //     .rd_num(num_dis),  // number of regs to take off of the free list
    //     .wr_num(num_retired),  // number of regs to add back to the free list
    //     .wr_reg({retiring_data.t_old, retiring_data.valid}),  // reg idxs to add to free list
    //     .br_en(),  // enable signal for EBR
    //     .head_ptr_in(cp_out.fl_head),  // free list copy for EBR

    //     .rd_reg(fl_reg),
    //     .out_fl(),
    //     .head_ptr(fl_head_ptr)
    // )

    // map_table map_table(
    //     .clock(clock),
    //     .reset(reset), 

    //     .r1_idx(dis_insts.reg1),
    //     .r2_idx(dis_insts.reg2),       
    //     .dest_reg_idx(dis_insts.dest_reg_idx), // dest_regs that are getting mapped to a new phys_reg from free_list
    //     .free_reg(fl_reg.reg_idx),  // comes from the free list
    //     .incoming_valid(dis_insts.valid), // inputs to expect                       

    //     .ready_reg_idx(), // readys from CDB - arch reg
    //     .ready_phys_idx(), // corresponding phys reg
    //     .ready_valid(), // one hot encoded inputs to expect

    //     .in_mt_en(),
    //     .in_mt(cp.rec_mt),

    //     .t_old_data(t_old_data), //?
    //     .r1_p_reg(r1_p_reg),
    //     .r2_p_reg(r2_p_reg),
    //     .out_mt(out_mt)
    // )

    // BR_STACK br_stack (
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
    // )

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
