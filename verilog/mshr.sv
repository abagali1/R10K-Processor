`include "verilog/sys_defs.svh"

module mshr (
    input               clock,
    input               reset,

    input   logic       valid,
    input   ADDR        in_addr,
    input   DATA        in_data,
    input   MEM_SIZE    st_size,
    input   logic       is_store,

    // From Dcache
    input   logic       Dcache_hit,

    // From memory
    input   MEM_TAG     mem2proc_transaction_tag, // Should be zero unless there is a response
    input   MEM_TAG     mem2proc_data_tag,

    // To memory
    output  MEM_COMMAND proc2mem_command,

    // To cache
    output  ADDR        mshr2cache_addr,
    output  DATA        mshr2cache_data,
    output  MEM_SIZE    mshr2cache_st_size,
    output  logic       mshr2cache_is_store,
    output  logic       mshr2cache_wr,

    // To load and store units
    output  logic       stall

    `ifdef DEBUG
    , output MSHR       debug_mshr
    `endif
);
 
    MSHR mshr, next_mshr;

    assign stall = (mshr.state != NONE);

    `ifdef DEBUG
        `ifndef DC
            always_ff @(posedge clock) begin
                $display("--- mshr inputs ---");
                $display("valid: %b", valid);
                $display("in_addr: %d", in_addr);
                $display("in_data: %d", in_data);
                $display("st_size: %s", st_size.name());
                $display("is_store: %d", is_store);

                $display("Dcache_hit: %d", Dcache_hit);
                $display("mem2proc_transaction_tag: %d", mem2proc_transaction_tag);
                $display("mem2proc_data_tag: %d", mem2proc_data_tag);
                $display("mshr state: %s", mshr.state.name());
                $display("--- mshr inputs ---");
            end
        `endif
    `endif

    //assign mshr2cache_wr = mshr.state == WAITING_FOR_LOAD_DATA;// && mshr.mem_tag !=0 && mem2proc_data_tag == mshr.mem_tag;

    always_comb begin
        next_mshr = mshr;

        proc2mem_command = MEM_NONE;
        mshr2cache_wr = 0;

        if (mshr.state == NONE) begin
            if (!Dcache_hit && valid) begin // make request directly to cashay and see what she says
                proc2mem_command = MEM_LOAD;

                next_mshr.state = WAITING_FOR_LOAD_DATA;
                next_mshr.addr = in_addr;
                next_mshr.data = in_data;
                next_mshr.mem_tag = mem2proc_transaction_tag;
                next_mshr.is_store = is_store;
                next_mshr.st_size = st_size;
            end
        end else begin
            if (mem2proc_data_tag == mshr.mem_tag && mshr.mem_tag != 0) begin
                next_mshr = '0;

                mshr2cache_wr = 1;
                mshr2cache_addr = mshr.addr;

                if (mshr.is_store) begin
                    proc2mem_command = MEM_STORE;
                    mshr2cache_st_size = mshr.st_size;
                    mshr2cache_is_store = mshr.is_store;
                    mshr2cache_data = mshr.data;
                end
            end
        end

        `ifdef DEBUG
            debug_mshr = mshr;
        `endif
    end


    always_ff @(posedge clock) begin
        if (reset) begin
            mshr <= '0;
        end else begin
            mshr <= next_mshr;
        end
    end

endmodule