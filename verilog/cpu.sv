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


module cpu (
    input                                                                   clock, // System clock
    input                                                                   reset, // System reset
    
    input INST_PACKET                   [7:0]                               in_insts,
    input logic                         [3:0]                               num_input,

    // Note: these are assigned at the very bottom of the modulo
    output COMMIT_PACKET                [`N-1:0]                            committed_insts,

    output logic                        [3:0]                               ib_open,
    output ADDR                                                             NPC

    `ifdef DEBUG
    ,   output  logic                   [$clog2(`N+1)-1:0]                  debug_num_dispatched,
        output  logic                   [$clog2(`N+1)-1:0]                  debug_num_retired,
    
        output INST_PACKET              [`INST_BUFF_DEPTH-1:0]              debug_inst_buff_entries,
        output logic                    [$clog2(`INST_BUFF_DEPTH)-1:0]      debug_inst_buff_head,
        output logic                    [$clog2(`INST_BUFF_DEPTH)-1:0]      debug_inst_buff_tail,

        output DECODED_PACKET           [`N-1:0]                            debug_dis_insts,

        output FREE_LIST_PACKET         [`ROB_SZ-1:0]                       debug_fl_entries,
        output logic                    [$clog2(`ROB_SZ)-1:0]               debug_fl_head,
        output logic                    [$clog2(`ROB_SZ)-1:0]               debug_fl_tail,

        output MAP_TABLE_PACKET         [`ARCH_REG_SZ-1:0]                  debug_mt_entries,

        output RS_PACKET                [`RS_SZ-1:0]                        debug_rs_entries,
        output logic                    [`RS_SZ-1:0]                        debug_rs_open_spots,
        output logic                    [`RS_SZ-1:0]                        debug_rs_other_sig,
        output logic                    [$clog2(`RS_SZ+1)-1:0]              debug_rs_open_entries,
        output logic                    [`RS_SZ-1:0]                        debug_rs_all_issued_insts,

        output ROB_PACKET               [`ROB_SZ-1:0]                       debug_rob_entries,
        output logic                    [$clog2(`ROB_SZ)-1:0]               debug_rob_head,
        output logic                    [$clog2(`ROB_SZ)-1:0]               debug_rob_tail,

        output CHECKPOINT               [`BRANCH_PRED_SZ-1:0]               debug_bs_entries,
        output logic                    [`BRANCH_PRED_SZ-1:0]               debug_bs_free_entries,
        output logic                    [`BRANCH_PRED_SZ-1:0]               debug_bs_stack_gnt
        
    `endif
);

    //////////////////////////////////////////////////
    //                                              //
    //               amrita trying                  //
    //                                              //
    //////////////////////////////////////////////////

    // the start of amrita ducking around

    // fake fetch

    ADDR PC;

    assign NPC = PC;

    always @(posedge clock) begin
        if (reset) begin
            PC <= 0;
        end else if (!br_fu_out.pred_correct) begin
            PC <= br_fu_out.result;
        end else begin
            PC <= NPC + num_input * 4;
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
    // dispatch helpers
    REG_IDX      [`N-1:0] dis_r1_idx;
    REG_IDX      [`N-1:0] dis_r2_idx;       
    REG_IDX      [`N-1:0] dis_dest_reg_idx; // dest_regs that are getting mapped to a new phys_reg from free_list
    PHYS_REG_IDX [`N-1:0] dis_free_reg;  // comes from the free list
    logic        [`N-1:0] dis_incoming_valid;


    // output of RS
    logic        [$clog2(`N+1)-1:0]     rs_open;
    RS_PACKET    [`NUM_FU_ALU-1:0]      issued_alu; 
    RS_PACKET    [`NUM_FU_MULT-1:0]     issued_mult;
    RS_PACKET    [`NUM_FU_LD-1:0]       issued_ld;
    RS_PACKET    [`NUM_FU_STORE-1:0]    issued_store;
    RS_PACKET                           issued_br;


    // output of ROB
    logic [$clog2(`N+1)-1:0] rob_open, num_retired; 
    ROB_PACKET [`N-1:0] retiring_data; // rob entry packet, but want register vals to update architectural map table + free list
    logic [$clog2(`ROB_SZ)-1:0] rob_tail;
    // commit helpers
    FREE_LIST_PACKET [`N-1:0] retiring_t_old;


    // output of MT
    PHYS_REG_IDX             [`N-1:0]             t_old_data;
    MAP_TABLE_PACKET         [`N-1:0]             r1_p_reg;
    MAP_TABLE_PACKET         [`N-1:0]             r2_p_reg;
    MAP_TABLE_PACKET         [`ARCH_REG_SZ-1:0]     out_mt; // CHECK: this size does not match up to branch stack in_mt


    // output of freelist
    FREE_LIST_PACKET [`N-1:0]                 fl_reg; // displayed available reg idxs, these are always output, and only updated based on rd_num
    logic            [$clog2(`ROB_SZ+1)-1:0]  fl_head_ptr;


    // output of cdb
    CDB_PACKET [`N-1:0] cdb_entries;
    logic [`NUM_FUS-`NUM_FU_BR-1:0] cdb_stall_sig;
    // cdb helpers
    REG_IDX         [`N-1:0] cdb_reg_idx;
    PHYS_REG_IDX    [`N-1:0] cdb_p_reg_idx;
    logic           [`N-1:0] cdb_valid;
    DATA            [`N-1:0] cdb_wr_data;


    // output of br stack
    CHECKPOINT  cp_out;
    logic br_full;
    BR_MASK assigned_b_id;


    // output of regfile
    DATA  [`NUM_FUS-1:0] reg_data_1, reg_data_2;


    // out of issue
    logic          [`NUM_FU_ALU-1:0]        alu_rd_en; 
    logic          [`NUM_FU_MULT-1:0]       mult_rd_en;
    logic          [`NUM_FU_LD-1:0]         ld_rd_en;
    logic          [`NUM_FU_STORE-1:0]      st_rd_en;
    logic                                   br_rd_en;

    ISSUE_PACKET   [`NUM_FU_ALU-1:0]        issued_alu_pack; 
    ISSUE_PACKET   [`NUM_FU_MULT-1:0]       issued_mult_pack;
    ISSUE_PACKET   [`NUM_FU_LD-1:0]         issued_ld_pack;
    ISSUE_PACKET   [`NUM_FU_STORE-1:0]      issued_st_pack;
    ISSUE_PACKET                            issued_br_pack;

    PHYS_REG_IDX   [`NUM_FUS-1:0]           reg_idx_1, reg_idx_2;


    // output of alu
    FU_PACKET [`NUM_FU_ALU-1:0] alu_fu_out;
    logic     [`NUM_FU_ALU-1:0] alu_done;


    // output of mult
    FU_PACKET [`NUM_FU_MULT-1:0] mult_fu_out;
    logic     [`NUM_FU_MULT-1:0] mult_done;


    // output of branch fu
    FU_PACKET br_fu_out;
    BR_TASK   br_task;
    logic     br_done;


    // hardcoded values

    FU_PACKET [`NUM_FU_LD-1:0] ld_fu_out;
    FU_PACKET [`NUM_FU_STORE-1:0] st_fu_out;

    logic [`NUM_FU_LD-1:0] ld_done;
    logic [`NUM_FU_STORE-1:0] st_done;

    assign ld_fu_out = '0;
    assign st_fu_out = '0;

    assign ld_done = '0;
    assign st_done = '0;

    `ifdef DEBUG
        assign debug_dis_insts = dis_insts;
        assign debug_num_dispatched = num_dis;
        assign debug_num_retired = num_retired;
    `endif


    inst_buffer buffet (
        .clock(clock),
        .reset(reset),

        .in_insts(in_insts),
        .num_dispatch(num_dis),
        .num_accept(num_input),

        .dispatched_insts(ib_insts),
        .open_entries(ib_open)

        `ifdef DEBUG
        ,   .debug_entries(debug_inst_buff_entries),
            .debug_head(debug_inst_buff_head),
            .debug_tail(debug_inst_buff_tail)
        `endif
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

    freelist flo_from_progressive (
        .clock(clock),
        .reset(reset),

        .rd_num(num_dis),  // number of regs to take off of the free list
        .wr_num(num_retired),  // number of regs to add back to the free list
        .wr_reg(retiring_t_old),  // reg idxs to add to free list
        .br_en(br_done & ~br_fu_out.pred_correct),  // enable signal for EBR
        .head_ptr_in(cp_out.fl_head),  // free list copy for EBR

        .rd_reg(fl_reg),
        .head_ptr(fl_head_ptr)

        `ifdef DEBUG
        ,   .debug_entries(debug_fl_entries),
            .debug_head(debug_fl_head),
            .debug_tail(debug_fl_tail)
        `endif
    );

    map_table im_the_map (
        .clock(clock),
        .reset(reset), 

        .r1_idx(dis_r1_idx),
        .r2_idx(dis_r2_idx),
        .dest_reg_idx(dis_dest_reg_idx), // dest_regs that are getting mapped to a new phys_reg from free_list
        .free_reg(dis_free_reg),  // comes from the free list
        .incoming_valid(dis_incoming_valid), // inputs to expect

        .ready_reg_idx(cdb_reg_idx), // readys from CDB - arch reg
        .ready_phys_idx(cdb_p_reg_idx), // corresponding phys reg
        .ready_valid(cdb_valid), // one hot encoded inputs to expect

        .in_mt_en(br_done & ~br_fu_out.pred_correct),
        .in_mt(cp_out.rec_mt),//cp.rec_mt),

        .t_old_data(t_old_data), //?
        .r1_p_reg(r1_p_reg),
        .r2_p_reg(r2_p_reg),
        .out_mt(out_mt)

        `ifdef DEBUG
        ,   .debug_entries(debug_mt_entries)
        `endif
    );

    rs rasam (
        .clock(clock),
        .reset(reset),

        .rs_in(dis_insts),
        .t_in(fl_reg),
        .t1_in(r1_p_reg),
        .t2_in(r2_p_reg),
        .b_id(assigned_b_id),

        .cdb_in(cdb_entries),

        // ebr logic
        .rem_b_id(br_fu_out.decoded_vals.b_id),
        .br_task(br_task),

        // busy bits from FUs to mark when available to issue
        .fu_alu_busy(cdb_stall_sig[`NUM_FU_ALU-1:0]),
        .fu_mult_busy(cdb_stall_sig[`NUM_FU_ALU+`NUM_FU_MULT-1:`NUM_FU_ALU]),
        .fu_ld_busy(cdb_stall_sig[`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LD-1:`NUM_FU_ALU+`NUM_FU_MULT]),
        .fu_store_busy(cdb_stall_sig[`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LD+`NUM_FU_STORE-1:`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LD]),
        .fu_br_busy(cdb_stall_sig[`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LD+`NUM_FU_STORE-1]), 

        .num_accept(num_dis),

        // output packets directly to FUs (they all are pipelined)
        .issued_alu(issued_alu), 
        .issued_mult(issued_mult),
        .issued_ld(issued_ld),
        .issued_store(issued_store),
        .issued_br(issued_br),

        .open_entries(rs_open)

        `ifdef DEBUG
        ,   .debug_entries(debug_rs_entries),
            .debug_open_spots(debug_rs_open_spots),
            .debug_other_sig(debug_rs_other_sig),
            .debug_open_entries(debug_rs_open_entries),
            .debug_all_issued_insts(debug_rs_all_issued_insts)
        `endif
    );

    rob robert (
        .clock(clock), 
        .reset(reset),

        .wr_data(dis_insts),
        .t(dis_free_reg),
        .t_old(t_old_data),

        .complete_t(cdb_p_reg_idx), // comes from the CDB
        .br_complete_t(br_fu_out.decoded_vals.t.reg_idx),
        .num_accept(num_dis), // input signal from min block, dependent on open_entries 
        .br_tail(cp_out.rob_tail),
        .br_en(br_done & ~br_fu_out.pred_correct),

        .retiring_data(retiring_data), // rob entry packet, but want register vals to update architectural map table + free list
        .open_entries(rob_open), // number of open entires AFTER retirement
        .num_retired(num_retired),
        .out_tail(rob_tail)

        `ifdef DEBUG
        ,   .debug_data(cdb_wr_data),
            .debug_entries(debug_rob_entries),
            .debug_head(debug_rob_head),
            .debug_tail(debug_rob_tail)
        `endif
    );

    cdb cbd (
        .clock(clock),
        .reset(reset),
        .fu_done({alu_done, mult_done, ld_done, st_done}), 
        .wr_data({alu_fu_out, mult_fu_out, ld_fu_out, st_fu_out}), 
        .entries(cdb_entries),
        .stall_sig(cdb_stall_sig)
    );

    br_stack pancake (
        .clock(clock),
        .reset(reset),

        .dis_inst(dis_insts[0]),
        .in_mt(out_mt),
        .in_fl_head(fl_head_ptr),
        .in_rob_tail(rob_tail), // CHECK size don't match up
    
        .cdb_in(cdb_entries),
    
        .br_task(br_task), // not defined here. in main sysdefs
        .rem_b_id(br_fu_out.decoded_vals.b_id), // b_id to remove
    
        .assigned_b_id(assigned_b_id), // CHECK added
        .cp_out(cp_out),
        .full(br_full)

        `ifdef DEBUG
        ,   .debug_entries(debug_bs_entries),
            .debug_free_entries(debug_bs_free_entries),
            .debug_stack_gnt(debug_bs_stack_gnt)
        `endif
    );

    regfile reggie (
        .clock(clock), // system clock
        .reset(reset),

        .read_idx_1(reg_idx_1),
        .read_idx_2(reg_idx_2), 
        .write_idx(cdb_p_reg_idx),
        .write_en(cdb_valid),
        .write_data(cdb_wr_data),

        .read_out_1(reg_data_1), 
        .read_out_2(reg_data_2)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                   dispatch                   //
    //                                              //
    //////////////////////////////////////////////////

    always_comb begin
        for (int i = 0; i < `N; i++) begin
            dis_r1_idx[i] = dis_insts[i].reg1;
            dis_r2_idx[i] = dis_insts[i].reg2;       
            dis_dest_reg_idx[i] = dis_insts[i].dest_reg_idx; // dest_regs that are getting mapped to a new phys_reg from free_list
            dis_free_reg[i] = fl_reg[i].reg_idx;  // comes from the free list
            dis_incoming_valid[i] = dis_insts[i].valid;
        end
    end

    //////////////////////////////////////////////////
    //                                              //
    //                    issue                     //
    //                                              //
    //////////////////////////////////////////////////

    issue anup (
        .clock(clock),
        .reset(reset),

        .reg_data_1(reg_data_1),
        .reg_data_2(reg_data_2),

        .issued_alu(issued_alu), 
        .issued_mult(issued_mult),
        .issued_ld(issued_ld),
        .issued_st(issued_store),
        .issued_br(issued_br),

        .alu_rd_en(alu_rd_en), 
        .mult_rd_en(mult_rd_en),
        .ld_rd_en(ld_rd_en),
        .st_rd_en(st_rd_en),
        .br_rd_en(br_rd_en),

        .issued_alu_pack(issued_alu_pack), 
        .issued_mult_pack(issued_mult_pack),
        .issued_ld_pack(issued_ld_pack),
        .issued_st_pack(issued_st_pack),
        .issued_br_pack(issued_br_pack),

        .reg_idx_1(reg_idx_1),
        .reg_idx_2(reg_idx_2)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  execution                   //
    //                                              //
    //////////////////////////////////////////////////

    generate
        for (genvar i = 0; i < `NUM_FU_ALU; i++) begin
            alu what_the (
                .clock(clock), 
                .reset(reset),
                .is_pack(issued_alu_pack[i]),
                .stall(cdb_stall_sig[i]),
                .rd_in(alu_rd_en[i]),

                .fu_pack(alu_fu_out[i]),
                .data_ready(alu_done[i])
            );
        end
    endgenerate
    
    generate
        for (genvar i = 0; i < `NUM_FU_MULT; i++) begin
            mult what_the_fck (
                .clock(clock), 
                .reset(reset),
                .is_pack(issued_mult_pack[i]),
                .stall(cdb_stall_sig[`NUM_FU_ALU + i]),
                .rd_in(mult_rd_en[i]),

                .fu_pack(mult_fu_out[i]),
                .data_ready(mult_done[i])
            );
        end
    endgenerate

    branch_fu what_the_duck (
        .clock(clock), 
        .reset(reset),
        .is_pack(issued_br_pack),
        .rd_en(br_rd_en),

        .fu_pack(br_fu_out),
        .br_task(br_task),
        .data_ready(br_done)
    );


    //////////////////////////////////////////////////
    //                                              //
    //               complete/commit                //
    //                                              //
    //////////////////////////////////////////////////

    always_comb begin
        cdb_reg_idx = '0;
        cdb_p_reg_idx = '0;
        cdb_valid = '0;
        cdb_wr_data = '0;
        for (int i = 0; i < `N; i++) begin
            cdb_reg_idx[i]   = cdb_entries[i].reg_idx;
            cdb_p_reg_idx[i] = cdb_entries[i].p_reg_idx;
            cdb_valid[i]     = cdb_entries[i].valid;
            cdb_wr_data[i]   = cdb_entries[i].reg_val;
        end
    end

    always_comb begin
        retiring_t_old = '0;

        for (int i = 0; i < `N; i++) begin
            retiring_t_old[i].valid = retiring_data[i].valid;
            retiring_t_old[i].reg_idx = retiring_data[i].t_old;
        end
    end

    //////////////////////////////////////////////////
    //                                              //
    //               pipeline outputs               //
    //                                              //
    //////////////////////////////////////////////////

    // Output the committed instruction to the testbench for counting
    always_comb begin
        committed_insts = '0;
        for (int i = 0; i < `N; i++) begin
            committed_insts[i].NPC = retiring_data[i].PC; // TODO
            committed_insts[i].data = retiring_data[i].data;
            committed_insts[i].reg_idx = retiring_data[i].dest_reg_idx;
            committed_insts[i].halt = retiring_data[i].halt;
            committed_insts[i].illegal = '0; //TODO
            committed_insts[i].valid = retiring_data[i].valid;
        end
    end

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
