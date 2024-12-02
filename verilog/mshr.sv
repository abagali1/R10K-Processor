`include "verilog/sys_defs.svh"

module mshr (
    input               clock,
    input               reset,

    input   ADDR        in_addr,
    input   DATA        in_data,
    input   MEM_SIZE    st_size,
    input   logic       is_store,

    // From Dcache
    input   logic       Dcache_valid,

    // From memory
    input   MEM_TAG     mem2proc_transaction_tag, // Should be zero unless there is a response
    input   MEM_BLOCK   mem2proc_data,
    input   MEM_TAG     mem2proc_data_tag,

    // To memory
    output  MEM_COMMAND proc2mem_command,

    // To cache
    output  ADDR        mshr2cache_addr,
    output  MEM_SIZE    mshr2cache_st_size,
    output  logic       mshr2cache_is_store,
    output  logic       mshr2cache_wr,

    // To load and store units
    output  logic       stall
);
 
    MSHR mshr, next_mshr;

    assign stall = (mshr.state != NONE);

    always_comb begin
        next_mshr = mshr;

        proc2mem_command = MEM_NONE;
        mshr2cache_wr = 0;

        if (mshr.state == NONE) begin
            if (!Dcache_valid) begin // make request directly to cashay and see what she says
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
                end
            end
        end
    end


    always_ff @(posedge clock) begin
        if (reset) begin
            mshr <= next_mshr;
        end else begin
            mshr <= next_mshr;
        end
    end

endmodule