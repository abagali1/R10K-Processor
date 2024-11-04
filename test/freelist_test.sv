/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  freelist_test.sv                                    //
//                                                                     //
//  Description :  Testbench module for the free list                  //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module freelist_tb();

    parameter DEPTH = `ROB_SZ;
    parameter N = 2;
    localparam LOG_DEPTH = $clog2(DEPTH);

    logic                                           clock;
    logic                                           reset;
    logic                   [$clog2(N+1)-1:0]       rd_num;  // number of regs to take off of the free list
    logic                   [$clog2(N+1)-1:0]       wr_num;  // number of regs to add back to the free list
    FREE_LIST_PACKET        [N-1:0]                 wr_reg;  // reg idxs to add to free list
    logic                                           br_en;  // enable signal for EBR
    FREE_LIST_PACKET        [DEPTH-1:0]             br_fl;  // free list copy for EBR

    FREE_LIST_PACKET        [N-1:0]                 rd_reg;   // displayed available reg idxs, these are always output, and only updated based on rd_num
    FREE_LIST_PACKET        [DEPTH-1:0]             out_fl;   // free list to output
    logic                   [$clog2(DEPTH+1)-1:0]   num_avail; // broadcasting number of regs available

    `ifdef DEBUG
      logic          [LOG_DEPTH-1:0]         debug_head;
      logic          [LOG_DEPTH-1:0]         debug_tail;
    `endif 

    // queue declaration for free_list model
    FREE_LIST_PACKET free_list_model [$:(DEPTH)];
    int popped;
    logic [$clog2(DEPTH)-1:0] k = 0;

    free_list #(
        .DEPTH(DEPTH),
        .N(N)
    )
    dut (
        .clock(clock),
        .reset(reset),
        .rd_num(rd_num),  
        .wr_num(wr_num),  
        .wr_reg(wr_reg),  
        .br_en(br_en),  
        .br_fl(br_fl),  

        .rd_reg(rd_reg),   
        .out_fl(out_fl),   
        .num_avail(num_avail)

        `ifdef DEBUG
        ,   .debug_head(debug_head),
            .debug_tail(debug_tail)
        `endif
    );

    always begin 
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    initial begin
        $display("\nStart Testbench");

        clock = 0;
        reset = 1;
        rd_num = 0;
        wr_num = 0;
        br_fl = 0;
        br_en = 0;

        @(negedge clock);
        @(negedge clock);
        reset = 0;
        
        // ------------------------------ Test 1 ------------------------------ //
        $display("\nTest 1: Check Free List is Full");
        // its just a queue
        reset_free_list();
        @(negedge clock);
        
        clear_inputs();
        @(posedge clock);
        @(negedge clock);

        $display("PASSED TEST 1");

        // ------------------------------ Test 2 ------------------------------ //
        $display("\nTest 2: Check One Entry Popped");
        // its just a queue
        reset_free_list();
        @(negedge clock);
        
        pop_n_from_free_list(1);
        @(negedge clock);
        
        clear_inputs();
        @(posedge clock);
        @(negedge clock);

        $display("PASSED TEST 2");

        // ------------------------------ Test 3 ------------------------------ //
        $finish;

    end

    int cycle_number = 0;
    // Correctness Verification
    always @(posedge clock) begin
        #(`CLOCK_PERIOD * 0.2);
        print_model();
        print_free_list();
        $display("rd_num: %d\n", rd_num);
        check_entries();
        $display("@@@ FINISHED CYCLE NUMBER: %0d @@@ \n", cycle_number);
        cycle_number++;
    end



// test EBR
// initially full
// can empty and fill it back up
// should be able to write and read into the same cycle

// pop_from_free_list function
    // if want to pop all, set N to size
function void pop_n_from_free_list(int num_pop);
    rd_num = num_pop;
    popped += num_pop;
    for (int i = 0; i < num_pop; i++) begin
        free_list_model.pop_front();
    end
endfunction

// add_to_free_list function
function void add_prs_to_free_list(FREE_LIST_PACKET [N-1:0] pr);
    wr_reg = pr;
    for (int i = 0; i < $size(pr); i++) begin
        free_list_model.push_back(pr[i]);
    end
endfunction

// reset free_list function, add all regs + valid bits
function void reset_free_list();
    for (int i = 0; i < DEPTH; i++) begin
        free_list_model[i].reg_idx = i + `ARCH_REG_SZ;
        free_list_model[i].valid = 1;
    end
endfunction

// assert empty
function void assert_empty();
    if (free_list_model.size() == 0) begin
        $error("@@@ FAILED @@@");
        $error("Assert empty error: expected %0d, but got %0d", 0, free_list_model.size());
    end
endfunction

// compare free list model to actual free list
function void check_entries();

    k = debug_head;
    for (int i = 0; i < DEPTH; i++) begin
        if (k == debug_tail && debug_head != 0 && debug_tail != 0) begin // how to account for case where we are just beginning and head and tail are 0
            break;
        end

        if (free_list_model[i].reg_idx != out_fl[k].reg_idx) begin
            $error("@@@ FAILED @@@");
            $error("Check entry error: expected %0d, but got %0d", free_list_model[i].reg_idx, out_fl[k].reg_idx);
            $finish;
        end

        k = (k + 1) % DEPTH;
    end
    
endfunction

function void print_model();
    $display("\nFree List Model");
    for (int i = 0; i < DEPTH; i++) begin
        $display("model[%0d]: %0d", i, free_list_model[i].reg_idx);
    end
endfunction

function void print_free_list();
    $display("\nActual Free List");
    for (int i = 0; i < DEPTH; i++) begin
        $display("free_list[%0d]: %0d", i, out_fl[i].reg_idx);
    end
    $display("\nhead %0d", debug_head);
    $display("tail %0d", debug_tail);
    $display("reset %0d", reset);
endfunction

function void clear_inputs();
    rd_num = 0;
    wr_num = 0;
    wr_reg = 0;
    br_en = 0;
    br_fl = 0;
    reset = 0;
endfunction

endmodule

// model to freelist
// i = 0 to head
// last element to tail